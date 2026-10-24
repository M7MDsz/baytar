// US-30: email + password sign-in with a lockout after 5 failed attempts in a row (15 minutes).
// Supabase's own password hook needs a paid plan, so the counter lives here.
// The reply never says whether the email or the password was wrong.

import { createClient } from "npm:@supabase/supabase-js@2";

const MAX_FAILURES = 5;
const LOCK_MINUTES = 15;

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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const { email: rawEmail, password } = await req.json().catch(() => ({}));
  if (typeof rawEmail !== "string" || typeof password !== "string") return json({ error: "bad_request" }, 400);
  const email = rawEmail.trim().toLowerCase();

  const url = Deno.env.get("SUPABASE_URL")!;
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const now = new Date();

  const { data: row } = await admin.from("login_attempts").select().eq("email", email).maybeSingle();
  if (row?.locked_until && new Date(row.locked_until) > now) {
    return json({ error: "locked", locked_until: row.locked_until }, 423);
  }

  const auth = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, { auth: { persistSession: false } });
  const { data, error } = await auth.auth.signInWithPassword({ email, password });

  if (error || !data.session) {
    if (error?.code === "email_not_confirmed") return json({ error: "email_not_confirmed" }, 403);
    // A lock that has run out starts a fresh count.
    const previous = row && !(row.locked_until && new Date(row.locked_until) <= now) ? row.failures : 0;
    const failures = previous + 1;
    const lockedUntil = failures >= MAX_FAILURES ? new Date(now.getTime() + LOCK_MINUTES * 60_000).toISOString() : null;
    await admin.from("login_attempts").upsert({
      email,
      failures: lockedUntil ? 0 : failures,
      locked_until: lockedUntil,
      updated_at: now.toISOString(),
    });
    return json({ error: "invalid_credentials" }, 401);
  }

  await admin.from("login_attempts").delete().eq("email", email);
  return json({ access_token: data.session.access_token, refresh_token: data.session.refresh_token });
});
