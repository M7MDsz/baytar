// US-14 / US-19: issues a LiveKit token for one appointment's video room.
// The access rules (who may join, and when) live in the join_consultation database function,
// which runs as the calling user; this function only mints a token when it answers "ok".

import { createClient } from "npm:@supabase/supabase-js@2";
import { AccessToken } from "npm:livekit-server-sdk@2";

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

  const authorization = req.headers.get("Authorization");
  if (!authorization) return json({ error: "unauthorized" }, 401);

  const { appointmentId } = await req.json().catch(() => ({}));
  if (typeof appointmentId !== "string") return json({ error: "bad_request" }, 400);

  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authorization } },
  });
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return json({ error: "unauthorized" }, 401);

  const { data: verdict, error } = await supabase.rpc("join_consultation", { p_appointment: appointmentId });
  if (error) return json({ error: "server_error" }, 500);
  if (verdict !== "ok") return json({ error: verdict }, 403);

  const token = new AccessToken(Deno.env.get("LIVEKIT_API_KEY")!, Deno.env.get("LIVEKIT_API_SECRET")!, {
    identity: user.id,
    ttl: "45m",
  });
  token.addGrant({ room: `appointment-${appointmentId}`, roomJoin: true, canPublish: true, canSubscribe: true });

  return json({ token: await token.toJwt(), url: Deno.env.get("LIVEKIT_URL") });
});
