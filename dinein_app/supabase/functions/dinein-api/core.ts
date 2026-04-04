// ─── DineIn API Handlers ─────────────────────────────────────────────────
// All handler implementations + helpers.  Imported by index.ts dispatcher.
// ─────────────────────────────────────────────────────────────────────────
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { JWT } from "npm:google-auth-library@9";
import { createClient } from "npm:@supabase/supabase-js@2";
import {
  buildWhatsAppTemplatePayload,
  buildWhatsAppTextPayload,
  postWhatsAppMessage,
} from "../_shared/whatsapp.ts";
import {
  auditMenuItemImage,
  createAdminClient as createMenuImageAdminClient,
  type FunctionEnv as MenuImageEnv,
  HttpError as MenuImageHttpError_,
  type MenuItemRecord,
  processMenuItemImageGeneration,
  type VenueRecord,
} from "../_shared/menu-image.ts";
import {
  inferMenuItemClass,
  normalizeMenuItemClass,
} from "../_shared/menu-item-context.ts";
import {
  createVenueAdminClient as createVenueEnrichmentAdminClient,
  fetchVenueForEnrichment,
  getVenueEnrichmentEnv,
  HttpError as VenueEnrichmentHttpError_,
  isVenueEnrichmentInFlight,
  normalizeVenueEnrichmentLimit,
  processVenueEnrichment,
  venueNeedsEnrichment,
  type VenueRecord as EnrichmentVenueRecord,
} from "../_shared/venue-enrichment.ts";
import {
  createVenueProfileImageAdminClient,
  getVenueProfileImageEnv,
  HttpError as VenueProfileImageHttpError_,
  isVenueProfileImageGenerationInFlight,
  normalizeVenueProfileImageLimit,
  processVenueProfileImageGeneration,
  venueNeedsProfileImageGeneration,
} from "../_shared/venue-profile-image.ts";
import {
  isAllowedMenuUploadUrl,
  normalizeMenuUploadContentType,
} from "./security.ts";
import {
  assertRateLimit,
  GOOGLE_MAPS_SEARCH_RATE_LIMIT,
  recordRateLimit,
  WAVE_RATE_LIMIT,
} from "./rate-limit.ts";
import {
  getEnv,
  optionalEnv,
  stringValue,
  numberValue,
  asRecord,
} from "../_shared/env.ts";

// Re-export domain error types so index.ts can catch them
export const MenuImageHttpError = MenuImageHttpError_;
export const VenueEnrichmentHttpError = VenueEnrichmentHttpError_;
export const VenueProfileImageHttpError = VenueProfileImageHttpError_;

export const corsHeaders = {
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
  "pending_activation",
]);
const publicVenueStatuses = new Set([
  "active",
  "inactive",
  "maintenance",
  "pending_activation",
]);
const orderStatuses = new Set(["placed", "received", "served", "cancelled"]);
const paymentMethods = new Set(["cash", "momo_ussd", "revolut_link"]);
const orderPaymentStatuses = new Set([
  "pending",
  "confirmed",
  "not_required",
  "failed",
]);
const accessVerificationMethods = new Set(["otp", "admin_override"]);
const menuImageStatuses = new Set(["pending", "generating", "ready", "failed"]);
const menuImageSources = new Set(["manual", "ai_gemini"]);
const pushPlatforms = new Set(["android", "ios"]);
const FIREBASE_MESSAGING_SCOPE =
  "https://www.googleapis.com/auth/firebase.messaging";
const VENUE_PUSH_ALERT_ROUTE_ORDERS = "/venue/orders";
const VENUE_PUSH_ALERT_ROUTE_WAVES = "/venue/waves";
const ANONYMOUS_WAVE_RATE_LIMIT_WINDOW_MS = 5 * 60 * 1000;
const ANONYMOUS_WAVE_RATE_LIMIT_MAX_REQUESTS = 3;
const GOOGLE_MAPS_SEARCH_RATE_LIMIT_WINDOW_MS = 15 * 60 * 1000;
const GOOGLE_MAPS_SEARCH_RATE_LIMIT_MAX_REQUESTS = 20;
const anonymousWaveRateLimitBuckets = new Map<string, number[]>();
const googleMapsSearchRateLimitBuckets = new Map<string, number[]>();
let firebaseMessagingAccessTokenCache:
  | { accessToken: string; expiresAt: number }
  | null = null;
let missingFirebaseMessagingConfigLogged = false;

type JsonRecord = Record<string, unknown>;
type CountryCode = "MT" | "RW";
type VenuePushNotificationPayload = {
  title: string;
  body: string;
  data: Record<string, string>;
};

export class HttpError extends Error {
  status: number;
  details?: JsonRecord;

  constructor(status: number, message: string, details?: JsonRecord) {
    super(message);
    this.status = status;
    this.details = details;
  }
}

// getEnv, optionalEnv imported from ../_shared/env.ts

function hasMatchingSecretHeader(req: Request, envName: string): boolean {
  const expected = optionalEnv(envName);
  if (!expected) return false;
  return req.headers.get("x-cron-secret") == expected;
}

function isVenueEnrichmentCronInvocation(req: Request): boolean {
  return hasMatchingSecretHeader(req, "VENUE_ENRICHMENT_CRON_SECRET");
}

function isVenueProfileImageCronInvocation(req: Request): boolean {
  return hasMatchingSecretHeader(req, "VENUE_IMAGE_CRON_SECRET");
}

function getSigningSecret(primary: string, fallback?: string): string {
  return optionalEnv(primary) ??
    (fallback ? getEnv(fallback) : getEnv(primary));
}

export function adminClient() {
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

export function ok(data: unknown, status = 200): Response {
  return new Response(JSON.stringify({ data }), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

export function fail(message: string, status = 400, details?: JsonRecord): Response {
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

// asRecord, stringValue imported from ../_shared/env.ts

export { asRecord };

export async function parseBody(req: Request): Promise<JsonRecord> {
  try {
    return asRecord(await req.json()) as JsonRecord;
  } catch {
    return {};
  }
}

function normalizeCountryCode(
  value: unknown,
  fallback: CountryCode = "MT",
): CountryCode {
  const normalized = stringValue(value)?.toUpperCase();
  if (normalized == "RW") return "RW";
  if (normalized == "MT") return "MT";
  return fallback;
}

function normalizeStringList(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((entry) => stringValue(entry))
    .filter((entry): entry is string => Boolean(entry));
}

function slugify(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .replace(/-{2,}/g, "-");
}

function requestCountryCode(
  body: JsonRecord,
  fallback: CountryCode = "MT",
): CountryCode {
  return normalizeCountryCode(body.country ?? body.country_code, fallback);
}

function countryLabel(code: CountryCode): string {
  return code == "RW" ? "Rwanda" : "Malta";
}

// numberValue imported from ../_shared/env.ts

function booleanValue(value: unknown): boolean | undefined {
  if (typeof value == "boolean") return value;
  if (typeof value == "string") {
    const normalized = value.trim().toLowerCase();
    if (["true", "1", "yes", "on"].includes(normalized)) return true;
    if (["false", "0", "no", "off"].includes(normalized)) return false;
  }
  return undefined;
}

export function normalizeWaveTableNumber(value: unknown): string {
  const raw = stringValue(value)?.replaceAll(/\s+/g, "");
  if (!raw || !/^\d{1,4}$/.test(raw)) {
    throw new HttpError(
      400,
      "Table number must be 1 to 4 digits.",
      { code: "invalid_table_number" },
    );
  }

  const normalized = Number.parseInt(raw, 10);
  if (!Number.isFinite(normalized) || normalized < 1) {
    throw new HttpError(
      400,
      "Table number must be 1 to 4 digits.",
      { code: "invalid_table_number" },
    );
  }

  return String(normalized);
}

function clientIpAddress(req: Request): string | null {
  const forwarded = req.headers.get("x-forwarded-for");
  if (forwarded) {
    const first = forwarded.split(",")[0]?.trim();
    if (first) return first;
  }

  return req.headers.get("cf-connecting-ip")?.trim() ??
    req.headers.get("x-real-ip")?.trim() ??
    null;
}

function anonymousWaveRateLimitKey(
  req: Request,
  venueId: string,
): string | null {
  const ip = clientIpAddress(req);
  if (!ip) return null;

  const userAgent = req.headers.get("user-agent")?.trim() ?? "unknown";
  return `${venueId}:${ip}:${userAgent.slice(0, 160)}`;
}

function pruneAnonymousWaveRateLimitBucket(
  key: string,
  nowMs: number,
): number[] {
  const windowStart = nowMs - ANONYMOUS_WAVE_RATE_LIMIT_WINDOW_MS;
  const recent = (anonymousWaveRateLimitBuckets.get(key) ?? []).filter((
    timestamp,
  ) => timestamp >= windowStart);

  if (recent.length == 0) {
    anonymousWaveRateLimitBuckets.delete(key);
  } else {
    anonymousWaveRateLimitBuckets.set(key, recent);
  }

  return recent;
}

function assertAnonymousWaveRateLimit(
  req: Request,
  venueId: string,
  nowMs: number,
): string | null {
  const key = anonymousWaveRateLimitKey(req, venueId);
  if (!key) return null;

  const recent = pruneAnonymousWaveRateLimitBucket(key, nowMs);
  if (recent.length >= ANONYMOUS_WAVE_RATE_LIMIT_MAX_REQUESTS) {
    throw new HttpError(
      429,
      "Too many staff requests from this device. Please wait a moment and try again.",
      { code: "wave_rate_limited" },
    );
  }

  return key;
}

function recordAnonymousWaveRateLimit(key: string, nowMs: number): void {
  const recent = pruneAnonymousWaveRateLimitBucket(key, nowMs);
  recent.push(nowMs);
  anonymousWaveRateLimitBuckets.set(key, recent);
}

export function resetWaveRateLimitState(): void {
  anonymousWaveRateLimitBuckets.clear();
}

function googleMapsSearchRateLimitKey(req: Request): string | null {
  const ip = clientIpAddress(req);
  if (!ip) return null;

  const userAgent = req.headers.get("user-agent")?.trim() ?? "unknown";
  return `${ip}:${userAgent.slice(0, 160)}`;
}

function pruneGoogleMapsSearchRateLimitBucket(
  key: string,
  nowMs: number,
): number[] {
  const windowStart = nowMs - GOOGLE_MAPS_SEARCH_RATE_LIMIT_WINDOW_MS;
  const recent = (googleMapsSearchRateLimitBuckets.get(key) ?? []).filter((
    timestamp,
  ) => timestamp >= windowStart);

  if (recent.length == 0) {
    googleMapsSearchRateLimitBuckets.delete(key);
  } else {
    googleMapsSearchRateLimitBuckets.set(key, recent);
  }

  return recent;
}

function assertGoogleMapsSearchRateLimit(
  req: Request,
  nowMs: number,
): string | null {
  const key = googleMapsSearchRateLimitKey(req);
  if (!key) return null;

  const recent = pruneGoogleMapsSearchRateLimitBucket(key, nowMs);
  if (recent.length >= GOOGLE_MAPS_SEARCH_RATE_LIMIT_MAX_REQUESTS) {
    throw new HttpError(
      429,
      "Too many venue search requests from this device. Please wait a moment and try again.",
      { code: "google_maps_search_rate_limited" },
    );
  }

  return key;
}

function recordGoogleMapsSearchRateLimit(key: string, nowMs: number): void {
  const recent = pruneGoogleMapsSearchRateLimitBucket(key, nowMs);
  recent.push(nowMs);
  googleMapsSearchRateLimitBuckets.set(key, recent);
}

export function resetGoogleMapsSearchRateLimitState(): void {
  googleMapsSearchRateLimitBuckets.clear();
}

function normalizeListLimit(value: unknown, max = 100): number | null {
  const raw = numberValue(value);
  if (raw == undefined) return null;
  return Math.min(max, Math.max(1, Math.trunc(raw)));
}

function normalizeListOffset(value: unknown): number {
  const raw = numberValue(value);
  if (raw == undefined) return 0;
  return Math.max(0, Math.trunc(raw));
}

function roundCurrency(value: number): number {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

function normalizePushPlatform(value: unknown): string {
  const normalized = (stringValue(value) ?? "").trim().toLowerCase();
  if (!pushPlatforms.has(normalized)) {
    throw new HttpError(400, `Unsupported push platform: ${value}`);
  }
  return normalized;
}

function sanitizePushToken(value: unknown): string {
  const token = requireString({ value }, "value").trim();
  if (token.length < 32) {
    throw new HttpError(400, "Push token is invalid.");
  }
  return token;
}

function defaultVenueNotificationSettings(): JsonRecord {
  return {
    order_push_enabled: true,
    whatsapp_updates_enabled: true,
  };
}

function normalizeVenueNotificationSettingsInput(value: unknown): JsonRecord {
  const settings = asRecord(value);
  return {
    order_push_enabled:
      booleanValue(settings.order_push_enabled ?? settings.orderPushEnabled) ??
        true,
    whatsapp_updates_enabled: booleanValue(
      settings.whatsapp_updates_enabled ??
        settings.whatsAppUpdatesEnabled ??
        settings.whatsappUpdatesEnabled,
    ) ?? true,
  };
}

function notificationData(
  values: Record<string, unknown>,
): Record<string, string> {
  return Object.fromEntries(
    Object.entries(values)
      .filter(([, value]) => value !== undefined && value !== null)
      .map(([key, value]) => [
        key,
        typeof value == "string" ? value : JSON.stringify(value),
      ]),
  );
}

function firebaseMessagingConfig(): {
  projectId: string;
  clientEmail: string;
  privateKey: string;
} | null {
  const projectId = optionalEnv("FIREBASE_PROJECT_ID") ??
    optionalEnv("GOOGLE_CLOUD_PROJECT") ??
    optionalEnv("GCLOUD_PROJECT");
  const clientEmail = optionalEnv("FIREBASE_CLIENT_EMAIL");
  const privateKey = optionalEnv("FIREBASE_PRIVATE_KEY");

  if (!projectId || !clientEmail || !privateKey) {
    if (!missingFirebaseMessagingConfigLogged) {
      console.warn(
        "[dinein-api] Firebase Messaging is not configured; venue push alerts are disabled.",
      );
      missingFirebaseMessagingConfigLogged = true;
    }
    return null;
  }

  return {
    projectId,
    clientEmail,
    privateKey: privateKey.replace(/\\n/g, "\n"),
  };
}

async function firebaseMessagingAccessToken(): Promise<
  {
    projectId: string;
    accessToken: string;
  } | null
> {
  const config = firebaseMessagingConfig();
  if (!config) return null;

  const now = Date.now();
  if (
    firebaseMessagingAccessTokenCache &&
    firebaseMessagingAccessTokenCache.expiresAt > now + 60_000
  ) {
    return {
      projectId: config.projectId,
      accessToken: firebaseMessagingAccessTokenCache.accessToken,
    };
  }

  const client = new JWT({
    email: config.clientEmail,
    key: config.privateKey,
    scopes: [FIREBASE_MESSAGING_SCOPE],
  });
  const tokens = await client.authorize();
  const accessToken = stringValue(tokens.access_token);
  if (!accessToken) {
    throw new Error("Could not authorize Firebase Messaging.");
  }

  firebaseMessagingAccessTokenCache = {
    accessToken,
    expiresAt: numberValue(tokens.expiry_date) ?? (now + 45 * 60_000),
  };

  return {
    projectId: config.projectId,
    accessToken,
  };
}

function isInvalidPushTokenError(value: unknown): boolean {
  const error = asRecord(asRecord(value).error);
  const status = (stringValue(error.status) ?? "").toUpperCase();
  if (status == "NOT_FOUND") return true;

  const message = (stringValue(error.message) ?? "").toUpperCase();
  if (
    message.includes("UNREGISTERED") ||
    message.includes("REGISTRATION TOKEN") ||
    message.includes("REQUESTED ENTITY WAS NOT FOUND")
  ) {
    return true;
  }

  const details = Array.isArray(error.details) ? error.details : [];
  for (const detail of details) {
    const errorCode = (stringValue(asRecord(detail).errorCode) ?? "")
      .toUpperCase();
    if (errorCode == "UNREGISTERED" || errorCode == "INVALID_ARGUMENT") {
      return true;
    }
  }

  return false;
}

function orderItemCount(value: unknown): number {
  if (!Array.isArray(value)) return 0;
  return value.reduce((total, item) => {
    const quantity = numberValue(asRecord(item).quantity) ?? 0;
    return total + Math.max(0, Math.trunc(quantity));
  }, 0);
}

function formatOrderTotal(value: unknown): string | null {
  const amount = numberValue(value);
  return amount == undefined ? null : `EUR ${amount.toFixed(2)}`;
}

function buildNewOrderPushNotification(
  order: JsonRecord,
): VenuePushNotificationPayload {
  const venueId = stringValue(order.venue_id);
  const orderId = stringValue(order.id);
  const orderNumber = stringValue(order.order_number) ?? "New";
  const tableNumber = stringValue(order.table_number) ?? "unknown";
  const itemCount = Math.max(1, orderItemCount(order.items));
  const totalLabel = formatOrderTotal(order.total);

  return {
    title: `New order for table ${tableNumber}`,
    body: [
      `Order ${orderNumber}`,
      itemCount == 1 ? "1 item" : `${itemCount} items`,
      ...(totalLabel ? [totalLabel] : []),
    ].join(" - "),
    data: notificationData({
      event_type: "new_order",
      route: VENUE_PUSH_ALERT_ROUTE_ORDERS,
      venue_id: venueId,
      order_id: orderId,
      order_number: orderNumber,
      table_number: tableNumber,
    }),
  };
}

function buildBellRequestPushNotification(
  venue: JsonRecord,
  bellRequest: JsonRecord,
): VenuePushNotificationPayload {
  const venueId = stringValue(venue.id);
  const venueName = stringValue(venue.name) ?? "your venue";
  const requestId = stringValue(bellRequest.id);
  const tableNumber = stringValue(bellRequest.table_number) ?? "unknown";

  return {
    title: `Table ${tableNumber} requested service`,
    body: `A guest tapped the bell at ${venueName}.`,
    data: notificationData({
      event_type: "bell_request",
      route: VENUE_PUSH_ALERT_ROUTE_WAVES,
      venue_id: venueId,
      bell_request_id: requestId,
      table_number: tableNumber,
    }),
  };
}

export function generateOrderNumber(): string {
  const randomValue = new Uint32Array(1);
  crypto.getRandomValues(randomValue);
  return String(10_000_000 + (randomValue[0] % 90_000_000));
}

export function normalizePaymentMethod(rawValue: unknown): string {
  const normalized = (stringValue(rawValue) ?? "cash")
    .trim()
    .toLowerCase()
    .replaceAll(/[\s-]+/g, "_");

  switch (normalized) {
    case "cash":
      return "cash";
    case "momo":
    case "momo_ussd":
    case "mobile_money":
      return "momo_ussd";
    case "revolut":
    case "revolut_link":
    case "revolutlink":
    case "revolut_me":
      return "revolut_link";
    default:
      throw new HttpError(400, `Unsupported payment method: ${normalized}`);
  }
}

export function orderPaymentStatusForMethod(paymentMethod: string): string {
  if (!paymentMethods.has(paymentMethod)) {
    throw new HttpError(400, `Unsupported payment method: ${paymentMethod}`, {
      code: "unsupported_payment_method",
    });
  }

  const paymentStatus = (() => {
    switch (paymentMethod) {
      case "cash":
        return "not_required";
      case "momo_ussd":
      case "revolut_link":
        return "pending";
      default:
        return "pending";
    }
  })();
  if (!orderPaymentStatuses.has(paymentStatus)) {
    throw new HttpError(500, `Unsupported payment status: ${paymentStatus}`, {
      code: "unsupported_payment_status",
    });
  }

  return paymentStatus;
}

export function normalizeVenueSupportedPaymentMethods(
  rawValue: unknown,
  rawRevolutUrl?: unknown,
): string[] {
  const values = Array.isArray(rawValue)
    ? rawValue
    : typeof rawValue == "string"
    ? rawValue.split(",")
    : [];

  const normalized = values
    .map((value) => {
      const raw = stringValue(value);
      return raw ? normalizePaymentMethod(raw) : null;
    })
    .filter((value): value is string => Boolean(value));

  if (normalized.length == 0) {
    const fallback = ["cash"];
    if (stringValue(rawRevolutUrl)) {
      fallback.push("revolut_link");
    }
    return fallback;
  }

  return [...new Set(normalized)];
}

export function shouldGenerateAiVenueProfileImage(rawVenue: unknown): boolean {
  const venue = asRecord(rawVenue);
  if (booleanValue(venue.image_locked) ?? false) {
    return false;
  }

  const imageSource = stringValue(venue.image_source) ?? null;
  const hasImage = Boolean(stringValue(venue.image_url));

  if (imageSource == "manual") {
    return false;
  }

  if (!hasImage) {
    return true;
  }

  return imageSource != "ai_gemini";
}

export function venueOrderingReadiness(rawVenue: unknown): {
  ready: boolean;
  reasons: string[];
  supportedPaymentMethods: string[];
} {
  const venue = asRecord(rawVenue);
  const reasons: string[] = [];
  const googleBusinessStatus =
    stringValue(venue.google_business_status)?.trim().toUpperCase() ?? null;
  const googleClosedOverride =
    booleanValue(venue.google_closed_override_enabled) ?? false;
  const declaredPaymentMethods = normalizeVenueSupportedPaymentMethods(
    venue.supported_payment_methods,
    venue.revolut_url,
  );
  const supportedPaymentMethods = declaredPaymentMethods.filter((method) => {
    switch (method) {
      case "cash":
        return true;
      case "revolut_link":
        return Boolean(stringValue(venue.revolut_url));
      case "momo_ussd":
        return false;
      default:
        return false;
    }
  });

  if (venueStatus(venue) != "active") {
    reasons.push("venue_not_active");
  }
  if (
    googleBusinessStatus == "CLOSED_PERMANENTLY" &&
    !googleClosedOverride
  ) {
    reasons.push("google_business_closed_permanently");
  }
  if (!stringValue(venue.access_verified_at)) {
    reasons.push("access_verification_required");
  }
  if (!stringValue(venue.name)) {
    reasons.push("venue_name_required");
  }
  if (!stringValue(venue.address)) {
    reasons.push("venue_address_required");
  }
  if (!effectiveVenuePhone(venue)) {
    reasons.push("venue_phone_required");
  }
  if (!stringValue(venue.image_url)) {
    reasons.push("venue_image_required");
  }
  if (supportedPaymentMethods.length == 0) {
    if (
      declaredPaymentMethods.includes("revolut_link") &&
      !stringValue(venue.revolut_url)
    ) {
      reasons.push("revolut_url_required");
    }
    if (declaredPaymentMethods.includes("momo_ussd")) {
      reasons.push("momo_configuration_required");
    }
    if (reasons.length == 0) {
      reasons.push("payment_method_required");
    }
  }

  return {
    ready: reasons.length == 0,
    reasons,
    supportedPaymentMethods,
  };
}

export function assertValidOrderStatusTransition(
  currentStatus: string,
  nextStatus: string,
): void {
  if (!orderStatuses.has(currentStatus)) {
    throw new HttpError(
      500,
      `Unexpected stored order status: ${currentStatus}`,
      {
        code: "invalid_stored_order_status",
      },
    );
  }

  if (!orderStatuses.has(nextStatus)) {
    throw new HttpError(400, `Unsupported order status: ${nextStatus}`, {
      code: "unsupported_order_status",
    });
  }

  if (currentStatus == nextStatus) return;

  const allowedTransitions: Record<string, string[]> = {
    placed: ["received", "cancelled"],
    received: ["served", "cancelled"],
    served: [],
    cancelled: [],
  };
  if (allowedTransitions[currentStatus]?.includes(nextStatus)) return;

  throw new HttpError(
    409,
    `Invalid order status transition: ${currentStatus} -> ${nextStatus}.`,
    {
      code: "invalid_order_transition",
      current_status: currentStatus,
      next_status: nextStatus,
    },
  );
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

export function requireString(body: JsonRecord, ...keys: string[]): string {
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

function effectiveVenuePhone(rawVenue: unknown): string | null {
  const venue = asRecord(rawVenue);
  return stringValue(venue.phone) ?? stringValue(venue.owner_contact_phone) ??
    stringValue(venue.owner_whatsapp_number) ?? null;
}

function normalizedVenueAccessPhone(rawVenue: unknown): string | null {
  const venue = asRecord(rawVenue);
  const explicit = stringValue(venue.normalized_access_phone);
  if (explicit) return explicit;

  const phone = effectiveVenuePhone(venue);
  if (!phone) return null;

  try {
    return normalizePhone(phone);
  } catch {
    return null;
  }
}

async function ensureUniqueVenueAccessPhone(
  supabase: ReturnType<typeof adminClient>,
  normalizedPhone: string,
  venueId: string,
): Promise<void> {
  const { data, error } = await supabase
    .from("dinein_venues")
    .select("id, name, status")
    .eq("normalized_access_phone", normalizedPhone)
    .neq("id", venueId)
    .not("status", "eq", "deleted")
    .limit(1);

  if (error) {
    console.error("[dinein-api] venue access duplicate lookup failed", error);
    throw new HttpError(500, "Could not validate venue access ownership.");
  }

  const conflict = Array.isArray(data) && data.length > 0
    ? asRecord(data[0])
    : null;
  if (conflict == null) return;

  throw new HttpError(
    409,
    "This WhatsApp number is already assigned to another venue.",
    {
      code: "venue_access_phone_in_use",
      conflicting_venue_id: stringValue(conflict.id),
      conflicting_venue_name: stringValue(conflict.name),
    },
  );
}

async function venueSnapshot(
  supabase: ReturnType<typeof adminClient>,
  venueId: string,
): Promise<JsonRecord> {
  const { data, error } = await supabase
    .from("dinein_venues")
    .select("*")
    .eq("id", venueId)
    .maybeSingle();

  if (error) {
    console.error("[dinein-api] venue snapshot lookup failed", error);
    throw new HttpError(500, "Could not load the venue.");
  }

  const venue = asRecord(data);
  if (!stringValue(venue.id)) {
    throw new HttpError(404, "Venue not found.");
  }

  return venue;
}

const VENUE_TOKEN_TTL_SECONDS = 30 * 24 * 60 * 60; // 30 days

function venueTokenSecret(): string {
  return getSigningSecret(
    "DINEIN_VENUE_SESSION_SECRET",
    "DINEIN_ADMIN_SESSION_SECRET",
  );
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

  return {
    venueId,
    contactPhone: phone,
  };
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
    return {
      venueId: tokenVenueId,
      contactPhone: tokenPhone,
    };
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

function isServiceRoleRequest(req: Request): boolean {
  return decodeJwtRole(req.headers.get("Authorization")) == "service_role";
}

async function venueNotificationSettingsSnapshot(
  supabase: ReturnType<typeof adminClient>,
  venueId: string,
): Promise<JsonRecord> {
  const { data, error } = await supabase
    .from("dinein_venue_notification_settings")
    .select("order_push_enabled, whatsapp_updates_enabled")
    .eq("venue_id", venueId)
    .maybeSingle();

  if (error) {
    console.error(
      "[dinein-api] venue notification settings lookup failed",
      error,
    );
    throw new HttpError(500, "Could not load notification settings.");
  }

  return {
    ...defaultVenueNotificationSettings(),
    ...asRecord(data),
  };
}

async function upsertVenueNotificationSettings(
  supabase: ReturnType<typeof adminClient>,
  venueId: string,
  settingsInput: unknown,
): Promise<JsonRecord> {
  const settings = normalizeVenueNotificationSettingsInput(settingsInput);
  const { data, error } = await supabase
    .from("dinein_venue_notification_settings")
    .upsert(
      {
        venue_id: venueId,
        ...settings,
      },
      { onConflict: "venue_id" },
    )
    .select("order_push_enabled, whatsapp_updates_enabled")
    .single();

  if (error) {
    console.error(
      "[dinein-api] venue notification settings upsert failed",
      error,
    );
    throw new HttpError(500, "Could not save notification settings.");
  }

  return {
    ...defaultVenueNotificationSettings(),
    ...asRecord(data),
  };
}

async function syncVenuePushRegistrationFlags(
  supabase: ReturnType<typeof adminClient>,
  venueId: string,
  notificationsEnabled: boolean,
): Promise<void> {
  const { error } = await supabase
    .from("dinein_push_registrations")
    .update({ notifications_enabled: notificationsEnabled })
    .eq("venue_id", venueId);

  if (error) {
    console.error(
      "[dinein-api] venue push registration settings sync failed",
      error,
    );
  }
}

async function resolveVenueNotificationContactPhone(
  supabase: ReturnType<typeof adminClient>,
  venueId: string,
  body: JsonRecord,
): Promise<string | null> {
  const directPhone = stringValue(body.contactPhone) ??
    stringValue(body.contact_phone);
  if (directPhone) return directPhone;

  const session = asRecord(body.venue_session);
  const sessionPhone = stringValue(session.contact_phone) ??
    stringValue(session.contactPhone);
  if (sessionPhone) return sessionPhone;

  const venue = await venueSnapshot(supabase, venueId);
  return stringValue(venue.owner_whatsapp_number) ??
    stringValue(venue.owner_contact_phone) ??
    stringValue(venue.phone) ??
    null;
}

async function activeVenuePushRegistrations(
  supabase: ReturnType<typeof adminClient>,
  venueId: string,
): Promise<JsonRecord[]> {
  const settings = await venueNotificationSettingsSnapshot(supabase, venueId);
  if (booleanValue(settings.order_push_enabled) == false) {
    return [];
  }

  const { data, error } = await supabase
    .from("dinein_push_registrations")
    .select("id, push_token, platform, device_key")
    .eq("venue_id", venueId)
    .eq("provider", "fcm")
    .eq("notifications_enabled", true)
    .order("last_seen_at", { ascending: false })
    .limit(25);

  if (error) {
    console.error("[dinein-api] venue push registration lookup failed", error);
    throw new HttpError(500, "Could not load push registrations.");
  }

  return (data ?? [])
    .map((entry) => asRecord(entry))
    .filter((entry) => {
      const token = stringValue(entry.push_token);
      const platform = (stringValue(entry.platform) ?? "").toLowerCase();
      return Boolean(token) && pushPlatforms.has(platform);
    });
}

async function sendVenuePushNotification(
  auth: { projectId: string; accessToken: string },
  registration: JsonRecord,
  payload: VenuePushNotificationPayload,
): Promise<"sent" | "invalid_token"> {
  const pushToken = requireString(registration, "push_token");
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${auth.projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${auth.accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: pushToken,
          notification: {
            title: payload.title,
            body: payload.body,
          },
          data: payload.data,
          android: {
            priority: "high",
            notification: {
              channel_id: "venue_operational_alerts",
              sound: "default",
              click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
          },
          apns: {
            headers: { "apns-priority": "10" },
            payload: {
              aps: {
                sound: "default",
              },
            },
          },
        },
      }),
    },
  );

  if (response.ok) {
    return "sent";
  }

  const errorBody = await response.json().catch(() => null);
  if (isInvalidPushTokenError(errorBody)) {
    return "invalid_token";
  }

  throw new Error(
    `FCM send failed with status ${response.status}: ${
      JSON.stringify(errorBody)
    }`,
  );
}

async function prunePushRegistrations(
  supabase: ReturnType<typeof adminClient>,
  registrationIds: string[],
): Promise<void> {
  if (registrationIds.length == 0) return;

  const { error } = await supabase
    .from("dinein_push_registrations")
    .delete()
    .in("id", registrationIds);

  if (error) {
    console.error("[dinein-api] push registration prune failed", error);
  }
}

async function dispatchVenueOperationalAlert(
  supabase: ReturnType<typeof adminClient>,
  venueId: string,
  payload: VenuePushNotificationPayload,
): Promise<void> {
  const auth = await firebaseMessagingAccessToken();
  if (!auth) return;

  const registrations = await activeVenuePushRegistrations(supabase, venueId);
  if (registrations.length == 0) return;

  const results = await Promise.allSettled(
    registrations.map(async (registration) => {
      const registrationId = requireString(registration, "id");
      const outcome = await sendVenuePushNotification(
        auth,
        registration,
        payload,
      );
      return { registrationId, outcome };
    }),
  );

  const invalidRegistrationIds: string[] = [];
  for (const result of results) {
    if (result.status == "fulfilled") {
      if (result.value.outcome == "invalid_token") {
        invalidRegistrationIds.push(result.value.registrationId);
      }
      continue;
    }

    console.error("[dinein-api] venue push delivery failed", result.reason);
  }

  await prunePushRegistrations(supabase, invalidRegistrationIds);
}
async function venueOwnerWhatsAppNumber(
  supabase: ReturnType<typeof adminClient>,
  venueId: string,
): Promise<string | null> {
  const { data, error } = await supabase
    .from("dinein_venues")
    .select("owner_whatsapp_number, owner_contact_phone")
    .eq("id", venueId)
    .maybeSingle();

  if (error) {
    console.error("[dinein-api] venue owner lookup failed", error);
    return null;
  }

  return stringValue(data?.owner_whatsapp_number) ??
    stringValue(data?.owner_contact_phone) ??
    null;
}

async function dispatchVenueWhatsAppAlert(
  supabase: ReturnType<typeof adminClient>,
  venueId: string,
  messageBody: string,
): Promise<void> {
  const settings = await venueNotificationSettingsSnapshot(supabase, venueId);
  if (!settings.whatsapp_updates_enabled) {
    return;
  }

  const phone = await venueOwnerWhatsAppNumber(supabase, venueId);
  if (!phone) {
    console.log(
      "[dinein-api] Skipping WhatsApp alert, no valid phone for venue",
      venueId,
    );
    return;
  }

  const templateName = Deno.env.get("WHATSAPP_VENUE_ORDER_TEMPLATE");
  if (templateName) {
    // Note: Template requires approved WhatsApp Meta Business Template
    const templatePayload = buildWhatsAppTemplatePayload(
      phone,
      templateName,
      [{ type: "body", parameters: [{ type: "text", text: messageBody }] }],
    );
    const result = await postWhatsAppMessage(templatePayload);
    if (!result.ok) {
      console.error("[dinein-api] WhatsApp template alert failed", result);
    }
  } else {
    // Fallback to text if testing limits or inside 24-hr session window.
    const textPayload = buildWhatsAppTextPayload(phone, messageBody);
    const result = await postWhatsAppMessage(textPayload);
    if (!result.ok) {
      console.error("[dinein-api] WhatsApp text alert failed", result);
    }
  }
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

async function menuItemAdminSnapshot(
  supabase: ReturnType<typeof adminClient>,
  itemId: string,
): Promise<JsonRecord> {
  const { data, error } = await supabase
    .from("dinein_menu_items")
    .select(
      "id, venue_id, admin_group_id, admin_managed, name, description, category, class, image_url, image_source, image_status, image_model, image_prompt, image_error, image_generated_at, image_locked, image_storage_path, image_attempts, tags",
    )
    .eq("id", itemId)
    .maybeSingle();

  if (error) {
    console.error("[dinein-api] menu item admin snapshot failed", error);
    throw new HttpError(500, "Could not load the menu item.");
  }

  if (!data) {
    throw new HttpError(404, "Menu item not found.");
  }

  return asRecord(data);
}

async function adminManagedMenuGroupSeed(
  supabase: ReturnType<typeof adminClient>,
  groupId: string,
): Promise<JsonRecord> {
  const { data, error } = await supabase
    .from("dinein_menu_items")
    .select(
      "id, venue_id, admin_group_id, admin_managed, name, description, category, class, image_url, image_source, image_status, image_model, image_prompt, image_error, image_generated_at, image_locked, image_storage_path, image_attempts, tags",
    )
    .eq("admin_group_id", groupId)
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) {
    console.error("[dinein-api] admin menu group seed lookup failed", error);
    throw new HttpError(500, "Could not load the menu group.");
  }

  if (!data) {
    throw new HttpError(404, "Admin menu group not found.");
  }

  return asRecord(data);
}

async function syncAdminManagedGroupSharedFields(
  supabase: ReturnType<typeof adminClient>,
  groupId: string,
  updates: JsonRecord,
): Promise<void> {
  if (Object.keys(updates).length == 0) return;

  const { error } = await supabase
    .from("dinein_menu_items")
    .update(updates)
    .eq("admin_group_id", groupId);

  if (error) {
    console.error("[dinein-api] sync admin menu group fields failed", error);
    throw new HttpError(500, "Could not update the admin menu group.");
  }
}

async function syncAdminManagedGroupImageFields(
  supabase: ReturnType<typeof adminClient>,
  groupId: string,
  sourceItemId: string,
): Promise<void> {
  const source = await menuItemAdminSnapshot(supabase, sourceItemId);
  const updates: JsonRecord = {
    image_url: stringValue(source.image_url) ?? null,
    image_source: stringValue(source.image_source) ?? null,
    image_status: stringValue(source.image_status) ?? null,
    image_model: stringValue(source.image_model) ?? null,
    image_prompt: stringValue(source.image_prompt) ?? null,
    image_error: stringValue(source.image_error) ?? null,
    image_generated_at: stringValue(source.image_generated_at) ?? null,
    image_locked: booleanValue(source.image_locked) ?? false,
    image_storage_path: stringValue(source.image_storage_path) ?? null,
    image_attempts: numberValue(source.image_attempts) ?? 0,
  };

  await syncAdminManagedGroupSharedFields(supabase, groupId, updates);
}

async function ensureUniqueVenueSlug(
  supabase: ReturnType<typeof adminClient>,
  input: string,
  excludeVenueId?: string,
): Promise<string> {
  const base = slugify(input) || "venue";
  let attempt = 0;

  while (attempt < 100) {
    const candidate = attempt == 0 ? base : `${base}-${attempt + 1}`;
    let query = supabase.from("dinein_venues").select("id").eq(
      "slug",
      candidate,
    );
    if (excludeVenueId) {
      query = query.neq("id", excludeVenueId);
    }
    const { data, error } = await query.maybeSingle();
    if (error) {
      console.error("[dinein-api] venue slug lookup failed", error);
      throw new HttpError(500, "Could not validate the venue slug.");
    }
    if (!data) return candidate;
    attempt += 1;
  }

  throw new HttpError(500, "Could not generate a unique venue slug.");
}

async function resolveAdminAssignmentVenueIds(
  supabase: ReturnType<typeof adminClient>,
  body: JsonRecord,
): Promise<string[]> {
  const assignAll = booleanValue(body.assignAll ?? body.assign_all) ?? false;
  const requestedVenueIds = Array.from(
    new Set(
      normalizeStringList(body.venueIds ?? body.venue_ids).map((value) =>
        value.trim()
      ).filter(Boolean),
    ),
  );

  let query = supabase
    .from("dinein_venues")
    .select("id")
    .neq("status", "deleted");

  if (assignAll) {
    query = query.eq("country", requestCountryCode(body));
  } else {
    if (requestedVenueIds.length == 0) {
      throw new HttpError(
        400,
        "Select at least one venue or choose to assign to all venues.",
      );
    }
    query = query.in("id", requestedVenueIds);
  }

  const { data, error } = await query.order("name", { ascending: true });
  if (error) {
    console.error("[dinein-api] resolve admin venue assignment failed", error);
    throw new HttpError(500, "Could not load the target venues.");
  }

  const resolvedVenueIds = (data ?? [])
    .map((row) => stringValue(asRecord(row).id))
    .filter((value): value is string => Boolean(value));

  if (!assignAll && resolvedVenueIds.length != requestedVenueIds.length) {
    throw new HttpError(400, "One or more selected venues could not be found.");
  }

  if (resolvedVenueIds.length == 0) {
    throw new HttpError(400, "No venues are available for this assignment.");
  }

  return resolvedVenueIds;
}

function sanitizeAdminManagedMenuDraft(rawItem: unknown): JsonRecord {
  const item = asRecord(rawItem);
  const name = requireString(item, "name");
  const description = stringValue(item.description) ?? "";
  const category = stringValue(item.category) ?? "Uncategorized";
  const tags = normalizeStringList(item.tags);
  const sanitized: JsonRecord = {
    name,
    description,
    category,
    tags,
  };

  if ("class" in item) {
    const normalizedClass = normalizeMenuItemClass(item.class);
    if (item.class != undefined && item.class != null && !normalizedClass) {
      throw new HttpError(400, "Menu item class must be food or drinks.");
    }
    if (normalizedClass) sanitized.class = normalizedClass;
  }

  if ("image_url" in item || "imageUrl" in item) {
    const imageUrl = stringValue(item.image_url) ??
      stringValue(item.imageUrl) ??
      null;
    sanitized.image_url = imageUrl;
    if (imageUrl) {
      sanitized.image_source = "manual";
      sanitized.image_status = "ready";
      sanitized.image_model = null;
      sanitized.image_error = null;
      sanitized.image_generated_at = null;
      sanitized.image_storage_path = null;
      sanitized.image_locked = true;
    } else {
      sanitized.image_source = null;
      sanitized.image_status = "pending";
      sanitized.image_model = null;
      sanitized.image_error = null;
      sanitized.image_generated_at = null;
      sanitized.image_storage_path = null;
      sanitized.image_locked = false;
    }
  }

  return sanitized;
}

function sanitizeAdminMenuUpdates(rawUpdates: unknown): JsonRecord {
  const updates = asRecord(rawUpdates);
  const forbiddenKeys = [
    "price",
    "is_available",
    "isAvailable",
    "highlight_rank",
    "highlightRank",
    "sort_order",
    "sortOrder",
    "venue_id",
    "venueId",
    "admin_group_id",
    "adminGroupId",
    "admin_managed",
    "adminManaged",
  ];
  for (const key of forbiddenKeys) {
    if (key in updates) {
      throw new HttpError(
        403,
        "Admin can update shared menu content only. Price and availability remain venue-specific.",
      );
    }
  }

  const sanitized: JsonRecord = {};

  if ("name" in updates) sanitized.name = requireString(updates, "name");
  if ("description" in updates) {
    sanitized.description = stringValue(updates.description) ?? "";
  }
  if ("category" in updates) {
    sanitized.category = stringValue(updates.category) ?? "Uncategorized";
  }
  if ("tags" in updates) {
    sanitized.tags = normalizeStringList(updates.tags);
  }
  if ("class" in updates) {
    const normalizedClass = normalizeMenuItemClass(updates.class);
    if (
      updates.class != undefined &&
      updates.class != null &&
      !normalizedClass
    ) {
      throw new HttpError(400, "Menu item class must be food or drinks.");
    }
    sanitized.class = normalizedClass ?? null;
  }
  if ("image_url" in updates || "imageUrl" in updates) {
    const imageUrl = stringValue(updates.image_url) ??
      stringValue(updates.imageUrl) ??
      null;
    sanitized.image_url = imageUrl;
    if (imageUrl) {
      sanitized.image_source = "manual";
      sanitized.image_status = "ready";
      sanitized.image_model = null;
      sanitized.image_error = null;
      sanitized.image_generated_at = null;
      sanitized.image_storage_path = null;
      sanitized.image_locked = true;
    } else {
      sanitized.image_source = null;
      sanitized.image_status = "pending";
      sanitized.image_model = null;
      sanitized.image_error = null;
      sanitized.image_generated_at = null;
      sanitized.image_storage_path = null;
      sanitized.image_locked = false;
    }
  }
  if ("image_locked" in updates || "imageLocked" in updates) {
    const imageLocked = booleanValue(
      updates.image_locked ?? updates.imageLocked,
    );
    if (imageLocked == undefined) {
      throw new HttpError(400, "A valid image_locked flag is required.");
    }
    sanitized.image_locked = imageLocked;
  }

  return sanitized;
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

async function orderStatusSnapshot(
  supabase: ReturnType<typeof adminClient>,
  orderId: string,
): Promise<{ venueId: string; status: string }> {
  const { data, error } = await supabase
    .from("dinein_orders")
    .select("venue_id,status")
    .eq("id", orderId)
    .maybeSingle();

  if (error) {
    console.error("[dinein-api] order status lookup failed", error);
    throw new HttpError(500, "Could not load the order.");
  }

  const record = asRecord(data);
  const venueId = stringValue(record.venue_id);
  const status = stringValue(record.status);
  if (!venueId || !status) {
    throw new HttpError(404, "Order not found.", { code: "order_not_found" });
  }

  return { venueId, status };
}

function orderReceiptSecret(): string {
  const primary = optionalEnv("DINEIN_ORDER_RECEIPT_SECRET");
  if (primary) return primary;
  const venueSecret = optionalEnv("DINEIN_VENUE_SESSION_SECRET");
  if (venueSecret) {
    console.warn(
      "[dinein-api] WARN: DINEIN_ORDER_RECEIPT_SECRET not set, falling back to DINEIN_VENUE_SESSION_SECRET.",
    );
    return venueSecret;
  }
  console.warn(
    "[dinein-api] WARN: DINEIN_ORDER_RECEIPT_SECRET and DINEIN_VENUE_SESSION_SECRET not set, falling back to DINEIN_ADMIN_SESSION_SECRET.",
  );
  return getEnv("DINEIN_ADMIN_SESSION_SECRET");
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
  applyString("email");
  applyString("website_url");
  applyString("reservation_url");
  applyString("revolut_url");
  applyString("wifi_ssid");
  applyString("wifi_password");

  if ("phone" in updates) {
    const phone = stringValue(updates.phone);
    sanitized.phone = phone ? normalizePhone(phone) : null;
  }

  if ("wifi_security" in updates || "wifiSecurity" in updates) {
    const raw = stringValue(updates.wifi_security ?? updates.wifiSecurity);
    if (raw) {
      const allowed = new Set(["WPA", "WEP", "Open"]);
      if (!allowed.has(raw)) {
        throw new HttpError(400, `Unsupported wifi_security: ${raw}`);
      }
      sanitized.wifi_security = raw;
    } else {
      sanitized.wifi_security = null;
    }
  }

  if ("wifiSsid" in updates) {
    sanitized.wifi_ssid = stringValue(updates.wifiSsid) ?? null;
  }

  if ("wifiPassword" in updates) {
    sanitized.wifi_password = stringValue(updates.wifiPassword) ?? null;
  }

  if ("image_url" in updates || "imageUrl" in updates) {
    const imageUrl = stringValue(updates.image_url ?? updates.imageUrl) ?? null;
    sanitized.image_url = imageUrl;

    if (imageUrl) {
      sanitized.image_source = "manual";
      sanitized.image_status = "ready";
      sanitized.image_model = null;
      sanitized.image_prompt = null;
      sanitized.image_error = null;
      sanitized.image_generated_at = null;
      sanitized.image_storage_path = null;
      sanitized.image_locked = true;
    } else {
      sanitized.image_source = null;
      sanitized.image_status = "pending";
      sanitized.image_model = null;
      sanitized.image_prompt = null;
      sanitized.image_error = null;
      sanitized.image_generated_at = null;
      sanitized.image_storage_path = null;
      sanitized.image_locked = false;
    }
  }

  if ("image_locked" in updates || "imageLocked" in updates) {
    const imageLocked = booleanValue(
      updates.image_locked ?? updates.imageLocked,
    );
    if (imageLocked != undefined) sanitized.image_locked = imageLocked;
  }

  if ("websiteUrl" in updates) {
    sanitized.website_url = stringValue(updates.websiteUrl) ?? null;
  }

  if ("reservationUrl" in updates) {
    sanitized.reservation_url = stringValue(updates.reservationUrl) ?? null;
  }

  if ("revolutUrl" in updates) {
    sanitized.revolut_url = stringValue(updates.revolutUrl) ?? null;
  }

  if ("opening_hours" in updates) {
    sanitized.opening_hours = updates.opening_hours ?? null;
  }

  if ("social_links" in updates || "socialLinks" in updates) {
    sanitized.social_links = asRecord(
      updates.social_links ?? updates.socialLinks ?? {},
    );
  }

  if ("status" in updates) {
    const rawStatus = requireString(updates, "status");
    const status = rawStatus == "pending_claim"
      ? "pending_activation"
      : rawStatus;
    const allowedStatuses = allowAdminFields
      ? venueStatuses
      : new Set(["active", "inactive"]);
    if (!allowedStatuses.has(status)) {
      throw new HttpError(400, `Unsupported venue status: ${status}`);
    }
    sanitized.status = status;
  }

  if (allowAdminFields) {
    if (
      "supported_payment_methods" in updates ||
      "supportedPaymentMethods" in updates
    ) {
      sanitized.supported_payment_methods =
        normalizeVenueSupportedPaymentMethods(
          updates.supported_payment_methods ?? updates.supportedPaymentMethods,
          updates.revolut_url ?? updates.revolutUrl,
        );
    }

    if ("ordering_enabled" in updates || "orderingEnabled" in updates) {
      const orderingEnabled = booleanValue(
        updates.ordering_enabled ?? updates.orderingEnabled,
      );
      if (orderingEnabled == undefined) {
        throw new HttpError(
          400,
          "A valid ordering_enabled flag is required.",
        );
      }
      sanitized.ordering_enabled = orderingEnabled;
    }

    if (
      "google_closed_override_enabled" in updates ||
      "googleClosedOverrideEnabled" in updates
    ) {
      const overrideEnabled = booleanValue(
        updates.google_closed_override_enabled ??
          updates.googleClosedOverrideEnabled,
      );
      if (overrideEnabled == undefined) {
        throw new HttpError(
          400,
          "A valid google_closed_override_enabled flag is required.",
        );
      }
      sanitized.google_closed_override_enabled = overrideEnabled;
    }

    if ("country" in updates) {
      sanitized.country = normalizeCountryCode(updates.country);
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

function publicVenueListPayload(
  rawVenue: unknown,
  options?: { distanceKm?: number | null },
): JsonRecord {
  const venue = asRecord(rawVenue);
  const readiness = venueOrderingReadiness(venue);
  return {
    id: stringValue(venue.id) ?? "",
    name: stringValue(venue.name) ?? "",
    slug: stringValue(venue.slug) ?? "",
    category: stringValue(venue.category) ?? "restaurant",
    description: stringValue(venue.description) ?? "",
    address: stringValue(venue.address) ?? "",
    phone: effectiveVenuePhone(venue),
    email: stringValue(venue.email) ?? null,
    image_url: stringValue(venue.image_url) ?? null,
    status: stringValue(venue.status) ?? "active",
    ordering_enabled: (booleanValue(venue.ordering_enabled) ?? false) &&
      readiness.ready,
    supported_payment_methods: readiness.supportedPaymentMethods,
    rating: numberValue(venue.rating) ?? 0,
    rating_count: numberValue(venue.rating_count) ?? 0,
    google_maps_uri: stringValue(venue.google_maps_uri) ?? null,
    google_location: venue.google_location ?? null,
    google_price_level: stringValue(venue.google_price_level) ?? null,
    google_review_summary: stringValue(venue.google_review_summary) ?? null,
    google_place_summary: stringValue(venue.google_place_summary) ?? null,
    enrichment_status: stringValue(venue.enrichment_status) ?? null,
    last_enriched_at: stringValue(venue.last_enriched_at) ?? null,
    enrichment_confidence: numberValue(venue.enrichment_confidence) ?? null,
    distance_km: options?.distanceKm ?? null,
    country: stringValue(venue.country) ?? "MT",
  };
}

function publicVenueDetailPayload(rawVenue: unknown): JsonRecord {
  const venue = asRecord(rawVenue);
  return {
    ...publicVenueListPayload(venue),
    opening_hours: venue.opening_hours ?? null,
    website_url: stringValue(venue.website_url) ?? null,
    reservation_url: stringValue(venue.reservation_url) ?? null,
    revolut_url: stringValue(venue.revolut_url) ?? null,
    social_links: venue.social_links ?? null,
    reviews: venue.reviews ?? null,
    wifi_ssid: stringValue(venue.wifi_ssid) ?? null,
    wifi_password: stringValue(venue.wifi_password) ?? null,
    wifi_security: stringValue(venue.wifi_security) ?? null,
  };
}

function venueStatus(rawVenue: unknown): string {
  const status = stringValue(asRecord(rawVenue).status) ?? "active";
  return status === "pending_claim" ? "pending_activation" : status;
}

function venueOrderingEnabled(rawVenue: unknown): boolean {
  return booleanValue(asRecord(rawVenue).ordering_enabled) ?? false;
}

function venueSupportedPaymentMethods(rawVenue: unknown): string[] {
  return venueOrderingReadiness(rawVenue).supportedPaymentMethods;
}

function isGuestVisibleVenue(rawVenue: unknown): boolean {
  return publicVenueStatuses.has(venueStatus(rawVenue));
}

function venueCoordinates(rawVenue: unknown): {
  latitude: number | null;
  longitude: number | null;
} {
  const venue = asRecord(rawVenue);
  const location = asRecord(venue.google_location);
  return {
    latitude: numberValue(location.latitude) ?? numberValue(location.lat) ??
      null,
    longitude: numberValue(location.longitude) ?? numberValue(location.lng) ??
      null,
  };
}

function venueDistanceKm(
  rawVenue: unknown,
  latitude: number,
  longitude: number,
): number | null {
  const coordinates = venueCoordinates(rawVenue);
  if (coordinates.latitude == null || coordinates.longitude == null) {
    return null;
  }

  const toRadians = (value: number) => value * (Math.PI / 180);
  const earthRadiusKm = 6371;
  const deltaLatitude = toRadians(coordinates.latitude - latitude);
  const deltaLongitude = toRadians(coordinates.longitude - longitude);
  const startLatitude = toRadians(latitude);
  const endLatitude = toRadians(coordinates.latitude);

  const a = Math.sin(deltaLatitude / 2) ** 2 +
    Math.cos(startLatitude) *
      Math.cos(endLatitude) *
      Math.sin(deltaLongitude / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return earthRadiusKm * c;
}

function venueMatchesQuery(rawVenue: unknown, query: string): boolean {
  const venue = asRecord(rawVenue);
  if (!query) return true;
  const haystack = [
    stringValue(venue.name),
    stringValue(venue.category),
    stringValue(venue.description),
    stringValue(venue.address),
    stringValue(venue.google_place_summary),
    stringValue(venue.google_review_summary),
  ]
    .filter((value): value is string => Boolean(value))
    .join(" ")
    .toLowerCase();

  return haystack.includes(query);
}

function canVenueAcceptGuestOrders(rawVenue: unknown): boolean {
  return venueOrderingEnabled(rawVenue) &&
    venueOrderingReadiness(rawVenue).ready;
}

function publicMenuItemPayload(
  rawItem: unknown,
  { hidePrice = false }: { hidePrice?: boolean } = {},
): JsonRecord {
  const item = asRecord(rawItem);
  return {
    ...item,
    price: hidePrice ? 0 : numberValue(item.price) ?? 0,
    price_hidden: hidePrice,
  };
}

async function hasPrivateVenueAccess(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  venueId: string,
  venueSession: unknown,
): Promise<boolean> {
  if (decodeJwtRole(req.headers.get("Authorization")) == "service_role") {
    return true;
  }

  if (await adminUserId(supabase, req)) {
    return true;
  }

  try {
    await authorizeVenueSession(req, supabase, venueSession, venueId);
    return true;
  } catch {
    return false;
  }
}

function decodeBase64Bytes(value: string): Uint8Array {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  const binary = atob(padded);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

function sanitizeStorageFileName(fileName: string): string {
  const sanitized = fileName
    .trim()
    .replaceAll(/[^a-zA-Z0-9._-]+/g, "-")
    .replaceAll(/-+/g, "-");
  return sanitized.length == 0 ? "menu-upload" : sanitized;
}

function normalizeHighlightRank(
  value: unknown,
  { allowNull = false }: { allowNull?: boolean } = {},
): number | null | undefined {
  if (value === null) {
    return allowNull ? null : undefined;
  }

  const rank = numberValue(value);
  if (rank == undefined) {
    return undefined;
  }

  const rounded = Math.round(rank);
  if (rounded < 1 || rounded > 3) {
    throw new HttpError(400, "Highlight rank must be between 1 and 3.");
  }

  return rounded;
}

function sanitizeMenuItemInsert(
  rawItem: unknown,
  venueId?: string,
): JsonRecord {
  const item = asRecord(rawItem);
  const name = requireString(item, "name");
  const description = stringValue(item.description) ?? "";
  const category = stringValue(item.category) ?? "Uncategorized";
  const tags = Array.isArray(item.tags)
    ? item.tags.map((tag) => stringValue(tag)).filter((tag): tag is string =>
      Boolean(tag)
    )
    : [];
  const sanitized: JsonRecord = {
    venue_id: venueId ?? requireString(item, "venue_id", "venueId"),
    name,
    description,
    price: numberValue(item.price),
    category,
    image_url: stringValue(item.image_url) ?? stringValue(item.imageUrl) ??
      null,
    is_available: booleanValue(item.is_available) ?? true,
    tags,
  };

  if (sanitized.price == undefined) {
    throw new HttpError(400, "A valid price is required.");
  }

  const explicitClass = normalizeMenuItemClass(item.class);
  if (item.class != undefined && item.class != null && !explicitClass) {
    throw new HttpError(400, "Menu item class must be food or drinks.");
  }

  sanitized.class = explicitClass ?? inferMenuItemClass({
    name,
    category,
    description,
    tags,
    class: null,
  });

  const sortOrder = numberValue(item.sort_order);
  if (sortOrder != undefined) sanitized.sort_order = Math.round(sortOrder);

  if ("highlight_rank" in item || "highlightRank" in item) {
    const rawHighlightRank = "highlight_rank" in item
      ? item.highlight_rank
      : item.highlightRank;
    const highlightRank = normalizeHighlightRank(
      rawHighlightRank,
      { allowNull: true },
    );
    if (highlightRank !== undefined) {
      sanitized.highlight_rank = highlightRank;
    }
  }

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

  if ("class" in updates) {
    const normalizedClass = normalizeMenuItemClass(updates.class);
    if (
      updates.class != undefined &&
      updates.class != null &&
      !normalizedClass
    ) {
      throw new HttpError(400, "Menu item class must be food or drinks.");
    }
    if (normalizedClass) sanitized.class = normalizedClass;
  }

  const sortOrder = numberValue(updates.sort_order);
  if (sortOrder != undefined) sanitized.sort_order = Math.round(sortOrder);

  if ("highlight_rank" in updates || "highlightRank" in updates) {
    const rawHighlightRank = "highlight_rank" in updates
      ? updates.highlight_rank
      : updates.highlightRank;
    const highlightRank = normalizeHighlightRank(
      rawHighlightRank,
      { allowNull: true },
    );
    if (highlightRank !== undefined) {
      sanitized.highlight_rank = highlightRank;
    }
  }

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
    menuItemResearchModels: (
      Deno.env.get("GEMINI_MENU_ITEM_MODELS") ??
        "gemini-3-flash-preview,gemini-2.5-flash"
    )
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean),
    menuImageVerifierModels: (
      Deno.env.get("GEMINI_MENU_IMAGE_VERIFIER_MODELS") ??
        "gemini-2.5-flash,gemini-2.5-flash-lite"
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

function normalizeMenuImageAuditLimit(value: unknown): number {
  const parsed = numberValue(value);
  if (parsed == undefined || !Number.isFinite(parsed)) return 5;
  return Math.max(1, Math.min(10, Math.floor(parsed)));
}

function normalizeOffset(value: unknown): number {
  const parsed = numberValue(value);
  if (parsed == undefined || !Number.isFinite(parsed)) return 0;
  return Math.max(0, Math.floor(parsed));
}

async function loadMenuItemsForImageAudit(
  supabase: ReturnType<typeof adminClient>,
  args: {
    venueId?: string;
    itemIds?: string[];
    limit: number;
    offset: number;
  },
): Promise<{ items: MenuItemRecord[]; totalCount: number }> {
  let query = supabase
    .from("dinein_menu_items")
    .select(
      "id, venue_id, name, description, category, class, menu_context, menu_context_status, menu_context_error, menu_context_model, menu_context_attempts, menu_context_locked, menu_context_updated_at, image_url, image_source, image_status, image_model, image_prompt, image_error, image_attempts, image_locked, image_storage_path, tags",
      { count: "exact" },
    )
    .order("updated_at", { ascending: false, nullsFirst: false })
    .order("id", { ascending: true })
    .range(args.offset, args.offset + args.limit - 1);

  if (args.venueId) {
    query = query.eq("venue_id", args.venueId);
  }

  if ((args.itemIds?.length ?? 0) > 0) {
    query = query.in("id", args.itemIds ?? []);
  }

  const { data, error, count } = await query;
  if (error) {
    console.error("[dinein-api] menu image audit lookup failed", error);
    throw new HttpError(500, "Could not load menu items for image audit.");
  }

  return {
    items: (data ?? []) as MenuItemRecord[],
    totalCount: count ?? 0,
  };
}

async function loadMenuItemForImageGeneration(
  supabase: ReturnType<typeof adminClient>,
  venueId: string,
  itemId: string,
): Promise<MenuItemRecord> {
  const { data, error } = await supabase
    .from("dinein_menu_items")
    .select(
      "id, venue_id, name, description, category, class, menu_context, menu_context_status, menu_context_error, menu_context_model, menu_context_attempts, menu_context_locked, menu_context_updated_at, image_url, image_source, image_status, image_model, image_prompt, image_error, image_attempts, image_locked, image_storage_path, tags",
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

export function sanitizeOrderInsert(
  rawOrder: unknown,
  userId?: string | null,
): JsonRecord {
  const order = asRecord(rawOrder);
  const paymentMethod = normalizePaymentMethod(
    order.payment_method ?? order.paymentMethod,
  );
  const requestedUserId = stringValue(order.user_id) ??
    stringValue(order.userId);
  if (requestedUserId && !userId) {
    throw new HttpError(
      403,
      "Authenticated session required to attach an order to a user account.",
      { code: "user_id_auth_required" },
    );
  }
  if (requestedUserId && userId && requestedUserId != userId) {
    throw new HttpError(
      403,
      "Order user does not match the authenticated session.",
      { code: "user_id_mismatch" },
    );
  }

  const tableNumber = stringValue(order.table_number) ??
    stringValue(order.tableNumber);
  if (!tableNumber) {
    throw new HttpError(
      400,
      "Table number is required to place a dine-in order.",
      { code: "table_number_required" },
    );
  }

  return {
    venue_id: requireString(order, "venue_id", "venueId"),
    venue_name: stringValue(order.venue_name) ?? stringValue(order.venueName) ??
      null,
    user_id: userId ?? requestedUserId ?? null,
    user_name: stringValue(order.user_name) ?? stringValue(order.userName) ??
      null,
    items: sanitizeOrderItems(order.items),
    status: "placed",
    payment_method: paymentMethod,
    payment_status: orderPaymentStatusForMethod(paymentMethod),
    table_number: tableNumber,
    special_requests: stringValue(order.special_requests) ??
      stringValue(order.specialRequests) ??
      null,
  };
}

async function uniqueOrderInsert(
  supabase: ReturnType<typeof adminClient>,
  order: JsonRecord,
): Promise<JsonRecord> {
  for (let attempt = 0; attempt < 10; attempt += 1) {
    const { data, error } = await supabase
      .from("dinein_orders")
      .insert({
        ...order,
        order_number: generateOrderNumber(),
      })
      .select("*")
      .single();

    if (!error && data) {
      return asRecord(data);
    }

    if (error?.code != "23505") {
      console.error("[dinein-api] place order failed", error);
      throw new HttpError(500, "Could not place the order.");
    }
  }

  throw new HttpError(
    409,
    "Could not allocate a unique order number. Please try again.",
  );
}

export async function handleCreateProfile(
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

export async function handleGetUserRole(
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

export async function handleTrackGuestEvent(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const eventName = requireString(body, "eventName", "event_name");
  const sessionId = requireString(body, "sessionId", "session_id");
  const user = await currentUser(req);

  const insert: JsonRecord = {
    country: requestCountryCode(body),
    event_name: eventName,
    session_id: sessionId,
    route: stringValue(body.route) ?? null,
    venue_id: stringValue(body.venueId ?? body.venue_id) ?? null,
    menu_item_id: stringValue(body.menuItemId ?? body.menu_item_id) ?? null,
    order_id: stringValue(body.orderId ?? body.order_id) ?? null,
    user_id: user?.id ?? null,
    user_agent: req.headers.get("user-agent") ?? null,
    referrer: req.headers.get("referer") ?? null,
    details: asRecord(body.details ?? body.metadata ?? body.properties),
  };

  const { error } = await supabase
    .from("dinein_guest_analytics_events")
    .insert(insert);

  if (error) {
    console.error("[dinein-api] track guest event failed", error);
    throw new HttpError(500, "Could not record the analytics event.");
  }

  return ok(true, 201);
}

export async function handleGetVenues(
  supabase: ReturnType<typeof adminClient>,
  body: JsonRecord,
): Promise<Response> {
  const countryCode = requestCountryCode(body);
  const limit = normalizeListLimit(body.limit);
  const offset = normalizeListOffset(body.offset);
  const query = (stringValue(body.query) ?? "").toLowerCase();
  const category = stringValue(body.category)?.toLowerCase();
  const orderingOnly = booleanValue(body.ordering_only ?? body.orderingOnly) ??
    false;
  const includeSummary = booleanValue(
    body.include_summary ?? body.includeSummary,
  ) ?? false;
  const latitude = numberValue(body.latitude ?? body.lat);
  const longitude = numberValue(body.longitude ?? body.lng);
  const { data, error } = await supabase
    .from("dinein_venues")
    .select("*")
    .eq("country", countryCode);

  if (error) {
    console.error("[dinein-api] get venues failed", error);
    throw new HttpError(500, "Could not load venues.");
  }

  // Filter visibility in application code so the guest list works against
  // both the current text-status schema and legacy deployments that still use
  // enum-backed status values.
  const venues = (data ?? [])
    .filter((venue) => isGuestVisibleVenue(venue))
    .filter((venue) => venueMatchesQuery(venue, query))
    .filter((venue) => {
      if (!category || category == "all") return true;
      return (stringValue(asRecord(venue).category) ?? "").toLowerCase() ==
        category;
    })
    .filter((venue) => !orderingOnly || canVenueAcceptGuestOrders(venue))
    .sort((left, right) => {
      if (latitude != null && longitude != null) {
        const leftDistance = venueDistanceKm(left, latitude, longitude);
        const rightDistance = venueDistanceKm(right, latitude, longitude);
        if (leftDistance == null && rightDistance != null) return 1;
        if (leftDistance != null && rightDistance == null) return -1;
        if (leftDistance != null && rightDistance != null) {
          const distanceCompare = leftDistance - rightDistance;
          if (distanceCompare != 0) return distanceCompare;
        }
      }

      const orderableCompare = Number(canVenueAcceptGuestOrders(right)) -
        Number(canVenueAcceptGuestOrders(left));
      if (orderableCompare != 0) return orderableCompare;

      const ratingCompare = (numberValue(right.rating) ?? 0) -
        (numberValue(left.rating) ?? 0);
      if (ratingCompare != 0) return ratingCompare;

      const ratingCountCompare = (numberValue(right.rating_count) ?? 0) -
        (numberValue(left.rating_count) ?? 0);
      if (ratingCountCompare != 0) return ratingCountCompare;

      return (stringValue(left.name) ?? "").localeCompare(
        stringValue(right.name) ?? "",
      );
    });
  const visible = limit == null ? venues : venues.slice(offset, offset + limit);
  const items = visible.map((venue) =>
    publicVenueListPayload(venue, {
      distanceKm: latitude != null && longitude != null
        ? venueDistanceKm(venue, latitude, longitude)
        : null,
    })
  );

  if (includeSummary) {
    const categories = [...new Set(venues
      .map((venue) => stringValue(asRecord(venue).category)?.trim() ?? "")
      .filter((value) => value.length > 0))]
      .sort((left, right) => left.localeCompare(right))
      .slice(0, 8);

    return ok({
      items,
      categories,
      total_count: venues.length,
      has_more: limit != null ? offset + visible.length < venues.length : false,
    });
  }

  return ok(items);
}

export async function handleGetAllVenues(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  await requireAdmin(supabase, req);
  const countryCode = requestCountryCode(body);

  const limit = normalizeListLimit(body.limit);
  const offset = normalizeListOffset(body.offset);
  let query = supabase
    .from("dinein_venues")
    .select("*")
    .eq("country", countryCode)
    .order("created_at", { ascending: false });
  if (limit != null) {
    query = query.range(offset, offset + limit - 1);
  }
  const { data, error } = await query;

  if (error) {
    console.error("[dinein-api] get all venues failed", error);
    throw new HttpError(500, "Could not load venues.");
  }

  return ok(data ?? []);
}

export async function handleCreateVenue(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  await requireAdmin(supabase, req);

  const venuePayload = asRecord(body.venue);
  const payload = Object.keys(venuePayload).length == 0 ? body : venuePayload;
  const updates = sanitizeVenueUpdates(payload, true);
  const name = stringValue(updates.name);
  if (!name) {
    throw new HttpError(400, "Venue name is required.");
  }

  const slug = await ensureUniqueVenueSlug(
    supabase,
    stringValue(updates.slug) ?? name,
  );

  const insert: JsonRecord = {
    name,
    slug,
    category: stringValue(updates.category) ?? "restaurant",
    description: stringValue(updates.description) ?? "",
    address: stringValue(updates.address) ?? "",
    email: stringValue(updates.email) ?? null,
    image_url: stringValue(updates.image_url) ?? null,
    revolut_url: stringValue(updates.revolut_url) ?? null,
    website_url: stringValue(updates.website_url) ?? null,
    reservation_url: stringValue(updates.reservation_url) ?? null,
    opening_hours: updates.opening_hours ?? null,
    social_links: updates.social_links ?? {},
    phone: stringValue(updates.phone) ?? null,
    owner_contact_phone: stringValue(updates.phone) ?? null,
    owner_whatsapp_number: stringValue(updates.phone) ?? null,
    normalized_access_phone: stringValue(updates.phone) ?? null,
    status: stringValue(updates.status) ?? "inactive",
    ordering_enabled: booleanValue(updates.ordering_enabled) ?? false,
    country: normalizeCountryCode(
      updates.country ?? payload.country ?? payload.country_code,
    ),
    owner_id: stringValue(updates.owner_id) ?? null,
    wifi_ssid: stringValue(updates.wifi_ssid) ?? null,
    wifi_password: stringValue(updates.wifi_password) ?? null,
    wifi_security: stringValue(updates.wifi_security) ?? null,
    supported_payment_methods: Array.isArray(updates.supported_payment_methods)
      ? updates.supported_payment_methods
      : ["cash"],
  };

  const { data, error } = await supabase
    .from("dinein_venues")
    .insert(insert)
    .select("*")
    .single();

  if (error) {
    console.error("[dinein-api] create venue failed", error);
    throw new HttpError(500, "Could not create the venue.");
  }

  return ok(data, 201);
}

export async function handleGetVenueBySlug(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const slug = requireString(body, "slug");
  const countryCode = requestCountryCode(body);

  const { data, error } = await supabase
    .from("dinein_venues")
    .select("*")
    .eq("country", countryCode)
    .eq("slug", slug)
    .maybeSingle();

  if (error) {
    console.error("[dinein-api] get venue by slug failed", error);
    throw new HttpError(500, "Could not load the venue.");
  }

  if (!data) {
    return ok(null);
  }

  const venue = asRecord(data);
  const venueId = stringValue(venue.id);
  if (!venueId) {
    return ok(null);
  }

  const canReadPrivate = await hasPrivateVenueAccess(
    supabase,
    req,
    venueId,
    body.venue_session,
  );
  if (!canReadPrivate && !isGuestVisibleVenue(venue)) {
    return ok(null);
  }
  return ok(canReadPrivate ? venue : publicVenueDetailPayload(venue));
}

export async function handleGetVenueById(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const venueId = requireString(body, "venueId", "venue_id");
  const countryCode = requestCountryCode(body);

  const { data, error } = await supabase
    .from("dinein_venues")
    .select("*")
    .eq("country", countryCode)
    .eq("id", venueId)
    .maybeSingle();

  if (error) {
    console.error("[dinein-api] get venue by id failed", error);
    throw new HttpError(500, "Could not load the venue.");
  }

  if (!data) {
    return ok(null);
  }

  const venue = asRecord(data);
  const canReadPrivate = await hasPrivateVenueAccess(
    supabase,
    req,
    venueId,
    body.venue_session,
  );
  if (!canReadPrivate && !isGuestVisibleVenue(venue)) {
    return ok(null);
  }
  return ok(canReadPrivate ? venue : publicVenueDetailPayload(venue));
}

export async function handleGetVenueForOwner(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const ownerId = requireString(body, "ownerId", "owner_id");
  const countryCode = requestCountryCode(body);
  await requireSelfOrAdmin(supabase, req, ownerId);

  const { data, error } = await supabase
    .from("dinein_venues")
    .select("*")
    .eq("country", countryCode)
    .eq("owner_id", ownerId)
    .maybeSingle();

  if (error) {
    console.error("[dinein-api] get venue for owner failed", error);
    throw new HttpError(500, "Could not load the venue.");
  }

  return ok(data ?? null);
}

export async function handleUpdateVenue(
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
  const adminActorId = mode == "admin"
    ? (decodeJwtRole(req.headers.get("Authorization")) == "service_role"
      ? "service_role"
      : await requireAdmin(supabase, req))
    : null;

  const updates = sanitizeVenueUpdates(body.updates, mode == "admin");
  if (mode == "venue") {
    delete updates.phone;
  }
  if ("slug" in updates) {
    updates.slug = await ensureUniqueVenueSlug(
      supabase,
      requireString(updates, "slug"),
      venueId,
    );
  }
  if (Object.keys(updates).length == 0) {
    return ok(true);
  }

  const currentVenue = mode == "admin" || "status" in updates
    ? await venueSnapshot(supabase, venueId)
    : null;

  if (mode == "admin") {
    const persistedVenue = currentVenue ??
      await venueSnapshot(supabase, venueId);
    if ("phone" in updates) {
      const nextAccessPhone = stringValue(updates.phone);
      const previousAccessPhone = normalizedVenueAccessPhone(persistedVenue);
      const accessPhoneChanged = nextAccessPhone != previousAccessPhone;

      if (nextAccessPhone && accessPhoneChanged) {
        await ensureUniqueVenueAccessPhone(
          supabase,
          nextAccessPhone,
          venueId,
        );
      }

      updates.owner_contact_phone = nextAccessPhone;
      updates.owner_whatsapp_number = nextAccessPhone;
      updates.normalized_access_phone = nextAccessPhone;
      updates.access_number_updated_at = new Date().toISOString();
      updates.access_number_updated_by = adminActorId;

      if (!nextAccessPhone || accessPhoneChanged) {
        updates.access_verified_at = null;
        updates.access_verification_method = null;
        updates.access_verified_by = null;
        updates.access_verification_note = null;
        updates.last_access_token_issued_at = null;
      }
    }

    const nextVenue = { ...persistedVenue, ...updates };
    const readiness = venueOrderingReadiness(nextVenue);
    const explicitEnable = updates.ordering_enabled === true;

    if (explicitEnable && !readiness.ready) {
      throw new HttpError(
        409,
        "Venue is not ready to accept guest orders.",
        {
          code: "venue_not_order_ready",
          readiness_reasons: readiness.reasons,
        },
      );
    }

    if (
      (booleanValue(persistedVenue.ordering_enabled) ?? false) &&
      !readiness.ready
    ) {
      updates.ordering_enabled = false;
    }
  }

  if (mode == "venue" && currentVenue != null && "status" in updates) {
    const nextStatus = stringValue(updates.status) ?? venueStatus(currentVenue);
    if (nextStatus != "active") {
      updates.ordering_enabled = false;
    } else {
      const readiness = venueOrderingReadiness({
        ...currentVenue,
        ...updates,
        status: "active",
        ordering_enabled: true,
      });
      updates.ordering_enabled = readiness.ready;
    }
  }

  const { data, error } = await supabase
    .from("dinein_venues")
    .update(updates)
    .eq("id", venueId)
    .select("*")
    .maybeSingle();

  if (error) {
    console.error("[dinein-api] update venue failed", error);
    if (error.code == "23505") {
      throw new HttpError(
        409,
        "This WhatsApp number is already assigned to another venue.",
        { code: "venue_access_phone_in_use" },
      );
    }
    if (error.code == "23514") {
      throw new HttpError(
        409,
        "Venue is not ready to accept guest orders.",
        {
          code: "venue_not_order_ready",
          readiness_reasons: String(error.details ?? "")
            .split(",")
            .map((value) => value.trim())
            .filter(Boolean),
        },
      );
    }
    throw new HttpError(500, "Could not update the venue.");
  }

  return ok(data ?? true);
}

export async function handleGetMenuItems(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const venueId = requireString(body, "venueId", "venue_id");
  const { data: venueData, error: venueError } = await supabase
    .from("dinein_venues")
    .select("*")
    .eq("id", venueId)
    .maybeSingle();

  if (venueError) {
    console.error(
      "[dinein-api] get menu items venue lookup failed",
      venueError,
    );
    throw new HttpError(500, "Could not load the venue.");
  }

  const venue = asRecord(venueData);
  if (!stringValue(venue.id)) {
    throw new HttpError(404, "Venue not found.");
  }

  const canReadPrivate = await hasPrivateVenueAccess(
    supabase,
    req,
    venueId,
    body.venue_session,
  );
  if (!canReadPrivate && !isGuestVisibleVenue(venue)) {
    throw new HttpError(404, "Venue not found.");
  }

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

  const visibleItems = canReadPrivate
    ? (data ?? [])
    : (data ?? []).filter((item) =>
      booleanValue(asRecord(item).is_available) ?? true
    );
  const hidePrice = !canReadPrivate && !canVenueAcceptGuestOrders(venue);
  return ok(
    visibleItems.map((item) => publicMenuItemPayload(item, { hidePrice })),
  );
}

export async function handleGetMenuItemById(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const itemId = requireString(body, "itemId", "item_id", "id");
  const { data, error } = await supabase
    .from("dinein_menu_items")
    .select("*")
    .eq("id", itemId)
    .maybeSingle();

  if (error) {
    console.error("[dinein-api] get menu item by id failed", error);
    throw new HttpError(500, "Could not load menu item.");
  }

  const item = asRecord(data);
  const venueId = stringValue(item.venue_id);
  if (!venueId) {
    throw new HttpError(404, "Menu item not found.");
  }

  const { data: venueData, error: venueError } = await supabase
    .from("dinein_venues")
    .select("*")
    .eq("id", venueId)
    .maybeSingle();

  if (venueError) {
    console.error(
      "[dinein-api] get menu item by id venue lookup failed",
      venueError,
    );
    throw new HttpError(500, "Could not load the venue.");
  }

  const venue = asRecord(venueData);
  if (!stringValue(venue.id)) {
    throw new HttpError(404, "Menu item not found.");
  }

  const canReadPrivate = await hasPrivateVenueAccess(
    supabase,
    req,
    venueId,
    body.venue_session,
  );
  if (!canReadPrivate && !isGuestVisibleVenue(venue)) {
    throw new HttpError(404, "Menu item not found.");
  }

  const isAvailable = booleanValue(item.is_available) ?? true;
  if (!canReadPrivate && !isAvailable) {
    throw new HttpError(404, "Menu item not found.");
  }

  const hidePrice = !canReadPrivate && !canVenueAcceptGuestOrders(venue);
  return ok(publicMenuItemPayload(item, { hidePrice }));
}

export async function handleGetAdminMenuQueue(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
): Promise<Response> {
  await requireAdmin(supabase, req);

  const { data, error } = await supabase
    .from("dinein_menu_items")
    .select(
      "venue_id, category, is_available, image_status, menu_context_status, updated_at, venue:dinein_venues!inner(id, name, image_url, address, category, status)",
    )
    .or("admin_managed.is.false,admin_managed.is.null")
    .order("updated_at", { ascending: false });

  if (error) {
    console.error("[dinein-api] get admin menu queue failed", error);
    throw new HttpError(500, "Could not load the admin menu queue.");
  }

  type QueueAccumulator = {
    venueId: string;
    venueName: string;
    venueImageUrl: string | null;
    venueAddress: string;
    venueCategory: string;
    venueStatus: string;
    totalItems: number;
    availableItems: number;
    pendingReviewCount: number;
    failedReviewCount: number;
    readyCount: number;
    categories: Set<string>;
    lastUpdatedAt: string | null;
  };

  const queue = new Map<string, QueueAccumulator>();

  for (const rawRow of data ?? []) {
    const row = asRecord(rawRow);
    const venue = asRecord(row.venue);
    const venueId = stringValue(row.venue_id) ?? stringValue(venue.id);
    if (!venueId) continue;

    const existing = queue.get(venueId) ?? {
      venueId,
      venueName: stringValue(venue.name) ?? "Venue",
      venueImageUrl: stringValue(venue.image_url) ?? null,
      venueAddress: stringValue(venue.address) ?? "",
      venueCategory: stringValue(venue.category) ?? "",
      venueStatus: stringValue(venue.status) ?? "active",
      totalItems: 0,
      availableItems: 0,
      pendingReviewCount: 0,
      failedReviewCount: 0,
      readyCount: 0,
      categories: new Set<string>(),
      lastUpdatedAt: null,
    };

    existing.totalItems += 1;
    if (booleanValue(row.is_available) ?? true) {
      existing.availableItems += 1;
    }

    const reviewStatus = stringValue(row.menu_context_status) ??
      (stringValue(row.image_status) == "ready" ? "ready" : "pending");
    switch (reviewStatus) {
      case "ready":
        existing.readyCount += 1;
        break;
      case "failed":
        existing.failedReviewCount += 1;
        break;
      default:
        existing.pendingReviewCount += 1;
        break;
    }

    const category = stringValue(row.category);
    if (category) {
      existing.categories.add(category);
    }

    const updatedAt = stringValue(row.updated_at);
    if (
      updatedAt &&
      (!existing.lastUpdatedAt || updatedAt > existing.lastUpdatedAt)
    ) {
      existing.lastUpdatedAt = updatedAt;
    }

    queue.set(venueId, existing);
  }

  const items = Array.from(queue.values())
    .map((entry) => ({
      venue_id: entry.venueId,
      venue_name: entry.venueName,
      venue_image_url: entry.venueImageUrl,
      venue_address: entry.venueAddress,
      venue_category: entry.venueCategory,
      venue_status: entry.venueStatus,
      total_items: entry.totalItems,
      available_items: entry.availableItems,
      pending_review_count: entry.pendingReviewCount,
      failed_review_count: entry.failedReviewCount,
      ready_count: entry.readyCount,
      category_count: entry.categories.size,
      last_updated_at: entry.lastUpdatedAt,
    }))
    .sort((a, b) => {
      const aNeedsReview = a.pending_review_count > 0 ||
        a.failed_review_count > 0;
      const bNeedsReview = b.pending_review_count > 0 ||
        b.failed_review_count > 0;
      if (aNeedsReview != bNeedsReview) {
        return aNeedsReview ? -1 : 1;
      }
      return (b.last_updated_at ?? "").localeCompare(a.last_updated_at ?? "");
    });

  return ok(items);
}

export async function handleGetAdminMenuCatalog(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
): Promise<Response> {
  await requireAdmin(supabase, req);

  const { data, error } = await supabase
    .from("dinein_menu_items")
    .select(
      "id, venue_id, admin_group_id, name, description, category, class, image_url, image_source, image_status, image_locked, tags, updated_at, venue:dinein_venues!inner(status)",
    )
    .eq("admin_managed", true)
    .not("admin_group_id", "is", null)
    .order("updated_at", { ascending: false });

  if (error) {
    console.error("[dinein-api] get admin menu catalog failed", error);
    throw new HttpError(500, "Could not load the admin menu catalog.");
  }

  type CatalogAccumulator = {
    groupId: string;
    representativeItemId: string;
    representativeVenueId: string;
    name: string;
    description: string;
    category: string;
    itemClass: string | null;
    imageUrl: string | null;
    imageSource: string | null;
    imageStatus: string | null;
    imageLocked: boolean;
    tags: string[];
    assignedVenueCount: number;
    assignedActiveVenueCount: number;
    lastUpdatedAt: string | null;
  };

  const catalog = new Map<string, CatalogAccumulator>();
  for (const rawRow of data ?? []) {
    const row = asRecord(rawRow);
    const groupId = stringValue(row.admin_group_id);
    if (!groupId) continue;
    const venue = asRecord(row.venue);
    const updatedAt = stringValue(row.updated_at) ?? null;
    const existing = catalog.get(groupId);
    if (!existing) {
      catalog.set(groupId, {
        groupId,
        representativeItemId: stringValue(row.id) ?? "",
        representativeVenueId: stringValue(row.venue_id) ?? "",
        name: stringValue(row.name) ?? "",
        description: stringValue(row.description) ?? "",
        category: stringValue(row.category) ?? "Uncategorized",
        itemClass: stringValue(row.class) ?? null,
        imageUrl: stringValue(row.image_url) ?? null,
        imageSource: stringValue(row.image_source) ?? null,
        imageStatus: stringValue(row.image_status) ?? "pending",
        imageLocked: booleanValue(row.image_locked) ?? false,
        tags: normalizeStringList(row.tags),
        assignedVenueCount: 1,
        assignedActiveVenueCount: stringValue(venue.status) == "active" ? 1 : 0,
        lastUpdatedAt: updatedAt,
      });
      continue;
    }

    existing.assignedVenueCount += 1;
    if (stringValue(venue.status) == "active") {
      existing.assignedActiveVenueCount += 1;
    }
    if (
      updatedAt &&
      (!existing.lastUpdatedAt ||
        updatedAt.localeCompare(existing.lastUpdatedAt) > 0)
    ) {
      existing.representativeItemId = stringValue(row.id) ??
        existing.representativeItemId;
      existing.representativeVenueId = stringValue(row.venue_id) ??
        existing.representativeVenueId;
      existing.name = stringValue(row.name) ?? existing.name;
      existing.description = stringValue(row.description) ??
        existing.description;
      existing.category = stringValue(row.category) ?? existing.category;
      existing.itemClass = stringValue(row.class) ?? existing.itemClass;
      existing.imageUrl = stringValue(row.image_url) ?? existing.imageUrl;
      existing.imageSource = stringValue(row.image_source) ??
        existing.imageSource;
      existing.imageStatus = stringValue(row.image_status) ??
        existing.imageStatus;
      existing.imageLocked = booleanValue(row.image_locked) ??
        existing.imageLocked;
      existing.tags = normalizeStringList(row.tags);
      existing.lastUpdatedAt = updatedAt;
    }
  }

  return ok(
    Array.from(catalog.values()).sort((left, right) =>
      (right.lastUpdatedAt ?? "").localeCompare(left.lastUpdatedAt ?? "")
    ).map((entry) => ({
      group_id: entry.groupId,
      representative_item_id: entry.representativeItemId,
      representative_venue_id: entry.representativeVenueId,
      name: entry.name,
      description: entry.description,
      category: entry.category,
      class: entry.itemClass,
      image_url: entry.imageUrl,
      image_source: entry.imageSource,
      image_status: entry.imageStatus,
      image_locked: entry.imageLocked,
      tags: entry.tags,
      assigned_venue_count: entry.assignedVenueCount,
      assigned_active_venue_count: entry.assignedActiveVenueCount,
      last_updated_at: entry.lastUpdatedAt,
    })),
  );
}

export async function handleGetAdminMenuGroupAssignments(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  await requireAdmin(supabase, req);
  const groupId = requireString(body, "groupId", "group_id");

  const { data, error } = await supabase
    .from("dinein_menu_items")
    .select(
      "id, admin_group_id, price, is_available, updated_at, venue:dinein_venues!inner(id, name, slug, status, ordering_enabled)",
    )
    .eq("admin_group_id", groupId)
    .order("updated_at", { ascending: false });

  if (error) {
    console.error("[dinein-api] get admin menu assignments failed", error);
    throw new HttpError(500, "Could not load menu assignments.");
  }

  return ok(
    (data ?? []).map((row) => {
      const record = asRecord(row);
      const venue = asRecord(record.venue);
      return {
        item_id: stringValue(record.id) ?? "",
        group_id: stringValue(record.admin_group_id) ?? groupId,
        venue_id: stringValue(venue.id) ?? "",
        venue_name: stringValue(venue.name) ?? "Venue",
        venue_slug: stringValue(venue.slug) ?? "",
        venue_status: stringValue(venue.status) ?? "active",
        ordering_enabled: booleanValue(venue.ordering_enabled) ?? false,
        price: numberValue(record.price) ?? 0,
        is_available: booleanValue(record.is_available) ?? false,
        updated_at: stringValue(record.updated_at) ?? null,
      };
    }),
  );
}

export async function handleCreateAdminMenuGroups(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  await requireAdmin(supabase, req);

  const rawItems = Array.isArray(body.items)
    ? body.items
    : (body.item ? [body.item] : []);
  if (rawItems.length == 0) {
    throw new HttpError(400, "At least one menu item is required.");
  }

  const venueIds = await resolveAdminAssignmentVenueIds(supabase, body);
  const inserts: JsonRecord[] = [];
  const groupIds: string[] = [];

  for (const rawItem of rawItems) {
    const draft = sanitizeAdminManagedMenuDraft(rawItem);
    const groupId = crypto.randomUUID();
    groupIds.push(groupId);
    for (const venueId of venueIds) {
      inserts.push({
        venue_id: venueId,
        admin_group_id: groupId,
        admin_managed: true,
        name: stringValue(draft.name) ?? "",
        description: stringValue(draft.description) ?? "",
        category: stringValue(draft.category) ?? "Uncategorized",
        class: stringValue(draft.class) ?? null,
        image_url: stringValue(draft.image_url) ?? null,
        image_source: stringValue(draft.image_source) ?? null,
        image_status: stringValue(draft.image_status) ?? "pending",
        image_model: null,
        image_prompt: null,
        image_error: null,
        image_generated_at: null,
        image_locked: booleanValue(draft.image_locked) ?? false,
        image_storage_path: null,
        image_attempts: 0,
        price: 0,
        is_available: false,
        tags: Array.isArray(draft.tags) ? draft.tags : [],
      });
    }
  }

  const { error } = await supabase.from("dinein_menu_items").insert(inserts);
  if (error) {
    console.error("[dinein-api] create admin menu groups failed", error);
    throw new HttpError(500, "Could not create the admin menu items.");
  }

  return ok({
    created_groups: groupIds.length,
    assigned_venues: venueIds.length,
    group_ids: groupIds,
  }, 201);
}

export async function handleAssignAdminMenuGroup(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  await requireAdmin(supabase, req);
  const groupId = requireString(body, "groupId", "group_id");
  const venueIds = await resolveAdminAssignmentVenueIds(supabase, body);
  const seed = await adminManagedMenuGroupSeed(supabase, groupId);

  const { data: existingRows, error: existingError } = await supabase
    .from("dinein_menu_items")
    .select("venue_id")
    .eq("admin_group_id", groupId)
    .in("venue_id", venueIds);

  if (existingError) {
    console.error(
      "[dinein-api] assign admin menu group lookup failed",
      existingError,
    );
    throw new HttpError(500, "Could not validate existing menu assignments.");
  }

  const existingVenueIds = new Set(
    (existingRows ?? [])
      .map((row) => stringValue(asRecord(row).venue_id))
      .filter((value): value is string => Boolean(value)),
  );
  const missingVenueIds = venueIds.filter((venueId) =>
    !existingVenueIds.has(venueId)
  );

  if (missingVenueIds.length == 0) {
    return ok({
      group_id: groupId,
      assigned_count: 0,
      total_count: venueIds.length,
    });
  }

  const inserts = missingVenueIds.map((venueId) => ({
    venue_id: venueId,
    admin_group_id: groupId,
    admin_managed: true,
    name: stringValue(seed.name) ?? "",
    description: stringValue(seed.description) ?? "",
    category: stringValue(seed.category) ?? "Uncategorized",
    class: stringValue(seed.class) ?? null,
    image_url: stringValue(seed.image_url) ?? null,
    image_source: stringValue(seed.image_source) ?? null,
    image_status: stringValue(seed.image_status) ?? "pending",
    image_model: stringValue(seed.image_model) ?? null,
    image_prompt: stringValue(seed.image_prompt) ?? null,
    image_error: stringValue(seed.image_error) ?? null,
    image_generated_at: stringValue(seed.image_generated_at) ?? null,
    image_locked: booleanValue(seed.image_locked) ?? false,
    image_storage_path: stringValue(seed.image_storage_path) ?? null,
    image_attempts: numberValue(seed.image_attempts) ?? 0,
    price: 0,
    is_available: false,
    tags: normalizeStringList(seed.tags),
  }));

  const { error } = await supabase.from("dinein_menu_items").insert(inserts);
  if (error) {
    console.error("[dinein-api] assign admin menu group failed", error);
    throw new HttpError(500, "Could not assign the menu item to venues.");
  }

  return ok({
    group_id: groupId,
    assigned_count: missingVenueIds.length,
    total_count: venueIds.length,
  });
}

export async function handleDeleteAdminMenuGroup(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  await requireAdmin(supabase, req);
  const groupId = requireString(body, "groupId", "group_id");

  const { error } = await supabase
    .from("dinein_menu_items")
    .delete()
    .eq("admin_group_id", groupId);

  if (error) {
    console.error("[dinein-api] delete admin menu group failed", error);
    throw new HttpError(500, "Could not delete the admin menu item.");
  }

  return ok(true);
}

export async function handleToggleMenuItemAvailability(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const itemId = requireString(body, "itemId", "item_id");
  const venueId = await menuItemVenueId(supabase, itemId);
  const mode = await authorizeVenueMutation(
    supabase,
    req,
    venueId,
    body.venue_session,
  );
  if (mode == "admin" && !isServiceRoleRequest(req)) {
    throw new HttpError(
      403,
      "Admin cannot change venue-specific availability. Venue teams control this field.",
    );
  }

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

export async function handleCreateMenuItem(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const item = sanitizeMenuItemInsert(body.item);
  const venueId = requireString(item, "venue_id");
  const mode = await authorizeVenueMutation(
    supabase,
    req,
    venueId,
    body.venue_session,
  );
  if (mode == "admin" && !isServiceRoleRequest(req)) {
    throw new HttpError(
      403,
      "Admin menu creation must use the centralized assignment flow.",
    );
  }

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

export async function handleUpdateMenuItem(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const itemId = requireString(body, "itemId", "item_id");
  const venueId = await menuItemVenueId(supabase, itemId);
  const mode = await authorizeVenueMutation(
    supabase,
    req,
    venueId,
    body.venue_session,
  );
  const snapshot = mode == "admin"
    ? await menuItemAdminSnapshot(supabase, itemId)
    : null;

  const updates = mode == "admin"
    ? sanitizeAdminMenuUpdates(body.updates)
    : sanitizeMenuItemUpdates(body.updates);
  if (Object.keys(updates).length == 0) {
    return ok(true);
  }

  if (mode == "admin") {
    const groupId = stringValue(snapshot?.admin_group_id);
    if (groupId) {
      await syncAdminManagedGroupSharedFields(supabase, groupId, updates);
      const refreshed = await adminManagedMenuGroupSeed(supabase, groupId);
      return ok(refreshed);
    }
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

export async function handleDeleteMenuItem(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const itemId = requireString(body, "itemId", "item_id");
  const venueId = await menuItemVenueId(supabase, itemId);
  const mode = await authorizeVenueMutation(
    supabase,
    req,
    venueId,
    body.venue_session,
  );
  if (mode == "admin" && !isServiceRoleRequest(req)) {
    throw new HttpError(
      403,
      "Admin deletion must use the centralized menu group flow.",
    );
  }

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

export async function handleSetMenuItemHighlights(
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
  if (mode == "admin" && !isServiceRoleRequest(req)) {
    throw new HttpError(
      403,
      "Admin cannot change venue-specific highlight ordering.",
    );
  }

  const rawItemIds = Array.isArray(body.itemIds)
    ? body.itemIds
    : Array.isArray(body.item_ids)
    ? body.item_ids
    : [];
  const itemIds = rawItemIds
    .map((value) => stringValue(value)?.trim() ?? "")
    .filter(Boolean)
    .filter((value, index, values) => values.indexOf(value) == index);

  if (itemIds.length > 3) {
    throw new HttpError(400, "You can select at most 3 highlighted items.");
  }

  if (itemIds.length > 0) {
    const { data: existingItems, error: validateError } = await supabase
      .from("dinein_menu_items")
      .select("id")
      .eq("venue_id", venueId)
      .in("id", itemIds);

    if (validateError) {
      console.error(
        "[dinein-api] validate menu item highlights failed",
        validateError,
      );
      throw new HttpError(500, "Could not validate highlighted menu items.");
    }

    if ((existingItems ?? []).length != itemIds.length) {
      throw new HttpError(
        400,
        "Highlighted items must belong to the current venue.",
      );
    }
  }

  const { error: clearError } = await supabase
    .from("dinein_menu_items")
    .update({ highlight_rank: null })
    .eq("venue_id", venueId);

  if (clearError) {
    console.error("[dinein-api] clear menu item highlights failed", clearError);
    throw new HttpError(500, "Could not reset highlighted menu items.");
  }

  for (const [index, itemId] of itemIds.entries()) {
    const { error: updateError } = await supabase
      .from("dinein_menu_items")
      .update({ highlight_rank: index + 1 })
      .eq("venue_id", venueId)
      .eq("id", itemId);

    if (updateError) {
      console.error(
        "[dinein-api] set menu item highlight failed",
        updateError,
      );
      throw new HttpError(500, "Could not update highlighted menu items.");
    }
  }

  const { data, error } = await supabase
    .from("dinein_menu_items")
    .select("*")
    .eq("venue_id", venueId)
    .order("highlight_rank", { ascending: true, nullsFirst: false })
    .order("sort_order", { ascending: true })
    .order("created_at", { ascending: true });

  if (error) {
    console.error("[dinein-api] reload menu item highlights failed", error);
    throw new HttpError(500, "Could not reload the updated menu items.");
  }

  return ok(data ?? []);
}

export async function handleGenerateMenuItemImage(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const itemId = requireString(body, "itemId", "item_id");
  const forceRegenerate = booleanValue(body.forceRegenerate) ?? false;
  const venueSession = asRecord(body.venue_session);
  const venueId = stringValue(venueSession.venue_id) ??
    requireString(body, "venueId", "venue_id");
  const mode = await authorizeVenueMutation(
    supabase,
    req,
    venueId,
    body.venue_session,
  );
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

  if (mode == "admin") {
    const snapshot = await menuItemAdminSnapshot(supabase, itemId);
    const groupId = stringValue(snapshot.admin_group_id);
    if (groupId) {
      await syncAdminManagedGroupImageFields(supabase, groupId, itemId);
    }
  }

  return ok(result);
}

export async function handleBackfillMenuImages(
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
      "id, venue_id, name, description, category, class, menu_context, menu_context_status, menu_context_error, menu_context_model, menu_context_attempts, menu_context_locked, menu_context_updated_at, image_url, image_source, image_status, image_model, image_prompt, image_error, image_attempts, image_locked, image_storage_path, tags",
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

export async function handleAuditMenuItemImages(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const venueId = stringValue(body.venueId) ?? stringValue(body.venue_id);
  const itemIds = Array.from(
    new Set(
      normalizeStringList(body.itemIds ?? body.item_ids).map((value) =>
        value.trim()
      ).filter(Boolean),
    ),
  );
  const limit = normalizeMenuImageAuditLimit(body.limit);
  const offset = normalizeOffset(body.offset);
  const regenerateMismatches = booleanValue(body.regenerateMismatches) ??
    booleanValue(body.regenerate_mismatches) ?? false;
  const regenerateManual = booleanValue(body.regenerateManual) ??
    booleanValue(body.regenerate_manual) ?? false;
  const forceRefreshContext = booleanValue(body.forceRefreshContext) ??
    booleanValue(body.force_refresh_context) ?? false;

  let mode: "admin" | "venue" = "admin";
  if (venueId) {
    mode = await authorizeVenueMutation(
      supabase,
      req,
      venueId,
      body.venue_session,
    );
  } else if (!isServiceRoleRequest(req)) {
    await requireAdmin(supabase, req);
  }

  const imageClient = supabase as unknown as ReturnType<
    typeof createMenuImageAdminClient
  >;
  const env = menuImageEnv();
  const { items, totalCount } = await loadMenuItemsForImageAudit(supabase, {
    venueId: venueId ?? undefined,
    itemIds,
    limit,
    offset,
  });
  const venueCache = new Map<string, VenueRecord>();
  const results: JsonRecord[] = [];

  let cleanCount = 0;
  let warningCount = 0;
  let mismatchCount = 0;
  let needsRegenerationCount = 0;
  let regeneratedCount = 0;
  let blockedCount = 0;

  for (const item of items) {
    let venue = venueCache.get(item.venue_id);
    if (!venue) {
      venue = await loadVenueForImageGeneration(supabase, item.venue_id);
      venueCache.set(item.venue_id, venue);
    }

    const audit = await auditMenuItemImage({
      adminClient: imageClient,
      env,
      item,
      venue,
      forceRefreshContext,
      regenerateMismatch: regenerateMismatches,
      regenerateManual,
    });

    switch (audit.auditStatus) {
      case "clean":
        cleanCount += 1;
        break;
      case "warning":
        warningCount += 1;
        break;
      case "mismatch":
        mismatchCount += 1;
        break;
    }

    if (audit.needsRegeneration) {
      needsRegenerationCount += 1;
    }

    if (audit.regenerationResult?.status === "success") {
      regeneratedCount += 1;
      if (mode === "admin") {
        const snapshot = await menuItemAdminSnapshot(supabase, audit.itemId);
        const groupId = stringValue(snapshot.admin_group_id);
        if (groupId) {
          await syncAdminManagedGroupImageFields(
            supabase,
            groupId,
            audit.itemId,
          );
        }
      }
    } else if (audit.regenerationBlockedReason) {
      blockedCount += 1;
    }

    results.push(audit as unknown as JsonRecord);
  }

  return ok({
    total_count: totalCount,
    offset,
    limit,
    has_more: offset + items.length < totalCount,
    summary: {
      clean_count: cleanCount,
      warning_count: warningCount,
      mismatch_count: mismatchCount,
      needs_regeneration_count: needsRegenerationCount,
      regenerated_count: regeneratedCount,
      blocked_count: blockedCount,
    },
    items: results,
  });
}

export async function handleEnrichVenueProfile(
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
  const generateProfileImage = booleanValue(
    body.generateProfileImage ?? body.generate_profile_image,
  ) ?? true;
  const forceImageRegenerate = booleanValue(
    body.forceImageRegenerate ?? body.force_image_regenerate,
  ) ?? false;
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

  let profileImageResult: JsonRecord | null = null;
  let profileImageError: string | null = null;
  try {
    profileImageResult = await maybeGenerateVenueProfileImageAfterEnrichment(
      supabase,
      venueId,
      {
        generateProfileImage,
        forceImageRegenerate,
        forceGroundingRefresh: false,
        skipSearchGrounding,
      },
    );
  } catch (error) {
    profileImageError = error instanceof Error ? error.message : String(error);
  }

  return ok({
    ...(result as unknown as JsonRecord),
    ...(profileImageResult == null ? {} : {
      profile_image: profileImageResult,
      profileImage: profileImageResult,
    }),
    ...(profileImageError == null ? {} : {
      profile_image_error: profileImageError,
      profileImageError,
    }),
  });
}

export async function handleBackfillVenueProfiles(
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
  const generateProfileImage = booleanValue(
    body.generateProfileImage ?? body.generate_profile_image,
  ) ?? true;
  const forceImageRegenerate = booleanValue(
    body.forceImageRegenerate ?? body.force_image_regenerate,
  ) ?? false;
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
  let imagesGenerated = 0;
  let imagesSkipped = 0;
  let imagesFailed = 0;

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
      let profileImageResult: JsonRecord | null = null;
      let profileImageError: string | null = null;
      try {
        profileImageResult =
          await maybeGenerateVenueProfileImageAfterEnrichment(
            supabase,
            venue.id,
            {
              generateProfileImage,
              forceImageRegenerate,
              forceGroundingRefresh: false,
              skipSearchGrounding,
            },
          );
        if (profileImageResult == null) {
          imagesSkipped += 1;
        } else if (stringValue(profileImageResult.status) == "success") {
          imagesGenerated += 1;
        } else {
          imagesSkipped += 1;
        }
      } catch (error) {
        imagesFailed += 1;
        profileImageError = error instanceof Error
          ? error.message
          : String(error);
      }

      results.push({
        ...(result as unknown as JsonRecord),
        ...(profileImageResult == null ? {} : {
          profile_image: profileImageResult,
          profileImage: profileImageResult,
        }),
        ...(profileImageError == null ? {} : {
          profile_image_error: profileImageError,
          profileImageError,
        }),
      });
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
    images_generated: imagesGenerated,
    imagesGenerated,
    images_skipped: imagesSkipped,
    imagesSkipped,
    images_failed: imagesFailed,
    imagesFailed,
    results,
  });
}

export async function handleGenerateVenueProfileImage(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const venueId = requireString(body, "venueId", "venue_id");
  const isPrivileged = decodeJwtRole(req.headers.get("Authorization")) ==
      "service_role" || isVenueProfileImageCronInvocation(req);
  if (!isPrivileged) {
    await authorizeVenueMutation(supabase, req, venueId, body.venue_session);
  }

  const forceRegenerate = booleanValue(body.forceRegenerate) ?? false;
  const forceGroundingRefresh = booleanValue(body.forceGroundingRefresh) ??
    false;
  const skipSearchGrounding = booleanValue(body.skipSearchGrounding) ?? false;
  const imageClient = supabase as unknown as ReturnType<
    typeof createVenueProfileImageAdminClient
  >;
  const venue = await fetchVenueForEnrichment(
    imageClient as unknown as ReturnType<
      typeof createVenueEnrichmentAdminClient
    >,
    venueId,
  );

  const result = await processVenueProfileImageGeneration({
    adminClient: imageClient,
    env: getVenueProfileImageEnv(),
    venue,
    forceRegenerate,
    forceGroundingRefresh,
    skipSearchGrounding,
  });

  return ok(result);
}

export async function handleBackfillVenueProfileImages(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const venueId = stringValue(body.venueId) ?? stringValue(body.venue_id) ??
    null;
  const isServiceRole =
    decodeJwtRole(req.headers.get("Authorization")) == "service_role";
  const isCron = isVenueProfileImageCronInvocation(req);
  if (venueId) {
    if (!isServiceRole && !isCron) {
      await authorizeVenueMutation(supabase, req, venueId, body.venue_session);
    }
  } else if (!isServiceRole && !isCron) {
    await requireAdmin(supabase, req);
  }

  const forceRegenerate = booleanValue(body.forceRegenerate) ?? false;
  const forceGroundingRefresh = booleanValue(body.forceGroundingRefresh) ??
    false;
  const skipSearchGrounding = booleanValue(body.skipSearchGrounding) ?? false;
  const limit = normalizeVenueProfileImageLimit(body.limit);
  const imageClient = supabase as unknown as ReturnType<
    typeof createVenueProfileImageAdminClient
  >;
  const venues = venueId
    ? [
      await fetchVenueForEnrichment(
        imageClient as unknown as ReturnType<
          typeof createVenueEnrichmentAdminClient
        >,
        venueId,
      ),
    ]
    : await loadVenuesForVenueImageBackfill(
      imageClient,
      limit,
      forceRegenerate,
    );

  const results: JsonRecord[] = [];
  let generated = 0;
  let skipped = 0;
  let failed = 0;

  for (const venue of venues) {
    try {
      const result = await processVenueProfileImageGeneration({
        adminClient: imageClient,
        env: getVenueProfileImageEnv(),
        venue,
        forceRegenerate,
        forceGroundingRefresh,
        skipSearchGrounding,
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
    generated,
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

async function loadVenuesForVenueImageBackfill(
  supabase: ReturnType<typeof createVenueProfileImageAdminClient>,
  limit: number,
  forceRegenerate: boolean,
): Promise<EnrichmentVenueRecord[]> {
  const scanLimit = Math.max(limit * 5, limit);
  const { data, error } = await supabase
    .from("dinein_venues")
    .select("*")
    .eq("image_locked", false)
    .order("last_enriched_at", { ascending: false })
    .limit(Math.min(100, scanLimit));

  if (error) {
    console.error("[dinein-api] venue image backfill lookup failed", error);
    throw new HttpError(
      500,
      "Could not load venues for profile image backfill.",
    );
  }

  return ((data ?? []) as EnrichmentVenueRecord[])
    .filter((venue) =>
      !isVenueEnrichmentInFlight(venue) &&
      !isVenueProfileImageGenerationInFlight(venue) &&
      venueNeedsProfileImageGeneration(venue, forceRegenerate)
    )
    .slice(0, limit);
}

async function maybeGenerateVenueProfileImageAfterEnrichment(
  supabase: ReturnType<typeof adminClient>,
  venueId: string,
  options?: {
    generateProfileImage?: boolean;
    forceImageRegenerate?: boolean;
    forceGroundingRefresh?: boolean;
    skipSearchGrounding?: boolean;
  },
): Promise<JsonRecord | null> {
  if (options?.generateProfileImage === false) {
    return null;
  }

  const imageClient = supabase as unknown as ReturnType<
    typeof createVenueProfileImageAdminClient
  >;
  const venue = await fetchVenueForEnrichment(
    imageClient as unknown as ReturnType<
      typeof createVenueEnrichmentAdminClient
    >,
    venueId,
  );

  if (
    !shouldGenerateAiVenueProfileImage(venue) &&
    !(options?.forceImageRegenerate ?? false)
  ) {
    return null;
  }

  const imageSource = stringValue(venue.image_source) ?? null;
  const hasImage = Boolean(stringValue(venue.image_url));
  const shouldForceRegenerate = (options?.forceImageRegenerate ?? false) ||
    (hasImage && imageSource != "ai_gemini" && imageSource != "manual");

  const result = await processVenueProfileImageGeneration({
    adminClient: imageClient,
    env: getVenueProfileImageEnv(),
    venue,
    forceRegenerate: shouldForceRegenerate,
    forceGroundingRefresh: options?.forceGroundingRefresh ?? false,
    skipSearchGrounding: options?.skipSearchGrounding ?? false,
  });

  return result as unknown as JsonRecord;
}

export async function handleSearchGoogleMaps(
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const query = requireString(body, "query").trim();
  if (query.length < 2) {
    return ok([]);
  }

  const geminiApiKey = optionalEnv("GEMINI_API_KEY");
  if (!geminiApiKey) {
    return ok([]);
  }

  const nowMs = Date.now();
  const searchSubjectKey = googleMapsSearchRateLimitKey(req);
  await assertRateLimit(
    adminClient(),
    searchSubjectKey,
    GOOGLE_MAPS_SEARCH_RATE_LIMIT,
    nowMs,
  );
  await recordRateLimit(
    adminClient(),
    searchSubjectKey,
    GOOGLE_MAPS_SEARCH_RATE_LIMIT,
    nowMs,
  );

  const country = countryLabel(requestCountryCode(body));
  const models = (
    Deno.env.get("GEMINI_VENUE_MODELS") ??
      "gemini-2.5-flash,gemini-2.5-flash-lite"
  ).split(",").map((value) => value.trim()).filter(Boolean);

  const prompt = [
    "You are searching for hospitality venues on Google Maps.",
    "Use only grounded Google Maps results from the built-in googleMaps tool.",
    "Never invent venues, ratings, phone numbers, or addresses.",
    "",
    `Search query: ${query}`,
    `Country: ${country}`,
    "",
    "Return up to 5 venues as a JSON array.",
    "Each venue should include name, address, category, rating, ratingCount, phone, website, placeId, and googleMapsUri when available.",
    "Return only valid JSON.",
  ].join("\n");

  for (const model of models) {
    try {
      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${
          encodeURIComponent(model)
        }:generateContent`,
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
      if (!response.ok) {
        continue;
      }

      const json = asRecord(await response.json());
      const candidate = asRecord((json.candidates as unknown[] ?? [])[0]);
      const content = asRecord(candidate.content);
      const parts = (content.parts as unknown[] | undefined) ?? [];
      const text = parts
        .map((part) => stringValue(asRecord(part).text))
        .filter((value): value is string => Boolean(value))
        .join("\n")
        .trim();
      if (!text) {
        continue;
      }

      const cleaned = text
        .replace(/```(?:json)?\s*/gi, "")
        .replace(/```/g, "")
        .trim();
      try {
        const parsed = JSON.parse(cleaned);
        if (Array.isArray(parsed)) {
          return ok(parsed);
        }
        if (
          parsed && typeof parsed == "object" && Array.isArray(parsed.results)
        ) {
          return ok(parsed.results);
        }
        return ok([parsed]);
      } catch {
        const arrayMatch = cleaned.match(/\[[\s\S]*\]/);
        if (arrayMatch) {
          try {
            return ok(JSON.parse(arrayMatch[0]));
          } catch {
            continue;
          }
        }
      }
    } catch {
      continue;
    }
  }

  return ok([]);
}

export async function handleGetVenueNotificationSettings(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const venueId = requireString(body, "venueId", "venue_id");
  await authorizeVenueMutation(supabase, req, venueId, body.venue_session);
  return ok(await venueNotificationSettingsSnapshot(supabase, venueId));
}

export async function handleUpdateVenueNotificationSettings(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const venueId = requireString(body, "venueId", "venue_id");
  await authorizeVenueMutation(supabase, req, venueId, body.venue_session);

  const settings = await upsertVenueNotificationSettings(
    supabase,
    venueId,
    body.settings ?? body,
  );
  await syncVenuePushRegistrationFlags(
    supabase,
    venueId,
    booleanValue(settings.order_push_enabled) ?? true,
  );
  return ok(settings);
}

export async function handleRegisterPushDevice(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const venueId = requireString(body, "venueId", "venue_id");
  await authorizeVenueMutation(supabase, req, venueId, body.venue_session);

  const deviceKey = requireString(body, "deviceKey", "device_key");
  const pushToken = sanitizePushToken(body.pushToken ?? body.push_token);
  const platform = normalizePushPlatform(body.platform);
  const settings = await venueNotificationSettingsSnapshot(supabase, venueId);
  const notificationsEnabled =
    booleanValue(body.notificationsEnabled ?? body.notifications_enabled) ??
      (booleanValue(settings.order_push_enabled) ?? true);
  const contactPhone = await resolveVenueNotificationContactPhone(
    supabase,
    venueId,
    body,
  );

  const cleanupByToken = await supabase
    .from("dinein_push_registrations")
    .delete()
    .eq("push_token", pushToken);
  if (cleanupByToken.error) {
    console.error(
      "[dinein-api] push registration token cleanup failed",
      cleanupByToken.error,
    );
    throw new HttpError(500, "Could not register the push device.");
  }

  const cleanupByDevice = await supabase
    .from("dinein_push_registrations")
    .delete()
    .eq("device_key", deviceKey)
    .neq("venue_id", venueId);
  if (cleanupByDevice.error) {
    console.error(
      "[dinein-api] push registration device cleanup failed",
      cleanupByDevice.error,
    );
    throw new HttpError(500, "Could not register the push device.");
  }

  const now = new Date().toISOString();
  const { data, error } = await supabase
    .from("dinein_push_registrations")
    .upsert(
      {
        venue_id: venueId,
        contact_phone: contactPhone,
        device_key: deviceKey,
        push_token: pushToken,
        platform,
        provider: "fcm",
        notifications_enabled: notificationsEnabled,
        app_version: stringValue(body.appVersion) ??
          stringValue(body.app_version) ??
          null,
        locale: stringValue(body.locale) ?? null,
        time_zone: stringValue(body.timeZone) ??
          stringValue(body.time_zone) ??
          null,
        last_seen_at: now,
      },
      { onConflict: "venue_id,device_key" },
    )
    .select(
      "id, venue_id, device_key, push_token, platform, notifications_enabled, last_seen_at",
    )
    .single();

  if (error) {
    console.error("[dinein-api] register push device failed", error);
    throw new HttpError(500, "Could not register the push device.");
  }

  return ok(asRecord(data));
}

export async function handleUnregisterPushDevice(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const venueId = requireString(body, "venueId", "venue_id");
  await authorizeVenueMutation(supabase, req, venueId, body.venue_session);

  const deviceKey = stringValue(body.deviceKey) ?? stringValue(body.device_key);
  const pushToken = stringValue(body.pushToken) ?? stringValue(body.push_token);
  if (!deviceKey && !pushToken) {
    throw new HttpError(
      400,
      "Device key or push token is required to unregister a push device.",
    );
  }

  let query = supabase
    .from("dinein_push_registrations")
    .delete()
    .eq("venue_id", venueId);
  query = deviceKey ? query.eq("device_key", deviceKey) : query.eq(
    "push_token",
    pushToken!,
  );

  const { error } = await query;
  if (error) {
    console.error("[dinein-api] unregister push device failed", error);
    throw new HttpError(500, "Could not unregister the push device.");
  }

  return ok(true);
}

async function bellRequestVenueId(
  supabase: ReturnType<typeof adminClient>,
  requestId: string,
): Promise<string> {
  const { data, error } = await supabase
    .from("bell_requests")
    .select("venue_id")
    .eq("id", requestId)
    .maybeSingle();
  if (error) {
    console.error("[dinein-api] bell request venue lookup failed", error);
    throw new HttpError(500, "Could not load the bell request.");
  }

  const venueId = stringValue(asRecord(data ?? {}).venue_id);
  if (!venueId) {
    throw new HttpError(404, "Bell request not found.");
  }
  return venueId;
}

export async function handleSendWave(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const venueId = requireString(body, "venueId", "venue_id");
  const tableNumber = normalizeWaveTableNumber(
    body.tableNumber ?? body.table_number,
  );

  // Verify the venue exists and is active before accepting a wave
  const { data: venueCheck, error: venueCheckError } = await supabase
    .from("dinein_venues")
    .select("id, name, status")
    .eq("id", venueId)
    .maybeSingle();
  if (venueCheckError) {
    console.error("[dinein-api] wave venue check failed", venueCheckError);
    throw new HttpError(500, "Could not verify the venue.");
  }
  if (!venueCheck || stringValue(asRecord(venueCheck).status) !== "active") {
    throw new HttpError(409, "This venue is not accepting requests right now.");
  }

  const user = await currentUser(req);
  const now = new Date();
  const dedupeThreshold = new Date(now.getTime() - 30_000).toISOString();

  const { data: existing, error: existingError } = await supabase
    .from("bell_requests")
    .select("*")
    .eq("venue_id", venueId)
    .eq("table_number", tableNumber)
    .eq("status", "pending")
    .gte("created_at", dedupeThreshold)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (existingError) {
    console.error("[dinein-api] wave dedupe lookup failed", existingError);
    throw new HttpError(500, "Could not create the wave request.");
  }
  if (existing) {
    return ok(existing, 200);
  }

  const waveRateLimitSubjectKey = user == null
    ? anonymousWaveRateLimitKey(req, venueId)
    : null;
  await assertRateLimit(
    supabase,
    waveRateLimitSubjectKey,
    WAVE_RATE_LIMIT,
    now.getTime(),
  );

  const { data, error } = await supabase
    .from("bell_requests")
    .insert({
      venue_id: venueId,
      table_number: tableNumber,
      user_id: user?.id ?? null,
    })
    .select("*")
    .single();
  if (error) {
    console.error("[dinein-api] wave insert failed", error);
    throw new HttpError(500, "Could not create the wave request.");
  }

  await recordRateLimit(
    supabase,
    waveRateLimitSubjectKey,
    WAVE_RATE_LIMIT,
    now.getTime(),
  );

  try {
    await dispatchVenueOperationalAlert(
      supabase,
      venueId,
      buildBellRequestPushNotification(asRecord(venueCheck), asRecord(data)),
    );
  } catch (error) {
    console.error("[dinein-api] bell request push dispatch failed", error);
  }

  return ok(data, 201);
}

export async function handleGetBellRequests(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const venueId = requireString(body, "venueId", "venue_id");
  const status = stringValue(body.status);
  await authorizeVenueMutation(supabase, req, venueId, body.venue_session);

  let query = supabase
    .from("bell_requests")
    .select("*")
    .eq("venue_id", venueId)
    .order("created_at", { ascending: false });

  if (status == "pending" || status == "resolved") {
    query = query.eq("status", status);
  }

  const { data, error } = await query;
  if (error) {
    console.error("[dinein-api] get bell requests failed", error);
    throw new HttpError(500, "Could not load bell requests.");
  }

  return ok(data ?? []);
}

export async function handleResolveBellRequest(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const requestId = requireString(body, "requestId", "request_id");
  const venueId = await bellRequestVenueId(supabase, requestId);
  await authorizeVenueMutation(supabase, req, venueId, body.venue_session);

  const { error } = await supabase
    .from("bell_requests")
    .update({
      status: "resolved",
      resolved_at: new Date().toISOString(),
    })
    .eq("id", requestId);
  if (error) {
    console.error("[dinein-api] resolve bell request failed", error);
    throw new HttpError(500, "Could not resolve the bell request.");
  }

  return ok(true);
}

export async function handlePlaceOrder(
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
    .select("*")
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

  if (!canVenueAcceptGuestOrders(venue)) {
    throw new HttpError(
      409,
      "This venue is unavailable for guest ordering right now.",
      { code: "venue_unavailable" },
    );
  }

  if (
    stringValue(order.payment_method) == "revolut_link" &&
    !stringValue(venue.revolut_url)
  ) {
    throw new HttpError(
      409,
      "This venue has not configured Revolut payments yet.",
      { code: "revolut_unavailable" },
    );
  }

  const supportedPaymentMethods = venueSupportedPaymentMethods(venue);
  if (
    !supportedPaymentMethods.includes(stringValue(order.payment_method) ?? "")
  ) {
    throw new HttpError(
      409,
      "This venue does not support the selected payment method.",
      {
        code: "payment_method_unavailable",
        supported_payment_methods: supportedPaymentMethods,
      },
    );
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
        { code: "menu_item_unavailable", menu_item_id: item.menuItemId },
      );
    }

    if (booleanValue(menuItem.is_available) == false) {
      throw new HttpError(
        409,
        `Menu item "${
          stringValue(menuItem.name) ?? item.menuItemId
        }" is sold out.`,
        { code: "menu_item_sold_out", menu_item_id: item.menuItemId },
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

  const orderData = await uniqueOrderInsert(supabase, {
    ...order,
    items: normalizedItems,
    subtotal,
    service_fee: serviceFee,
    total,
    venue_name: stringValue(venue.name) ??
      stringValue(order.venue_name) ??
      "Venue",
  });
  const orderId = stringValue(orderData.id);
  const receiptToken = orderId
    ? await issueOrderReceiptToken(orderId, venueId)
    : null;

  try {
    await dispatchVenueOperationalAlert(
      supabase,
      venueId,
      buildNewOrderPushNotification(orderData),
    );
  } catch (error) {
    console.error("[dinein-api] order push dispatch failed", error);
  }

  try {
    await dispatchVenueWhatsAppAlert(
      supabase,
      venueId,
      `New Order #${orderData.daily_sequence_number} received! Total: €${orderData.total}`,
    );
  } catch (error) {
    console.error("[dinein-api] venue whatsapp alert dispatch failed", error);
  }

  return ok({
    ...orderData,
    venue_image_url: stringValue(venue.image_url) ?? null,
    ...(receiptToken == null ? {} : { receipt_token: receiptToken }),
  }, 201);
}

async function attachVenueImagesToOrders(
  supabase: ReturnType<typeof adminClient>,
  orders: unknown[],
): Promise<JsonRecord[]> {
  const normalizedOrders = orders.map((order) => asRecord(order));
  const venueIds = [
    ...new Set(
      normalizedOrders
        .map((order) => stringValue(order.venue_id))
        .filter((value): value is string => Boolean(value)),
    ),
  ];

  if (venueIds.length == 0) {
    return normalizedOrders;
  }

  const { data, error } = await supabase
    .from("dinein_venues")
    .select("id, image_url")
    .in("id", venueIds);

  if (error) {
    console.error("[dinein-api] order venue image lookup failed", error);
    return normalizedOrders;
  }

  const imageByVenueId = new Map<string, string | null>();
  for (const entry of (data ?? [])) {
    const venue = asRecord(entry);
    const venueId = stringValue(venue.id);
    if (!venueId) continue;
    imageByVenueId.set(venueId, stringValue(venue.image_url) ?? null);
  }

  return normalizedOrders.map((order) => {
    const venueId = stringValue(order.venue_id);
    return {
      ...order,
      venue_image_url: venueId == null
        ? stringValue(order.venue_image_url) ?? null
        : imageByVenueId.get(venueId) ??
          stringValue(order.venue_image_url) ??
          null,
    };
  });
}

export async function handleGetOrdersForVenue(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const venueId = requireString(body, "venueId", "venue_id");
  await authorizeVenueMutation(supabase, req, venueId, body.venue_session);

  const { data, error } = await supabase
    .from("dinein_orders")
    .select("*")
    .eq("venue_id", venueId)
    .order("created_at", { ascending: false });

  if (error) {
    console.error("[dinein-api] get orders for venue failed", error);
    throw new HttpError(500, "Could not load venue orders.");
  }

  return ok(await attachVenueImagesToOrders(supabase, data ?? []));
}

export async function handleGetOrdersForUser(
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

  return ok(await attachVenueImagesToOrders(supabase, data ?? []));
}

export async function handleImageHealth(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
): Promise<Response> {
  await requireAdmin(supabase, req);

  const { data, error } = await supabase
    .from("dinein_menu_items")
    .select("image_status");

  if (error) {
    console.error("[dinein-api] image health query failed", error);
    throw new HttpError(500, "Could not load image health data.");
  }

  const items = data ?? [];
  const total = items.length;
  let ready = 0;
  let pending = 0;
  let generating = 0;
  let failed = 0;

  for (const item of items) {
    switch (item.image_status) {
      case "ready":
        ready++;
        break;
      case "generating":
        generating++;
        break;
      case "failed":
        failed++;
        break;
      default:
        pending++;
        break;
    }
  }

  return ok({ total, ready, pending, generating, failed });
}

export async function handleGetAllOrders(
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

  return ok(await attachVenueImagesToOrders(supabase, data ?? []));
}

export async function handleGetOrderById(
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
    return ok((await attachVenueImagesToOrders(supabase, [data]))[0] ?? data);
  }

  if (await adminUserId(supabase, req)) {
    return ok((await attachVenueImagesToOrders(supabase, [data]))[0] ?? data);
  }

  const order = asRecord(data);
  const user = await currentUser(req);
  if (user && stringValue(order.user_id) == user.id) {
    return ok((await attachVenueImagesToOrders(supabase, [data]))[0] ?? data);
  }

  const venueClaims = await venueSessionClaims(req);
  if (
    stringValue(venueClaims?.venue_id) != undefined &&
    stringValue(venueClaims?.venue_id) == stringValue(order.venue_id)
  ) {
    return ok((await attachVenueImagesToOrders(supabase, [data]))[0] ?? data);
  }

  throw new HttpError(403, "You are not allowed to access this order.");
}

export async function handleUpdateOrderStatus(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const orderId = requireString(body, "orderId", "order_id");
  const status = requireString(body, "status");

  if (!orderStatuses.has(status)) {
    throw new HttpError(400, `Unsupported order status: ${status}`, {
      code: "unsupported_order_status",
    });
  }

  const order = await orderStatusSnapshot(supabase, orderId);
  await authorizeVenueMutation(
    supabase,
    req,
    order.venueId,
    body.venue_session,
  );
  assertValidOrderStatusTransition(order.status, status);

  if (order.status == status) {
    return ok(true);
  }

  const { error } = await supabase
    .from("dinein_orders")
    .update({ status, updated_at: new Date().toISOString() })
    .eq("id", orderId);

  if (error) {
    console.error("[dinein-api] update order status failed", error);
    throw new HttpError(500, "Could not update the order status.");
  }

  return ok(true);
}

// handleAppRequest + Deno.serve live in index.ts
