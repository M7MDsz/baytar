// US-36 unit tests for the pure parts of transcribe-voice. No network: run with
//   deno test supabase/functions/transcribe-voice/

import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  AiError,
  audioMimeType,
  isOwnVoicePath,
  readTranscript,
  toBase64,
  TRANSCRIBE_INSTRUCTION,
  transcriptionRequest,
} from "./transcribe.ts";

const OWNER = "11111111-1111-1111-1111-111111111111";
const CASE = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";

function reply(text: string, finishReason = "STOP") {
  return { candidates: [{ finishReason, content: { parts: [{ text }] } }] };
}

function failsWith(fn: () => unknown, code: string) {
  const e = assertThrows(fn, AiError);
  assertEquals(e.code, code);
}

Deno.test("only the owner's own recording of this case is accepted", () => {
  assert(isOwnVoicePath(`${OWNER}/${CASE}/1730000000000-ab12.m4a`, OWNER, CASE));
  assert(!isOwnVoicePath(`22222222-2222-2222-2222-222222222222/${CASE}/a.m4a`, OWNER, CASE), "another owner");
  assert(!isOwnVoicePath(`${OWNER}/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb/a.m4a`, OWNER, CASE), "another case");
  assert(!isOwnVoicePath(`${OWNER}/${CASE}/x/a.m4a`, OWNER, CASE), "deeper folder");
  assert(!isOwnVoicePath(`${OWNER}/${CASE}/..`, OWNER, CASE), "dot file");
  assert(!isOwnVoicePath(`${OWNER}/${CASE}/`, OWNER, CASE), "no file name");
});

Deno.test("audio type comes from the stored content type, else from the extension", () => {
  assertEquals(audioMimeType("a/b/c.m4a", "audio/mp4"), "audio/mp4");
  assertEquals(audioMimeType("a/b/c.m4a", "audio/m4a"), "audio/mp4");
  assertEquals(audioMimeType("a/b/c.aac", "audio/aac; charset=binary"), "audio/aac");
  assertEquals(audioMimeType("a/b/c.m4a", "application/octet-stream"), "audio/mp4");
  assertEquals(audioMimeType("a/b/c.AAC", null), "audio/aac");
  assertEquals(audioMimeType("a/b/c", ""), "audio/mp4");
});

Deno.test("base64 encodes small and large recordings exactly", () => {
  assertEquals(toBase64(new TextEncoder().encode("hello")), btoa("hello"));
  const big = new Uint8Array(100_000).map((_, i) => (i * 7) % 256);
  const decoded = Uint8Array.from(atob(toBase64(big)), (ch) => ch.charCodeAt(0));
  assertEquals(decoded, big);
});

Deno.test("the request sends inline audio, asks for a verbatim transcript, and sets a thinking budget", () => {
  const body = transcriptionRequest("QUJD", "audio/mp4");
  assertEquals(body.contents[0].parts[0], { inlineData: { mimeType: "audio/mp4", data: "QUJD" } });
  assertEquals(body.generationConfig.temperature, 0);
  assertEquals(body.generationConfig.responseMimeType, "application/json");
  assertEquals(body.generationConfig.responseSchema.required, ["transcript"]);
  assertEquals(body.generationConfig.thinkingConfig, { thinkingBudget: 0 });
  assert(TRANSCRIBE_INSTRUCTION.includes("verbatim"));
  assert(TRANSCRIBE_INSTRUCTION.includes("Do not summarise"));
  assert(TRANSCRIBE_INSTRUCTION.includes("Arabic script"));
});

Deno.test("a good reply gives the trimmed transcript", () => {
  const text = readTranscript(reply(JSON.stringify({ transcript: "  قطتي ما تاكل   من يومين  " })));
  assertEquals(text, "قطتي ما تاكل من يومين");
});

Deno.test("thinking parts are ignored", () => {
  const r = {
    candidates: [{
      finishReason: "STOP",
      content: { parts: [{ text: "thinking...", thought: true }, { text: '{"transcript":"كلبي يعرج"}' }] },
    }],
  };
  assertEquals(readTranscript(r), "كلبي يعرج");
});

Deno.test("blocked, cut-off, empty and malformed replies are failures", () => {
  failsWith(() => readTranscript({ promptFeedback: { blockReason: "SAFETY" } }), "blocked");
  failsWith(() => readTranscript(reply('{"transcript":"x"}', "SAFETY")), "blocked");
  failsWith(() => readTranscript(reply('{"transcript":"x', "MAX_TOKENS")), "truncated");
  failsWith(() => readTranscript({ candidates: [] }), "empty");
  failsWith(() => readTranscript(null), "empty");
  failsWith(() => readTranscript(reply("   ")), "empty");
  failsWith(() => readTranscript(reply("Here is the transcript")), "bad_json");
  failsWith(() => readTranscript(reply('{"text":"x"}')), "bad_json");
  failsWith(() => readTranscript(reply('{"transcript":"   "}')), "no_speech");
});
