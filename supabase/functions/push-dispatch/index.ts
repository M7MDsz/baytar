// US-35: sends one push notification through Firebase Cloud Messaging (HTTP v1).
// Called by the notifications_push database trigger with a shared secret.
// The push text is always generic so the lock screen never shows medical details.

import { createClient } from "npm:@supabase/supabase-js@2";

const LOCK_SCREEN_BODY = "افتح بيطار لعرض التفاصيل";

type ServiceAccount = { client_email: string; private_key: string; project_id: string };

function base64url(data: ArrayBuffer | string): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : new Uint8Array(data);
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function googleAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const pem = sa.private_key.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"],
  );
  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${header}.${claims}`));
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${header}.${claims}.${base64url(signature)}`,
    }),
  });
  if (!res.ok) throw new Error(`google token ${res.status}`);
  return (await res.json()).access_token;
}

Deno.serve(async (req) => {
  if (req.headers.get("Authorization") !== `Bearer ${Deno.env.get("PUSH_WEBHOOK_SECRET")}`) {
    return new Response("unauthorized", { status: 401 });
  }
  const { notification_id } = await req.json();
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  const { data: n } = await admin
    .from("notifications")
    .select("id, title, route, user_id")
    .eq("id", notification_id)
    .maybeSingle();
  if (!n) return Response.json({ skipped: true });
  const { data: profile } = await admin
    .from("profiles")
    .select("push_enabled, fcm_token")
    .eq("id", n.user_id)
    .maybeSingle();
  // Push turned off or no device: the notification is still in the in-app list.
  if (!profile?.push_enabled || !profile.fcm_token) return Response.json({ skipped: true });

  const sa: ServiceAccount = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!);
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
    method: "POST",
    headers: { Authorization: `Bearer ${await googleAccessToken(sa)}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      message: {
        token: profile.fcm_token,
        notification: { title: n.title, body: LOCK_SCREEN_BODY },
        data: { route: n.route ?? "/notifications", notification_id: n.id },
        android: { priority: "high" },
      },
    }),
  });
  if (!res.ok) return Response.json({ error: await res.text() }, { status: 502 });

  await admin.from("notifications").update({ pushed_at: new Date().toISOString() }).eq("id", n.id);
  return Response.json({ sent: true });
});
