// Supabase Edge Function: identifier-sign-in
// Resolves a private username, phone, or MC-number alias without exposing account email addresses.
// Requires SUPABASE_URL, SUPABASE_ANON_KEY, and SUPABASE_SERVICE_ROLE_KEY function secrets.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://www.tuckerstruckers.com",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
const normalized = (value: string) => value.trim().toLowerCase();
const compact = (value: string) => value.replace(/[^a-z0-9]/gi, "").toLowerCase();

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed." }, 405);
  const origin = req.headers.get("origin");
  if (origin && origin !== "https://www.tuckerstruckers.com" && origin !== "https://tuckerstruckers.github.io") return json({ error: "Origin not allowed." }, 403);

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) return json({ error: "Sign-in service is not configured." }, 500);

  let body: { identifier?: unknown; password?: unknown };
  try { body = await req.json(); } catch { return json({ error: "Invalid request." }, 400); }
  const identifier = typeof body.identifier === "string" ? body.identifier.trim() : "";
  const password = typeof body.password === "string" ? body.password : "";
  if (!identifier || !password) return json({ error: "Enter your login identifier and password." }, 400);
  if (identifier.includes("@")) return json({ error: "Use the standard email sign-in option for email addresses." }, 400);

  let type: "username" | "phone" | "mc_number";
  let value: string;
  if (/^mc\s*\d/i.test(identifier)) {
    type = "mc_number";
    value = compact(identifier.replace(/^mc\s*/i, ""));
  } else if (/^[+()0-9.\-\s]+$/.test(identifier) && compact(identifier).length >= 7) {
    // Treat typical phone-length digit strings as phone numbers even without punctuation.
    type = "phone";
    value = compact(identifier);
  } else if (/^\d{5,6}$/.test(identifier)) {
    // Unprefixed short numeric IDs are treated as MC numbers; users can enter MC-123456 explicitly.
    type = "mc_number";
    value = compact(identifier);
  } else if (/^[a-z0-9._-]{3,32}$/i.test(identifier)) {
    type = "username";
    value = normalized(identifier);
  } else {
    type = "phone";
    value = compact(identifier);
  }
  if (!value) return json({ error: "Sign-in failed. Check your details or use your account email." }, 401);

  const admin = createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
  const { data: match, error: lookupError } = await admin.from("portal_login_identifiers")
    .select("user_id").eq("identifier_type", type).eq("identifier_value_normalized", value).maybeSingle();
  if (lookupError || !match) return json({ error: "Sign-in failed. Check your details or use your account email." }, 401);

  const { data: userResult, error: userError } = await admin.auth.admin.getUserById(match.user_id);
  if (userError || !userResult.user?.email) return json({ error: "Sign-in failed. Check your details or use your account email." }, 401);

  const authClient = createClient(url, anonKey, { auth: { autoRefreshToken: false, persistSession: false } });
  const { data: signedIn, error: signInError } = await authClient.auth.signInWithPassword({ email: userResult.user.email, password });
  if (signInError || !signedIn.session) return json({ error: "Sign-in failed. Check your details or use your account email." }, 401);
  return json({
    access_token: signedIn.session.access_token,
    refresh_token: signedIn.session.refresh_token,
    expires_in: signedIn.session.expires_in,
    token_type: signedIn.session.token_type,
  });
});
