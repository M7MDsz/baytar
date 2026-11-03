// US-30 lockout rules, kept free of I/O so they can be tested.
//
// QA M-5: the old counter was keyed on the email alone, so anyone could lock a real owner out with 5 wrong
// passwords from anywhere. Now there are two counters:
//   * per account AND client (the caller's address): 5 failures in a row lock that account from that client for
//     15 minutes. This is the US-30 rule as the user meets it.
//   * per account from all clients together: 20 failures within 15 minutes lock the account everywhere for
//     15 minutes, so guessing from many addresses stays bounded.
// A stranger on another network therefore needs 4 addresses to lock an owner out, and cannot do it from one.

export const MAX_FAILURES = 5;
export const ACCOUNT_CEILING = 20;
export const LOCK_MINUTES = 15;
const WINDOW_MS = LOCK_MINUTES * 60_000;

/** A stored counter: login_attempts (per account) or login_attempts_by_client (per account and client). */
export interface Counter {
  failures: number;
  locked_until: string | null;
  window_started_at?: string | null;
}

/** The lock that is still running, if any. */
export function activeLock(row: Counter | null | undefined, now: Date): string | null {
  return row?.locked_until && new Date(row.locked_until) > now ? row.locked_until : null;
}

/** Per account and client: the counter after one more failure in a row. A lock that has run out starts afresh. */
export function afterClientFailure(row: Counter | null | undefined, now: Date): Counter {
  const lapsed = !!row?.locked_until && new Date(row.locked_until) <= now;
  const failures = (row && !lapsed ? row.failures : 0) + 1;
  return failures >= MAX_FAILURES
    ? { failures: 0, locked_until: new Date(now.getTime() + WINDOW_MS).toISOString() }
    : { failures, locked_until: null };
}

/** Per account, all clients: the counter after one more failure, counted within a 15-minute window. */
export function afterAccountFailure(row: Counter | null | undefined, now: Date): Counter {
  const start = row?.window_started_at ? new Date(row.window_started_at) : null;
  const lapsed = !!row?.locked_until && new Date(row.locked_until) <= now;
  const inWindow = !!start && !lapsed && now.getTime() - start.getTime() < WINDOW_MS;
  const failures = (inWindow ? row!.failures : 0) + 1;
  if (failures >= ACCOUNT_CEILING) {
    return { failures: 0, locked_until: new Date(now.getTime() + WINDOW_MS).toISOString(), window_started_at: null };
  }
  return { failures, locked_until: null, window_started_at: (inWindow ? start! : now).toISOString() };
}

/** The caller's address. Cloudflare sets cf-connecting-ip and refuses a request that tries to supply its own. */
export function clientAddress(headers: Headers): string {
  return headers.get("cf-connecting-ip")?.trim() ||
    headers.get("x-forwarded-for")?.split(",")[0]?.trim() ||
    "unknown";
}

/** The stored client key: a SHA-256 of the address, so the table never holds an IP address. */
export async function clientKey(address: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(address));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}
