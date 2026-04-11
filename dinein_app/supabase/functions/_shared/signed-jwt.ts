export type Json = Record<string, unknown>;

interface VerifySignedJwtOptions {
  role?: string;
  audiences?: string[];
  jwtSecret?: string | null;
  fallbackJwtSecret?: string | null;
  serviceRoleKeys?: string[];
}

export function bearerTokenFromAuthHeader(
  authHeader: string | null | undefined,
): string | null {
  if (!authHeader?.startsWith("Bearer ")) return null;
  const token = authHeader.slice("Bearer ".length).trim();
  return token.length > 0 ? token : null;
}

export function resolveSupabaseJwtSecret(): string | null {
  return Deno.env.get("SUPABASE_JWT_SECRET")?.trim() ||
    Deno.env.get("DINEIN_SUPABASE_JWT_SECRET")?.trim() ||
    null;
}

export async function verifySupabaseServiceRoleHeader(
  authHeader: string | null | undefined,
  options: VerifySignedJwtOptions = {},
): Promise<Json | null> {
  const token = bearerTokenFromAuthHeader(authHeader);
  if (!token) return null;

  const serviceRoleKey = resolveSupabaseServiceRoleKeys(
    options.serviceRoleKeys,
  ).find((candidate) => timingSafeSecretMatch(candidate, token));
  if (serviceRoleKey) {
    return {
      role: "service_role",
      auth_source: "service_role_key",
      key_prefix: serviceRoleKey.slice(0, 8),
    };
  }

  return await verifySignedJwtClaims(token, {
    ...options,
    role: "service_role",
    jwtSecret: options.jwtSecret ?? resolveSupabaseJwtSecret(),
    fallbackJwtSecret: options.fallbackJwtSecret ?? null,
  });
}

function resolveSupabaseServiceRoleKeys(
  explicitKeys?: string[],
): string[] {
  return [
    ...(explicitKeys ?? []),
    safeEnvGet("SUPABASE_SERVICE_ROLE_KEY"),
    safeEnvGet("SERVICE_ROLE_KEY"),
  ]
    .map((value) => value.trim())
    .filter((value, index, values) =>
      value.length > 0 && values.indexOf(value) === index
    );
}

function safeEnvGet(name: string): string {
  try {
    return Deno.env.get(name) ?? "";
  } catch (_) {
    return "";
  }
}

export async function verifySignedJwtClaims(
  token: string,
  options: VerifySignedJwtOptions,
): Promise<Json | null> {
  const parts = token.split(".");
  if (parts.length !== 3) {
    return null;
  }

  const [encodedHeader, encodedPayload, encodedSignature] = parts;
  const signingInput = `${encodedHeader}.${encodedPayload}`;
  const secrets = [options.jwtSecret, options.fallbackJwtSecret]
    .map((value) => value?.trim() || null)
    .filter((value, index, values): value is string =>
      Boolean(value) && values.indexOf(value) === index
    );

  if (secrets.length === 0) {
    return null;
  }

  let signatureVerified = false;
  for (const secret of secrets) {
    const expectedSignature = await hmacSha256Base64Url(signingInput, secret);
    if (timingSafeEqual(expectedSignature, encodedSignature)) {
      signatureVerified = true;
      break;
    }
  }

  if (!signatureVerified) {
    return null;
  }

  let payload: Json;
  try {
    const parsed = JSON.parse(base64UrlDecode(encodedPayload));
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return null;
    }
    payload = parsed as Json;
  } catch (_) {
    return null;
  }

  if (
    options.role &&
    (typeof payload.role !== "string" || payload.role !== options.role)
  ) {
    return null;
  }

  if (options.audiences && options.audiences.length > 0) {
    const payloadAud = payload.aud;
    const matches = typeof payloadAud === "string"
      ? options.audiences.includes(payloadAud)
      : Array.isArray(payloadAud)
      ? payloadAud.some((value) =>
        typeof value === "string" && options.audiences!.includes(value)
      )
      : false;
    if (!matches) {
      return null;
    }
  }

  const expiresAt = typeof payload.exp === "number"
    ? payload.exp
    : typeof payload.exp === "string"
    ? Number.parseInt(payload.exp, 10)
    : null;
  if (
    expiresAt != null &&
    Number.isFinite(expiresAt) &&
    Math.floor(Date.now() / 1000) >= expiresAt
  ) {
    return null;
  }

  return payload;
}

function base64UrlDecode(value: string): string {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/")
    .padEnd(Math.ceil(value.length / 4) * 4, "=");
  return atob(padded);
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

function bytesToBase64Url(bytes: Uint8Array): string {
  let binary = "";
  const chunkSize = 0x8000;
  for (let index = 0; index < bytes.length; index += chunkSize) {
    const slice = bytes.subarray(index, index + chunkSize);
    binary += String.fromCharCode(...slice);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(
    /=+$/g,
    "",
  );
}

function timingSafeEqual(left: string, right: string): boolean {
  if (left.length !== right.length) {
    return false;
  }

  let mismatch = 0;
  for (let index = 0; index < left.length; index += 1) {
    mismatch |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return mismatch === 0;
}

function timingSafeSecretMatch(left: string, right: string): boolean {
  return left.length === right.length && timingSafeEqual(left, right);
}
