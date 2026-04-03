import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { postWhatsAppMessage } from "../_shared/whatsapp.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const tableName = "venue_whatsapp_otp_challenges";
const otpTtlMinutes = intEnv("WHATSAPP_OTP_TTL_MINUTES", 10);
const otpMaxAttempts = intEnv("WHATSAPP_OTP_MAX_ATTEMPTS", 5);
const requestLimit = intEnv("WHATSAPP_OTP_REQUEST_LIMIT", 3);
const requestWindowMinutes = intEnv("WHATSAPP_OTP_REQUEST_WINDOW_MINUTES", 5);
const adminSessionTtlMinutes = intEnv("DINEIN_ADMIN_SESSION_TTL_MINUTES", 720);
const venueSessionTtlMinutes = intEnv("DINEIN_VENUE_SESSION_TTL_MINUTES", 720);
const graphApiVersion = Deno.env.get("WHATSAPP_GRAPH_API_VERSION") ?? "v22.0";
const defaultCountryCode =
  (Deno.env.get("DEFAULT_WHATSAPP_COUNTRY_CODE") ?? "356")
    .replace(/\D/g, "");
const allowMock = boolEnv("WHATSAPP_OTP_ALLOW_MOCK", false);
const allowTextFallback = boolEnv("WHATSAPP_OTP_ALLOW_TEXT_FALLBACK", false);
const allowTestOverride = boolEnv("WHATSAPP_OTP_ALLOW_TEST_OVERRIDE", false);
const accessVerificationMethods = new Set(["otp", "admin_override"]);

type JsonRecord = Record<string, unknown>;
type AdminProfile = {
  id: string;
  display_name?: string | null;
  email?: string | null;
  role?: string | null;
  whatsapp_number?: string | null;
};

type VenueAccessRow = {
  id: string;
  name?: string | null;
  slug?: string | null;
  image_url?: string | null;
  status?: string | null;
  approved_at?: string | null;
  access_verified_at?: string | null;
  normalized_access_phone?: string | null;
  phone?: string | null;
  owner_contact_phone?: string | null;
  owner_whatsapp_number?: string | null;
};

function boolEnv(key: string, fallback: boolean): boolean {
  const raw = Deno.env.get(key)?.trim().toLowerCase();
  if (!raw) return fallback;
  return raw === "1" || raw === "true" || raw === "yes" || raw === "on";
}

function intEnv(key: string, fallback: number): number {
  const raw = Deno.env.get(key)?.trim();
  if (!raw) return fallback;
  const parsed = Number.parseInt(raw, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function getEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    throw new Error(`Missing environment variable: ${name}`);
  }
  return value;
}

function optionalEnv(name: string): string | null {
  const value = Deno.env.get(name)?.trim();
  return value && value.length > 0 ? value : null;
}

function getSigningSecret(primary: string, fallback?: string): string {
  return optionalEnv(primary) ??
    (fallback ? getEnv(fallback) : getEnv(primary));
}

function adminClient() {
  return createClient(
    getEnv("SUPABASE_URL"),
    getEnv("SUPABASE_SERVICE_ROLE_KEY"),
    { auth: { persistSession: false } },
  );
}

function digitsOnly(phone: string): string {
  return phone.replace(/\D/g, "");
}

function normalizePhone(raw: string): string {
  const trimmed = raw.trim();
  const digits = digitsOnly(trimmed);

  if (!digits) {
    throw new Error("A valid WhatsApp number is required.");
  }

  if (trimmed.startsWith("+")) {
    if (digits.length < 8 || digits.length > 15) {
      throw new Error("A valid WhatsApp number is required.");
    }
    return `+${digits}`;
  }

  if (trimmed.startsWith("00")) {
    const normalized = digits.slice(2);
    if (normalized.length < 8 || normalized.length > 15) {
      throw new Error("A valid WhatsApp number is required.");
    }
    return `+${normalized}`;
  }

  if (digits.length === 8 && defaultCountryCode.length > 0) {
    return `+${defaultCountryCode}${digits}`;
  }

  if (digits.length >= 10 && digits.length <= 15) {
    return `+${digits}`;
  }

  throw new Error("A valid WhatsApp number is required.");
}

function optionalNormalizedPhone(raw?: string | null): string | null {
  if (!raw || !raw.trim()) return null;
  try {
    return normalizePhone(raw);
  } catch {
    return null;
  }
}

function numericOtp(length = 6): string {
  let code = "";
  const bytes = crypto.getRandomValues(new Uint8Array(length));
  for (const byte of bytes) {
    code += (byte % 10).toString();
  }
  return code;
}

async function sha256Hex(value: string): Promise<string> {
  const encoded = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", encoded);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function bytesToBase64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(
    /=+$/g,
    "",
  );
}

function base64UrlEncode(value: string): string {
  return bytesToBase64Url(new TextEncoder().encode(value));
}

async function hmacSha256Base64Url(
  value: string,
  secret: string,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(value),
  );
  return bytesToBase64Url(new Uint8Array(signature));
}

async function signAdminSessionJwt(payload: JsonRecord): Promise<string> {
  const header = { alg: "HS256", typ: "JWT" };
  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const signingInput = `${encodedHeader}.${encodedPayload}`;
  const signature = await hmacSha256Base64Url(
    signingInput,
    getSigningSecret("DINEIN_ADMIN_SESSION_SECRET"),
  );
  return `${signingInput}.${signature}`;
}

async function signVenueSessionJwt(payload: JsonRecord): Promise<string> {
  const header = { alg: "HS256", typ: "JWT" };
  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const signingInput = `${encodedHeader}.${encodedPayload}`;
  const signature = await hmacSha256Base64Url(
    signingInput,
    getSigningSecret(
      "DINEIN_VENUE_SESSION_SECRET",
      "DINEIN_ADMIN_SESSION_SECRET",
    ),
  );
  return `${signingInput}.${signature}`;
}

async function otpHash(phone: string, code: string): Promise<string> {
  const pepper = Deno.env.get("WHATSAPP_OTP_PEPPER") ?? "";
  return await sha256Hex(`${digitsOnly(phone)}:${code}:${pepper}`);
}

function jsonResponse(status: number, body: JsonRecord): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function errorResponse(
  message: string,
  status = 400,
  details?: JsonRecord,
): Response {
  return jsonResponse(status, {
    success: false,
    message,
    ...(details ?? {}),
  });
}

function extractMessageId(payload: unknown): string | null {
  if (!payload || typeof payload !== "object") return null;
  const messages = (payload as { messages?: Array<{ id?: string }> }).messages;
  if (!Array.isArray(messages) || typeof messages[0]?.id !== "string") {
    return null;
  }
  return messages[0].id;
}

async function sendCloudApiOtp(phone: string, code: string) {
  const recipient = digitsOnly(phone);
  const templateName = Deno.env.get("WHATSAPP_TEMPLATE_NAME")?.trim();
  const templateLanguage = Deno.env.get("WHATSAPP_TEMPLATE_LANGUAGE")?.trim() ??
    "en_US";
  const buttonIndex = Deno.env.get("WHATSAPP_TEMPLATE_URL_BUTTON_INDEX")
    ?.trim();

  if (templateName) {
    const components: Array<JsonRecord> = [
      {
        type: "body",
        parameters: [{ type: "text", text: code }],
      },
    ];

    if (buttonIndex) {
      components.push({
        type: "button",
        sub_type: "url",
        index: buttonIndex,
        parameters: [{ type: "text", text: code }],
      });
    }

    const templatePayload = {
      messaging_product: "whatsapp",
      to: recipient,
      type: "template",
      template: {
        name: templateName,
        language: { code: templateLanguage },
        components,
      },
    };

    const templateResponse = await postWhatsAppMessage(templatePayload);
    if (templateResponse.ok) {
      return {
        sent: true,
        method: "template",
        messageId: extractMessageId(templateResponse.data),
        response: templateResponse.data,
      };
    }

    if (!allowTextFallback) {
      return {
        sent: false,
        method: "template",
        messageId: null,
        response: templateResponse.data,
      };
    }
  }

  if (!allowTextFallback) {
    return {
      sent: false,
      method: templateName ? "template" : "text",
      messageId: null,
      response: {
        message: "WhatsApp template send failed and text fallback is disabled.",
      },
    };
  }

  const textPayload = {
    messaging_product: "whatsapp",
    to: recipient,
    type: "text",
    text: {
      preview_url: false,
      body:
        `Your DineIn verification code is ${code}. It expires in ${otpTtlMinutes} minutes.`,
    },
  };

  const textResponse = await postWhatsAppMessage(textPayload);
  return {
    sent: textResponse.ok,
    method: "text",
    messageId: extractMessageId(textResponse.data),
    response: textResponse.data,
  };
}

async function getAdminProfileByPhone(
  supabase: ReturnType<typeof adminClient>,
  normalizedPhone: string,
): Promise<AdminProfile | null> {
  const { data, error } = await supabase
    .from("dinein_profiles")
    .select("id, display_name, email, role, whatsapp_number")
    .eq("role", "admin");

  if (error) {
    console.error("[whatsapp-otp] admin profile lookup failed", error);
    throw new Error("Could not verify admin access configuration.");
  }

  const normalizedDigits = digitsOnly(normalizedPhone);
  for (const row of (data ?? []) as AdminProfile[]) {
    const rowPhone = typeof row.whatsapp_number === "string"
      ? row.whatsapp_number
      : "";
    if (digitsOnly(rowPhone) === normalizedDigits) {
      return row;
    }
  }

  return null;
}

function venueMatchesPhone(
  venue: VenueAccessRow,
  normalizedPhone: string,
): boolean {
  const targetDigits = digitsOnly(normalizedPhone);
  if (digitsOnly(venue.normalized_access_phone ?? "") === targetDigits) {
    return true;
  }
  return [
    venue.phone,
    venue.owner_contact_phone,
    venue.owner_whatsapp_number,
  ].some((value) => digitsOnly(value ?? "") === targetDigits);
}

export function buildVenueAccessAuditUpdate(
  venue: VenueAccessRow,
  args: {
    issuedAt: string;
    verifiedAt?: string;
    normalizedPhone?: string;
    verificationMethod?: string;
    verifiedBy?: string;
    verificationNote?: string | null;
  },
): JsonRecord {
  if (
    args.verificationMethod &&
    !accessVerificationMethods.has(args.verificationMethod)
  ) {
    throw new Error(
      `Unsupported access verification method: ${args.verificationMethod}`,
    );
  }
  return {
    normalized_access_phone: args.normalizedPhone ?? null,
    phone: venue.phone?.trim() || args.normalizedPhone || null,
    owner_contact_phone: venue.owner_contact_phone?.trim() ||
      args.normalizedPhone || null,
    owner_whatsapp_number: venue.owner_whatsapp_number?.trim() ||
      args.normalizedPhone || null,
    approved_at: venue.approved_at ?? args.verifiedAt ?? args.issuedAt,
    last_access_token_issued_at: args.issuedAt,
    ...(args.verifiedAt ? { access_verified_at: args.verifiedAt } : {}),
    ...(args.verifiedAt && args.verificationMethod
      ? { access_verification_method: args.verificationMethod }
      : {}),
    ...(args.verifiedAt && args.verifiedBy
      ? { access_verified_by: args.verifiedBy }
      : {}),
    ...(args.verifiedAt && args.verificationNote !== undefined
      ? { access_verification_note: args.verificationNote }
      : {}),
  };
}

async function getValidatedVenueByPhone(
  supabase: ReturnType<typeof adminClient>,
  normalizedPhone: string,
): Promise<VenueAccessRow | null> {
  const selectClause =
    "id, name, slug, image_url, status, approved_at, access_verified_at, normalized_access_phone, phone, owner_contact_phone, owner_whatsapp_number";
  const { data, error } = await supabase
    .from("dinein_venues")
    .select(selectClause)
    .eq("status", "active")
    .eq("normalized_access_phone", normalizedPhone)
    .maybeSingle();

  if (!error) {
    return data as VenueAccessRow | null;
  }

  const missingNormalizedColumn = `${error.message ?? ""} ${
    error.details ?? ""
  }`
    .toLowerCase()
    .includes("normalized_access_phone");
  if (!missingNormalizedColumn) {
    console.error("[whatsapp-otp] venue lookup failed", error);
    throw new Error("Could not verify venue access configuration.");
  }

  const { data: legacyData, error: legacyError } = await supabase
    .from("dinein_venues")
    .select(
      "id, name, slug, image_url, status, approved_at, access_verified_at, phone, owner_contact_phone, owner_whatsapp_number",
    )
    .eq("status", "active");

  if (legacyError) {
    console.error("[whatsapp-otp] legacy venue lookup failed", legacyError);
    throw new Error("Could not verify venue access configuration.");
  }

  for (const venue of (legacyData ?? []) as VenueAccessRow[]) {
    if (venueMatchesPhone(venue, normalizedPhone)) {
      return venue;
    }
  }

  return null;
}

async function buildAdminSession(
  profile: AdminProfile,
  normalizedPhone: string,
) {
  const issuedAt = new Date();
  const expiresAt = new Date(
    issuedAt.getTime() + adminSessionTtlMinutes * 60 * 1000,
  );
  const token = await signAdminSessionJwt({
    iss: "dinein-whatsapp-otp",
    aud: "dinein-admin",
    sub: profile.id,
    role: "admin",
    name: profile.display_name ?? "Admin",
    email: profile.email ?? null,
    phone: normalizedPhone,
    iat: Math.floor(issuedAt.getTime() / 1000),
    exp: Math.floor(expiresAt.getTime() / 1000),
  });

  return {
    admin_user_id: profile.id,
    access_token: token,
    display_name: profile.display_name ?? "Admin",
    whatsapp_number: normalizedPhone,
    email: profile.email ?? null,
    issued_at: issuedAt.toISOString(),
    expires_at: expiresAt.toISOString(),
  };
}

async function buildVenueSession(
  venue: VenueAccessRow,
  normalizedPhone: string,
) {
  if (!venue.id) {
    throw new Error("The validated venue could not be found.");
  }

  const issuedAt = new Date();
  const expiresAt = new Date(
    issuedAt.getTime() + venueSessionTtlMinutes * 60 * 1000,
  );
  const token = await signVenueSessionJwt({
    iss: "dinein-whatsapp-otp",
    aud: "dinein-venue",
    sub: venue.id,
    role: "venue_owner",
    venue_id: venue.id,
    phone: normalizedPhone,
    iat: Math.floor(issuedAt.getTime() / 1000),
    exp: Math.floor(expiresAt.getTime() / 1000),
  });

  return {
    access_token: token,
    venue_id: venue.id,
    venue_name: (typeof venue.name === "string" && venue.name.trim().length > 0)
      ? venue.name
      : "Venue",
    venue_slug: typeof venue.slug === "string" && venue.slug.trim().length > 0
      ? venue.slug
      : null,
    whatsapp_number: normalizedPhone,
    venue_image_url: typeof venue.image_url === "string"
      ? venue.image_url
      : null,
    issued_at: issuedAt.toISOString(),
    expires_at: expiresAt.toISOString(),
  };
}

async function persistVerifiedVenueAccess(
  supabase: ReturnType<typeof adminClient>,
  venue: VenueAccessRow,
  args: {
    issuedAt: string;
    verifiedAt: string;
    normalizedPhone: string;
    verificationMethod: string;
    verifiedBy: string;
    verificationNote?: string | null;
  },
): Promise<void> {
  const { error } = await supabase
    .from("dinein_venues")
    .update(buildVenueAccessAuditUpdate(venue, args))
    .eq("id", venue.id);

  if (error) {
    console.error(
      "[whatsapp-otp] venue access audit update failed",
      error,
    );
    throw new Error("Could not persist venue access verification.");
  }
}

function testOverrideCode(
  normalizedPhone: string,
  appScope: string,
): string | null {
  if (!allowTestOverride) return null;

  const configuredPhone = optionalNormalizedPhone(
    Deno.env.get("WHATSAPP_OTP_TEST_PHONE"),
  );
  const configuredCode = Deno.env.get("WHATSAPP_OTP_TEST_CODE")?.trim();
  const configuredScope =
    Deno.env.get("WHATSAPP_OTP_TEST_SCOPE")?.trim().toLowerCase() ?? "admin";

  if (!configuredPhone || !configuredCode || !/^\d{6}$/.test(configuredCode)) {
    return null;
  }

  if (configuredScope !== appScope) return null;
  return configuredPhone === normalizedPhone ? configuredCode : null;
}

async function handleSend(
  supabase: ReturnType<typeof adminClient>,
  body: JsonRecord,
  req: Request,
): Promise<Response> {
  const rawPhone = String(body.phone ?? body.whatsappNumber ?? "").trim();
  const appScope = String(body.appScope ?? body.app_scope ?? "venue")
    .trim()
    .toLowerCase();

  let normalizedPhone: string;
  try {
    normalizedPhone = normalizePhone(rawPhone);
  } catch (error) {
    return errorResponse(
      error instanceof Error ? error.message : "Invalid WhatsApp number.",
      400,
      { reason: "invalid_phone" },
    );
  }

  if (appScope !== "venue" && appScope !== "admin") {
    return errorResponse("Unsupported appScope.", 400, {
      reason: "unsupported_scope",
    });
  }

  if (appScope === "admin") {
    const adminProfile = await getAdminProfileByPhone(
      supabase,
      normalizedPhone,
    );
    if (!adminProfile) {
      return errorResponse(
        "This WhatsApp number is not registered for admin console access.",
        403,
        { reason: "admin_not_found" },
      );
    }
  } else if (appScope === "venue") {
    const validatedVenue = await getValidatedVenueByPhone(
      supabase,
      normalizedPhone,
    );
    if (!validatedVenue) {
      return errorResponse(
        "This WhatsApp number is not linked to a validated venue account.",
        403,
        { reason: "venue_not_found" },
      );
    }
  }

  const normalizedDigits = digitsOnly(normalizedPhone);
  const windowStart = new Date(
    Date.now() - requestWindowMinutes * 60 * 1000,
  ).toISOString();

  const { count, error: rateError } = await supabase
    .from(tableName)
    .select("id", { count: "exact", head: true })
    .eq("normalized_whatsapp_number", normalizedDigits)
    .eq("app_scope", appScope)
    .gte("created_at", windowStart);

  if (rateError) {
    console.error("[whatsapp-otp] rate limit check failed", rateError);
    return errorResponse("Could not start WhatsApp verification.", 500, {
      reason: "network_error",
    });
  }

  if ((count ?? 0) >= requestLimit) {
    return errorResponse(
      `Too many code requests. Try again in ${requestWindowMinutes} minutes.`,
      429,
      { reason: "rate_limited" },
    );
  }

  const overrideCode = testOverrideCode(normalizedPhone, appScope);
  const code = overrideCode ?? numericOtp(6);
  const verificationId = crypto.randomUUID();
  const expiresAt = new Date(Date.now() + otpTtlMinutes * 60 * 1000);
  const hash = await otpHash(normalizedPhone, code);
  const metadata = {
    user_agent: req.headers.get("user-agent"),
    forwarded_for: req.headers.get("x-forwarded-for"),
    ...(overrideCode == null ? {} : { test_override: true }),
  };

  const { error: insertError } = await supabase.from(tableName).insert({
    challenge_id: verificationId,
    whatsapp_number: normalizedPhone,
    app_scope: appScope,
    otp_hash: hash,
    expires_at: expiresAt.toISOString(),
    max_attempts: otpMaxAttempts,
    metadata,
  });

  if (insertError) {
    console.error("[whatsapp-otp] insert failed", insertError);
    return errorResponse(
      "Could not prepare WhatsApp verification. Apply the OTP migration first.",
      500,
      { reason: "configuration_missing" },
    );
  }

  const credentialsPresent = Boolean(Deno.env.get("WHATSAPP_ACCESS_TOKEN")) &&
    Boolean(Deno.env.get("WHATSAPP_PHONE_NUMBER_ID"));

  if (!credentialsPresent && allowMock) {
    await supabase
      .from(tableName)
      .update({
        delivery_status: "sent",
        delivery_method: "mock",
        metadata: {
          ...metadata,
          debug_code: code,
        },
      })
      .eq("challenge_id", verificationId);

    return jsonResponse(200, {
      success: true,
      verificationId,
      expiresAt: expiresAt.toISOString(),
      usesMock: true,
      debugCode: code,
      deliveryMethod: "mock",
    });
  }

  if (overrideCode != null) {
    await supabase
      .from(tableName)
      .update({
        delivery_status: "sent",
        delivery_method: "test_override",
        failure_reason: null,
      })
      .eq("challenge_id", verificationId);

    return jsonResponse(200, {
      success: true,
      verificationId,
      expiresAt: expiresAt.toISOString(),
      usesMock: false,
      deliveryMethod: "test_override",
    });
  }

  let sendResult;
  try {
    sendResult = await sendCloudApiOtp(normalizedPhone, code);
  } catch (error) {
    console.error("[whatsapp-otp] cloud api send failed", error);
    sendResult = {
      sent: false,
      method: "template",
      messageId: null,
      response: {
        message: error instanceof Error ? error.message : "Unknown error",
      },
    };
  }

  if (!sendResult.sent) {
    await supabase
      .from(tableName)
      .update({
        delivery_status: "failed",
        delivery_method: sendResult.method,
        failure_reason: JSON.stringify(sendResult.response),
      })
      .eq("challenge_id", verificationId);

    return errorResponse(
      "WhatsApp OTP delivery failed. Check the Cloud API secrets and template.",
      502,
      {
        reason: "delivery_failed",
        verificationId,
        deliveryMethod: sendResult.method,
      },
    );
  }

  await supabase
    .from(tableName)
    .update({
      delivery_status: "sent",
      delivery_method: sendResult.method,
      wa_message_id: sendResult.messageId,
      failure_reason: null,
    })
    .eq("challenge_id", verificationId);

  return jsonResponse(200, {
    success: true,
    verificationId,
    expiresAt: expiresAt.toISOString(),
    usesMock: false,
    deliveryMethod: sendResult.method,
  });
}

async function handleVerify(
  supabase: ReturnType<typeof adminClient>,
  body: JsonRecord,
): Promise<Response> {
  const rawPhone = String(body.phone ?? body.whatsappNumber ?? "").trim();
  const verificationId = String(
    body.verificationId ?? body.verification_id ?? "",
  ).trim();
  const code = String(body.code ?? "").replace(/\D/g, "");

  if (!verificationId || code.length != 6) {
    return errorResponse(
      "verificationId and a 6-digit code are required.",
      400,
    );
  }

  let normalizedPhone: string;
  try {
    normalizedPhone = normalizePhone(rawPhone);
  } catch (error) {
    return errorResponse(
      error instanceof Error ? error.message : "Invalid WhatsApp number.",
      400,
      { reason: "invalid_phone" },
    );
  }

  const normalizedDigits = digitsOnly(normalizedPhone);
  const { data, error } = await supabase
    .from(tableName)
    .select(
      "id, otp_hash, expires_at, consumed_at, attempts, max_attempts, app_scope",
    )
    .eq("challenge_id", verificationId)
    .eq("normalized_whatsapp_number", normalizedDigits)
    .maybeSingle();

  if (error) {
    console.error("[whatsapp-otp] verify lookup failed", error);
    return errorResponse("Could not verify the WhatsApp code.", 500, {
      reason: "network_error",
    });
  }

  if (!data) {
    return jsonResponse(200, {
      success: true,
      verified: false,
      reason: "not_found",
    });
  }

  if (data.consumed_at) {
    return jsonResponse(200, {
      success: true,
      verified: false,
      reason: "already_used",
    });
  }

  if (Date.now() > Date.parse(data.expires_at as string)) {
    return jsonResponse(200, {
      success: true,
      verified: false,
      reason: "expired",
    });
  }

  if ((data.attempts as number) >= (data.max_attempts as number)) {
    return jsonResponse(200, {
      success: true,
      verified: false,
      reason: "attempts_exceeded",
    });
  }

  const submittedHash = await otpHash(normalizedPhone, code);
  const nextAttempts = (data.attempts as number) + 1;

  if (submittedHash !== data.otp_hash) {
    await supabase
      .from(tableName)
      .update({
        attempts: nextAttempts,
        failure_reason: "invalid_code",
      })
      .eq("id", data.id as string);

    return jsonResponse(200, {
      success: true,
      verified: false,
      reason: "invalid_code",
      remainingAttempts: Math.max(
        0,
        (data.max_attempts as number) - nextAttempts,
      ),
    });
  }

  await supabase
    .from(tableName)
    .update({
      attempts: nextAttempts,
      failure_reason: null,
    })
    .eq("id", data.id as string);

  let adminSession: JsonRecord | null = null;
  let venueSession: JsonRecord | null = null;
  let validatedVenue: VenueAccessRow | null = null;
  if (data.app_scope === "admin") {
    const adminProfile = await getAdminProfileByPhone(
      supabase,
      normalizedPhone,
    );
    if (!adminProfile) {
      return jsonResponse(200, {
        success: true,
        verified: false,
        reason: "admin_not_found",
      });
    }

    try {
      adminSession = await buildAdminSession(adminProfile, normalizedPhone);
    } catch (error) {
      console.error("[whatsapp-otp] admin session build failed", error);
      return errorResponse("Admin OTP session is not configured.", 500, {
        reason: "session_not_configured",
      });
    }
  } else if (data.app_scope === "venue") {
    validatedVenue = await getValidatedVenueByPhone(
      supabase,
      normalizedPhone,
    );
    if (!validatedVenue) {
      return jsonResponse(200, {
        success: true,
        verified: false,
        reason: "venue_not_found",
      });
    }

    try {
      venueSession = await buildVenueSession(
        validatedVenue,
        normalizedPhone,
      );
    } catch (error) {
      console.error("[whatsapp-otp] venue session build failed", error);
      return errorResponse("Venue OTP session is not configured.", 500, {
        reason: "session_not_configured",
      });
    }
  }

  const verifiedAt = new Date().toISOString();
  const { error: consumeError } = await supabase
    .from(tableName)
    .update({
      consumed_at: verifiedAt,
    })
    .eq("id", data.id as string);

  if (consumeError) {
    console.error("[whatsapp-otp] verify consume update failed", consumeError);
    return errorResponse("Could not finalize the WhatsApp verification.", 500, {
      reason: "verification_finalize_failed",
    });
  }

  if (validatedVenue && venueSession?.issued_at) {
    try {
      await persistVerifiedVenueAccess(supabase, validatedVenue, {
        issuedAt: venueSession.issued_at as string,
        verifiedAt,
        normalizedPhone,
        verificationMethod: "otp",
        verifiedBy: normalizedPhone,
        verificationNote: "Verified via WhatsApp OTP.",
      });
    } catch (error) {
      console.error(
        "[whatsapp-otp] venue verification persistence failed",
        error,
      );
      return errorResponse(
        "Could not persist venue access verification.",
        500,
        {
          reason: "verification_persist_failed",
        },
      );
    }
  }

  return jsonResponse(200, {
    success: true,
    verified: true,
    verifiedAt,
    ...(adminSession == null ? {} : { adminSession }),
    ...(venueSession == null ? {} : { venueSession }),
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return errorResponse("Method not allowed.", 405);
  }

  let body: JsonRecord;
  try {
    body = (await req.json()) as JsonRecord;
  } catch {
    return errorResponse("A JSON body is required.", 400);
  }

  const action = String(body.action ?? "").trim().toLowerCase();
  if (!action) {
    return errorResponse("An action is required.", 400);
  }

  try {
    const supabase = adminClient();

    if (action === "send") {
      return await handleSend(supabase, body, req);
    }

    if (action === "verify") {
      return await handleVerify(supabase, body);
    }

    return errorResponse("Unsupported action.", 400);
  } catch (error) {
    console.error("[whatsapp-otp] unhandled error", error);
    return errorResponse("Unexpected OTP service failure.", 500);
  }
});
