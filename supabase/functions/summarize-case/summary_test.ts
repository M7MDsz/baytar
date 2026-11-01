// US-24 unit tests for the pure parts of summarize-case. No network: run with
//   deno test supabase/functions/summarize-case/

import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  AiError,
  buildSourceText,
  isGrounded,
  normalizeForMatch,
  readSummary,
  SUMMARY_INSTRUCTION,
  SUMMARY_SCHEMA,
  summaryRequest,
} from "./summary.ts";

const SOURCE = buildSourceText(
  "قطتي ما تاكل من يومين، وتستفرغ بعد الأكل.",
  "بدأ فجأة بعد ما أكلت من الأرض، وبطنها منتفخ",
  "done",
);

function reply(body: unknown, finishReason = "STOP") {
  return { candidates: [{ finishReason, content: { parts: [{ text: JSON.stringify(body) }] } }] };
}

function failsWith(fn: () => unknown, code: string) {
  const e = assertThrows(fn, AiError);
  assertEquals(e.code, code);
}

const GOOD = {
  has_symptoms: true,
  chief_complaint: { value: "فقدان الشهية", quote: "ما تاكل من يومين" },
  duration: { value: "يومان", quote: "من يومين" },
  onset: { value: "فجأة بعد أكل شيء من الأرض", quote: "بدأ فجأة بعد ما أكلت من الأرض" },
  affected_area: { value: "البطن", quote: "بطنها منتفخ" },
  symptoms: [
    { value: "فقدان الشهية", quote: "ما تاكل" },
    { value: "قيء بعد الأكل", quote: "وتستفرغ بعد الأكل" },
    { value: "انتفاخ البطن", quote: "بطنها منتفخ" },
  ],
};

Deno.test("the source is the written description plus a confirmed transcript only", () => {
  assertEquals(buildSourceText(" يعرج ", "كلبي يعرج", "done"), "الوصف المكتوب:\nيعرج\n\nنص التسجيل الصوتي:\nكلبي يعرج");
  assertEquals(buildSourceText("يعرج", null, null), "الوصف المكتوب:\nيعرج");
  assertEquals(buildSourceText(null, "كلبي يعرج", "done"), "نص التسجيل الصوتي:\nكلبي يعرج");
  assertEquals(buildSourceText("يعرج", "نص لم يكتمل", "pending"), "الوصف المكتوب:\nيعرج");
  assertEquals(buildSourceText("  ", null, "failed"), "");
});

Deno.test("the request uses temperature 0, a JSON schema, a thinking budget and the strict rules", () => {
  const body = summaryRequest(SOURCE);
  assertEquals(body.generationConfig.temperature, 0);
  assertEquals(body.generationConfig.responseMimeType, "application/json");
  assertEquals(body.generationConfig.responseSchema, SUMMARY_SCHEMA);
  assertEquals(body.generationConfig.thinkingConfig, { thinkingBudget: 0 });
  assert(body.contents[0].parts[0].text.includes(SOURCE));
  assertEquals(Object.keys(SUMMARY_SCHEMA.properties), [
    "has_symptoms",
    "chief_complaint",
    "duration",
    "onset",
    "affected_area",
    "symptoms",
  ]);
  for (const rule of ["Use only what is written", "Never diagnose", "Arabic", "has_symptoms", "NOT a diagnosis"]) {
    assert(SUMMARY_INSTRUCTION.includes(rule), rule);
  }
});

Deno.test("a grounded answer becomes a generated summary", () => {
  const result = readSummary(reply(GOOD), SOURCE);
  assertEquals(result.status, "generated");
  if (result.status !== "generated") return;
  assertEquals(result.content.chief_complaint, GOOD.chief_complaint);
  assertEquals(result.content.duration, GOOD.duration);
  assertEquals(result.content.onset, GOOD.onset);
  assertEquals(result.content.affected_area, GOOD.affected_area);
  assertEquals(result.content.symptoms, GOOD.symptoms);
});

Deno.test("anything not in the description is dropped, and so is any field outside the schema", () => {
  const result = readSummary(
    reply({
      ...GOOD,
      diagnosis: "التهاب المعدة",
      duration: { value: "أسبوع", quote: "منذ أسبوع" },
      symptoms: [...GOOD.symptoms, { value: "حمى", quote: "حرارتها عالية" }],
    }),
    SOURCE,
  );
  assertEquals(result.status, "generated");
  if (result.status !== "generated") return;
  assert(!("diagnosis" in result.content));
  assertEquals(result.content.duration, null);
  assertEquals(result.content.symptoms.map((s) => s.value), ["فقدان الشهية", "قيء بعد الأكل", "انتفاخ البطن"]);
});

Deno.test("missing, empty and malformed fields are left out", () => {
  const result = readSummary(
    reply({
      has_symptoms: true,
      chief_complaint: { value: "  ", quote: "ما تاكل" },
      onset: "فجأة",
      symptoms: [{ value: "فقدان الشهية", quote: "ما تاكل" }, "قيء", { value: "فقدان الشهية", quote: "ما تاكل" }],
    }),
    SOURCE,
  );
  assertEquals(result, {
    status: "generated",
    content: {
      chief_complaint: null,
      duration: null,
      onset: null,
      affected_area: null,
      symptoms: [{ value: "فقدان الشهية", quote: "ما تاكل" }],
    },
  });
});

Deno.test("no symptom in the description means no summary", () => {
  assertEquals(readSummary(reply({ has_symptoms: false, symptoms: [] }), SOURCE), { status: "not_generated" });
  assertEquals(readSummary(reply({ has_symptoms: true, symptoms: [] }), SOURCE), { status: "not_generated" });
  assertEquals(readSummary(reply({ has_symptoms: false, symptoms: GOOD.symptoms }), SOURCE), {
    status: "not_generated",
  });
});

Deno.test("symptoms that are all invented are a failure, not a summary", () => {
  failsWith(() => readSummary(reply({ has_symptoms: true, symptoms: [{ value: "حمى", quote: "حرارتها عالية" }] }), SOURCE), "ungrounded");
});

Deno.test("blocked, cut-off, empty and malformed replies are failures", () => {
  failsWith(() => readSummary({ promptFeedback: { blockReason: "SAFETY" } }, SOURCE), "blocked");
  failsWith(() => readSummary(reply(GOOD, "SAFETY"), SOURCE), "blocked");
  failsWith(() => readSummary(reply(GOOD, "MAX_TOKENS"), SOURCE), "truncated");
  failsWith(() => readSummary({ candidates: [] }, SOURCE), "empty");
  failsWith(() => readSummary(undefined, SOURCE), "empty");
  failsWith(() => readSummary({ candidates: [{ content: { parts: [{ text: "ملخص الحالة" }] } }] }, SOURCE), "bad_json");
  failsWith(() => readSummary(reply([GOOD]), SOURCE), "bad_json");
  failsWith(() => readSummary(reply({ has_symptoms: "yes", symptoms: [] }), SOURCE), "bad_json");
  failsWith(() => readSummary(reply({ has_symptoms: true, symptoms: "قيء" }), SOURCE), "bad_json");
});

Deno.test("quotes match despite diacritics, alef forms, digits and punctuation", () => {
  assertEquals(normalizeForMatch("أُصيبَ  بالإسهال!"), "اصيب بالاسهال");
  assertEquals(normalizeForMatch("منذ ٣ أيام"), "منذ 3 ايام");
  assert(isGrounded("تستفرغ بعد الأكل", "وتستفرغُ بعدَ الاكل."));
  assert(isGrounded("منذ 3 أيام", "يعرج منذ ٣ ايام"));
  assert(!isGrounded("حرارة", "يعرج منذ ٣ ايام"));
  assert(!isGrounded("، .", "يعرج"));
});
