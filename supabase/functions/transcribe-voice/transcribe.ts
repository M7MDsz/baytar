// US-36: the pure parts of transcribe-voice (no network), so they can be unit tested with `deno test`.

/** Gemini must answer within this time, or the transcript is stored as failed (criterion: transcript within 30 s). */
export const TIMEOUT_MS = 25_000;

/** Gemini takes inline audio up to about 20 MB per request; base64 adds a third, so larger files are refused. */
export const MAX_AUDIO_BYTES = 10 * 1024 * 1024;

/** A failure with a short code that is safe to store and show in logs (never a URL or a key). */
export class AiError extends Error {
  constructor(readonly code: string) {
    super(code);
  }
}

/** Loudest sample below this (about -40 dBFS) means nothing was picked up: a muted or wrong microphone. */
export const SILENCE_PEAK = 0.01;

/**
 * The loudest sample of a 16-bit PCM WAV recording (the web app records these), from 0 to 1, or null for any other
 * format (phones record AAC, which is not decoded here).
 */
export function wavPeak(bytes: Uint8Array): number | null {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const tag = (at: number) => String.fromCharCode(...bytes.subarray(at, at + 4));
  if (bytes.length < 12 || tag(0) !== "RIFF" || tag(8) !== "WAVE") return null;
  let pcm16 = false;
  for (let at = 12; at + 8 <= bytes.length;) {
    const id = tag(at);
    const size = view.getUint32(at + 4, true);
    const body = at + 8;
    if (id === "fmt ") {
      pcm16 = view.getUint16(body, true) === 1 && view.getUint16(body + 14, true) === 16;
    } else if (id === "data") {
      if (!pcm16) return null;
      const end = Math.min(body + size, bytes.length) & ~1;
      let peak = 0;
      for (let i = body; i < end; i += 2) peak = Math.max(peak, Math.abs(view.getInt16(i, true)));
      return peak / 32768;
    }
    at = body + size + (size % 2);
  }
  return null;
}

/**
 * True when the recording is a WAV with no sound in it. Such a recording is never sent to Gemini: given silence, a
 * model can invent a believable description, which is worse than no transcript.
 */
export function isSilentRecording(bytes: Uint8Array): boolean {
  const peak = wavPeak(bytes);
  return peak !== null && peak < SILENCE_PEAK;
}

/** Recordings are saved as <owner id>/<case id>/<file> (US-04). Anything else is not this owner's recording. */
export function isOwnVoicePath(path: string, ownerId: string, caseId: string): boolean {
  const parts = path.split("/");
  return parts.length === 3 && parts[0] === ownerId && parts[1] === caseId &&
    /^[\w.-]+$/.test(parts[2]) && !parts[2].startsWith(".");
}

const MIME_BY_EXTENSION: Record<string, string> = { m4a: "audio/mp4", mp4: "audio/mp4", aac: "audio/aac" };

/** The audio type to send to Gemini: the stored content type when it is audio, otherwise from the file extension. */
export function audioMimeType(path: string, contentType?: string | null): string {
  const type = (contentType ?? "").split(";")[0].trim().toLowerCase();
  if (type.startsWith("audio/")) return type === "audio/m4a" ? "audio/mp4" : type;
  const extension = path.split(".").pop()?.toLowerCase() ?? "";
  return MIME_BY_EXTENSION[extension] ?? "audio/mp4";
}

export function toBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}

export const TRANSCRIBE_INSTRUCTION = [
  "You transcribe a voice note recorded by an animal owner in Saudi Arabia who is describing their animal's problem",
  "to a veterinarian. The speech is usually Arabic, often in a Saudi or other dialect.",
  "Write a verbatim transcript in Arabic script: every word as spoken, in the order spoken, keeping the dialect.",
  "Do not summarise, shorten, translate, correct, explain, reorder or add anything, and do not answer the speaker.",
  "Write numbers as the speaker said them. If a word cannot be understood, write [غير واضح] in its place.",
  'If there is no speech in the recording, return an empty "transcript".',
].join("\n");

const TRANSCRIPT_SCHEMA = {
  type: "OBJECT",
  properties: { transcript: { type: "STRING" } },
  required: ["transcript"],
};

/** The generateContent request body: the recording as inline audio plus a strict verbatim instruction. */
export function transcriptionRequest(audioBase64: string, mimeType: string) {
  return {
    systemInstruction: { parts: [{ text: TRANSCRIBE_INSTRUCTION }] },
    contents: [{
      role: "user",
      parts: [
        { inlineData: { mimeType, data: audioBase64 } },
        { text: "اكتب نص هذا التسجيل حرفيًا." },
      ],
    }],
    generationConfig: {
      temperature: 0,
      maxOutputTokens: 8192,
      responseMimeType: "application/json",
      responseSchema: TRANSCRIPT_SCHEMA,
      // Without a thinking budget this model has returned empty replies; transcription needs no thinking.
      thinkingConfig: { thinkingBudget: 0 },
    },
  };
}

type GeminiReply = {
  promptFeedback?: { blockReason?: string };
  candidates?: { finishReason?: string; content?: { parts?: { text?: string; thought?: boolean }[] } }[];
};

/** The answer text of a generateContent reply. A blocked, cut-off or empty reply is a failure. */
export function geminiText(reply: unknown): string {
  const r = (reply ?? {}) as GeminiReply;
  if (r.promptFeedback?.blockReason) throw new AiError("blocked");
  const candidate = r.candidates?.[0];
  if (!candidate) throw new AiError("empty");
  const finish = candidate.finishReason ?? "STOP";
  if (finish === "MAX_TOKENS") throw new AiError("truncated");
  if (finish !== "STOP") throw new AiError("blocked");
  const text = (candidate.content?.parts ?? [])
    .filter((p) => !p.thought && typeof p.text === "string")
    .map((p) => p.text)
    .join("")
    .trim();
  if (!text) throw new AiError("empty");
  return text;
}

/** The transcript from a Gemini reply, or an AiError (blocked, empty, bad_json, no_speech). */
export function readTranscript(reply: unknown): string {
  let parsed: unknown;
  try {
    parsed = JSON.parse(geminiText(reply));
  } catch (e) {
    if (e instanceof AiError) throw e;
    throw new AiError("bad_json");
  }
  const transcript = (parsed as { transcript?: unknown })?.transcript;
  if (typeof transcript !== "string") throw new AiError("bad_json");
  const text = transcript.replace(/[ \t]+/g, " ").trim();
  if (!text) throw new AiError("no_speech");
  return text;
}
