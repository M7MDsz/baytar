// Unit tests for the Gemini model fallback. No network: run with
//   deno test supabase/functions/_shared/

import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { DEFAULT_FALLBACK_MODELS, FallbackError, modelChain, withModelFallback } from "./model_fallback.ts";

class Coded extends Error {
  constructor(readonly code: string) {
    super(code);
  }
}

const opts = { perAttemptMs: 30_000, deadlineMs: 40_000 };

Deno.test("the chain starts with GEMINI_MODEL and then the defaults, without duplicates", () => {
  assertEquals(modelChain("gemini-3.5-flash", undefined), ["gemini-3.5-flash", ...DEFAULT_FALLBACK_MODELS]);
  assertEquals(modelChain(undefined, "")[0], "gemini-3.5-flash");
  assertEquals(modelChain("a", " b , a ,, c "), ["a", "b", "c"]);
  assertEquals(modelChain("a", "none"), ["a"]);
});

Deno.test("a model out of quota hands over to the next one", async () => {
  const tried: string[] = [];
  const r = await withModelFallback(["m1", "m2", "m3"], (model) => {
    tried.push(model);
    if (model === "m1") throw new Coded("http_429");
    if (model === "m2") throw new Coded("http_503");
    return Promise.resolve(`text from ${model}`);
  }, opts);
  assertEquals(r.value, "text from m3");
  assertEquals(r.model, "m3");
  assertEquals(tried, ["m1", "m2", "m3"]);
  assertEquals(r.attempts, [{ model: "m1", code: "http_429" }, { model: "m2", code: "http_503" }]);
});

Deno.test("the first model answering ends the chain at once", async () => {
  let calls = 0;
  const r = await withModelFallback(["m1", "m2"], () => {
    calls++;
    return Promise.resolve(1);
  }, opts);
  assertEquals([r.model, calls, r.attempts.length], ["m1", 1, 0]);
});

Deno.test("refused content is final: no other model is asked", async () => {
  let calls = 0;
  const e = await assertRejects(
    () =>
      withModelFallback(["m1", "m2"], () => {
        calls++;
        throw new Coded("blocked");
      }, opts),
    FallbackError,
  );
  assertEquals([e.code, calls], ["blocked", 1]);
});

Deno.test("when every model fails, the last failure code is reported", async () => {
  const e = await assertRejects(
    () => withModelFallback(["m1", "m2"], (m) => Promise.reject(new Coded(m === "m1" ? "http_429" : "empty")), opts),
    FallbackError,
  );
  assertEquals(e.code, "empty");
  assertEquals(e.attempts.map((a) => a.code), ["http_429", "empty"]);
});

Deno.test("no new model is tried once the deadline has passed", async () => {
  let t = 0;
  const tried: string[] = [];
  const e = await assertRejects(
    () =>
      withModelFallback(["m1", "m2", "m3"], (model) => {
        tried.push(model);
        t += 39_500; // the first try uses up almost all of the 40 s
        throw new Coded("timeout");
      }, { ...opts, now: () => t }),
    FallbackError,
  );
  assertEquals(tried, ["m1"]);
  assertEquals(e.code, "timeout");
});

Deno.test("an error without a code counts as a network failure", async () => {
  const e = await assertRejects(
    () => withModelFallback(["m1"], () => Promise.reject(new TypeError("fetch failed")), opts),
    FallbackError,
  );
  assertEquals(e.code, "network");
});
