// US-30: email + password sign-in with a lockout after 5 failed attempts in a row (15 minutes).
// Supabase's own password hook needs a paid plan, so the counters live here (rules in attempts.ts).
// The reply never says whether the email or the password was wrong. "email_not_confirmed" is returned only after
// Supabase has accepted the password, so it reveals nothing to someone guessing (checked live for QA M-5).

import { createClient } from "npm:@supabase/supabase-js@2";
import { activeLock, afterAccountFailure, afterClientFailure, clientAddress, clientKey } from "./attempts.ts";

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
  const client = await clientKey(clientAddress(req.headers));

  const url = Deno.env.get("SUPABASE_URL")!;
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const now = new Date();

  const [{ data: mine }, { data: account }] = await Promise.all([
    admin.from("login_attempts_by_client").select().match({ email, client }).maybeSingle(),
    admin.from("login_attempts").select().eq("email", email).maybeSingle(),
  ]);
  const lock = activeLock(mine, now) ?? activeLock(account, now);
  if (lock) return json({ error: "locked", locked_until: lock }, 423);

  const auth = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, { auth: { persistSession: false } });
  const { data, error } = await auth.auth.signInWithPassword({ email, password });

  if (error || !data.session) {
    if (error?.code === "email_not_confirmed") return json({ error: "email_not_confirmed" }, 403);
    const stamp = now.toISOString();
    await Promise.all([
      admin.from("login_attempts_by_client").upsert({ email, client, ...afterClientFailure(mine, now), updated_at: stamp }),
      admin.from("login_attempts").upsert({ email, ...afterAccountFailure(account, now), updated_at: stamp }),
    ]);
    return json({ error: "invalid_credentials" }, 401);
  }

  // A success ends this client's run of failures. The account-wide window is left to expire on its own, so a
  // correct sign-in by the owner does not hand someone guessing from elsewhere a fresh count.
  await admin.from("login_attempts_by_client").delete().match({ email, client });
  return json({ access_token: data.session.access_token, refresh_token: data.session.refresh_token });
});
