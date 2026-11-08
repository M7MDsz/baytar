// Gemini model fallback for the AI functions (transcribe-voice, summarize-case).
// On the free tier every model has its own daily request limit. When one model is out of quota (429), overloaded
// (5xx), times out or answers with something unusable, the next model in the chain is tried, so one model's limit
// does not stop a demo. Pure apart from the `call` it is given, so it is unit tested with `deno test`.

/**
 * Tried in this order after the primary model. Checked live on 8 Nov 2026 with the real transcription (Arabic audio)
 * and summary requests: both models accept audio, the JSON response schema and thinkingBudget 0. Rejected then:
 * gemini-3.5-flash-lite and gemini-flash-lite-latest (400 on thinkingBudget 0), gemini-3.7-flash and gemini-3.8-flash
 * (over 30 s), gemini-2.5-* (closed to new keys).
 */
export const DEFAULT_FALLBACK_MODELS = ["gemini-3-flash-preview", "gemini-3.1-flash-lite"];

/**
 * Codes after which another model must not be asked: the content was refused, nothing is configured, or a model
 * heard no speech. "No speech" is an answer, not a failure; asking another model invites one that invents a sentence.
 */
const FINAL_CODES = new Set(["blocked", "not_configured", "no_speech"]);

export type Attempt = { model: string; code: string };

/** The whole chain failed. `code` is the last model's failure code; `attempts` lists every try (no URLs, no keys). */
export class FallbackError extends Error {
  constructor(readonly code: string, readonly attempts: Attempt[]) {
    super(code);
  }
}

/**
 * The models to try, in order: the primary (GEMINI_MODEL), then GEMINI_FALLBACK_MODELS (comma separated) or the
 * defaults. Duplicates and blanks are removed. Setting GEMINI_FALLBACK_MODELS to "none" turns the fallback off.
 */
export function modelChain(primary: string | undefined, fallbacks: string | undefined): string[] {
  const first = primary?.trim() || "gemini-3.5-flash";
  const rest = fallbacks?.trim().toLowerCase() === "none"
    ? []
    : fallbacks?.trim()
    ? fallbacks.split(",")
    : DEFAULT_FALLBACK_MODELS;
  return [...new Set([first, ...rest].map((m) => m.trim()).filter(Boolean))];
}

/** A short, safe code for any failure: an error's own `code`, or timeout / network. */
export function failureCode(e: unknown): string {
  const code = (e as { code?: unknown } | null)?.code;
  if (typeof code === "string" && code) return code;
  if (e instanceof DOMException && (e.name === "TimeoutError" || e.name === "AbortError")) return "timeout";
  return "network";
}

/**
 * Runs `call` with each model in turn until one succeeds. Each try gets at most `perAttemptMs`, and no try starts
 * once `deadlineMs` (counted from the start) has passed, so the caller's own time limit is respected.
 */
export async function withModelFallback<T>(
  models: string[],
  call: (model: string, signal: AbortSignal) => Promise<T>,
  opts: { perAttemptMs: number; deadlineMs: number; now?: () => number },
): Promise<{ value: T; model: string; attempts: Attempt[] }> {
  const now = opts.now ?? Date.now;
  const start = now();
  const attempts: Attempt[] = [];
  for (const model of models) {
    const left = opts.deadlineMs - (now() - start);
    if (left < 1_000) break;
    try {
      const value = await call(model, AbortSignal.timeout(Math.min(opts.perAttemptMs, left)));
      return { value, model, attempts };
    } catch (e) {
      const code = failureCode(e);
      attempts.push({ model, code });
      if (FINAL_CODES.has(code)) break;
    }
  }
  throw new FallbackError(attempts.at(-1)?.code ?? "timeout", attempts);
}
