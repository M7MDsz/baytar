import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  ACCOUNT_CEILING,
  activeLock,
  afterAccountFailure,
  afterClientFailure,
  clientAddress,
  clientKey,
  type Counter,
  MAX_FAILURES,
} from "./attempts.ts";

const now = new Date("2026-11-03T09:00:00Z");
const minutes = (m: number) => new Date(now.getTime() + m * 60_000);

Deno.test("US-30: 5 failures in a row from one client lock it for 15 minutes", () => {
  let row: Counter | null = null;
  for (let i = 1; i < MAX_FAILURES; i++) {
    row = afterClientFailure(row, now);
    assertEquals(row, { failures: i, locked_until: null });
  }
  row = afterClientFailure(row, now);
  assertEquals(row.locked_until, minutes(15).toISOString());
  assertEquals(activeLock(row, minutes(14)), row.locked_until);
  assertEquals(activeLock(row, minutes(15)), null);
});

Deno.test("a lock that has run out starts a fresh count", () => {
  const row = afterClientFailure({ failures: 0, locked_until: minutes(-1).toISOString() }, now);
  assertEquals(row, { failures: 1, locked_until: null });
});

Deno.test("QA M-5: the account-wide counter locks only at 20 failures within 15 minutes", () => {
  let row: Counter | null = null;
  for (let i = 1; i < ACCOUNT_CEILING; i++) {
    row = afterAccountFailure(row, now);
    assertEquals(row.failures, i);
    assertEquals(row.locked_until, null);
    assertEquals(row.window_started_at, now.toISOString());
  }
  row = afterAccountFailure(row, now);
  assertEquals(row.locked_until, minutes(15).toISOString());
});

Deno.test("QA M-5: account failures older than the window are forgotten", () => {
  const old: Counter = { failures: 19, locked_until: null, window_started_at: minutes(-16).toISOString() };
  const row = afterAccountFailure(old, now);
  assertEquals(row, { failures: 1, locked_until: null, window_started_at: now.toISOString() });
});

Deno.test("an old counter without a window starts one", () => {
  const row = afterAccountFailure({ failures: 3, locked_until: null }, now);
  assertEquals(row, { failures: 1, locked_until: null, window_started_at: now.toISOString() });
});

Deno.test("the client is Cloudflare's address, then the first forwarded one, and is stored hashed", async () => {
  assertEquals(clientAddress(new Headers({ "cf-connecting-ip": "203.0.113.7", "x-forwarded-for": "198.51.100.1" })), "203.0.113.7");
  assertEquals(clientAddress(new Headers({ "x-forwarded-for": "198.51.100.1, 10.0.0.1" })), "198.51.100.1");
  assertEquals(clientAddress(new Headers()), "unknown");
  const key = await clientKey("203.0.113.7");
  assertEquals(key.length, 64);
  assert(!key.includes("203.0.113.7"));
  assertEquals(key, await clientKey("203.0.113.7"));
});
