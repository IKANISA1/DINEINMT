import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { getEnv, optionalEnv, intEnv, numberValue, stringValue, asRecord } from "../_shared/env.ts";
import { collapseWhitespace, digitsOnly, sha256Hex, bytesToBase64Url, base64UrlEncode, base64UrlDecode, hmacSha256Base64Url } from "../_shared/crypto.ts";
import { corsAllowHeaders, corsAllowMethods, corsHeaders, HttpError, buildResponseHeaders, ok, fail, parseBody } from "../_shared/http.ts";
const defaultBiopayAllowedOrigins = [
  "https://dineinmt.ikanisa.com",
  "https://www.dineinmt.ikanisa.com",
  "https://dineinrw.ikanisa.com",
  "https://www.dineinrw.ikanisa.com",
];

const biopayActions = new Set([
  "health_check",
  "enroll_face",
  "match_face",
  "get_managed_profile",
  "update_profile",
  "re_enroll_face",
  "delete_profile",
  "report_profile",
]);

type JsonRecord = Record<string, unknown>;
type MatchRateLimitAuditField = "client_install_id" | "ip_hash";
type BiopayAction =
  | "health_check"
  | "enroll_face"
  | "match_face"
  | "get_managed_profile"
  | "update_profile"
  | "re_enroll_face"
  | "delete_profile"
  | "report_profile";

type BiopayProfileRow = {
  id: string;
  biopay_id: string;
  display_name: string;
  ussd_string: string;
  status: string;
  owner_token_version: number;
  management_code_hash: string;
  management_code_hint: string | null;
  created_at: string;
};

type MatchRpcRow = {
  profile_id: string;
  biopay_id: string;
  display_name: string;
  ussd_string: string;
  similarity: number;
  model_version: string | null;
};

type DuplicateRpcRow = {
  profile_id: string;
  biopay_id: string;
  display_name: string;
  similarity: number;
};

type EmbeddingRow = {
  id: string;
};

type MatchRateLimitSubject = {
  auditField: MatchRateLimitAuditField | null;
  auditValue: string | null;
  localKey: string;
  source: "anonymous" | "client_install_id" | "ip_hash";
};

// Imported from _shared

export function normalizeOrigin(value: string): string | null {
  const trimmed = value.trim();
  if (!trimmed || trimmed == "null") {
    return null;
  }

  try {
    return new URL(trimmed).origin;
  } catch {
    return null;
  }
}

function allowedBiopayOrigins(): string[] {
  const configured = optionalEnv("BIOPAY_ALLOWED_ORIGINS");
  const candidates = (configured?.split(",") ?? defaultBiopayAllowedOrigins)
    .map((value) => normalizeOrigin(value))
    .filter((value): value is string => Boolean(value));

  return [...new Set(candidates)];
}

export function resolveAllowedBiopayOrigin(
  origin: string | null,
): string | null {
  const normalized = origin ? normalizeOrigin(origin) : null;
  if (!normalized) {
    return null;
  }

  return allowedBiopayOrigins().includes(normalized) ? normalized : null;
}

function assertAllowedBiopayOrigin(req: Request): string | null {
  const origin = req.headers.get("origin");
  if (!origin) {
    return null;
  }

  const allowedOrigin = resolveAllowedBiopayOrigin(origin);
  if (!allowedOrigin) {
    throw new HttpError(403, "Origin not allowed.", {
      code: "origin_not_allowed",
    });
  }

  return allowedOrigin;
}

// Imported from http.ts

function adminClient() {
  return createClient(
    getEnv("SUPABASE_URL"),
    getEnv("SUPABASE_SERVICE_ROLE_KEY"),
    { auth: { persistSession: false } },
  );
}

// Imported from crypto.ts

function ownerTokenSecret(): string {
  return getEnv("BIOPAY_OWNER_TOKEN_SECRET");
}

function managementCodePepper(): string {
  return getEnv("BIOPAY_MANAGE_CODE_PEPPER");
}

function rateLimitSecret(): string {
  return optionalEnv("BIOPAY_RATE_LIMIT_SECRET") ?? managementCodePepper();
}

function defaultMatchThreshold(): number {
  return normalizeBiopayThreshold(
    optionalEnv("BIOPAY_DEFAULT_MATCH_THRESHOLD"),
    0.72,
  );
}

function duplicateFaceThreshold(): number {
  return normalizeBiopayThreshold(
    optionalEnv("BIOPAY_DUPLICATE_FACE_THRESHOLD"),
    0.90,
  );
}

function minimumMatchThreshold(): number {
  const configuredFloor = normalizeBiopayThreshold(
    optionalEnv("BIOPAY_MIN_MATCH_THRESHOLD"),
    0.72,
  );
  return Math.max(configuredFloor, defaultMatchThreshold());
}

function ownerTokenTtlMinutes(): number {
  return intEnv("BIOPAY_OWNER_TOKEN_TTL_MINUTES", 60 * 24 * 180);
}

function manageCodeLength(): number {
  return intEnv("BIOPAY_MANAGE_CODE_LENGTH", 6);
}

function matchRateLimitWindowMs(): number {
  return intEnv("BIOPAY_MATCH_RATE_LIMIT_WINDOW_MINUTES", 5) * 60 * 1000;
}

function matchRateLimitMaxRequests(): number {
  return intEnv("BIOPAY_MATCH_RATE_LIMIT_MAX_REQUESTS", 20);
}

function matchRateLimitRetryAfterSeconds(): number {
  return Math.ceil(matchRateLimitWindowMs() / 1000);
}

export function normalizeBiopayAction(value: unknown): BiopayAction {
  const action = stringValue(value);
  if (!action || !biopayActions.has(action)) {
    throw new HttpError(400, "Unsupported BioPay action.", {
      code: "unsupported_action",
    });
  }
  return action as BiopayAction;
}

export function normalizeBiopayId(value: unknown): string {
  const biopayId = stringValue(value)?.replace(/\D/g, "");
  if (!biopayId || !/^\d{6}$/.test(biopayId)) {
    throw new HttpError(400, "BioPay ID must be 6 digits.", {
      code: "invalid_biopay_id",
    });
  }
  return biopayId;
}

export function normalizeBiopayDisplayName(value: unknown): string {
  const displayName = collapseWhitespace(stringValue(value) ?? "");
  if (displayName.length < 2 || displayName.length > 80) {
    throw new HttpError(400, "Display name must be 2 to 80 characters.", {
      code: "invalid_display_name",
    });
  }
  return displayName;
}

export function normalizeBiopayConsentVersion(value: unknown): number {
  const parsed = numberValue(value);
  if (!parsed || !Number.isInteger(parsed) || parsed < 1) {
    throw new HttpError(400, "Consent version is required.", {
      code: "invalid_consent_version",
    });
  }
  return parsed;
}

export function normalizeBiopayThreshold(
  value: unknown,
  fallback: number,
): number {
  const parsed = numberValue(value);
  if (parsed === undefined) return fallback;
  if (parsed < 0 || parsed > 1) {
    throw new HttpError(400, "Threshold must be between 0 and 1.", {
      code: "invalid_threshold",
    });
  }
  return parsed;
}

export function normalizeBiopayMatchThreshold(value: unknown): number {
  const minimum = minimumMatchThreshold();
  const requested = numberValue(value);
  if (requested === undefined) {
    return Math.max(defaultMatchThreshold(), minimum);
  }

  const threshold = normalizeBiopayThreshold(
    requested,
    defaultMatchThreshold(),
  );
  if (threshold < minimum) {
    throw new HttpError(400, "Threshold is below the minimum allowed.", {
      code: "threshold_too_low",
      min_threshold: minimum,
    });
  }
  return threshold;
}

export function normalizeBiopayQualityScore(
  value: unknown,
): number | null {
  const parsed = numberValue(value);
  if (parsed === undefined) return null;
  if (parsed < 0 || parsed > 1) {
    throw new HttpError(400, "Quality score must be between 0 and 1.", {
      code: "invalid_quality_score",
    });
  }
  return parsed;
}

export function normalizeBiopayReason(value: unknown): string {
  const reason = collapseWhitespace(stringValue(value) ?? "");
  if (reason.length < 3 || reason.length > 120) {
    throw new HttpError(400, "Reason must be 3 to 120 characters.", {
      code: "invalid_reason",
    });
  }
  return reason;
}

export function normalizeBiopayManagementCode(value: unknown): string {
  const managementCode = stringValue(value)?.replace(/\D/g, "");
  const length = manageCodeLength();
  if (!managementCode || managementCode.length != length) {
    throw new HttpError(
      400,
      `Management code must be ${length} digits.`,
      { code: "invalid_management_code" },
    );
  }
  return managementCode;
}

export function normalizeBiopayClientInstallId(
  value: unknown,
  options: { required?: boolean } = {},
): string | null {
  const clientInstallId = collapseWhitespace(stringValue(value) ?? "");
  if (!clientInstallId) {
    if (options.required) {
      throw new HttpError(400, "Client install ID is required.", {
        code: "missing_client_install_id",
      });
    }
    return null;
  }
  if (clientInstallId.length > 200) {
    throw new HttpError(400, "Client install ID is too long.", {
      code: "invalid_client_install_id",
    });
  }
  return clientInstallId;
}

export function normalizeBiopayDeviceLabel(value: unknown): string | null {
  const deviceLabel = collapseWhitespace(stringValue(value) ?? "");
  if (!deviceLabel) return null;
  if (deviceLabel.length > 120) {
    throw new HttpError(400, "Device label is too long.", {
      code: "invalid_device_label",
    });
  }
  return deviceLabel;
}

export function normalizeRwandaPhone(raw: string): string {
  const trimmed = raw.trim();
  const digits = digitsOnly(trimmed);

  if (!digits) {
    throw new HttpError(400, "A Rwanda MTN mobile number is required.", {
      code: "invalid_phone",
    });
  }

  if (trimmed.startsWith("+")) {
    if (/^2507\d{8}$/.test(digits)) {
      return `+${digits}`;
    }
  }

  if (/^2507\d{8}$/.test(digits)) {
    return `+${digits}`;
  }

  if (/^07\d{8}$/.test(digits)) {
    return `+250${digits.slice(1)}`;
  }

  if (/^7\d{8}$/.test(digits)) {
    return `+250${digits}`;
  }

  throw new HttpError(400, "A Rwanda MTN mobile number is required.", {
    code: "invalid_phone",
  });
}

export function normalizeBiopayUssd(value: unknown): {
  ussdString: string;
  ussdNormalized: string;
  recipientPhoneE164: string;
} {
  const raw = stringValue(value);
  if (!raw) {
    throw new HttpError(400, "A MoMo USSD string is required.", {
      code: "missing_ussd",
    });
  }

  let candidate = raw.trim().replace(/\s+/g, "");
  if (candidate.toLowerCase().startsWith("tel:")) {
    candidate = candidate.slice(4);
  }
  candidate = candidate.replace(/%23$/i, "#");

  let recipientPart = candidate;
  const ussdMatch = candidate.match(/^\*182\*1\*1\*([^#]+)#$/);
  if (ussdMatch) {
    recipientPart = ussdMatch[1];
  }

  const recipientPhoneE164 = normalizeRwandaPhone(recipientPart);
  const localPhone = `0${recipientPhoneE164.slice(4)}`;
  const ussdNormalized = `*182*1*1*${localPhone}#`;

  return {
    ussdString: ussdNormalized,
    ussdNormalized,
    recipientPhoneE164,
  };
}

export function normalizeBiopayEmbedding(value: unknown): number[] {
  if (!Array.isArray(value) || value.length != 192) {
    throw new HttpError(400, "Embedding must contain 192 values.", {
      code: "invalid_embedding_shape",
    });
  }

  const numeric = value.map((entry) => {
    const parsed = numberValue(entry);
    if (parsed === undefined || !Number.isFinite(parsed)) {
      throw new HttpError(400, "Embedding values must be finite numbers.", {
        code: "invalid_embedding_value",
      });
    }
    return parsed;
  });

  const norm = Math.sqrt(
    numeric.reduce((sum, entry) => sum + (entry * entry), 0),
  );
  if (!Number.isFinite(norm) || norm <= 0) {
    throw new HttpError(400, "Embedding norm must be greater than zero.", {
      code: "invalid_embedding_norm",
    });
  }

  return numeric.map((entry) => entry / norm);
}

export function toVectorLiteral(embedding: number[]): string {
  return `[${embedding.map((entry) => entry.toFixed(8)).join(",")}]`;
}

function nowEpochSeconds(): number {
  return Math.floor(Date.now() / 1000);
}

function decodeJwtPayload(token: string): JsonRecord {
  const segments = token.split(".");
  if (segments.length != 3) {
    throw new HttpError(401, "Invalid owner token.", {
      code: "invalid_owner_token",
    });
  }

  try {
    const decoded = base64UrlDecode(segments[1]);
    return asRecord(JSON.parse(decoded));
  } catch {
    throw new HttpError(401, "Invalid owner token.", {
      code: "invalid_owner_token",
    });
  }
}

export async function signOwnerToken(payload: JsonRecord): Promise<string> {
  const header = { alg: "HS256", typ: "JWT" };
  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const signingInput = `${encodedHeader}.${encodedPayload}`;
  const signature = await hmacSha256Base64Url(
    signingInput,
    ownerTokenSecret(),
  );
  return `${signingInput}.${signature}`;
}

export async function verifyOwnerToken(token: string): Promise<JsonRecord> {
  const segments = token.split(".");
  if (segments.length != 3) {
    throw new HttpError(401, "Invalid owner token.", {
      code: "invalid_owner_token",
    });
  }

  const signingInput = `${segments[0]}.${segments[1]}`;
  const expectedSignature = await hmacSha256Base64Url(
    signingInput,
    ownerTokenSecret(),
  );
  if (segments[2] != expectedSignature) {
    throw new HttpError(401, "Invalid owner token.", {
      code: "invalid_owner_token",
    });
  }

  const payload = decodeJwtPayload(token);
  const exp = numberValue(payload.exp);
  if (exp !== undefined && exp < nowEpochSeconds()) {
    throw new HttpError(401, "Owner token has expired.", {
      code: "expired_owner_token",
    });
  }

  return payload;
}

function parseRequestIp(req: Request): string | null {
  const forwarded = req.headers.get("x-forwarded-for");
  if (forwarded) {
    const first = forwarded.split(",")[0]?.trim();
    if (first) return first;
  }
  return req.headers.get("cf-connecting-ip")?.trim() || null;
}

async function hashFingerprint(value: string): Promise<string> {
  return await sha256Hex(`${value}:${rateLimitSecret()}`);
}

function generateNumericCode(length: number): string {
  let code = "";
  const bytes = crypto.getRandomValues(new Uint8Array(length));
  for (const byte of bytes) {
    code += (byte % 10).toString();
  }
  return code;
}

async function hashManagementCode(
  biopayId: string,
  managementCode: string,
): Promise<string> {
  return await sha256Hex(
    `${biopayId}:${managementCode}:${managementCodePepper()}`,
  );
}

async function createOwnerToken(profile: BiopayProfileRow): Promise<string> {
  const issuedAt = nowEpochSeconds();
  const expiresAt = issuedAt + (ownerTokenTtlMinutes() * 60);
  return await signOwnerToken({
    sub: profile.id,
    biopay_id: profile.biopay_id,
    owner_token_version: profile.owner_token_version,
    iat: issuedAt,
    exp: expiresAt,
  });
}

async function recordEnrollmentAudit(
  supabase: ReturnType<typeof adminClient>,
  payload: JsonRecord,
) {
  const { error } = await supabase.from("biopay_enrollment_audit").insert(
    payload,
  );
  if (error) {
    console.error("[biopay-api] failed to write enrollment audit", error);
  }
}

async function recordMatchAudit(
  supabase: ReturnType<typeof adminClient>,
  payload: JsonRecord,
) {
  const { error } = await supabase.from("biopay_match_audit").insert(payload);
  if (error) {
    console.error("[biopay-api] failed to write match audit", error);
  }
}

async function buildMatchRateLimitSubjects(
  req: Request,
  clientInstallId: string | null,
): Promise<{ ipHash: string | null; subjects: MatchRateLimitSubject[] }> {
  const ip = parseRequestIp(req);
  const ipHash = ip ? await hashFingerprint(ip) : null;
  const subjects: MatchRateLimitSubject[] = [];

  if (clientInstallId) {
    subjects.push({
      auditField: "client_install_id",
      auditValue: clientInstallId,
      localKey: `client_install_id:${await hashFingerprint(clientInstallId)}`,
      source: "client_install_id",
    });
  }

  if (ipHash) {
    subjects.push({
      auditField: "ip_hash",
      auditValue: ipHash,
      localKey: `ip_hash:${ipHash}`,
      source: "ip_hash",
    });
  }

  if (subjects.length == 0) {
    subjects.push({
      auditField: null,
      auditValue: null,
      localKey: "anonymous",
      source: "anonymous",
    });
  }

  return { ipHash, subjects };
}

async function countRecentMatchAuditRows(
  supabase: ReturnType<typeof adminClient>,
  field: MatchRateLimitAuditField,
  value: string,
  windowStartIso: string,
): Promise<number> {
  const { count, error } = await supabase
    .from("biopay_match_audit")
    .select("id", { count: "exact", head: true })
    .eq(field, value)
    .gte("created_at", windowStartIso);

  if (error) {
    throw error;
  }

  return count ?? 0;
}

export async function enforceMatchRateLimit(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  clientInstallId: string | null,
  deviceLabel: string | null,
): Promise<{ ipHash: string | null }> {
  const now = Date.now();
  const retryAfterSeconds = matchRateLimitRetryAfterSeconds();
  const { ipHash, subjects } = await buildMatchRateLimitSubjects(
    req,
    clientInstallId,
  );

  const windowStartIso = new Date(now - matchRateLimitWindowMs()).toISOString();
  for (const subject of subjects) {
    if (!subject.auditField || !subject.auditValue) {
      continue;
    }

    const recentCount = await countRecentMatchAuditRows(
      supabase,
      subject.auditField,
      subject.auditValue,
      windowStartIso,
    );
    if (recentCount >= matchRateLimitMaxRequests()) {
      await recordMatchAudit(supabase, {
        matched_profile_id: null,
        similarity: null,
        result: "rate_limited",
        client_install_id: clientInstallId,
        ip_hash: ipHash,
        device_label: deviceLabel,
        details: {
          limited_by: subject.source,
          limiter: "durable",
          max_requests: matchRateLimitMaxRequests(),
          recent_count: recentCount,
          retry_after_seconds: retryAfterSeconds,
          window_minutes: Math.ceil(matchRateLimitWindowMs() / 60000),
        },
      });
      throw new HttpError(429, "Too many BioPay match requests.", {
        code: "rate_limited",
        limited_by: subject.source,
        retry_after_seconds: retryAfterSeconds,
      });
    }
  }

  return { ipHash };
}

async function fetchManagedProfile(
  supabase: ReturnType<typeof adminClient>,
  body: JsonRecord,
): Promise<BiopayProfileRow> {
  const ownerToken = stringValue(body.owner_token);
  if (ownerToken) {
    const payload = await verifyOwnerToken(ownerToken);
    const profileId = stringValue(payload.sub);
    const biopayId = normalizeBiopayId(payload.biopay_id);
    const ownerTokenVersion = numberValue(payload.owner_token_version);
    if (!profileId || ownerTokenVersion === undefined) {
      throw new HttpError(401, "Invalid owner token.", {
        code: "invalid_owner_token",
      });
    }

    const { data, error } = await supabase
      .from("biopay_profiles")
      .select(
        "id, biopay_id, display_name, ussd_string, status, owner_token_version, management_code_hash, management_code_hint, created_at",
      )
      .eq("id", profileId)
      .eq("biopay_id", biopayId)
      .maybeSingle();

    if (error) throw error;
    if (!data || data.owner_token_version != ownerTokenVersion) {
      throw new HttpError(401, "Owner token is no longer valid.", {
        code: "stale_owner_token",
      });
    }

    return data as BiopayProfileRow;
  }

  const biopayId = normalizeBiopayId(body.biopay_id);
  const managementCode = normalizeBiopayManagementCode(body.management_code);
  const { data, error } = await supabase
    .from("biopay_profiles")
    .select(
      "id, biopay_id, display_name, ussd_string, status, owner_token_version, management_code_hash, management_code_hint, created_at",
    )
    .eq("biopay_id", biopayId)
    .maybeSingle();

  if (error) throw error;
  if (!data) {
    throw new HttpError(404, "BioPay profile not found.", {
      code: "profile_not_found",
    });
  }

  const expectedHash = await hashManagementCode(biopayId, managementCode);
  if (expectedHash != data.management_code_hash) {
    throw new HttpError(401, "Management code is invalid.", {
      code: "invalid_management_code",
    });
  }

  return data as BiopayProfileRow;
}

function ensureMutableProfile(profile: BiopayProfileRow) {
  if (profile.status == "deleted") {
    throw new HttpError(410, "BioPay profile has already been deleted.", {
      code: "profile_deleted",
    });
  }
}

async function reactivateEmbeddings(
  supabase: ReturnType<typeof adminClient>,
  embeddingIds: string[],
) {
  if (embeddingIds.length == 0) return;
  const { error } = await supabase
    .from("biopay_face_embeddings")
    .update({ is_active: true })
    .in("id", embeddingIds);
  if (error) {
    console.error("[biopay-api] failed to reactivate embeddings", error);
  }
}

async function handleEnrollFace(
  body: JsonRecord,
  req: Request,
  origin: string | null,
): Promise<Response> {
  const supabase = adminClient();
  const displayName = normalizeBiopayDisplayName(body.display_name);
  const { ussdString, ussdNormalized, recipientPhoneE164 } =
    normalizeBiopayUssd(body.ussd_string);
  const consentVersion = normalizeBiopayConsentVersion(body.consent_version);
  const embedding = normalizeBiopayEmbedding(body.embedding);
  const modelVersion =
    collapseWhitespace(stringValue(body.model_version) ?? "") ||
    "mobilefacenet_int8_v1";
  const qualityScore = normalizeBiopayQualityScore(body.quality_score);
  const clientInstallId = normalizeBiopayClientInstallId(
    body.client_install_id,
  );
  const deviceLabel = normalizeBiopayDeviceLabel(body.device_label);
  const requestIpHash = parseRequestIp(req)
    ? await hashFingerprint(parseRequestIp(req) as string)
    : null;

  const { data: existingProfile, error: existingProfileError } = await supabase
    .from("biopay_profiles")
    .select("id, biopay_id")
    .eq("ussd_normalized", ussdNormalized)
    .in("status", ["pending", "active", "suspended"])
    .maybeSingle();

  if (existingProfileError) {
    throw existingProfileError;
  }

  if (existingProfile) {
    throw new HttpError(409, "That MoMo number is already registered.", {
      code: "duplicate_ussd",
      biopay_id: existingProfile.biopay_id,
    });
  }

  const { data: duplicateRows, error: duplicateError } = await supabase.rpc(
    "find_duplicate_biopay_profile",
    {
      query_embedding: toVectorLiteral(embedding),
      similarity_threshold: duplicateFaceThreshold(),
    },
  );

  if (duplicateError) {
    throw duplicateError;
  }

  const duplicateProfile = (duplicateRows as DuplicateRpcRow[] | null)?.[0];
  if (duplicateProfile) {
    throw new HttpError(409, "That face is already registered.", {
      code: "duplicate_face",
      biopay_id: duplicateProfile.biopay_id,
      similarity: duplicateProfile.similarity,
    });
  }

  const { data: generatedId, error: generatedIdError } = await supabase.rpc(
    "generate_biopay_id",
  );
  if (generatedIdError) {
    throw generatedIdError;
  }

  const biopayId = normalizeBiopayId(generatedId);
  const managementCode = generateNumericCode(manageCodeLength());
  const managementCodeHash = await hashManagementCode(
    biopayId,
    managementCode,
  );

  const { data: profile, error: profileError } = await supabase
    .from("biopay_profiles")
    .insert({
      biopay_id: biopayId,
      display_name: displayName,
      ussd_string: ussdString,
      ussd_normalized: ussdNormalized,
      recipient_phone_e164: recipientPhoneE164,
      consent_version: consentVersion,
      management_code_hash: managementCodeHash,
      management_code_hint: managementCode.slice(-2),
    })
    .select(
      "id, biopay_id, display_name, ussd_string, status, owner_token_version, management_code_hash, management_code_hint, created_at",
    )
    .single();

  if (profileError) {
    throw profileError;
  }

  const { error: embeddingError } = await supabase
    .from("biopay_face_embeddings")
    .insert({
      profile_id: profile.id,
      embedding: toVectorLiteral(embedding),
      model_version: modelVersion,
      quality_score: qualityScore,
      source: "enrollment",
      is_active: true,
    });

  if (embeddingError) {
    await supabase.from("biopay_profiles").delete().eq("id", profile.id);
    throw embeddingError;
  }

  await recordEnrollmentAudit(supabase, {
    profile_id: profile.id,
    event_type: "enrollment_succeeded",
    client_install_id: clientInstallId,
    ip_hash: requestIpHash,
    details: {
      device_label: deviceLabel,
      model_version: modelVersion,
      quality_score: qualityScore,
    },
  });

  const ownerToken = await createOwnerToken(profile as BiopayProfileRow);

  return ok(
    {
      biopay_id: profile.biopay_id,
      enrolled_at: profile.created_at,
      owner_token: ownerToken,
      management_code: managementCode,
      management_code_hint: managementCode.slice(-2),
      ussd_string: ussdString,
    },
    201,
    origin,
  );
}

async function handleMatchFace(
  body: JsonRecord,
  req: Request,
  origin: string | null,
): Promise<Response> {
  const supabase = adminClient();
  const embedding = normalizeBiopayEmbedding(body.embedding);
  const threshold = normalizeBiopayMatchThreshold(body.threshold);
  const clientInstallId = normalizeBiopayClientInstallId(
    body.client_install_id,
    { required: true },
  );
  const deviceLabel = normalizeBiopayDeviceLabel(body.device_label);
  const { ipHash } = await enforceMatchRateLimit(
    supabase,
    req,
    clientInstallId,
    deviceLabel,
  );

  const { data, error } = await supabase.rpc("match_biopay_embedding", {
    query_embedding: toVectorLiteral(embedding),
    limit_count: 1,
  });

  if (error) {
    throw error;
  }

  const topMatch = (data as MatchRpcRow[] | null)?.[0];
  const score = topMatch?.similarity ?? 0;
  const matched = Boolean(topMatch && score >= threshold);

  await recordMatchAudit(supabase, {
    matched_profile_id: matched ? topMatch?.profile_id : null,
    similarity: topMatch?.similarity ?? null,
    result: matched ? "matched" : "no_match",
    client_install_id: clientInstallId,
    ip_hash: ipHash,
    device_label: deviceLabel,
    details: {
      threshold,
      top_biopay_id: topMatch?.biopay_id ?? null,
      model_version: topMatch?.model_version ?? null,
    },
  });

  if (!matched || !topMatch) {
    return ok(
      {
        match: false,
        score,
      },
      200,
      origin,
    );
  }

  return ok(
    {
      match: true,
      biopay_id: topMatch.biopay_id,
      display_name: topMatch.display_name,
      ussd_string: topMatch.ussd_string,
      score,
    },
    200,
    origin,
  );
}

async function handleGetManagedProfile(
  body: JsonRecord,
  origin: string | null,
): Promise<Response> {
  const supabase = adminClient();
  const profile = await fetchManagedProfile(supabase, body);

  return ok(
    {
      biopay_id: profile.biopay_id,
      display_name: profile.display_name,
      ussd_string: profile.ussd_string,
      status: profile.status,
      management_code_hint: profile.management_code_hint,
      created_at: profile.created_at,
    },
    200,
    origin,
  );
}

async function handleUpdateProfile(
  body: JsonRecord,
  req: Request,
  origin: string | null,
): Promise<Response> {
  const supabase = adminClient();
  const profile = await fetchManagedProfile(supabase, body);
  ensureMutableProfile(profile);

  const updates: JsonRecord = {};
  if ("display_name" in body) {
    updates.display_name = normalizeBiopayDisplayName(body.display_name);
  }

  if ("ussd_string" in body) {
    const { ussdString, ussdNormalized, recipientPhoneE164 } =
      normalizeBiopayUssd(body.ussd_string);
    const { data: duplicateProfile, error: duplicateError } = await supabase
      .from("biopay_profiles")
      .select("id, biopay_id")
      .eq("ussd_normalized", ussdNormalized)
      .in("status", ["pending", "active", "suspended"])
      .neq("id", profile.id)
      .maybeSingle();

    if (duplicateError) {
      throw duplicateError;
    }
    if (duplicateProfile) {
      throw new HttpError(409, "That MoMo number is already registered.", {
        code: "duplicate_ussd",
        biopay_id: duplicateProfile.biopay_id,
      });
    }

    updates.ussd_string = ussdString;
    updates.ussd_normalized = ussdNormalized;
    updates.recipient_phone_e164 = recipientPhoneE164;
  }

  const updateKeys = Object.keys(updates);
  if (updateKeys.length == 0) {
    throw new HttpError(400, "No profile changes were provided.", {
      code: "no_profile_updates",
    });
  }

  const clientInstallId = normalizeBiopayClientInstallId(
    body.client_install_id,
  );
  const deviceLabel = normalizeBiopayDeviceLabel(body.device_label);
  const requestIpHash = parseRequestIp(req)
    ? await hashFingerprint(parseRequestIp(req) as string)
    : null;

  const { data, error } = await supabase
    .from("biopay_profiles")
    .update(updates)
    .eq("id", profile.id)
    .select(
      "id, biopay_id, display_name, ussd_string, status, owner_token_version, management_code_hash, management_code_hint, created_at",
    )
    .single();

  if (error) {
    throw error;
  }

  await recordEnrollmentAudit(supabase, {
    profile_id: profile.id,
    event_type: "profile_updated",
    client_install_id: clientInstallId,
    ip_hash: requestIpHash,
    details: {
      updated_fields: updateKeys,
      device_label: deviceLabel,
    },
  });

  const updatedProfile = data as BiopayProfileRow;
  return ok(
    {
      biopay_id: updatedProfile.biopay_id,
      display_name: updatedProfile.display_name,
      ussd_string: updatedProfile.ussd_string,
      status: updatedProfile.status,
      management_code_hint: updatedProfile.management_code_hint,
      created_at: updatedProfile.created_at,
    },
    200,
    origin,
  );
}

async function handleReEnrollFace(
  body: JsonRecord,
  req: Request,
  origin: string | null,
): Promise<Response> {
  const supabase = adminClient();
  const profile = await fetchManagedProfile(supabase, body);
  ensureMutableProfile(profile);

  const embedding = normalizeBiopayEmbedding(body.embedding);
  const modelVersion =
    collapseWhitespace(stringValue(body.model_version) ?? "") ||
    "mobilefacenet_int8_v1";
  const qualityScore = normalizeBiopayQualityScore(body.quality_score);
  const clientInstallId = normalizeBiopayClientInstallId(
    body.client_install_id,
  );
  const deviceLabel = normalizeBiopayDeviceLabel(body.device_label);
  const requestIpHash = parseRequestIp(req)
    ? await hashFingerprint(parseRequestIp(req) as string)
    : null;

  const { data: duplicateRows, error: duplicateError } = await supabase.rpc(
    "find_duplicate_biopay_profile",
    {
      query_embedding: toVectorLiteral(embedding),
      similarity_threshold: duplicateFaceThreshold(),
    },
  );

  if (duplicateError) {
    throw duplicateError;
  }

  const duplicateProfile = (duplicateRows as DuplicateRpcRow[] | null)?.[0];
  if (duplicateProfile && duplicateProfile.profile_id != profile.id) {
    throw new HttpError(409, "That face is already registered.", {
      code: "duplicate_face",
      biopay_id: duplicateProfile.biopay_id,
      similarity: duplicateProfile.similarity,
    });
  }

  const { data: activeRows, error: activeRowsError } = await supabase
    .from("biopay_face_embeddings")
    .select("id")
    .eq("profile_id", profile.id)
    .eq("is_active", true);

  if (activeRowsError) {
    throw activeRowsError;
  }

  const activeEmbeddingIds = ((activeRows ?? []) as EmbeddingRow[])
    .map((row) => row.id);
  if (activeEmbeddingIds.length > 0) {
    const { error: deactivateError } = await supabase
      .from("biopay_face_embeddings")
      .update({ is_active: false })
      .in("id", activeEmbeddingIds);
    if (deactivateError) {
      throw deactivateError;
    }
  }

  const { error: insertError } = await supabase
    .from("biopay_face_embeddings")
    .insert({
      profile_id: profile.id,
      embedding: toVectorLiteral(embedding),
      model_version: modelVersion,
      quality_score: qualityScore,
      source: "re_enrollment",
      is_active: true,
    });

  if (insertError) {
    await reactivateEmbeddings(supabase, activeEmbeddingIds);
    throw insertError;
  }

  const { data: updatedProfile, error: updateError } = await supabase
    .from("biopay_profiles")
    .update({
      owner_token_version: profile.owner_token_version + 1,
      status: "active",
    })
    .eq("id", profile.id)
    .select(
      "id, biopay_id, display_name, ussd_string, status, owner_token_version, management_code_hash, management_code_hint, created_at",
    )
    .single();

  if (updateError) {
    throw updateError;
  }

  await recordEnrollmentAudit(supabase, {
    profile_id: profile.id,
    event_type: "re_enrollment_succeeded",
    client_install_id: clientInstallId,
    ip_hash: requestIpHash,
    details: {
      device_label: deviceLabel,
      model_version: modelVersion,
      quality_score: qualityScore,
    },
  });

  const ownerToken = await createOwnerToken(updatedProfile as BiopayProfileRow);
  return ok(
    {
      success: true,
      biopay_id: profile.biopay_id,
      display_name: profile.display_name,
      management_code_hint: profile.management_code_hint,
      owner_token: ownerToken,
      enrolled_at: new Date().toISOString(),
    },
    200,
    origin,
  );
}

async function handleDeleteProfile(
  body: JsonRecord,
  req: Request,
  origin: string | null,
): Promise<Response> {
  const supabase = adminClient();
  const profile = await fetchManagedProfile(supabase, body);

  if (profile.status != "deleted") {
    const { error: embeddingsError } = await supabase
      .from("biopay_face_embeddings")
      .update({ is_active: false })
      .eq("profile_id", profile.id)
      .eq("is_active", true);

    if (embeddingsError) {
      throw embeddingsError;
    }

    const { error: deleteError } = await supabase
      .from("biopay_profiles")
      .update({
        status: "deleted",
        owner_token_version: profile.owner_token_version + 1,
      })
      .eq("id", profile.id);

    if (deleteError) {
      throw deleteError;
    }

    const clientInstallId = normalizeBiopayClientInstallId(
      body.client_install_id,
    );
    const requestIpHash = parseRequestIp(req)
      ? await hashFingerprint(parseRequestIp(req) as string)
      : null;

    await recordEnrollmentAudit(supabase, {
      profile_id: profile.id,
      event_type: "profile_deleted",
      client_install_id: clientInstallId,
      ip_hash: requestIpHash,
      details: {},
    });
  }

  return ok(
    {
      deleted: true,
      biopay_id: profile.biopay_id,
    },
    200,
    origin,
  );
}

async function handleReportProfile(
  body: JsonRecord,
  origin: string | null,
): Promise<Response> {
  const supabase = adminClient();
  const biopayId = normalizeBiopayId(body.biopay_id);
  const reason = normalizeBiopayReason(body.reason);
  const notes = stringValue(body.notes) ?? null;
  const clientInstallId = normalizeBiopayClientInstallId(
    body.client_install_id,
  );

  const { data: profile, error: profileError } = await supabase
    .from("biopay_profiles")
    .select("id, biopay_id")
    .eq("biopay_id", biopayId)
    .maybeSingle();

  if (profileError) {
    throw profileError;
  }
  if (!profile) {
    throw new HttpError(404, "BioPay profile not found.", {
      code: "profile_not_found",
    });
  }

  const { error } = await supabase.from("biopay_abuse_reports").insert({
    profile_id: profile.id,
    reason,
    notes,
    client_install_id: clientInstallId,
  });

  if (error) {
    throw error;
  }

  return ok(
    {
      reported: true,
      biopay_id: biopayId,
    },
    201,
    origin,
  );
}

export async function handleBiopayRequest(req: Request): Promise<Response> {
  let origin: string | null = null;

  try {
    origin = assertAllowedBiopayOrigin(req);
    if (req.method == "OPTIONS") {
      const headers = buildResponseHeaders(origin);
      headers.set("Access-Control-Max-Age", "600");
      return new Response("ok", { headers });
    }

    if (req.method == "GET") {
      return ok(
        {
          ok: true,
          service: "biopay-api",
          version: 1,
        },
        200,
        origin,
      );
    }

    if (req.method != "POST") {
      return fail("Method not allowed.", 405, undefined, origin);
    }

    const body = await parseBody(req);
    const action = normalizeBiopayAction(body.action);

    switch (action) {
      case "health_check":
        return ok(
          {
            ok: true,
            service: "biopay-api",
            version: 1,
          },
          200,
          origin,
        );
      case "enroll_face":
        return await handleEnrollFace(body, req, origin);
      case "match_face":
        return await handleMatchFace(body, req, origin);
      case "get_managed_profile":
        return await handleGetManagedProfile(body, origin);
      case "update_profile":
        return await handleUpdateProfile(body, req, origin);
      case "re_enroll_face":
        return await handleReEnrollFace(body, req, origin);
      case "delete_profile":
        return await handleDeleteProfile(body, req, origin);
      case "report_profile":
        return await handleReportProfile(body, origin);
    }
  } catch (error) {
    if (error instanceof HttpError) {
      return fail(error.message, error.status, error.details, origin);
    }

    console.error("[biopay-api] unhandled error", error);
    return fail(
      error instanceof Error ? error.message : "Unexpected server error.",
      500,
      undefined,
      origin,
    );
  }
}

if (import.meta.main) {
  Deno.serve(handleBiopayRequest);
}
