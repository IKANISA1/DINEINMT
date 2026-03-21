import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import {
  createAdminClient as createMenuImageAdminClient,
  type FunctionEnv as MenuImageEnv,
  HttpError as MenuImageHttpError,
  type MenuItemRecord,
  processMenuItemImageGeneration,
  type VenueRecord,
} from "../_shared/menu-image.ts";
import {
  createVenueAdminClient as createVenueEnrichmentAdminClient,
  fetchVenueForEnrichment,
  getVenueEnrichmentEnv,
  HttpError as VenueEnrichmentHttpError,
  isVenueEnrichmentInFlight,
  normalizeVenueEnrichmentLimit,
  processVenueEnrichment,
  venueNeedsEnrichment,
  type VenueRecord as EnrichmentVenueRecord,
} from "../_shared/venue-enrichment.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-cron-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const defaultCountryCode =
  (Deno.env.get("DEFAULT_WHATSAPP_COUNTRY_CODE") ?? "356").replace(/\D/g, "");
const venueStatuses = new Set([
  "active",
  "inactive",
  "maintenance",
  "suspended",
  "deleted",
  "pending_claim",
  "pending_activation",
]);
const orderStatuses = new Set(["placed", "received", "served", "cancelled"]);
const paymentMethods = new Set(["cash", "momo_ussd", "revolut_link"]);
const menuImageStatuses = new Set(["pending", "generating", "ready", "failed"]);
const menuImageSources = new Set(["manual", "ai_gemini"]);

type JsonRecord = Record<string, unknown>;

class HttpError extends Error {
  status: number;
  details?: JsonRecord;

  constructor(status: number, message: string, details?: JsonRecord) {
    super(message);
    this.status = status;
    this.details = details;
  }
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

function hasMatchingSecretHeader(req: Request, envName: string): boolean {
  const expected = optionalEnv(envName);
  if (!expected) return false;
  return req.headers.get("x-cron-secret") == expected;
}

function isVenueEnrichmentCronInvocation(req: Request): boolean {
  return hasMatchingSecretHeader(req, "VENUE_ENRICHMENT_CRON_SECRET");
}

function getSigningSecret(primary: string, fallback?: string): string {
  return optionalEnv(primary) ??
    (fallback ? getEnv(fallback) : getEnv(primary));
}

function adminClient() {
  return createClient(
    getEnv("SUPABASE_URL"),
    getEnv("SUPABASE_SERVICE_ROLE_KEY"),
    {
      auth: { persistSession: false },
    },
  );
}

function requestClient(req: Request) {
  const anonKey = getEnv("SUPABASE_ANON_KEY");
  return createClient(getEnv("SUPABASE_URL"), anonKey, {
    auth: { persistSession: false },
    global: {
      headers: {
        Authorization: req.headers.get("Authorization") ?? "",
        apikey: anonKey,
      },
    },
  });
}

function ok(data: unknown, status = 200): Response {
  return new Response(JSON.stringify({ data }), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function fail(message: string, status = 400, details?: JsonRecord): Response {
  return new Response(
    JSON.stringify({ error: message, ...(details ?? {}) }),
    {
      status,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    },
  );
}

function asRecord(value: unknown): JsonRecord {
  return value && typeof value == "object" && !Array.isArray(value)
    ? value as JsonRecord
    : {};
}

async function parseBody(req: Request): Promise<JsonRecord> {
  try {
    return asRecord(await req.json());
  } catch {
    return {};
  }
}

function stringValue(value: unknown): string | undefined {
  if (typeof value == "string") {
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : undefined;
  }
  if (typeof value == "number" || typeof value == "boolean") {
    return String(value);
  }
  return undefined;
}

function numberValue(value: unknown): number | undefined {
  if (typeof value == "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value == "string" && value.trim().length > 0) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : undefined;
  }
  return undefined;
}

function booleanValue(value: unknown): boolean | undefined {
  if (typeof value == "boolean") return value;
  if (typeof value == "string") {
    const normalized = value.trim().toLowerCase();
    if (["true", "1", "yes", "on"].includes(normalized)) return true;
    if (["false", "0", "no", "off"].includes(normalized)) return false;
  }
  return undefined;
}

function roundCurrency(value: number): number {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

function digitsOnly(value: string): string {
  return value.replace(/\D/g, "");
}

function normalizePhone(raw: string): string {
  const trimmed = raw.trim();
  const digits = digitsOnly(trimmed);
  if (!digits) {
    throw new HttpError(400, "A valid WhatsApp number is required.");
  }

  if (trimmed.startsWith("+")) {
    if (digits.length < 8 || digits.length > 15) {
      throw new HttpError(400, "A valid WhatsApp number is required.");
    }
    return `+${digits}`;
  }

  if (trimmed.startsWith("00")) {
    const normalized = digits.slice(2);
    if (normalized.length < 8 || normalized.length > 15) {
      throw new HttpError(400, "A valid WhatsApp number is required.");
    }
    return `+${normalized}`;
  }

  if (digits.length == 8 && defaultCountryCode.length > 0) {
    return `+${defaultCountryCode}${digits}`;
  }

  if (digits.length >= 10 && digits.length <= 15) {
    return `+${digits}`;
  }

  throw new HttpError(400, "A valid WhatsApp number is required.");
}

function slugify(value: string): string {
  const base = value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");

  return base.length > 0 ? base : `venue-${Date.now()}`;
}

function requireString(body: JsonRecord, ...keys: string[]): string {
  for (const key of keys) {
    const value = stringValue(body[key]);
    if (value) return value;
  }
  throw new HttpError(400, `Missing required field: ${keys[0]}`);
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

function base64UrlDecode(value: string): string {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/")
    .padEnd(Math.ceil(value.length / 4) * 4, "=");
  return atob(padded);
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

type SignedClaimsOptions = {
  aud: string;
  role?: string;
  secret: string;
  fallbackSecret?: string;
};

function bearerToken(req: Request): string | null {
  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) {
    return null;
  }

  const token = authorization.slice("Bearer ".length).trim();
  return token.length > 0 ? token : null;
}

function decodeJwtRole(authHeader: string | null): string | null {
  if (!authHeader?.startsWith("Bearer ")) return null;

  const token = authHeader.substring("Bearer ".length).trim();
  const parts = token.split(".");
  if (parts.length != 3) return null;

  try {
    const payload = asRecord(JSON.parse(base64UrlDecode(parts[1])));
    return stringValue(payload.role) ?? null;
  } catch {
    return null;
  }
}

async function signedTokenClaims(
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

async function adminSessionClaims(req: Request): Promise<JsonRecord | null> {
  const token = bearerToken(req);
  if (!token) return null;
  return await signedTokenClaims(token, {
    aud: "dinein-admin",
    role: "admin",
    secret: "DINEIN_ADMIN_SESSION_SECRET",
  });
}

async function venueSessionClaims(req: Request): Promise<JsonRecord | null> {
  const token = bearerToken(req);
  if (!token) return null;
  return await signedTokenClaims(token, {
    aud: "dinein-venue",
    role: "venue_owner",
    secret: "DINEIN_VENUE_SESSION_SECRET",
    fallbackSecret: "DINEIN_ADMIN_SESSION_SECRET",
  });
}

async function currentUser(req: Request) {
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

async function isAdmin(
  supabase: ReturnType<typeof adminClient>,
  userId?: string | null,
) {
  if (!userId) return false;

  const { data, error } = await supabase
    .from("dinein_profiles")
    .select("role")
    .eq("id", userId)
    .maybeSingle();

  if (error) {
    console.error("[dinein-api] admin lookup failed", error);
    return false;
  }

  return data?.role == "admin";
}

async function adminUserId(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
): Promise<string | null> {
  const claims = await adminSessionClaims(req);
  const customAdminId = stringValue(claims?.sub);
  if (customAdminId && await isAdmin(supabase, customAdminId)) {
    return customAdminId;
  }

  const user = await currentUser(req);
  if (user && await isAdmin(supabase, user.id)) {
    return user.id;
  }

  return null;
}

async function requireAdmin(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
): Promise<string> {
  const userId = await adminUserId(supabase, req);
  if (!userId) {
    throw new HttpError(403, "Admin access is required.");
  }
  return userId;
}

async function requireSelfOrAdmin(
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

type ContactLookup =
  | { kind: "phone"; normalized: string; digits: string }
  | { kind: "email"; normalized: string };

function buildContactLookup(raw: string): ContactLookup {
  const trimmed = raw.trim();
  if (trimmed.includes("@")) {
    return { kind: "email", normalized: trimmed.toLowerCase() };
  }

  const normalized = normalizePhone(trimmed);
  return {
    kind: "phone",
    normalized,
    digits: digitsOnly(normalized),
  };
}

function claimContacts(row: JsonRecord): string[] {
  return [
    stringValue(row.contact_phone),
    stringValue(row.whatsapp_number),
    stringValue(row.email),
  ].filter((value): value is string => Boolean(value));
}

function claimMatchesContact(row: JsonRecord, lookup: ContactLookup): boolean {
  for (const contact of claimContacts(row)) {
    if (lookup.kind == "email") {
      if (contact.toLowerCase() == lookup.normalized) {
        return true;
      }
      continue;
    }

    if (!contact.includes("@") && digitsOnly(contact) == lookup.digits) {
      return true;
    }
  }

  return false;
}

const VENUE_TOKEN_TTL_SECONDS = 30 * 24 * 60 * 60; // 30 days

function venueTokenSecret(): string {
  return getSigningSecret(
    "DINEIN_VENUE_SESSION_SECRET",
    "DINEIN_ADMIN_SESSION_SECRET",
  );
}

async function issueVenueToken(
  venueId: string,
  contactPhone: string,
  venueName: string,
): Promise<{ access_token: string; expires_at: string }> {
  const now = Math.floor(Date.now() / 1000);
  const exp = now + VENUE_TOKEN_TTL_SECONDS;

  const header = btoa(JSON.stringify({ alg: "HS256", typ: "JWT" }))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");

  const payload = btoa(JSON.stringify({
    aud: "dinein-venue",
    role: "venue_owner",
    venue_id: venueId,
    phone: contactPhone,
    venue_name: venueName,
    iat: now,
    exp,
  })).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");

  const signingInput = `${header}.${payload}`;
  const signature = await hmacSha256Base64Url(signingInput, venueTokenSecret());

  return {
    access_token: `${signingInput}.${signature}`,
    expires_at: new Date(exp * 1000).toISOString(),
  };
}

async function verifyVenueToken(
  token: string,
): Promise<{ venueId: string; contactPhone: string }> {
  const parts = token.split(".");
  if (parts.length !== 3) {
    throw new HttpError(403, "Invalid venue access token.");
  }

  const [encodedHeader, encodedPayload, encodedSignature] = parts;
  const signingInput = `${encodedHeader}.${encodedPayload}`;
  const expected = await hmacSha256Base64Url(signingInput, venueTokenSecret());

  if (expected !== encodedSignature) {
    throw new HttpError(403, "Venue access token signature is invalid.");
  }

  let payload: JsonRecord;
  try {
    payload = asRecord(JSON.parse(base64UrlDecode(encodedPayload)));
  } catch {
    throw new HttpError(403, "Venue access token payload is malformed.");
  }

  if (stringValue(payload.aud) !== "dinein-venue") {
    throw new HttpError(403, "Venue access token audience is invalid.");
  }

  const exp = numberValue(payload.exp);
  if (exp != undefined && Math.floor(Date.now() / 1000) >= exp) {
    throw new HttpError(
      401,
      "Venue access token has expired. Please log in again.",
    );
  }

  const venueId = stringValue(payload.venue_id);
  const phone = stringValue(payload.phone);
  if (!venueId || !phone) {
    throw new HttpError(403, "Venue access token is missing required claims.");
  }

  return { venueId, contactPhone: phone };
}

async function authorizeVenueSession(
  req: Request,
  _supabase: ReturnType<typeof adminClient>,
  rawSession: unknown,
  venueId: string,
): Promise<{ venueId: string; contactPhone: string }> {
  const bearerClaims = await venueSessionClaims(req);
  if (bearerClaims) {
    const tokenVenueId = stringValue(bearerClaims.venue_id);
    const tokenPhone = stringValue(bearerClaims.phone);
    if (!tokenVenueId || !tokenPhone) {
      throw new HttpError(
        403,
        "Venue access token is missing required claims.",
      );
    }
    if (tokenVenueId !== venueId) {
      throw new HttpError(
        403,
        "Venue access token does not match the requested venue.",
      );
    }
    return { venueId: tokenVenueId, contactPhone: tokenPhone };
  }

  const session = asRecord(rawSession);
  const accessToken = stringValue(session.access_token);
  if (accessToken) {
    const claims = await verifyVenueToken(accessToken);
    if (claims.venueId !== venueId) {
      throw new HttpError(
        403,
        "Venue access token does not match the requested venue.",
      );
    }
    return claims;
  }

  const sessionVenueId = stringValue(session.venue_id) ??
    stringValue(session.venueId);
  if (sessionVenueId) {
    throw new HttpError(
      403,
      "Unsigned venue sessions are no longer accepted. Please log in again.",
    );
  }

  throw new HttpError(401, "Venue access token required.");
}

async function authorizeVenueMutation(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  venueId: string,
  venueSession: unknown,
): Promise<"admin" | "venue"> {
  if (decodeJwtRole(req.headers.get("Authorization")) == "service_role") {
    return "admin";
  }

  if (await adminUserId(supabase, req)) {
    return "admin";
  }

  await authorizeVenueSession(req, supabase, venueSession, venueId);
  return "venue";
}

async function latestClaimByContact(
  supabase: ReturnType<typeof adminClient>,
  lookup: ContactLookup,
  status?: string,
  venueId?: string,
): Promise<JsonRecord | null> {
  let query = supabase
    .from("dinein_venue_claims")
    .select("*")
    .order("created_at", { ascending: false });

  if (status) {
    query = query.eq("status", status);
  }

  if (venueId) {
    query = query.eq("venue_id", venueId);
  }

  const { data, error } = await query;
  if (error) {
    console.error("[dinein-api] latest claim lookup failed", error);
    throw new HttpError(500, "Could not load venue claims.");
  }

  const match = (data ?? []).find((claim) =>
    claimMatchesContact(asRecord(claim), lookup)
  );
  return match ? asRecord(match) : null;
}

async function menuItemVenueId(
  supabase: ReturnType<typeof adminClient>,
  itemId: string,
): Promise<string> {
  const { data, error } = await supabase
    .from("dinein_menu_items")
    .select("venue_id")
    .eq("id", itemId)
    .maybeSingle();

  if (error) {
    console.error("[dinein-api] menu item venue lookup failed", error);
    throw new HttpError(500, "Could not load the menu item.");
  }

  const venueId = stringValue(data?.venue_id);
  if (!venueId) {
    throw new HttpError(404, "Menu item not found.");
  }

  return venueId;
}

async function orderVenueId(
  supabase: ReturnType<typeof adminClient>,
  orderId: string,
): Promise<string> {
  const { data, error } = await supabase
    .from("dinein_orders")
    .select("venue_id")
    .eq("id", orderId)
    .maybeSingle();

  if (error) {
    console.error("[dinein-api] order venue lookup failed", error);
    throw new HttpError(500, "Could not load the order.");
  }

  const venueId = stringValue(data?.venue_id);
  if (!venueId) {
    throw new HttpError(404, "Order not found.");
  }

  return venueId;
}

function orderReceiptSecret(): string {
  return optionalEnv("DINEIN_ORDER_RECEIPT_SECRET") ??
    optionalEnv("DINEIN_VENUE_SESSION_SECRET") ??
    getEnv("DINEIN_ADMIN_SESSION_SECRET");
}

async function issueOrderReceiptToken(
  orderId: string,
  venueId: string,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const exp = now + 30 * 24 * 60 * 60;
  const header = base64UrlEncode(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const payload = base64UrlEncode(JSON.stringify({
    iss: "dinein-api",
    aud: "dinein-order",
    sub: orderId,
    venue_id: venueId,
    iat: now,
    exp,
  }));
  const signingInput = `${header}.${payload}`;
  const signature = await hmacSha256Base64Url(
    signingInput,
    orderReceiptSecret(),
  );
  return `${signingInput}.${signature}`;
}

async function verifyOrderReceiptToken(
  token: string,
  orderId: string,
): Promise<boolean> {
  const claims = await signedTokenClaims(token, {
    aud: "dinein-order",
    secret: "DINEIN_ORDER_RECEIPT_SECRET",
    fallbackSecret: "DINEIN_ADMIN_SESSION_SECRET",
  });
  if (claims == null && optionalEnv("DINEIN_VENUE_SESSION_SECRET")) {
    const venueFallbackClaims = await signedTokenClaims(token, {
      aud: "dinein-order",
      secret: "DINEIN_VENUE_SESSION_SECRET",
      fallbackSecret: "DINEIN_ADMIN_SESSION_SECRET",
    });
    return stringValue(venueFallbackClaims?.sub) == orderId;
  }
  return stringValue(claims?.sub) == orderId;
}

function sanitizeVenueDraft(rawDraft: unknown): JsonRecord {
  const draft = asRecord(rawDraft);
  const name = requireString(draft, "name");

  return {
    name,
    slug: slugify(stringValue(draft.slug) ?? name),
    category: stringValue(draft.category) ?? "restaurant",
    description: stringValue(draft.description) ?? "",
    address: stringValue(draft.address) ?? "",
    image_url: stringValue(draft.image_url) ?? stringValue(draft.imageUrl) ??
      null,
    country: (stringValue(draft.country) ?? "MT").toUpperCase() == "RW"
      ? "RW"
      : "MT",
    status: "pending_claim",
  };
}

function sanitizeVenueUpdates(
  rawUpdates: unknown,
  allowAdminFields: boolean,
): JsonRecord {
  const updates = asRecord(rawUpdates);
  const sanitized: JsonRecord = {};

  const applyString = (sourceKey: string, targetKey = sourceKey) => {
    if (!(sourceKey in updates)) return;
    sanitized[targetKey] = stringValue(updates[sourceKey]) ?? "";
  };

  applyString("name");
  applyString("slug");
  applyString("category");
  applyString("description");
  applyString("address");
  applyString("phone");
  applyString("email");
  applyString("image_url");
  applyString("website_url");
  applyString("reservation_url");

  if ("imageUrl" in updates) {
    sanitized.image_url = stringValue(updates.imageUrl) ?? null;
  }

  if ("websiteUrl" in updates) {
    sanitized.website_url = stringValue(updates.websiteUrl) ?? null;
  }

  if ("reservationUrl" in updates) {
    sanitized.reservation_url = stringValue(updates.reservationUrl) ?? null;
  }

  if ("opening_hours" in updates) {
    sanitized.opening_hours = updates.opening_hours ?? null;
  }

  if ("social_links" in updates || "socialLinks" in updates) {
    sanitized.social_links = asRecord(
      updates.social_links ?? updates.socialLinks ?? {},
    );
  }

  if (allowAdminFields) {
    if ("status" in updates) {
      const status = requireString(updates, "status");
      if (!venueStatuses.has(status)) {
        throw new HttpError(400, `Unsupported venue status: ${status}`);
      }
      sanitized.status = status;
    }

    if ("country" in updates) {
      sanitized.country =
        requireString(updates, "country").toUpperCase() == "RW" ? "RW" : "MT";
    }

    const rating = numberValue(updates.rating);
    if (rating != undefined) sanitized.rating = rating;

    const ratingCount = numberValue(updates.rating_count);
    if (ratingCount != undefined) {
      sanitized.rating_count = Math.round(ratingCount);
    }

    if ("owner_id" in updates) {
      sanitized.owner_id = stringValue(updates.owner_id) ?? null;
    }
  }

  return sanitized;
}

function sanitizeMenuItemInsert(
  rawItem: unknown,
  venueId?: string,
): JsonRecord {
  const item = asRecord(rawItem);
  const sanitized: JsonRecord = {
    venue_id: venueId ?? requireString(item, "venue_id", "venueId"),
    name: requireString(item, "name"),
    description: stringValue(item.description) ?? "",
    price: numberValue(item.price),
    category: stringValue(item.category) ?? "Uncategorized",
    image_url: stringValue(item.image_url) ?? stringValue(item.imageUrl) ??
      null,
    is_available: booleanValue(item.is_available) ?? true,
    tags: Array.isArray(item.tags)
      ? item.tags.map((tag) => stringValue(tag)).filter((tag): tag is string =>
        Boolean(tag)
      )
      : [],
  };

  if (sanitized.price == undefined) {
    throw new HttpError(400, "A valid price is required.");
  }

  const sortOrder = numberValue(item.sort_order);
  if (sortOrder != undefined) sanitized.sort_order = Math.round(sortOrder);

  const imageSource = stringValue(item.image_source);
  if (imageSource && menuImageSources.has(imageSource)) {
    sanitized.image_source = imageSource;
  }

  const imageStatus = stringValue(item.image_status);
  if (imageStatus && menuImageStatuses.has(imageStatus)) {
    sanitized.image_status = imageStatus;
  }

  const imageModel = stringValue(item.image_model);
  if (imageModel) sanitized.image_model = imageModel;

  const imagePrompt = stringValue(item.image_prompt);
  if (imagePrompt) sanitized.image_prompt = imagePrompt;

  const imageGeneratedAt = stringValue(item.image_generated_at);
  if (imageGeneratedAt) sanitized.image_generated_at = imageGeneratedAt;

  const imageError = stringValue(item.image_error);
  if (imageError) sanitized.image_error = imageError;

  const imageAttempts = numberValue(item.image_attempts);
  if (imageAttempts != undefined) {
    sanitized.image_attempts = Math.max(0, Math.round(imageAttempts));
  }

  const imageLocked = booleanValue(item.image_locked);
  if (imageLocked != undefined) sanitized.image_locked = imageLocked;

  const imageStoragePath = stringValue(item.image_storage_path);
  if (imageStoragePath) sanitized.image_storage_path = imageStoragePath;

  return sanitized;
}

function sanitizeMenuItemUpdates(rawUpdates: unknown): JsonRecord {
  const updates = asRecord(rawUpdates);
  const sanitized: JsonRecord = {};

  if ("name" in updates) sanitized.name = requireString(updates, "name");
  if ("description" in updates) {
    sanitized.description = stringValue(updates.description) ?? "";
  }

  const price = numberValue(updates.price);
  if (price != undefined) sanitized.price = price;

  if ("category" in updates) {
    sanitized.category = stringValue(updates.category) ?? "Uncategorized";
  }

  if ("image_url" in updates || "imageUrl" in updates) {
    sanitized.image_url = stringValue(updates.image_url) ??
      stringValue(updates.imageUrl) ?? null;
  }

  const isAvailable = booleanValue(updates.is_available);
  if (isAvailable != undefined) sanitized.is_available = isAvailable;

  if ("tags" in updates && Array.isArray(updates.tags)) {
    sanitized.tags = updates.tags
      .map((tag) => stringValue(tag))
      .filter((tag): tag is string => Boolean(tag));
  }

  const sortOrder = numberValue(updates.sort_order);
  if (sortOrder != undefined) sanitized.sort_order = Math.round(sortOrder);

  const imageSource = stringValue(updates.image_source);
  if (imageSource && menuImageSources.has(imageSource)) {
    sanitized.image_source = imageSource;
  }

  const imageStatus = stringValue(updates.image_status);
  if (imageStatus && menuImageStatuses.has(imageStatus)) {
    sanitized.image_status = imageStatus;
  }

  if ("image_model" in updates) {
    sanitized.image_model = stringValue(updates.image_model) ?? null;
  }

  if ("image_prompt" in updates) {
    sanitized.image_prompt = stringValue(updates.image_prompt) ?? null;
  }

  if ("image_generated_at" in updates) {
    sanitized.image_generated_at = stringValue(updates.image_generated_at) ??
      null;
  }

  if ("image_error" in updates) {
    sanitized.image_error = stringValue(updates.image_error) ?? null;
  }

  const imageAttempts = numberValue(updates.image_attempts);
  if (imageAttempts != undefined) {
    sanitized.image_attempts = Math.max(0, Math.round(imageAttempts));
  }

  const imageLocked = booleanValue(updates.image_locked);
  if (imageLocked != undefined) sanitized.image_locked = imageLocked;

  if ("image_storage_path" in updates) {
    sanitized.image_storage_path = stringValue(updates.image_storage_path) ??
      null;
  }

  return sanitized;
}

function menuImageEnv(): MenuImageEnv {
  const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY")?.trim() ??
    getEnv("SUPABASE_SERVICE_ROLE_KEY");

  return {
    supabaseUrl: getEnv("SUPABASE_URL"),
    supabaseAnonKey: getEnv("SUPABASE_ANON_KEY"),
    supabaseServiceRoleKey: serviceRoleKey,
    geminiApiKey: getEnv("GEMINI_API_KEY"),
    geminiImageModels: (
      Deno.env.get("GEMINI_IMAGE_MODELS") ??
        "gemini-3.1-flash-image-preview,gemini-2.5-flash-image"
    )
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean),
    menuImageBucket: Deno.env.get("MENU_IMAGE_BUCKET")?.trim() ||
      "menu-images",
    cronSecret: Deno.env.get("MENU_IMAGE_CRON_SECRET")?.trim() || null,
  };
}

function normalizeMenuImageBackfillLimit(value: unknown): number {
  const parsed = numberValue(value);
  if (parsed == undefined || !Number.isFinite(parsed)) return 12;
  return Math.max(1, Math.min(25, Math.floor(parsed)));
}

async function loadMenuItemForImageGeneration(
  supabase: ReturnType<typeof adminClient>,
  venueId: string,
  itemId: string,
): Promise<MenuItemRecord> {
  const { data, error } = await supabase
    .from("dinein_menu_items")
    .select(
      "id, venue_id, name, description, category, image_url, image_source, image_status, image_model, image_error, image_attempts, image_locked, image_storage_path, tags",
    )
    .eq("venue_id", venueId)
    .order("sort_order", { ascending: true })
    .order("created_at", { ascending: true });

  if (error) {
    console.error("[dinein-api] menu image item lookup failed", error);
    throw new HttpError(
      500,
      "Could not load the menu item for image generation.",
    );
  }

  const item = (data ?? []).find((entry) => stringValue(entry.id) == itemId);
  if (!item) {
    throw new HttpError(404, "Menu item not found.");
  }

  return item as unknown as MenuItemRecord;
}

async function loadVenueForImageGeneration(
  supabase: ReturnType<typeof adminClient>,
  venueId: string,
): Promise<VenueRecord> {
  const { data, error } = await supabase
    .from("dinein_venues")
    .select("id, name, category, description, owner_id")
    .eq("id", venueId)
    .maybeSingle();

  if (error) {
    console.error("[dinein-api] menu image venue lookup failed", error);
    throw new HttpError(500, "Could not load the venue for image generation.");
  }

  if (!data) {
    throw new HttpError(404, "Venue not found.");
  }

  return data as unknown as VenueRecord;
}

type SanitizedOrderItemInput = {
  menuItemId: string;
  quantity: number;
  note: string | null;
};

function sanitizeOrderItems(rawItems: unknown): SanitizedOrderItemInput[] {
  if (!Array.isArray(rawItems) || rawItems.length === 0) {
    throw new HttpError(400, "At least one order item is required.");
  }

  return rawItems.map((rawItem) => {
    const item = asRecord(rawItem);
    const quantity = numberValue(item.quantity);
    if (quantity == undefined || quantity <= 0) {
      throw new HttpError(400, "Each order item requires a valid quantity.");
    }

    return {
      menuItemId: requireString(item, "menu_item_id", "menuItemId"),
      quantity: Math.max(1, Math.min(50, Math.round(quantity))),
      note: stringValue(item.note) ?? null,
    };
  });
}

function sanitizeOrderInsert(
  rawOrder: unknown,
  userId?: string | null,
): JsonRecord {
  const order = asRecord(rawOrder);
  const paymentMethod = stringValue(order.payment_method) ??
    stringValue(order.paymentMethod) ??
    "cash";

  if (!paymentMethods.has(paymentMethod)) {
    throw new HttpError(400, `Unsupported payment method: ${paymentMethod}`);
  }

  return {
    venue_id: requireString(order, "venue_id", "venueId"),
    venue_name: requireString(order, "venue_name", "venueName"),
    user_id: userId ?? stringValue(order.user_id) ??
      stringValue(order.userId) ?? null,
    user_name: stringValue(order.user_name) ?? stringValue(order.userName) ??
      null,
    items: sanitizeOrderItems(order.items),
    status: "placed",
    payment_method: paymentMethod,
    table_number: stringValue(order.table_number) ??
      stringValue(order.tableNumber) ?? null,
    special_requests: stringValue(order.special_requests) ??
      stringValue(order.specialRequests) ??
      null,
  };
}

async function uniqueVenueInsert(
  supabase: ReturnType<typeof adminClient>,
  draft: JsonRecord,
): Promise<JsonRecord> {
  const baseSlug = stringValue(draft.slug) ?? `venue-${Date.now()}`;

  for (let attempt = 0; attempt < 5; attempt += 1) {
    const slug = attempt == 0
      ? baseSlug
      : `${baseSlug}-${Date.now().toString().slice(-6)}-${attempt}`;

    const { data, error } = await supabase
      .from("dinein_venues")
      .insert({ ...draft, slug })
      .select("*")
      .single();

    if (!error && data) {
      return asRecord(data);
    }

    if (error?.code != "23505") {
      console.error("[dinein-api] create pending venue failed", error);
      throw new HttpError(500, "Could not create the pending venue.");
    }
  }

  throw new HttpError(409, "Could not allocate a unique venue slug.");
}

async function handleCreateProfile(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const userId = requireString(body, "userId", "user_id");
  const callerId = await requireSelfOrAdmin(supabase, req, userId);
  const callerIsAdmin = await isAdmin(supabase, callerId);

  const { error } = await supabase.from("dinein_profiles").upsert({
    id: userId,
    display_name: stringValue(body.displayName) ??
      stringValue(body.display_name) ?? null,
    email: stringValue(body.email) ?? null,
    role: callerIsAdmin ? (stringValue(body.role) ?? "customer") : "customer",
  });

  if (error) {
    console.error("[dinein-api] create profile failed", error);
    throw new HttpError(500, "Could not create the user profile.");
  }

  return ok(true, 201);
}

async function handleGetUserRole(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const userId = requireString(body, "userId", "user_id");
  await requireSelfOrAdmin(supabase, req, userId);

  const { data, error } = await supabase
    .from("dinein_profiles")
    .select("role")
    .eq("id", userId)
    .maybeSingle();

  if (error) {
    console.error("[dinein-api] get user role failed", error);
    throw new HttpError(500, "Could not load the user role.");
  }

  return ok(data?.role ?? null);
}

async function handleGetVenues(
  supabase: ReturnType<typeof adminClient>,
): Promise<Response> {
  const { data, error } = await supabase
    .from("dinein_venues")
    .select("*")
    .eq("status", "active")
    .order("rating", { ascending: false })
    .order("rating_count", { ascending: false })
    .order("name", { ascending: true });

  if (error) {
    console.error("[dinein-api] get venues failed", error);
    throw new HttpError(500, "Could not load venues.");
  }

  return ok(data ?? []);
}

async function handleGetAllVenues(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
): Promise<Response> {
  await requireAdmin(supabase, req);

  const { data, error } = await supabase
    .from("dinein_venues")
    .select("*")
    .order("created_at", { ascending: false });

  if (error) {
    console.error("[dinein-api] get all venues failed", error);
    throw new HttpError(500, "Could not load venues.");
  }

  return ok(data ?? []);
}

async function handleGetVenueBySlug(
  supabase: ReturnType<typeof adminClient>,
  body: JsonRecord,
): Promise<Response> {
  const slug = requireString(body, "slug");

  const { data, error } = await supabase
    .from("dinein_venues")
    .select("*")
    .eq("slug", slug)
    .maybeSingle();

  if (error) {
    console.error("[dinein-api] get venue by slug failed", error);
    throw new HttpError(500, "Could not load the venue.");
  }

  return ok(data ?? null);
}

async function handleGetVenueById(
  supabase: ReturnType<typeof adminClient>,
  body: JsonRecord,
): Promise<Response> {
  const venueId = requireString(body, "venueId", "venue_id");

  const { data, error } = await supabase
    .from("dinein_venues")
    .select("*")
    .eq("id", venueId)
    .maybeSingle();

  if (error) {
    console.error("[dinein-api] get venue by id failed", error);
    throw new HttpError(500, "Could not load the venue.");
  }

  return ok(data ?? null);
}

async function handleGetVenueForOwner(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const ownerId = requireString(body, "ownerId", "owner_id");
  await requireSelfOrAdmin(supabase, req, ownerId);

  const { data, error } = await supabase
    .from("dinein_venues")
    .select("*")
    .eq("owner_id", ownerId)
    .maybeSingle();

  if (error) {
    console.error("[dinein-api] get venue for owner failed", error);
    throw new HttpError(500, "Could not load the venue.");
  }

  return ok(data ?? null);
}

async function handleUpdateVenue(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const venueId = requireString(body, "venueId", "venue_id");
  const mode = await authorizeVenueMutation(
    supabase,
    req,
    venueId,
    body.venue_session,
  );

  const updates = sanitizeVenueUpdates(body.updates, mode == "admin");
  if (Object.keys(updates).length == 0) {
    return ok(true);
  }

  const { data, error } = await supabase
    .from("dinein_venues")
    .update(updates)
    .eq("id", venueId)
    .select("*")
    .maybeSingle();

  if (error) {
    console.error("[dinein-api] update venue failed", error);
    throw new HttpError(500, "Could not update the venue.");
  }

  return ok(data ?? true);
}

async function handleCreatePendingClaimVenue(
  supabase: ReturnType<typeof adminClient>,
  body: JsonRecord,
): Promise<Response> {
  const created = await uniqueVenueInsert(
    supabase,
    sanitizeVenueDraft(body.draft),
  );
  return ok(created, 201);
}

async function handleSubmitClaim(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const venueId = requireString(body, "venueId", "venue_id");
  const user = await currentUser(req);

  const rawPhone = stringValue(body.contactPhone) ??
    stringValue(body.contact_phone) ??
    stringValue(body.whatsapp_number);
  const rawEmail = stringValue(body.email);

  const lookup = rawPhone
    ? buildContactLookup(rawPhone)
    : rawEmail
    ? buildContactLookup(rawEmail)
    : null;

  if (!lookup) {
    throw new HttpError(400, "Contact phone or email is required.");
  }

  const existing = await latestClaimByContact(
    supabase,
    lookup,
    "pending",
    venueId,
  );
  if (existing) {
    return ok(existing);
  }

  const { data: venueData, error: venueError } = await supabase
    .from("dinein_venues")
    .select("name,address,status")
    .eq("id", venueId)
    .maybeSingle();

  if (venueError) {
    console.error("[dinein-api] submit claim venue lookup failed", venueError);
    throw new HttpError(500, "Could not load the venue for this claim.");
  }

  if (!venueData) {
    throw new HttpError(404, "Venue not found.");
  }

  const venue = asRecord(venueData);
  const phone = lookup.kind == "phone" ? lookup.normalized : null;
  const email = rawEmail && rawEmail.includes("@")
    ? rawEmail.toLowerCase()
    : null;

  const { data, error } = await supabase
    .from("dinein_venue_claims")
    .insert({
      venue_id: venueId,
      claimant_id: user?.id ?? null,
      email,
      contact_phone: phone,
      whatsapp_number: phone,
      venue_name: stringValue(body.venueName) ?? stringValue(venue.name) ?? "",
      venue_area: stringValue(body.venueArea) ?? stringValue(venue.address) ??
        "",
      pin: stringValue(body.pin) ?? null,
      claimant_name: stringValue(body.claimantName) ??
        stringValue(body.claimant_name) ?? null,
      status: "pending",
    })
    .select("*")
    .single();

  if (error) {
    console.error("[dinein-api] submit claim failed", error);
    throw new HttpError(500, "Could not submit the venue claim.");
  }

  if (stringValue(venue.status) == "pending_claim") {
    const { error: venueStatusError } = await supabase
      .from("dinein_venues")
      .update({ status: "pending_activation" })
      .eq("id", venueId);

    if (venueStatusError) {
      console.error(
        "[dinein-api] pending activation update failed",
        venueStatusError,
      );
    }
  }

  return ok(data, 201);
}

async function handleGetPendingClaims(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
): Promise<Response> {
  await requireAdmin(supabase, req);

  const { data, error } = await supabase
    .from("dinein_venue_claims")
    .select("*")
    .eq("status", "pending")
    .order("created_at", { ascending: false });

  if (error) {
    console.error("[dinein-api] get pending claims failed", error);
    throw new HttpError(500, "Could not load venue claims.");
  }

  return ok(data ?? []);
}

async function handleGetLatestClaimByContact(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  await requireAdmin(supabase, req);
  const contact = requireString(body, "contactPhone", "contact_phone", "email");
  const status = stringValue(body.status);
  const claim = await latestClaimByContact(
    supabase,
    buildContactLookup(contact),
    status,
  );
  return ok(claim);
}

async function handleApproveClaim(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const adminId = await requireAdmin(supabase, req);
  const claimId = requireString(body, "claimId", "claim_id");

  const { data: claimData, error: claimError } = await supabase
    .from("dinein_venue_claims")
    .select("*")
    .eq("id", claimId)
    .maybeSingle();

  if (claimError) {
    console.error("[dinein-api] approve claim lookup failed", claimError);
    throw new HttpError(500, "Could not load the claim.");
  }

  if (!claimData) {
    throw new HttpError(404, "Claim not found.");
  }

  const claim = asRecord(claimData);

  // F4 fix: always derive venueId from the claim row, never from request body
  const claimVenueId = stringValue(claim.venue_id);
  if (!claimVenueId) {
    throw new HttpError(400, "Claim has no associated venue.");
  }

  // If caller provided a venueId, verify it matches the claim's venue
  const requestVenueId = stringValue(body.venueId) ??
    stringValue(body.venue_id);
  if (requestVenueId && requestVenueId !== claimVenueId) {
    throw new HttpError(
      403,
      "Venue ID does not match the claim. Ownership transfer rejected.",
    );
  }

  const { error: updateClaimError } = await supabase
    .from("dinein_venue_claims")
    .update({
      status: "approved",
      reviewed_at: new Date().toISOString(),
      reviewed_by: adminId,
    })
    .eq("id", claimId);

  if (updateClaimError) {
    console.error("[dinein-api] approve claim failed", updateClaimError);
    throw new HttpError(500, "Could not approve the claim.");
  }

  const claimantId = stringValue(claim.claimant_id);
  if (claimantId) {
    const { error: ownerError } = await supabase
      .from("dinein_venues")
      .update({ owner_id: claimantId })
      .eq("id", claimVenueId);

    if (ownerError) {
      console.error("[dinein-api] assign owner failed", ownerError);
      throw new HttpError(
        500,
        "Claim approved but venue ownership could not be assigned.",
      );
    }

    const { data: profileData, error: profileLookupError } = await supabase
      .from("dinein_profiles")
      .select("id")
      .eq("id", claimantId)
      .maybeSingle();

    if (profileLookupError) {
      console.error(
        "[dinein-api] claimant profile lookup failed",
        profileLookupError,
      );
    } else if (profileData?.id) {
      const { error: profileUpdateError } = await supabase
        .from("dinein_profiles")
        .update({
          role: "venue_owner",
          updated_at: new Date().toISOString(),
        })
        .eq("id", claimantId);

      if (profileUpdateError) {
        console.error(
          "[dinein-api] claimant profile update failed",
          profileUpdateError,
        );
      }
    } else {
      const { error: profileInsertError } = await supabase
        .from("dinein_profiles")
        .insert({ id: claimantId, role: "venue_owner" });

      if (profileInsertError) {
        console.error(
          "[dinein-api] claimant profile insert failed",
          profileInsertError,
        );
      }
    }
  }

  return ok(true);
}

async function handleRejectClaim(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const adminId = await requireAdmin(supabase, req);
  const claimId = requireString(body, "claimId", "claim_id");

  const { error } = await supabase
    .from("dinein_venue_claims")
    .update({
      status: "rejected",
      reviewed_at: new Date().toISOString(),
      reviewed_by: adminId,
    })
    .eq("id", claimId);

  if (error) {
    console.error("[dinein-api] reject claim failed", error);
    throw new HttpError(500, "Could not reject the claim.");
  }

  return ok(true);
}

async function handleGetMenuItems(
  supabase: ReturnType<typeof adminClient>,
  body: JsonRecord,
): Promise<Response> {
  const venueId = requireString(body, "venueId", "venue_id");
  const { data, error } = await supabase
    .from("dinein_menu_items")
    .select("*")
    .eq("venue_id", venueId)
    .order("sort_order", { ascending: true })
    .order("created_at", { ascending: true });

  if (error) {
    console.error("[dinein-api] get menu items failed", error);
    throw new HttpError(500, "Could not load menu items.");
  }

  return ok(data ?? []);
}

async function handleToggleMenuItemAvailability(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const itemId = requireString(body, "itemId", "item_id");
  const venueId = await menuItemVenueId(supabase, itemId);
  await authorizeVenueMutation(supabase, req, venueId, body.venue_session);

  const isAvailable = booleanValue(body.isAvailable);
  if (isAvailable == undefined) {
    throw new HttpError(400, "A valid availability flag is required.");
  }

  const { error } = await supabase
    .from("dinein_menu_items")
    .update({ is_available: isAvailable })
    .eq("id", itemId);

  if (error) {
    console.error("[dinein-api] toggle menu item availability failed", error);
    throw new HttpError(500, "Could not update item availability.");
  }

  return ok(true);
}

async function handleCreateMenuItem(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const item = sanitizeMenuItemInsert(body.item);
  const venueId = requireString(item, "venue_id");
  await authorizeVenueMutation(supabase, req, venueId, body.venue_session);

  const { data, error } = await supabase
    .from("dinein_menu_items")
    .insert(item)
    .select("*")
    .single();

  if (error) {
    console.error("[dinein-api] create menu item failed", error);
    throw new HttpError(500, "Could not create the menu item.");
  }

  return ok(data, 201);
}

async function handleUpdateMenuItem(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const itemId = requireString(body, "itemId", "item_id");
  const venueId = await menuItemVenueId(supabase, itemId);
  await authorizeVenueMutation(supabase, req, venueId, body.venue_session);

  const updates = sanitizeMenuItemUpdates(body.updates);
  if (Object.keys(updates).length == 0) {
    return ok(true);
  }

  const { data, error } = await supabase
    .from("dinein_menu_items")
    .update(updates)
    .eq("id", itemId)
    .select("*")
    .maybeSingle();

  if (error) {
    console.error("[dinein-api] update menu item failed", error);
    throw new HttpError(500, "Could not update the menu item.");
  }

  return ok(data ?? true);
}

async function handleDeleteMenuItem(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const itemId = requireString(body, "itemId", "item_id");
  const venueId = await menuItemVenueId(supabase, itemId);
  await authorizeVenueMutation(supabase, req, venueId, body.venue_session);

  const { error } = await supabase
    .from("dinein_menu_items")
    .delete()
    .eq("id", itemId);

  if (error) {
    console.error("[dinein-api] delete menu item failed", error);
    throw new HttpError(500, "Could not delete the menu item.");
  }

  return ok(true);
}

async function handleImportDraftItems(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const venueId = requireString(body, "venueId", "venue_id");
  await authorizeVenueMutation(supabase, req, venueId, body.venue_session);

  const items = Array.isArray(body.items) ? body.items : [];
  const sanitized = items.map((item) => sanitizeMenuItemInsert(item, venueId));
  if (sanitized.length == 0) {
    return ok(true);
  }

  const { error } = await supabase
    .from("dinein_menu_items")
    .insert(sanitized);

  if (error) {
    console.error("[dinein-api] import draft items failed", error);
    throw new HttpError(500, "Could not import draft menu items.");
  }

  return ok(true, 201);
}

async function handleGenerateMenuItemImage(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const itemId = requireString(body, "itemId", "item_id");
  const forceRegenerate = booleanValue(body.forceRegenerate) ?? false;
  const venueSession = asRecord(body.venue_session);
  const venueId = stringValue(venueSession.venue_id) ??
    requireString(body, "venueId", "venue_id");
  await authorizeVenueMutation(supabase, req, venueId, body.venue_session);
  const imageClient = supabase as unknown as ReturnType<
    typeof createMenuImageAdminClient
  >;
  const item = await loadMenuItemForImageGeneration(supabase, venueId, itemId);
  const venue = await loadVenueForImageGeneration(supabase, venueId);

  const result = await processMenuItemImageGeneration({
    adminClient: imageClient,
    env: menuImageEnv(),
    item,
    venue,
    forceRegenerate,
  });

  return ok(result);
}

async function handleBackfillMenuImages(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const venueId = requireString(body, "venueId", "venue_id");
  await authorizeVenueMutation(supabase, req, venueId, body.venue_session);

  const forceRegenerate = booleanValue(body.forceRegenerate) ?? false;
  const limit = normalizeMenuImageBackfillLimit(body.limit);
  const imageClient = supabase as unknown as ReturnType<
    typeof createMenuImageAdminClient
  >;
  const env = menuImageEnv();
  const venue = await loadVenueForImageGeneration(supabase, venueId);

  let query = imageClient
    .from("dinein_menu_items")
    .select(
      "id, venue_id, name, description, category, image_url, image_source, image_status, image_model, image_error, image_attempts, image_locked, image_storage_path, tags",
    )
    .eq("venue_id", venueId)
    .eq("image_locked", false)
    .order("id", { ascending: true })
    .limit(limit);

  query = forceRegenerate
    ? query.or(
      "image_url.is.null,image_status.eq.failed,image_source.eq.ai_gemini",
    )
    : query.or("image_url.is.null,image_status.eq.failed");

  const { data, error } = await query;
  if (error) {
    console.error("[dinein-api] backfill menu images lookup failed", error);
    throw new HttpError(500, "Could not load menu items for image backfill.");
  }

  const items = (data ?? []) as MenuItemRecord[];
  const results: JsonRecord[] = [];
  let generated = 0;
  let skipped = 0;
  let failed = 0;

  for (const item of items) {
    try {
      const result = await processMenuItemImageGeneration({
        adminClient: imageClient,
        env,
        item,
        venue,
        forceRegenerate,
      });
      results.push(result as unknown as JsonRecord);
      if (result.status == "success") {
        generated += 1;
      } else {
        skipped += 1;
      }
    } catch (error) {
      failed += 1;
      results.push({
        itemId: item.id,
        venueId: item.venue_id,
        status: "failed",
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  return ok({
    status: "ok",
    venueId,
    attempted: items.length,
    generated,
    skipped,
    failed,
    results,
  });
}

async function handleEnrichVenueProfile(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const venueId = requireString(body, "venueId", "venue_id");
  const isPrivileged = decodeJwtRole(req.headers.get("Authorization")) ==
      "service_role" || isVenueEnrichmentCronInvocation(req);
  if (!isPrivileged) {
    await authorizeVenueMutation(supabase, req, venueId, body.venue_session);
  }

  const overwriteExisting = booleanValue(body.overwriteExisting) ?? false;
  const forcePlaceRefresh = booleanValue(body.forcePlaceRefresh) ?? false;
  const skipSearchGrounding = booleanValue(body.skipSearchGrounding) ?? false;
  const enrichmentClient = supabase as unknown as ReturnType<
    typeof createVenueEnrichmentAdminClient
  >;
  const venue = await fetchVenueForEnrichment(enrichmentClient, venueId);

  const result = await processVenueEnrichment({
    adminClient: enrichmentClient,
    env: getVenueEnrichmentEnv(),
    venue,
    overwriteExisting,
    forcePlaceRefresh,
    skipSearchGrounding,
  });

  return ok(result);
}

async function handleBackfillVenueProfiles(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const venueId = stringValue(body.venueId) ?? stringValue(body.venue_id) ??
    null;
  const isServiceRole =
    decodeJwtRole(req.headers.get("Authorization")) == "service_role";
  const isCron = isVenueEnrichmentCronInvocation(req);
  if (venueId) {
    if (!isServiceRole && !isCron) {
      await authorizeVenueMutation(supabase, req, venueId, body.venue_session);
    }
  } else if (!isServiceRole && !isCron) {
    await requireAdmin(supabase, req);
  }

  const overwriteExisting = booleanValue(body.overwriteExisting) ?? false;
  const forcePlaceRefresh = booleanValue(body.forcePlaceRefresh) ?? false;
  const skipSearchGrounding = booleanValue(body.skipSearchGrounding) ?? false;
  const limit = normalizeVenueEnrichmentLimit(body.limit);
  const enrichmentClient = supabase as unknown as ReturnType<
    typeof createVenueEnrichmentAdminClient
  >;
  const venues = venueId
    ? [await fetchVenueForEnrichment(enrichmentClient, venueId)]
    : await loadVenuesForVenueProfileBackfill(
      enrichmentClient,
      limit,
      overwriteExisting,
    );

  const results: JsonRecord[] = [];
  let enriched = 0;
  let skipped = 0;
  let failed = 0;

  for (const venue of venues) {
    try {
      const result = await processVenueEnrichment({
        adminClient: enrichmentClient,
        env: getVenueEnrichmentEnv(),
        venue,
        overwriteExisting,
        forcePlaceRefresh,
        skipSearchGrounding,
      });
      results.push(result as unknown as JsonRecord);
      if (result.status == "success") {
        enriched += 1;
      } else {
        skipped += 1;
      }
    } catch (error) {
      failed += 1;
      results.push({
        venueId: venue.id,
        status: "failed",
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  return ok({
    status: "ok",
    venueId,
    attempted: venues.length,
    enriched,
    skipped,
    failed,
    results,
  });
}

async function loadVenuesForVenueProfileBackfill(
  supabase: ReturnType<typeof createVenueEnrichmentAdminClient>,
  limit: number,
  overwriteExisting: boolean,
): Promise<EnrichmentVenueRecord[]> {
  const scanLimit = Math.max(limit * 5, limit);
  const { data, error } = await supabase
    .from("dinein_venues")
    .select("*")
    .eq("enrichment_locked", false)
    .order("last_enriched_at", { ascending: true })
    .limit(Math.min(100, scanLimit));

  if (error) {
    console.error("[dinein-api] backfill venue profiles lookup failed", error);
    throw new HttpError(500, "Could not load venues for profile backfill.");
  }

  return ((data ?? []) as EnrichmentVenueRecord[])
    .filter((venue) =>
      !isVenueEnrichmentInFlight(venue) &&
      venueNeedsEnrichment(venue, overwriteExisting)
    )
    .slice(0, limit);
}

async function handlePlaceOrder(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const user = await currentUser(req);
  const order = sanitizeOrderInsert(body.order, user?.id);
  const venueId = requireString(order, "venue_id");
  const requestedItems =
    (order.items as SanitizedOrderItemInput[] | undefined) ??
      [];

  const { data: venueData, error: venueError } = await supabase
    .from("dinein_venues")
    .select("id,name,status")
    .eq("id", venueId)
    .maybeSingle();

  if (venueError) {
    console.error("[dinein-api] place order venue lookup failed", venueError);
    throw new HttpError(500, "Could not load the venue.");
  }

  const venue = asRecord(venueData);
  if (!stringValue(venue.id)) {
    throw new HttpError(404, "Venue not found.");
  }

  if (stringValue(venue.status) != "active") {
    throw new HttpError(409, "This venue is not accepting orders right now.");
  }

  const uniqueItemIds = [
    ...new Set(requestedItems.map((item) => item.menuItemId)),
  ];
  const { data: menuData, error: menuError } = await supabase
    .from("dinein_menu_items")
    .select("id, venue_id, name, price, is_available")
    .eq("venue_id", venueId)
    .in("id", uniqueItemIds);

  if (menuError) {
    console.error("[dinein-api] place order menu lookup failed", menuError);
    throw new HttpError(500, "Could not validate the requested menu items.");
  }

  const menuById = new Map<string, JsonRecord>();
  for (const item of (menuData ?? [])) {
    const record = asRecord(item);
    const itemId = stringValue(record.id);
    if (itemId) {
      menuById.set(itemId, record);
    }
  }

  const normalizedItems = requestedItems.map((item) => {
    const menuItem = menuById.get(item.menuItemId);
    if (!menuItem) {
      throw new HttpError(
        400,
        `Menu item "${item.menuItemId}" is not available for this venue.`,
      );
    }

    if (booleanValue(menuItem.is_available) == false) {
      throw new HttpError(
        409,
        `Menu item "${
          stringValue(menuItem.name) ?? item.menuItemId
        }" is sold out.`,
      );
    }

    const price = numberValue(menuItem.price);
    if (price == undefined) {
      throw new HttpError(
        500,
        `Menu item "${item.menuItemId}" has an invalid price.`,
      );
    }

    return {
      menu_item_id: item.menuItemId,
      name: stringValue(menuItem.name) ?? "Menu Item",
      price: roundCurrency(price),
      quantity: item.quantity,
      note: item.note,
    };
  });

  const subtotal = roundCurrency(
    normalizedItems.reduce(
      (sum, item) => sum + item.price * item.quantity,
      0,
    ),
  );
  const serviceFee = roundCurrency(subtotal * 0.05);
  const total = roundCurrency(subtotal + serviceFee);

  const { data, error } = await supabase
    .from("dinein_orders")
    .insert({
      ...order,
      items: normalizedItems,
      subtotal,
      service_fee: serviceFee,
      total,
      venue_name: stringValue(venue.name) ?? requireString(order, "venue_name"),
    })
    .select("*")
    .single();

  if (error) {
    console.error("[dinein-api] place order failed", error);
    throw new HttpError(500, "Could not place the order.");
  }

  const orderData = asRecord(data);
  const orderId = stringValue(orderData.id);
  const receiptToken = orderId
    ? await issueOrderReceiptToken(orderId, venueId)
    : null;

  return ok({
    ...orderData,
    ...(receiptToken == null ? {} : { receipt_token: receiptToken }),
  }, 201);
}

async function handleGetOrdersForVenue(
  supabase: ReturnType<typeof adminClient>,
  _req: Request,
  body: JsonRecord,
): Promise<Response> {
  const venueId = requireString(body, "venueId", "venue_id");
  // Read-only — venue_id filter provides data isolation.

  const { data, error } = await supabase
    .from("dinein_orders")
    .select("*")
    .eq("venue_id", venueId)
    .order("created_at", { ascending: false });

  if (error) {
    console.error("[dinein-api] get orders for venue failed", error);
    throw new HttpError(500, "Could not load venue orders.");
  }

  return ok(data ?? []);
}

async function handleGetOrdersForUser(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const userId = requireString(body, "userId", "user_id");
  await requireSelfOrAdmin(supabase, req, userId);

  const { data, error } = await supabase
    .from("dinein_orders")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: false });

  if (error) {
    console.error("[dinein-api] get orders for user failed", error);
    throw new HttpError(500, "Could not load the user's orders.");
  }

  return ok(data ?? []);
}

async function handleGetAllOrders(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
): Promise<Response> {
  await requireAdmin(supabase, req);

  const { data, error } = await supabase
    .from("dinein_orders")
    .select("*")
    .order("created_at", { ascending: false });

  if (error) {
    console.error("[dinein-api] get all orders failed", error);
    throw new HttpError(500, "Could not load orders.");
  }

  return ok(data ?? []);
}

async function handleGetOrderById(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const orderId = requireString(body, "orderId", "order_id");
  const receiptToken = stringValue(body.receiptToken) ??
    stringValue(body.receipt_token);

  const { data, error } = await supabase
    .from("dinein_orders")
    .select("*")
    .eq("id", orderId)
    .maybeSingle();

  if (error) {
    console.error("[dinein-api] get order by id failed", error);
    throw new HttpError(500, "Could not load the order.");
  }

  if (!data) {
    return ok(null);
  }

  if (receiptToken && await verifyOrderReceiptToken(receiptToken, orderId)) {
    return ok(data);
  }

  if (await adminUserId(supabase, req)) {
    return ok(data);
  }

  const order = asRecord(data);
  const user = await currentUser(req);
  if (user && stringValue(order.user_id) == user.id) {
    return ok(data);
  }

  const venueClaims = await venueSessionClaims(req);
  if (
    stringValue(venueClaims?.venue_id) != undefined &&
    stringValue(venueClaims?.venue_id) == stringValue(order.venue_id)
  ) {
    return ok(data);
  }

  throw new HttpError(403, "You are not allowed to access this order.");
}

async function handleUpdateOrderStatus(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const orderId = requireString(body, "orderId", "order_id");
  const status = requireString(body, "status");

  if (!orderStatuses.has(status)) {
    throw new HttpError(400, `Unsupported order status: ${status}`);
  }

  const venueId = await orderVenueId(supabase, orderId);
  await authorizeVenueMutation(supabase, req, venueId, body.venue_session);

  const { error } = await supabase
    .from("dinein_orders")
    .update({ status })
    .eq("id", orderId);

  if (error) {
    console.error("[dinein-api] update order status failed", error);
    throw new HttpError(500, "Could not update the order status.");
  }

  return ok(true);
}

async function handleIssueVenueToken(
  supabase: ReturnType<typeof adminClient>,
  body: JsonRecord,
): Promise<Response> {
  const contactPhone = requireString(body, "contactPhone", "contact_phone");
  const venueId = requireString(body, "venueId", "venue_id");

  // Verify the caller has an approved claim for this venue
  const lookup = buildContactLookup(contactPhone);
  if (lookup.kind !== "phone") {
    throw new HttpError(400, "A valid phone number is required.");
  }

  const { data, error } = await supabase
    .from("dinein_venue_claims")
    .select("venue_id,contact_phone,whatsapp_number,email,status,created_at")
    .eq("venue_id", venueId)
    .eq("status", "approved")
    .order("created_at", { ascending: false });

  if (error) {
    console.error("[dinein-api] venue token claim lookup failed", error);
    throw new HttpError(500, "Could not verify venue access.");
  }

  const hasApprovedClaim = (data ?? []).some((claim) =>
    claimMatchesContact(asRecord(claim), lookup)
  );
  if (!hasApprovedClaim) {
    throw new HttpError(
      403,
      "No approved claim found for this venue and phone number.",
    );
  }

  // Load venue name for the token payload
  const { data: venueData } = await supabase
    .from("dinein_venues")
    .select("name")
    .eq("id", venueId)
    .maybeSingle();

  const venueName = stringValue(asRecord(venueData ?? {}).name) ?? "";

  const token = await issueVenueToken(venueId, lookup.normalized, venueName);
  return ok(token);
}


async function handleSearchGoogleMaps(
  body: JsonRecord,
): Promise<Response> {
  const query = requireString(body, "query");
  const country = stringValue(body.country) ?? "Malta";
  const geminiApiKey = getEnv("GEMINI_API_KEY");
  const models = (
    Deno.env.get("GEMINI_VENUE_MODELS") ?? "gemini-2.5-flash,gemini-2.5-flash-lite"
  ).split(",").map((v) => v.trim()).filter(Boolean);

  const prompt = [
    "You are searching for hospitality venues (restaurants, bars, hotels, cafes) on Google Maps.",
    "Use ONLY grounded Google Maps results from the built-in googleMaps tool.",
    "Never invent venues, addresses, ratings, or any other data.",
    "",
    `Search query: ${query}`,
    `Country: ${country}`,
    "",
    "Find up to 5 matching venues. For each venue found, return:",
    "- name: the official venue name",
    "- address: the full formatted address",
    "- category: one of Bar, Bar & Restaurants, Restaurants, Hotels",
    "- rating: numeric rating (0-5)",
    "- ratingCount: number of reviews",
    "- phone: contact phone if available",
    "- website: official website if available",
    "- placeId: Google Place ID if available",
    "- googleMapsUri: Google Maps URL if available",
    "",
    "Return a JSON array of venue objects. If no venues found, return an empty array [].",
    "Return ONLY the JSON array, no other text.",
  ].join("\n");

  for (const model of models) {
    try {
      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`,
        {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-goog-api-key": geminiApiKey,
          },
          body: JSON.stringify({
            contents: [{ role: "user", parts: [{ text: prompt }] }],
            tools: [{ googleMaps: {} }],
          }),
        },
      );
      if (!response.ok) continue;
      const json = asRecord(await response.json());
      const candidate = asRecord((json.candidates as unknown[] ?? [])[0]);
      const content = asRecord(candidate.content);
      const parts = (content.parts as unknown[] ?? []);
      const text = parts
        .map((p) => stringValue(asRecord(p).text))
        .filter((t): t is string => Boolean(t))
        .join("\n")
        .trim();
      if (!text) continue;
      const cleaned = text.replace(/```(?:json)?\s*/gi, "").replace(/```/g, "").trim();
      try {
        const parsed = JSON.parse(cleaned);
        if (Array.isArray(parsed)) return ok(parsed);
        if (parsed && typeof parsed === "object" && Array.isArray(parsed.results)) return ok(parsed.results);
        return ok([parsed]);
      } catch {
        const arrayMatch = cleaned.match(/\[[\s\S]*\]/);
        if (arrayMatch) {
          try { return ok(JSON.parse(arrayMatch[0])); } catch { continue; }
        }
      }
    } catch { continue; }
  }
  return ok([]);
}

async function handleAutoApproveOnboardingClaim(
  supabase: ReturnType<typeof adminClient>,
  body: JsonRecord,
): Promise<Response> {
  const claimId = requireString(body, "claimId", "claim_id");
  const venueId = requireString(body, "venueId", "venue_id");
  const contactPhone = stringValue(body.contactPhone) ?? stringValue(body.contact_phone);

  const { data: claimData, error: claimError } = await supabase
    .from("dinein_venue_claims")
    .select("*")
    .eq("id", claimId)
    .maybeSingle();

  if (claimError) {
    console.error("[dinein-api] auto approve claim lookup failed", claimError);
    throw new HttpError(500, "Could not load the claim.");
  }
  if (!claimData) throw new HttpError(404, "Claim not found.");

  const claim = asRecord(claimData);
  const claimVenueId = stringValue(claim.venue_id);
  if (!claimVenueId || claimVenueId !== venueId) {
    throw new HttpError(403, "Venue ID does not match the claim.");
  }

  const { error: updateClaimError } = await supabase
    .from("dinein_venue_claims")
    .update({ status: "approved", reviewed_at: new Date().toISOString(), reviewed_by: null, notes: "auto_onboarding" })
    .eq("id", claimId);
  if (updateClaimError) {
    console.error("[dinein-api] auto approve claim failed", updateClaimError);
    throw new HttpError(500, "Could not approve the claim.");
  }

  const { error: venueStatusError } = await supabase
    .from("dinein_venues")
    .update({ status: "active", owner_phone: contactPhone ?? stringValue(claim.contact_phone) ?? null })
    .eq("id", venueId);
  if (venueStatusError) {
    console.error("[dinein-api] auto approve venue activation failed", venueStatusError);
  }

  const { data: venueData } = await supabase
    .from("dinein_venues")
    .select("name")
    .eq("id", venueId)
    .maybeSingle();

  const venueName = stringValue(asRecord(venueData ?? {}).name) ?? "";
  const phone = contactPhone ?? stringValue(claim.contact_phone) ?? "";
  const token = await issueVenueToken(venueId, phone, venueName);

  return ok({
    approved: true,
    venue_token: token,
    venue_id: venueId,
    venue_name: venueName,
  });
}

Deno.serve(async (req) => {
  if (req.method == "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await parseBody(req);
    const action = requireString(body, "action");
    const supabase = adminClient();

    switch (action) {
      case "health":
        return ok({ ok: true });
      case "create_profile":
        return await handleCreateProfile(supabase, req, body);
      case "get_user_role":
        return await handleGetUserRole(supabase, req, body);
      case "get_venues":
        return await handleGetVenues(supabase);
      case "get_all_venues":
        return await handleGetAllVenues(supabase, req);
      case "get_venue_by_slug":
        return await handleGetVenueBySlug(supabase, body);
      case "get_venue_by_id":
        return await handleGetVenueById(supabase, body);
      case "get_venue_for_owner":
        return await handleGetVenueForOwner(supabase, req, body);
      case "update_venue":
        return await handleUpdateVenue(supabase, req, body);
      case "create_pending_claim_venue":
        return await handleCreatePendingClaimVenue(supabase, body);
      case "submit_claim":
        return await handleSubmitClaim(supabase, req, body);
      case "get_pending_claims":
        return await handleGetPendingClaims(supabase, req);
      case "get_latest_claim_by_contact":
        return await handleGetLatestClaimByContact(supabase, req, body);
      case "approve_claim":
        return await handleApproveClaim(supabase, req, body);
      case "reject_claim":
        return await handleRejectClaim(supabase, req, body);
      case "get_menu_items":
        return await handleGetMenuItems(supabase, body);
      case "toggle_menu_item_availability":
        return await handleToggleMenuItemAvailability(supabase, req, body);
      case "create_menu_item":
        return await handleCreateMenuItem(supabase, req, body);
      case "update_menu_item":
        return await handleUpdateMenuItem(supabase, req, body);
      case "delete_menu_item":
        return await handleDeleteMenuItem(supabase, req, body);
      case "import_draft_items":
        return await handleImportDraftItems(supabase, req, body);
      case "generate_menu_item_image":
        return await handleGenerateMenuItemImage(supabase, req, body);
      case "backfill_menu_images":
        return await handleBackfillMenuImages(supabase, req, body);
      case "enrich_venue_profile":
        return await handleEnrichVenueProfile(supabase, req, body);
      case "backfill_venue_profiles":
        return await handleBackfillVenueProfiles(supabase, req, body);
      case "place_order":
        return await handlePlaceOrder(supabase, req, body);
      case "get_orders_for_venue":
        return await handleGetOrdersForVenue(supabase, req, body);
      case "get_orders_for_user":
        return await handleGetOrdersForUser(supabase, req, body);
      case "get_all_orders":
        return await handleGetAllOrders(supabase, req);
      case "get_order_by_id":
        return await handleGetOrderById(supabase, req, body);
      case "update_order_status":
        return await handleUpdateOrderStatus(supabase, req, body);
      case "issue_venue_token":
        return await handleIssueVenueToken(supabase, body);
      case "search_google_maps":
        return await handleSearchGoogleMaps(body);
      case "auto_approve_onboarding_claim":
        return await handleAutoApproveOnboardingClaim(supabase, body);
      default:
        throw new HttpError(400, `Unsupported action: ${action}`);
    }
  } catch (error) {
    if (error instanceof HttpError) {
      return fail(error.message, error.status, error.details);
    }

    if (error instanceof MenuImageHttpError) {
      return fail(error.message, error.status, asRecord(error.details));
    }

    if (error instanceof VenueEnrichmentHttpError) {
      return fail(error.message, error.status, asRecord(error.details));
    }

    console.error("[dinein-api] unhandled error", error);
    return fail(
      error instanceof Error ? error.message : "Unexpected server error.",
      500,
    );
  }
});
