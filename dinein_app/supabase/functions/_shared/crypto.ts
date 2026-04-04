export function digitsOnly(value: string): string {
  return value.replace(/\D/g, "");
}

export function collapseWhitespace(value: string): string {
  return value.replace(/\s+/g, " ").trim();
}

export function generateNumericCode(length: number): string {
  let code = "";
  const bytes = crypto.getRandomValues(new Uint8Array(length));
  for (const byte of bytes) {
    code += (byte % 10).toString();
  }
  return code;
}

export async function sha256Hex(value: string): Promise<string> {
  const encoded = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", encoded);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export function bytesToBase64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

export function base64UrlEncode(value: string): string {
  return bytesToBase64Url(new TextEncoder().encode(value));
}

export function base64UrlDecode(value: string): string {
  let normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  while (normalized.length % 4 != 0) {
    normalized += "=";
  }
  return atob(normalized);
}

export async function hmacSha256Base64Url(value: string, secret: string): Promise<string> {
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
