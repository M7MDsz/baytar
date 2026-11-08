// US-36: turns the saved voice description of a DRAFT case into an Arabic transcript.
// The app calls it after saving a recording. The caller must own the draft; the recording is read with the
// service role and sent to Gemini. The result is stored on the case as an automatic transcript (auto/done) or as
// failed, and the case can always be sent with the recording alone. The owner may then correct the text.

import { createClient } from "npm:@supabase/supabase-js@2";
import { FallbackError, modelChain, withModelFallback } from "../_shared/model_fallback.ts";
import {
  AiError,
  audioMimeType,
  isOwnVoicePath,
  MAX_AUDIO_BYTES,
  readTranscript,
  TIMEOUT_MS,
  toBase64,
  transcriptionRequest,
} from "./transcribe.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

/** The app waits about 45 seconds for the transcript, so every model in the chain must be done well before that. */
const DEADLINE_MS = 40_000;

async function transcribe(audio: Uint8Array, mimeType: string): Promise<string> {
  const key = Deno.env.get("GEMINI_API_KEY");
  if (!key) throw new AiError("not_configured");
  const body = JSON.stringify(transcriptionRequest(toBase64(audio), mimeType));
  const models = modelChain(Deno.env.get("GEMINI_MODEL"), Deno.env.get("GEMINI_FALLBACK_MODELS"));
  try {
    const { value, model, attempts } = await withModelFallback(models, async (model, signal) => {
      const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": key },
        body,
        signal,
      });
      if (!res.ok) throw new AiError(`http_${res.status}`);
      return readTranscript(await res.json());
    }, { perAttemptMs: TIMEOUT_MS, deadlineMs: DEADLINE_MS });
    if (attempts.length) console.warn(`transcribe-voice: ${model} answered after ${JSON.stringify(attempts)}`);
    return value;
  } catch (e) {
    if (e instanceof FallbackError) {
      console.error(`transcribe-voice: every model failed ${JSON.stringify(e.attempts)}`);
      throw new AiError(e.code);
    }
    throw e;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const authorization = req.headers.get("Authorization");
  if (!authorization) return json({ error: "unauthorized" }, 401);

  const { caseId } = await req.json().catch(() => ({}));
  if (typeof caseId !== "string") return json({ error: "bad_request" }, 400);

  const url = Deno.env.get("SUPABASE_URL")!;
  const asUser = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authorization } },
  });
  const { data: { user } } = await asUser.auth.getUser();
  if (!user) return json({ error: "unauthorized" }, 401);

  // 1. The caller must own the case and it must still be a draft (read as the caller, so row security applies too).
  const { data: c } = await asUser
    .from("cases")
    .select("id, owner_id, status, voice_path")
    .eq("id", caseId)
    .maybeSingle();
  if (!c || c.owner_id !== user.id) return json({ error: "case_not_found" }, 404);
  if (c.status !== "draft") return json({ error: "not_draft" }, 409);
  if (!c.voice_path || !isOwnVoicePath(c.voice_path, user.id, caseId)) return json({ error: "no_recording" }, 400);
  const voicePath: string = c.voice_path;

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const sameDraft = { id: caseId, status: "draft", voice_path: voicePath };
  await admin
    .from("cases")
    .update({ transcript: null, transcript_source: null, transcript_status: "pending" })
    .match(sameDraft);

  // 2-3. Download the recording with the service role and ask Gemini for a verbatim Arabic transcript.
  let transcript: string | null = null;
  let reason: string | null = null;
  try {
    const { data: file, error } = await admin.storage.from("case-voice").download(voicePath);
    if (error || !file) throw new AiError("download_failed");
    if (file.size > MAX_AUDIO_BYTES) throw new AiError("too_large");
    transcript = await transcribe(new Uint8Array(await file.arrayBuffer()), audioMimeType(voicePath, file.type));
  } catch (e) {
    reason = e instanceof AiError ? e.code : "error";
    console.error(`transcribe-voice ${caseId}: ${reason}`);
  }

  // 4. Store the result, unless meanwhile the owner sent the case, replaced the recording or typed a correction.
  const result = transcript
    ? { transcript, transcript_source: "auto", transcript_status: "done" }
    : { transcript: null, transcript_source: null, transcript_status: "failed" };
  const { data: stored, error: storeError } = await admin
    .from("cases")
    .update(result)
    .match({ ...sameDraft, transcript_status: "pending" })
    .select("id");
  if (storeError) return json({ error: "server_error" }, 500);
  if (!stored?.length) return json({ error: "case_changed" }, 409);

  return json({ status: result.transcript_status, transcript, reason });
});
