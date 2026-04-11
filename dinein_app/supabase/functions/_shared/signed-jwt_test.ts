import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";

import { verifySupabaseServiceRoleHeader } from "./signed-jwt.ts";

Deno.test("verifySupabaseServiceRoleHeader accepts a signed service-role token", async () => {
  const token = await signJwt(
    {
      role: "service_role",
      exp: Math.floor(Date.now() / 1000) + 60,
    },
    "test-secret",
  );

  const claims = await verifySupabaseServiceRoleHeader(`Bearer ${token}`, {
    jwtSecret: "test-secret",
  });

  assertEquals(claims?.role, "service_role");
});

Deno.test("verifySupabaseServiceRoleHeader rejects a forged signature", async () => {
  const token = await signJwt(
    {
      role: "service_role",
      exp: Math.floor(Date.now() / 1000) + 60,
    },
    "real-secret",
  );

  const claims = await verifySupabaseServiceRoleHeader(`Bearer ${token}`, {
    jwtSecret: "wrong-secret",
  });

  assertEquals(claims, null);
});

Deno.test("verifySupabaseServiceRoleHeader rejects expired tokens", async () => {
  const token = await signJwt(
    {
      role: "service_role",
      exp: Math.floor(Date.now() / 1000) - 5,
    },
    "test-secret",
  );

  const claims = await verifySupabaseServiceRoleHeader(`Bearer ${token}`, {
    jwtSecret: "test-secret",
  });

  assertEquals(claims, null);
});

Deno.test("verifySupabaseServiceRoleHeader accepts an exact service-role key match", async () => {
  const claims = await verifySupabaseServiceRoleHeader(
    "Bearer sb_secret_test_service_role_key",
    {
      serviceRoleKeys: ["sb_secret_test_service_role_key"],
    },
  );

  assertEquals(claims?.role, "service_role");
  assertEquals(claims?.auth_source, "service_role_key");
});

async function signJwt(
  payload: Record<string, unknown>,
  secret: string,
): Promise<string> {
  const header = base64UrlEncode(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const body = base64UrlEncode(JSON.stringify(payload));
  const signingInput = `${header}.${body}`;
  const signature = await hmacSha256Base64Url(signingInput, secret);
  return `${signingInput}.${signature}`;
}

function base64UrlEncode(value: string): string {
  return btoa(value).replace(/\+/g, "-").replace(/\//g, "_").replace(
    /=+$/g,
    "",
  );
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
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(
    /=+$/g,
    "",
  );
}
