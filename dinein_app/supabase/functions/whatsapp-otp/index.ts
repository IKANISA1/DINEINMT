import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { postWhatsAppMessage } from "../_shared/whatsapp.ts";
import {
  listAdminProfilesWithFallback,
  persistAdminWhatsAppNumberWithFallback,
} from "../_shared/admin-profile.ts";
import { boolEnv, getEnv, intEnv, optionalEnv } from "../_shared/env.ts";
import {
  base64UrlEncode,
  bytesToBase64Url,
  digitsOnly,
  hmacSha256Base64Url,
  sha256Hex,
} from "../_shared/crypto.ts";
import {
  applyCorsHeaders,
  assertAllowedAppOrigin,
  buildResponseHeaders,
  errorResponse,
  jsonResponse,
} from "../_shared/http.ts";
import {
  normalizeWhatsAppPhone,
  optionalNormalizedWhatsAppPhone,
  phoneNumbersMatch,
} from "../_shared/phone.ts";

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
const fallbackAdminWhatsAppByCountry = new Map<string, string>([
  ["250", "+25075588248"],
  ["356", "+35699711145"],
]);
const syntheticAdminProfileIdByCountry = new Map<string, string>([
  ["250", "00000000-0000-0000-0000-000000000250"],
  ["356", "00000000-0000-0000-0000-000000000356"],
]);
const allowMock = boolEnv("WHATSAPP_OTP_ALLOW_MOCK", false);
const allowTextFallback = boolEnv("WHATSAPP_OTP_ALLOW_TEXT_FALLBACK", false);
const allowTestOverride = boolEnv("WHATSAPP_OTP_ALLOW_TEST_OVERRIDE", false);

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
  country?: string | null;
  owner_whatsapp_number?: string | null;
};

// Imported from env.ts

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

// Imported from crypto.ts

function normalizePhone(raw: string): string {
  return normalizeWhatsAppPhone(raw, {
    defaultCountryCode,
  });
}

function optionalNormalizedPhone(raw?: string | null): string | null {
  return optionalNormalizedWhatsAppPhone(raw, {
    defaultCountryCode,
  });
}

export function configuredAdminWhatsAppNumberForCountry(
  countryCode: string,
): string | null {
  const normalizedCountryCode = countryCode.replace(/\D/g, "");
  const envKey = normalizedCountryCode === "250"
    ? "DINEIN_ADMIN_WHATSAPP_NUMBER_RW"
    : normalizedCountryCode === "356"
    ? "DINEIN_ADMIN_WHATSAPP_NUMBER_MT"
    : "DINEIN_ADMIN_WHATSAPP_NUMBER";
  const configured = optionalNormalizedPhone(Deno.env.get(envKey)) ??
    optionalNormalizedPhone(Deno.env.get("DINEIN_ADMIN_WHATSAPP_NUMBER"));
  if (configured != null) return configured;
  return fallbackAdminWhatsAppByCountry.get(normalizedCountryCode) ?? null;
}

function configuredAdminWhatsAppNumber(): string | null {
  return configuredAdminWhatsAppNumberForCountry(defaultCountryCode);
}

function syntheticAdminProfileIdForCountry(countryCode: string): string {
  const normalizedCountryCode = countryCode.replace(/\D/g, "");
  return syntheticAdminProfileIdByCountry.get(normalizedCountryCode) ??
    "00000000-0000-0000-0000-000000000000";
}

function phoneDefaultCountryCode(value?: string | null): string {
  const normalized = value?.trim().toUpperCase();
  if (normalized == "RW") return "250";
  if (normalized == "MT") return "356";
  return defaultCountryCode;
}

function numericOtp(length = 6): string {
  let code = "";
  const bytes = crypto.getRandomValues(new Uint8Array(length));
  for (const byte of bytes) {
    code += (byte % 10).toString();
  }
  return code;
}

// Imported from crypto.ts

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

// Imported from http.ts

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
  try {
    return selectAdminProfileForPhone(
      await listAdminProfilesWithFallback(supabase) as AdminProfile[],
      normalizedPhone,
      defaultCountryCode,
    );
  } catch (error) {
    console.error("[whatsapp-otp] admin profile lookup failed", error);
    const fallbackProfile = selectAdminProfileForPhone(
      [],
      normalizedPhone,
      defaultCountryCode,
    );
    if (fallbackProfile) return fallbackProfile;
    throw new Error("Could not verify admin access configuration.");
  }
}

export function selectAdminProfileForPhone(
  profiles: AdminProfile[],
  normalizedPhone: string,
  countryCode = defaultCountryCode,
): AdminProfile | null {
  for (const row of profiles) {
    const rowPhone = typeof row.whatsapp_number === "string"
      ? row.whatsapp_number
      : "";
    if (
      phoneNumbersMatch(rowPhone, normalizedPhone, {
        defaultCountryCode: countryCode,
      })
    ) {
      return row;
    }
  }

  for (const candidateCountryCode of new Set([
    countryCode,
    defaultCountryCode,
    "250",
    "356",
  ])) {
    const configuredAdminPhone = configuredAdminWhatsAppNumberForCountry(
      candidateCountryCode,
    );
    if (
      configuredAdminPhone != null &&
      phoneNumbersMatch(configuredAdminPhone, normalizedPhone, {
        defaultCountryCode: candidateCountryCode,
      })
    ) {
      return profiles[0] ?? {
        id: syntheticAdminProfileIdForCountry(candidateCountryCode),
        display_name: "Admin",
        email: null,
        role: "admin",
        whatsapp_number: configuredAdminPhone,
      };
    }
  }

  return null;
}

function isSyntheticAdminProfile(profile: AdminProfile): boolean {
  return profile.id === syntheticAdminProfileIdForCountry("250") ||
    profile.id === syntheticAdminProfileIdForCountry("356") ||
    profile.id === syntheticAdminProfileIdForCountry(defaultCountryCode);
}

function venueMatchesPhone(
  venue: VenueAccessRow,
  normalizedPhone: string,
): boolean {
  return phoneNumbersMatch(venue.owner_whatsapp_number, normalizedPhone, {
    defaultCountryCode: phoneDefaultCountryCode(venue.country),
  });
}

async function getValidatedVenueByPhone(
  supabase: ReturnType<typeof adminClient>,
  normalizedPhone: string,
): Promise<VenueAccessRow | null> {
  const { data, error } = await supabase
    .from("dinein_venues")
    .select("id, name, slug, image_url, status, country, owner_whatsapp_number")
    .neq("status", "deleted");

  if (error) {
    console.error("[whatsapp-otp] venue lookup failed", error);
    throw new Error("Could not verify venue access configuration.");
  }

  for (const venue of (data ?? []) as VenueAccessRow[]) {
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

async function persistAdminProfilePhone(
  supabase: ReturnType<typeof adminClient>,
  profile: AdminProfile,
  normalizedPhone: string,
): Promise<void> {
  if (isSyntheticAdminProfile(profile)) return;

  const currentDigits = digitsOnly(profile.whatsapp_number ?? "");
  const nextDigits = digitsOnly(normalizedPhone);
  if (currentDigits === nextDigits) return;

  try {
    await persistAdminWhatsAppNumberWithFallback(
      supabase,
      profile.id,
      normalizedPhone,
    );
  } catch (error) {
    console.error("[whatsapp-otp] admin profile whatsapp sync failed", error);
    throw new Error("Could not persist the admin WhatsApp number.");
  }
}

async function buildVenueSession(
  venue: VenueAccessRow,
  normalizedPhone: string,
) {
  if (!venue.id) {
    throw new Error("The registered venue could not be found.");
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

function accessLookupErrorResponse(appScope: string): Response {
  if (appScope === "admin") {
    return errorResponse(
      "Admin OTP access is not configured correctly.",
      500,
      { reason: "admin_lookup_failed" },
    );
  }

  return errorResponse(
    "Venue OTP access is not configured correctly.",
    500,
    { reason: "venue_lookup_failed" },
  );
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
    let adminProfile: AdminProfile | null = null;
    try {
      adminProfile = await getAdminProfileByPhone(
        supabase,
        normalizedPhone,
      );
    } catch {
      return accessLookupErrorResponse(appScope);
    }
    if (!adminProfile) {
      return errorResponse(
        "This WhatsApp number is not registered for admin console access.",
        403,
        { reason: "admin_not_found" },
      );
    }
  } else if (appScope === "venue") {
    let validatedVenue: VenueAccessRow | null = null;
    try {
      validatedVenue = await getValidatedVenueByPhone(
        supabase,
        normalizedPhone,
      );
    } catch {
      return accessLookupErrorResponse(appScope);
    }
    if (!validatedVenue) {
      return errorResponse(
        "This WhatsApp number is not registered to any venue account.",
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
    let adminProfile: AdminProfile | null = null;
    try {
      adminProfile = await getAdminProfileByPhone(
        supabase,
        normalizedPhone,
      );
    } catch {
      return accessLookupErrorResponse("admin");
    }
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

    try {
      await persistAdminProfilePhone(supabase, adminProfile, normalizedPhone);
    } catch (error) {
      console.error("[whatsapp-otp] admin profile sync failed", error);
    }
  } else if (data.app_scope === "venue") {
    try {
      validatedVenue = await getValidatedVenueByPhone(
        supabase,
        normalizedPhone,
      );
    } catch {
      return accessLookupErrorResponse("venue");
    }
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

  return jsonResponse(200, {
    success: true,
    verified: true,
    verifiedAt,
    ...(adminSession == null ? {} : { adminSession }),
    ...(venueSession == null ? {} : { venueSession }),
  });
}

if (import.meta.main) {
  Deno.serve(async (req) => {
    let allowedOrigin: string | null = null;

    try {
      allowedOrigin = assertAllowedAppOrigin(req);
      if (req.method === "OPTIONS") {
        return new Response("ok", {
          headers: buildResponseHeaders(allowedOrigin, {
            fallbackWildcard: false,
          }),
        });
      }

      if (req.method !== "POST") {
        return errorResponse(
          "Method not allowed.",
          405,
          undefined,
          allowedOrigin,
        );
      }

      let body: JsonRecord;
      try {
        body = (await req.json()) as JsonRecord;
      } catch {
        return errorResponse(
          "A JSON body is required.",
          400,
          undefined,
          allowedOrigin,
        );
      }

      const action = String(body.action ?? "").trim().toLowerCase();
      if (!action) {
        return errorResponse(
          "An action is required.",
          400,
          undefined,
          allowedOrigin,
        );
      }

      const supabase = adminClient();
      let response: Response;

      if (action === "send") {
        response = await handleSend(supabase, body, req);
        return applyCorsHeaders(response, allowedOrigin, {
          fallbackWildcard: false,
        });
      }

      if (action === "verify") {
        response = await handleVerify(supabase, body);
        return applyCorsHeaders(response, allowedOrigin, {
          fallbackWildcard: false,
        });
      }

      return errorResponse(
        "Unsupported action.",
        400,
        undefined,
        allowedOrigin,
      );
    } catch (error) {
      console.error("[whatsapp-otp] unhandled error", error);
      return errorResponse(
        "Unexpected OTP service failure.",
        500,
        undefined,
        allowedOrigin,
      );
    }
  });
}
