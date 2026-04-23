import { defaultCountryCode, fallbackAdminWhatsAppByCountry, syntheticAdminUserIdByCountry, verifySupabaseServiceRoleHeader, optionalEnv, getEnv, hmacSha256Base64Url, base64UrlEncode, base64UrlDecode, asRecord, JsonRecord, stringValue, numberValue, requestClient, ORDER_REALTIME_TOKEN_TTL_SECONDS, adminClient, isAdminUserWithFallback, HttpError, normalizeWhatsAppPhone, optionalNormalizedWhatsAppPhone, phoneNumbersMatch, getSigningSecret } from "../core.ts";
import * as Core from "../core.ts";
export function configuredAdminWhatsAppNumberForCountry(
  countryCode: string,
): string | null {
  const normalizedCountryCode = countryCode.replace(/\D/g, "");
  const envKey = normalizedCountryCode === "250"
    ? "DINEIN_ADMIN_WHATSAPP_NUMBER_RW"
    : normalizedCountryCode === "356"
    ? "DINEIN_ADMIN_WHATSAPP_NUMBER_MT"
    : "DINEIN_ADMIN_WHATSAPP_NUMBER";
  const configured = optionalNormalizedWhatsAppPhone(Deno.env.get(envKey), {
    defaultCountryCode,
  }) ??
    optionalNormalizedWhatsAppPhone(
      Deno.env.get("DINEIN_ADMIN_WHATSAPP_NUMBER"),
      {
        defaultCountryCode,
      },
    );
  if (configured != null) return configured;
  return fallbackAdminWhatsAppByCountry.get(normalizedCountryCode) ?? null;
}
export function configuredAdminUserIdForCountry(countryCode: string): string {
  const normalizedCountryCode = countryCode.replace(/\D/g, "");
  return syntheticAdminUserIdByCountry.get(normalizedCountryCode) ??
    "00000000-0000-0000-0000-000000000000";
}
export function configuredAdminUserIdForSessionPhone(
  rawPhone?: string | null,
): string | null {
  const phone = rawPhone?.trim();
  if (!phone) return null;

  for (
    const candidateCountryCode of new Set([
      defaultCountryCode,
      "250",
      "356",
    ])
  ) {
    const configuredPhone = configuredAdminWhatsAppNumberForCountry(
      candidateCountryCode,
    );
    if (
      configuredPhone != null &&
      phoneNumbersMatch(phone, configuredPhone, {
        defaultCountryCode: candidateCountryCode,
      })
    ) {
      return configuredAdminUserIdForCountry(candidateCountryCode);
    }
  }

  return null;
}
export async function hasVerifiedServiceRoleRequest(
  req: Request,
): Promise<boolean> {
  return await verifySupabaseServiceRoleHeader(
    req.headers.get("Authorization"),
  ) != null;
}
export async function signedTokenClaims(
  token: string,
  options: SignedClaimsOptions,
): Promise<JsonRecord | null> {
  const parts = token.split(".");
  if (parts.length != 3) {
    return null;
  }

  const [encodedHeader, encodedPayload, encodedSignature] = parts;
  const signingInput = `${encodedHeader}.${encodedPayload}`;
  const expectedSignature = await hmacSha256Base64Url(
    signingInput,
    getSigningSecret(options.secret, options.fallbackSecret),
  );

  if (expectedSignature != encodedSignature) {
    return null;
  }

  let payload: JsonRecord;
  try {
    payload = asRecord(JSON.parse(base64UrlDecode(encodedPayload)));
  } catch {
    return null;
  }

  if (stringValue(payload.aud) != options.aud) return null;
  if (options.role != undefined && stringValue(payload.role) != options.role) {
    return null;
  }

  const expiresAt = numberValue(payload.exp);
  if (expiresAt != undefined && Math.floor(Date.now() / 1000) >= expiresAt) {
    return null;
  }

  return payload;
}
export async function adminSessionClaims(req: Request): Promise<JsonRecord | null> {
  const token = bearerToken(req);
  if (!token) return null;
  return await signedTokenClaims(token, {
    aud: "dinein-admin",
    role: "admin",
    secret: "DINEIN_ADMIN_SESSION_SECRET",
  });
}
export async function venueSessionClaims(
  req: Request,
): Promise<JsonRecord | null> {
  const token = bearerToken(req);
  if (!token) return null;
  return await signedTokenClaims(token, {
    aud: "dinein-venue",
    role: "venue_owner",
    secret: "DINEIN_VENUE_SESSION_SECRET",
    fallbackSecret: "DINEIN_ADMIN_SESSION_SECRET",
  });
}
export async function currentUser(req: Request) {
  if (!req.headers.get("Authorization")) {
    return null;
  }

  if (await adminSessionClaims(req)) {
    return null;
  }

  if (await venueSessionClaims(req)) {
    return null;
  }

  const client = requestClient(req);
  const { data, error } = await client.auth.getUser();
  if (error) {
    console.error("[dinein-api] auth lookup failed", error);
    return null;
  }

  return data.user;
}
export async function signSupabaseScopedJwt(payload: JsonRecord): Promise<string> {
  const header = { alg: "HS256", typ: "JWT" };
  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const signingInput = `${encodedHeader}.${encodedPayload}`;
  const jwtSecret = optionalEnv("SUPABASE_JWT_SECRET") ??
    getEnv("DINEIN_SUPABASE_JWT_SECRET");
  const signature = await hmacSha256Base64Url(
    signingInput,
    jwtSecret,
  );
  return `${signingInput}.${signature}`;
}
export async function issueScopedRealtimeAccessToken(
  claims: JsonRecord,
): Promise<
  { access_token: string; expires_at: string; realtime_enabled: boolean }
> {
  const issuedAtSeconds = Math.floor(Date.now() / 1000);
  const expiresAtSeconds = issuedAtSeconds + ORDER_REALTIME_TOKEN_TTL_SECONDS;
  const jwtSecretAvailable = optionalEnv("SUPABASE_JWT_SECRET") != null ||
    optionalEnv("DINEIN_SUPABASE_JWT_SECRET") != null;

  if (!jwtSecretAvailable) {
    return {
      access_token: "",
      expires_at: new Date(expiresAtSeconds * 1000).toISOString(),
      realtime_enabled: false,
    };
  }

  const payload: JsonRecord = {
    iss: getEnv("SUPABASE_URL"),
    iat: issuedAtSeconds,
    exp: expiresAtSeconds,
    role: "authenticated",
    ...claims,
  };

  return {
    access_token: await signSupabaseScopedJwt(payload),
    expires_at: new Date(expiresAtSeconds * 1000).toISOString(),
    realtime_enabled: true,
  };
}
export async function isAdmin(
  supabase: ReturnType<typeof adminClient>,
  userId?: string | null,
) {
  if (!userId) return false;
  try {
    return await isAdminUserWithFallback(supabase, userId);
  } catch (error) {
    console.error("[dinein-api] admin lookup failed", error);
    return false;
  }
}
export async function adminUserId(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
): Promise<string | null> {
  const claims = await adminSessionClaims(req);
  const customAdminId = stringValue(claims?.sub);
  if (customAdminId && await isAdmin(supabase, customAdminId)) {
    return customAdminId;
  }

  const configuredAdminId = configuredAdminUserIdForSessionPhone(
    stringValue(claims?.phone),
  );
  if (configuredAdminId) {
    return customAdminId ?? configuredAdminId;
  }

  const user = await currentUser(req);
  if (user && await isAdmin(supabase, user.id)) {
    return user.id;
  }

  return null;
}
export async function requireAdmin(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
): Promise<string> {
  const userId = await adminUserId(supabase, req);
  if (!userId) {
    throw new HttpError(403, "Admin access is required.");
  }
  return userId;
}
export async function requireSelfOrAdmin(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  userId: string,
): Promise<string> {
  const adminId = await adminUserId(supabase, req);
  if (adminId) return adminId;

  const user = await currentUser(req);
  if (!user) {
    throw new HttpError(401, "Authentication is required.");
  }

  if (user.id != userId) {
    throw new HttpError(403, "You are not allowed to access this resource.");
  }

  return user.id;
}
export async function isServiceRoleRequest(req: Request): Promise<boolean> {
  return await hasVerifiedServiceRoleRequest(req);
}
export type SignedClaimsOptions = {
  aud: string;
  role?: string;
  secret: string;
  fallbackSecret?: string;
};
export function bearerToken(req: Request): string | null {
  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) {
    return null;
  }

  const token = authorization.slice("Bearer ".length).trim();
  return token.length > 0 ? token : null;
}
