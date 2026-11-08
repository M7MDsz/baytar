// US-24: builds the AI-structured summary of a sent case for the veterinarian.
// Called by the cases_request_summary database trigger (pg_net) with a shared secret, like push-dispatch.
// Only the owner's own words are used (the written description and the transcript confirmed at submission), and every
// item must quote them; anything the model adds that is not in the description is dropped. Calling it again for the
// same case is safe: store_case_summary never replaces a summary that was generated or reviewed.

import { createClient } from "npm:@supabase/supabase-js@2";
import { FallbackError, modelChain, withModelFallback } from "../_shared/model_fallback.ts";
import { AiError, buildSourceText, readSummary, summaryRequest, type SummaryResult, TIMEOUT_MS } from "./summary.ts";

/** The summary runs in the background (the database trigger does not wait), so the chain may take up to a minute. */
const DEADLINE_MS = 60_000;

/** Tries each model in the chain until one gives a usable summary; returns it with the model that answered. */
async function summarize(sourceText: string, models: string[]): Promise<{ result: SummaryResult; model: string }> {
  const key = Deno.env.get("GEMINI_API_KEY");
  if (!key) throw new AiError("not_configured");
  const body = JSON.stringify(summaryRequest(sourceText));
  try {
    const { value, model, attempts } = await withModelFallback(models, async (model, signal) => {
      const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": key },
        body,
        signal,
      });
      if (!res.ok) throw new AiError(`http_${res.status}`);
      return readSummary(await res.json(), sourceText);
    }, { perAttemptMs: TIMEOUT_MS, deadlineMs: DEADLINE_MS });
    if (attempts.length) console.warn(`summarize-case: ${model} answered after ${JSON.stringify(attempts)}`);
    return { result: value, model };
  } catch (e) {
    if (e instanceof FallbackError) {
      console.error(`summarize-case: every model failed ${JSON.stringify(e.attempts)}`);
      throw new AiError(e.code);
    }
    throw e;
  }
}

Deno.serve(async (req) => {
  const secret = Deno.env.get("AI_WEBHOOK_SECRET");
  if (!secret || req.headers.get("Authorization") !== `Bearer ${secret}`) {
    return new Response("unauthorized", { status: 401 });
  }
  const { case_id: caseId } = await req.json().catch(() => ({}));
  if (typeof caseId !== "string") return Response.json({ error: "bad_request" }, { status: 400 });

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: c } = await admin
    .from("cases")
    .select("status, description, transcript, transcript_status")
    .eq("id", caseId)
    .maybeSingle();
  if (!c) return Response.json({ error: "case_not_found" }, { status: 404 });
  if (c.status === "draft") return Response.json({ error: "case_not_submitted" }, { status: 409 });

  const { data: existing } = await admin.from("case_summaries").select("status").eq("case_id", caseId).maybeSingle();
  if (existing && existing.status !== "pending" && existing.status !== "failed") {
    return Response.json({ status: existing.status, skipped: true });
  }

  const models = modelChain(Deno.env.get("GEMINI_MODEL"), Deno.env.get("GEMINI_FALLBACK_MODELS"));
  let model = models[0];
  const sourceText = buildSourceText(c.description, c.transcript, c.transcript_status);
  let result: SummaryResult | null = null;
  let reason: string | null = null;
  if (!sourceText) {
    result = { status: "not_generated" };
    reason = "no_text";
  } else {
    try {
      ({ result, model } = await summarize(sourceText, models));
    } catch (e) {
      reason = e instanceof AiError ? e.code : "error";
      console.error(`summarize-case ${caseId}: ${reason}`);
    }
  }

  const { data: status, error } = await admin.rpc("store_case_summary", {
    p_case: caseId,
    p_status: result?.status ?? "failed",
    p_content: result?.status === "generated" ? result.content : null,
    p_source_text: sourceText || null,
    p_model: model,
    p_failure_reason: reason,
  });
  if (error) return Response.json({ error: "server_error" }, { status: 500 });
  return Response.json({ status });
});
