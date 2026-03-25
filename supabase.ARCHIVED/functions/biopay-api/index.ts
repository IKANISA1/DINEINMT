// BioPay Edge Function — Rwanda-only face-payment API
// Runs as Supabase Edge Function with service_role access.
// All BioPay data access goes through this function — no direct client policies.
//
// Actions: enroll_face, match_face, get_managed_profile, update_profile,
//          re_enroll_face, delete_profile, report_profile

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { encodeHex } from "https://deno.land/std@0.208.0/encoding/hex.ts";

// ─── Types ──────────────────────────────────────────────────

interface BiopayRequest {
  action: string;
  [key: string]: unknown;
}

interface EnrollInput {
  display_name: string;
  ussd_string: string;
  embedding: number[];
  quality_metrics: { score: number; model_version?: string };
  client_install_id: string;
  consent_version?: string;
}

interface MatchInput {
  embedding: number[];
  client_install_id: string;
  device_label?: string;
}

// ─── Constants ──────────────────────────────────────────────

const MATCH_THRESHOLD = 0.72;
const DUPLICATE_THRESHOLD = 0.85;
const RATE_LIMIT_WINDOW_MS = 60_000; // 1 minute
const RATE_LIMIT_MAX_REQUESTS = 10;
const MANAGEMENT_CODE_LENGTH = 8;

// ─── Crypto helpers ─────────────────────────────────────────

async function hmacSign(secret: string, data: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(data));
  return encodeHex(new Uint8Array(sig));
}

async function hashSha256(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return encodeHex(new Uint8Array(hash));
}

function generateManagementCode(): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no I/O/0/1 for clarity
  let code = "";
  const bytes = new Uint8Array(MANAGEMENT_CODE_LENGTH);
  crypto.getRandomValues(bytes);
  for (const b of bytes) {
    code += chars[b % chars.length];
  }
  return code;
}

async function hashManagementCode(code: string, pepper: string): Promise<string> {
  return await hashSha256(pepper + code);
}

function generateOwnerToken(
  profileId: string,
  version: number,
  secret: string,
): Promise<string> {
  return hmacSign(secret, `${profileId}:${version}`);
}

async function verifyOwnerToken(
  token: string,
  profileId: string,
  version: number,
  secret: string,
): Promise<boolean> {
  const expected = await generateOwnerToken(profileId, version, secret);
  return token === expected;
}

function hashIp(ip: string, secret: string): Promise<string> {
  return hmacSign(secret, ip);
}

// ─── Rate limiter (in-memory, per-instance) ─────────────────

const rateLimitMap = new Map<string, { count: number; windowStart: number }>();

function checkRateLimit(key: string): boolean {
  const now = Date.now();
  const entry = rateLimitMap.get(key);

  if (!entry || now - entry.windowStart > RATE_LIMIT_WINDOW_MS) {
    rateLimitMap.set(key, { count: 1, windowStart: now });
    return true;
  }

  if (entry.count >= RATE_LIMIT_MAX_REQUESTS) {
    return false;
  }

  entry.count++;
  return true;
}

// ─── USSD normalization ─────────────────────────────────────

function normalizeUssd(raw: string): string {
  let normalized = raw.replace(/\s/g, "");
  if (!normalized.endsWith("#")) {
    normalized += "#";
  }
  return normalized;
}

function validateRwUssd(ussd: string): boolean {
  const normalized = normalizeUssd(ussd);
  // Rwanda USSD: *NNN*...*# pattern
  return /^\*\d{2,4}(\*[\d\w]+)*\*?#$/.test(normalized);
}

// ─── Main handler ───────────────────────────────────────────

serve(async (req: Request) => {
  // CORS
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const body: BiopayRequest = await req.json();
    const { action } = body;

    // Get secrets
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const ownerTokenSecret = Deno.env.get("BIOPAY_OWNER_TOKEN_SECRET") || "dev-owner-secret";
    const manageCodePepper = Deno.env.get("BIOPAY_MANAGE_CODE_PEPPER") || "dev-manage-pepper";
    const rateLimitSecret = Deno.env.get("BIOPAY_RATE_LIMIT_SECRET") || "dev-rate-secret";

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // Get client IP for rate limiting / audit
    const clientIp = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
    const ipHash = await hashIp(clientIp, rateLimitSecret);

    switch (action) {
      case "enroll_face":
        return await handleEnrollFace(supabase, body as unknown as EnrollInput, ipHash, ownerTokenSecret, manageCodePepper);

      case "match_face":
        return await handleMatchFace(supabase, body as unknown as MatchInput, ipHash);

      case "get_managed_profile":
        return await handleGetManagedProfile(supabase, body, ownerTokenSecret, manageCodePepper);

      case "update_profile":
        return await handleUpdateProfile(supabase, body, ownerTokenSecret, manageCodePepper, ipHash);

      case "re_enroll_face":
        return await handleReEnrollFace(supabase, body, ownerTokenSecret, manageCodePepper, ipHash);

      case "delete_profile":
        return await handleDeleteProfile(supabase, body, ownerTokenSecret, manageCodePepper, ipHash);

      case "report_profile":
        return await handleReportProfile(supabase, body, ipHash);

      default:
        return jsonResponse({ error: `Unknown action: ${action}` }, 400);
    }
  } catch (err) {
    console.error("BioPay API error:", err);
    return jsonResponse({ error: "Internal server error" }, 500);
  }
});

// ─── Action handlers ────────────────────────────────────────

async function handleEnrollFace(
  supabase: ReturnType<typeof createClient>,
  input: EnrollInput,
  ipHash: string,
  ownerTokenSecret: string,
  manageCodePepper: string,
) {
  const { display_name, ussd_string, embedding, quality_metrics, client_install_id, consent_version } = input;

  // Validate inputs
  if (!display_name || !ussd_string || !embedding || !quality_metrics || !client_install_id) {
    return jsonResponse({ error: "Missing required fields" }, 400);
  }

  if (!Array.isArray(embedding) || embedding.length !== 128) {
    return jsonResponse({ error: "Embedding must be a 128-dimensional vector" }, 400);
  }

  if (!validateRwUssd(ussd_string)) {
    return jsonResponse({ error: "Invalid Rwanda USSD string" }, 400);
  }

  const ussdNormalized = normalizeUssd(ussd_string);

  // Check for duplicate USSD
  const { data: existingUssd } = await supabase
    .from("biopay_profiles")
    .select("id, biopay_id")
    .eq("ussd_normalized", ussdNormalized)
    .eq("status", "active")
    .maybeSingle();

  if (existingUssd) {
    return jsonResponse({ error: "This USSD string is already registered" }, 409);
  }

  // Check for duplicate face
  const embeddingStr = `[${embedding.join(",")}]`;
  const { data: duplicateFace } = await supabase.rpc("find_duplicate_biopay_profile", {
    query_embedding: embeddingStr,
    threshold: DUPLICATE_THRESHOLD,
  });

  if (duplicateFace && duplicateFace.length > 0) {
    return jsonResponse({
      error: "A similar face is already registered",
      existing_biopay_id: duplicateFace[0].biopay_id,
    }, 409);
  }

  // Insert profile
  const { data: profile, error: profileError } = await supabase
    .from("biopay_profiles")
    .insert({
      display_name,
      ussd_string,
      ussd_normalized: ussdNormalized,
      consent_version: consent_version || "v1",
      consent_at: new Date().toISOString(),
    })
    .select("id, biopay_id, owner_token_version")
    .single();

  if (profileError || !profile) {
    console.error("Profile insert error:", profileError);
    return jsonResponse({ error: "Failed to create profile" }, 500);
  }

  // Insert active embedding
  const { error: embeddingError } = await supabase
    .from("biopay_face_embeddings")
    .insert({
      profile_id: profile.id,
      embedding: embeddingStr,
      model_version: quality_metrics.model_version || "mobilefacenet_v2",
      quality_score: quality_metrics.score,
      is_active: true,
    });

  if (embeddingError) {
    console.error("Embedding insert error:", embeddingError);
    // Rollback profile
    await supabase.from("biopay_profiles").delete().eq("id", profile.id);
    return jsonResponse({ error: "Failed to store face embedding" }, 500);
  }

  // Generate owner token
  const ownerToken = await generateOwnerToken(
    profile.id,
    profile.owner_token_version,
    ownerTokenSecret,
  );

  // Generate management code
  const managementCode = generateManagementCode();
  const codeHash = await hashManagementCode(managementCode, manageCodePepper);

  // Store code hash
  await supabase
    .from("biopay_profiles")
    .update({ manage_code_hash: codeHash })
    .eq("id", profile.id);

  // Audit log
  await supabase.from("biopay_enrollment_audit").insert({
    profile_id: profile.id,
    event_type: "enrolled",
    client_install_id,
    ip_hash: ipHash,
    details: { consent_version: consent_version || "v1" },
  });

  return jsonResponse({
    success: true,
    biopay_id: profile.biopay_id,
    owner_token: ownerToken,
    management_code: managementCode,
    display_name,
  });
}

async function handleMatchFace(
  supabase: ReturnType<typeof createClient>,
  input: MatchInput,
  ipHash: string,
) {
  const { embedding, client_install_id, device_label } = input;

  if (!embedding || !client_install_id) {
    return jsonResponse({ error: "Missing required fields" }, 400);
  }

  if (!Array.isArray(embedding) || embedding.length !== 128) {
    return jsonResponse({ error: "Embedding must be a 128-dimensional vector" }, 400);
  }

  // Rate limit by IP + install
  const rlKey = `match:${ipHash}:${client_install_id}`;
  if (!checkRateLimit(rlKey)) {
    await supabase.from("biopay_match_audit").insert({
      similarity: 0,
      result: "rate_limited",
      client_install_id,
      ip_hash: ipHash,
      device_label,
    });
    return jsonResponse({ error: "Rate limit exceeded. Try again later." }, 429);
  }

  const embeddingStr = `[${embedding.join(",")}]`;
  const { data: matches, error } = await supabase.rpc("match_biopay_embedding", {
    query_embedding: embeddingStr,
    threshold: MATCH_THRESHOLD,
    limit_count: 3,
  });

  if (error) {
    console.error("Match RPC error:", error);
    await supabase.from("biopay_match_audit").insert({
      similarity: 0,
      result: "error",
      client_install_id,
      ip_hash: ipHash,
      device_label,
    });
    return jsonResponse({ error: "Match failed" }, 500);
  }

  if (!matches || matches.length === 0) {
    await supabase.from("biopay_match_audit").insert({
      similarity: 0,
      result: "no_match",
      client_install_id,
      ip_hash: ipHash,
      device_label,
    });
    return jsonResponse({ match: false });
  }

  const best = matches[0];

  // Audit
  await supabase.from("biopay_match_audit").insert({
    matched_profile_id: best.profile_id,
    similarity: best.similarity,
    result: "match",
    client_install_id,
    ip_hash: ipHash,
    device_label,
  });

  return jsonResponse({
    match: true,
    display_name: best.display_name,
    ussd_string: best.ussd_string,
    score: best.similarity,
    biopay_id: best.biopay_id,
  });
}

async function handleGetManagedProfile(
  supabase: ReturnType<typeof createClient>,
  body: BiopayRequest,
  ownerTokenSecret: string,
  manageCodePepper: string,
) {
  // Auth: owner_token OR (biopay_id + management_code)
  const auth = await authenticateProfileAccess(supabase, body, ownerTokenSecret, manageCodePepper);
  if (auth.error) return auth.error;

  const profile = auth.profile!;
  return jsonResponse({
    biopay_id: profile.biopay_id,
    display_name: profile.display_name,
    ussd_string: profile.ussd_string,
    status: profile.status,
    created_at: profile.created_at,
    updated_at: profile.updated_at,
  });
}

async function handleUpdateProfile(
  supabase: ReturnType<typeof createClient>,
  body: BiopayRequest,
  ownerTokenSecret: string,
  manageCodePepper: string,
  ipHash: string,
) {
  const auth = await authenticateProfileAccess(supabase, body, ownerTokenSecret, manageCodePepper);
  if (auth.error) return auth.error;

  const profile = auth.profile!;
  const updates: Record<string, unknown> = {};

  if (body.display_name && typeof body.display_name === "string") {
    updates.display_name = body.display_name;
  }

  if (body.ussd_string && typeof body.ussd_string === "string") {
    if (!validateRwUssd(body.ussd_string as string)) {
      return jsonResponse({ error: "Invalid Rwanda USSD string" }, 400);
    }
    updates.ussd_string = body.ussd_string;
    updates.ussd_normalized = normalizeUssd(body.ussd_string as string);
  }

  if (Object.keys(updates).length === 0) {
    return jsonResponse({ error: "No updates provided" }, 400);
  }

  const { error } = await supabase
    .from("biopay_profiles")
    .update(updates)
    .eq("id", profile.id);

  if (error) {
    return jsonResponse({ error: "Update failed" }, 500);
  }

  await supabase.from("biopay_enrollment_audit").insert({
    profile_id: profile.id,
    event_type: "updated",
    client_install_id: body.client_install_id || null,
    ip_hash: ipHash,
    details: { fields_updated: Object.keys(updates) },
  });

  return jsonResponse({ success: true });
}

async function handleReEnrollFace(
  supabase: ReturnType<typeof createClient>,
  body: BiopayRequest,
  ownerTokenSecret: string,
  manageCodePepper: string,
  ipHash: string,
) {
  const auth = await authenticateProfileAccess(supabase, body, ownerTokenSecret, manageCodePepper);
  if (auth.error) return auth.error;

  const profile = auth.profile!;
  const embedding = body.embedding as number[];
  const qualityMetrics = body.quality_metrics as { score: number; model_version?: string };

  if (!embedding || !Array.isArray(embedding) || embedding.length !== 128) {
    return jsonResponse({ error: "Valid 128-dim embedding required" }, 400);
  }

  if (!qualityMetrics?.score) {
    return jsonResponse({ error: "Quality metrics required" }, 400);
  }

  // Deactivate old embeddings
  await supabase
    .from("biopay_face_embeddings")
    .update({ is_active: false })
    .eq("profile_id", profile.id);

  // Insert new embedding
  const embeddingStr = `[${embedding.join(",")}]`;
  const { error: insertError } = await supabase
    .from("biopay_face_embeddings")
    .insert({
      profile_id: profile.id,
      embedding: embeddingStr,
      model_version: qualityMetrics.model_version || "mobilefacenet_v2",
      quality_score: qualityMetrics.score,
      is_active: true,
    });

  if (insertError) {
    return jsonResponse({ error: "Failed to store new embedding" }, 500);
  }

  // Rotate owner_token_version
  const newVersion = profile.owner_token_version + 1;
  await supabase
    .from("biopay_profiles")
    .update({ owner_token_version: newVersion })
    .eq("id", profile.id);

  const newOwnerToken = await generateOwnerToken(profile.id, newVersion, ownerTokenSecret);

  await supabase.from("biopay_enrollment_audit").insert({
    profile_id: profile.id,
    event_type: "re_enrolled",
    client_install_id: body.client_install_id || null,
    ip_hash: ipHash,
  });

  return jsonResponse({
    success: true,
    owner_token: newOwnerToken,
  });
}

async function handleDeleteProfile(
  supabase: ReturnType<typeof createClient>,
  body: BiopayRequest,
  ownerTokenSecret: string,
  manageCodePepper: string,
  ipHash: string,
) {
  const auth = await authenticateProfileAccess(supabase, body, ownerTokenSecret, manageCodePepper);
  if (auth.error) return auth.error;

  const profile = auth.profile!;

  // Soft-delete: set status + deactivate embeddings
  await supabase
    .from("biopay_profiles")
    .update({ status: "deleted" })
    .eq("id", profile.id);

  await supabase
    .from("biopay_face_embeddings")
    .update({ is_active: false })
    .eq("profile_id", profile.id);

  await supabase.from("biopay_enrollment_audit").insert({
    profile_id: profile.id,
    event_type: "deleted",
    client_install_id: body.client_install_id || null,
    ip_hash: ipHash,
  });

  return jsonResponse({ success: true });
}

async function handleReportProfile(
  supabase: ReturnType<typeof createClient>,
  body: BiopayRequest,
  ipHash: string,
) {
  const { biopay_id, reason, notes, client_install_id } = body as {
    biopay_id?: string;
    reason?: string;
    notes?: string;
    client_install_id?: string;
  };

  if (!biopay_id || !reason) {
    return jsonResponse({ error: "biopay_id and reason are required" }, 400);
  }

  const { data: profile } = await supabase
    .from("biopay_profiles")
    .select("id")
    .eq("biopay_id", biopay_id)
    .maybeSingle();

  if (!profile) {
    return jsonResponse({ error: "Profile not found" }, 404);
  }

  await supabase.from("biopay_abuse_reports").insert({
    profile_id: profile.id,
    reason,
    notes: notes || null,
    client_install_id: client_install_id || null,
  });

  return jsonResponse({ success: true });
}

// ─── Auth helper ────────────────────────────────────────────

interface AuthResult {
  profile?: {
    id: string;
    biopay_id: string;
    display_name: string;
    ussd_string: string;
    status: string;
    owner_token_version: number;
    manage_code_hash: string | null;
    created_at: string;
    updated_at: string;
  };
  error?: Response;
}

async function authenticateProfileAccess(
  supabase: ReturnType<typeof createClient>,
  body: BiopayRequest,
  ownerTokenSecret: string,
  manageCodePepper: string,
): Promise<AuthResult> {
  const ownerToken = body.owner_token as string | undefined;
  const profileId = body.profile_id as string | undefined;
  const biopayId = body.biopay_id as string | undefined;
  const managementCode = body.management_code as string | undefined;

  // Path 1: owner_token + profile_id (same-device)
  if (ownerToken && profileId) {
    const { data: profile } = await supabase
      .from("biopay_profiles")
      .select("*")
      .eq("id", profileId)
      .eq("status", "active")
      .maybeSingle();

    if (!profile) {
      return { error: jsonResponse({ error: "Profile not found" }, 404) };
    }

    const valid = await verifyOwnerToken(
      ownerToken,
      profile.id,
      profile.owner_token_version,
      ownerTokenSecret,
    );

    if (!valid) {
      return { error: jsonResponse({ error: "Invalid owner token" }, 403) };
    }

    return { profile };
  }

  // Path 2: biopay_id + management_code (cross-device recovery)
  if (biopayId && managementCode) {
    const { data: profile } = await supabase
      .from("biopay_profiles")
      .select("*")
      .eq("biopay_id", biopayId)
      .eq("status", "active")
      .maybeSingle();

    if (!profile) {
      return { error: jsonResponse({ error: "Profile not found" }, 404) };
    }

    if (!profile.manage_code_hash) {
      return { error: jsonResponse({ error: "No management code set" }, 403) };
    }

    const codeHash = await hashManagementCode(managementCode, manageCodePepper);
    if (codeHash !== profile.manage_code_hash) {
      return { error: jsonResponse({ error: "Invalid management code" }, 403) };
    }

    return { profile };
  }

  return { error: jsonResponse({ error: "Authentication required: provide owner_token+profile_id or biopay_id+management_code" }, 401) };
}

// ─── Response helper ────────────────────────────────────────

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}
