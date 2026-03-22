import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { JWT } from "npm:google-auth-library@9";
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
import {
  createVenueProfileImageAdminClient,
  getVenueProfileImageEnv,
  HttpError as VenueProfileImageHttpError,
  isVenueProfileImageGenerationInFlight,
  normalizeVenueProfileImageLimit,
  processVenueProfileImageGeneration,
  venueNeedsProfileImageGeneration,
} from "../_shared/venue-profile-image.ts";
import {
  isAllowedMenuUploadUrl,
  normalizeMenuUploadContentType,
} from "./security.ts";

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
const publicVenueStatuses = new Set([
  "active",
  "inactive",
  "maintenance",
  "pending_claim",
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

function isVenueProfileImageCronInvocation(req: Request): boolean {
  return hasMatchingSecretHeader(req, "VENUE_IMAGE_CRON_SECRET");
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

function normalizeCountryCode(
  value: unknown,
  fallback: CountryCode = "MT",
): CountryCode {
  const normalized = stringValue(value)?.toUpperCase();
  if (normalized == "RW") return "RW";
  if (normalized == "MT") return "MT";
  return fallback;
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
  if (!stringValue(venue.approved_claim_id)) {
    reasons.push("approved_claim_required");
  }
  if (!stringValue(venue.approved_at)) {
    reasons.push("approved_at_required");
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
  if (
    !(
      stringValue(venue.owner_contact_phone) ??
        stringValue(venue.owner_whatsapp_number)
    )
  ) {
    reasons.push("owner_contact_required");
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

function slugify(value: string): string {
  const base = value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");

  return base.length > 0 ? base : `venue-${Date.now()}`;
}

function normalizeVenueSearchQuery(value: unknown): string | null {
  const raw = stringValue(value);
  if (!raw) return null;
  const normalized = raw.replace(/[,%()]/g, " ").replace(/\s+/g, " ").trim();
  return normalized.length > 0 ? normalized : null;
}

function buildVenueSearchOrClause(query: string): string {
  const normalized = normalizeVenueSearchQuery(query) ?? query.trim();
  const slugTerm = slugify(normalized);
  const clauses = [
    `name.ilike.%${normalized}%`,
    `address.ilike.%${normalized}%`,
    `category.ilike.%${normalized}%`,
  ];

  if (!slugTerm.startsWith("venue-")) {
    clauses.push(`slug.ilike.%${slugTerm}%`);
  }

  return clauses.join(",");
}

function buildVenueConflictOrClause(name: string, slug: string): string {
  const normalizedName = normalizeVenueSearchQuery(name) ?? name.trim();
  return [`slug.eq.${slug}`, `name.ilike.${normalizedName}`].join(",");
}

function canonicalVenueLabel(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, " ").replace(/\s+/g, " ")
    .trim();
}

function isStrongOnboardingVenueMatch(
  query: string,
  rawVenue: unknown,
): boolean {
  const venue = asRecord(rawVenue);
  const normalizedQuery = canonicalVenueLabel(query);
  if (!normalizedQuery) return false;

  const venueName = canonicalVenueLabel(stringValue(venue.name) ?? "");
  const querySlug = slugify(query);
  const venueSlug = slugify(
    stringValue(venue.slug) ?? stringValue(venue.name) ?? "",
  );

  return venueName == normalizedQuery || venueSlug == querySlug;
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

async function onboardingMenuClaims(
  body: JsonRecord,
): Promise<JsonRecord | null> {
  const token = stringValue(body.onboardingMenuToken) ??
    stringValue(body.onboarding_menu_token);
  if (!token) return null;
  return await signedTokenClaims(token, {
    aud: "dinein-onboarding-menu",
    role: "onboarding_menu",
    secret: "DINEIN_ONBOARDING_MENU_SECRET",
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

function claimContactPhone(claim: JsonRecord): string | null {
  return stringValue(claim.contact_phone) ??
    stringValue(claim.whatsapp_number) ??
    null;
}

function claimWhatsappNumber(claim: JsonRecord): string | null {
  return stringValue(claim.whatsapp_number) ??
    stringValue(claim.contact_phone) ??
    null;
}

function venueHasLinkedAccess(row: JsonRecord): boolean {
  return Boolean(
    stringValue(row.owner_id) ?? stringValue(row.approved_claim_id),
  );
}

function effectiveVenuePhone(rawVenue: unknown): string | null {
  const venue = asRecord(rawVenue);
  return stringValue(venue.phone) ?? stringValue(venue.owner_contact_phone) ??
    stringValue(venue.owner_whatsapp_number) ?? null;
}

export function buildApprovedClaimUpdate(
  reviewedAt: string,
  reviewedBy?: string,
): JsonRecord {
  return {
    status: "approved",
    reviewed_at: reviewedAt,
    approved_at: reviewedAt,
    ...(reviewedBy ? { reviewed_by: reviewedBy } : {}),
  };
}

export function buildApprovedVenueLinkage(
  claim: JsonRecord,
  approvedAt: string,
): JsonRecord {
  const claimId = stringValue(claim.id);
  if (!claimId) {
    throw new HttpError(500, "Approved claim linkage is missing a claim id.");
  }

  const claimantId = stringValue(claim.claimant_id);
  return {
    approved_claim_id: claimId,
    approved_at: approvedAt,
    owner_contact_phone: claimContactPhone(claim),
    owner_whatsapp_number: claimWhatsappNumber(claim),
    ...(claimantId ? { owner_id: claimantId } : {}),
  };
}

export function buildClaimAccessAuditUpdate(args: {
  issuedAt: string;
  verifiedAt?: string;
  normalizedPhone?: string;
  challengeId?: string;
  verificationMethod?: string;
  verifiedBy?: string;
  verificationNote?: string | null;
}): JsonRecord {
  if (
    args.verificationMethod &&
    !accessVerificationMethods.has(args.verificationMethod)
  ) {
    throw new HttpError(
      500,
      `Unsupported access verification method: ${args.verificationMethod}`,
    );
  }
  return {
    last_access_token_issued_at: args.issuedAt,
    ...(args.verifiedAt ? { whatsapp_verified_at: args.verifiedAt } : {}),
    ...(args.normalizedPhone
      ? { last_verified_whatsapp_number: args.normalizedPhone }
      : {}),
    ...(args.challengeId ? { last_otp_challenge_id: args.challengeId } : {}),
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

export function buildVenueAccessAuditUpdate(
  claim: JsonRecord,
  args: {
    issuedAt: string;
    verifiedAt?: string;
    approvedAt?: string;
    verificationMethod?: string;
    verifiedBy?: string;
    verificationNote?: string | null;
  },
): JsonRecord {
  if (
    args.verificationMethod &&
    !accessVerificationMethods.has(args.verificationMethod)
  ) {
    throw new HttpError(
      500,
      `Unsupported access verification method: ${args.verificationMethod}`,
    );
  }
  return {
    ...buildApprovedVenueLinkage(
      claim,
      args.approvedAt ?? stringValue(claim.approved_at) ??
        stringValue(claim.reviewed_at) ?? args.issuedAt,
    ),
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

async function issueVenueToken(
  venueId: string,
  contactPhone: string,
  venueName: string,
  options?: {
    claimId?: string;
    issuedAt?: string;
  },
): Promise<{ access_token: string; issued_at: string; expires_at: string }> {
  const issuedAtDate = options?.issuedAt
    ? new Date(options.issuedAt)
    : new Date();
  const issuedAtMs = Number.isNaN(issuedAtDate.getTime())
    ? Date.now()
    : issuedAtDate.getTime();
  const now = Math.floor(issuedAtMs / 1000);
  const exp = now + VENUE_TOKEN_TTL_SECONDS;

  const header = btoa(JSON.stringify({ alg: "HS256", typ: "JWT" }))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");

  const payload = btoa(JSON.stringify({
    aud: "dinein-venue",
    sub: options?.claimId ?? venueId,
    role: "venue_owner",
    venue_id: venueId,
    phone: contactPhone,
    venue_name: venueName,
    ...(options?.claimId ? { claim_id: options.claimId } : {}),
    iat: now,
    exp,
  })).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");

  const signingInput = `${header}.${payload}`;
  const signature = await hmacSha256Base64Url(signingInput, venueTokenSecret());

  return {
    access_token: `${signingInput}.${signature}`,
    issued_at: new Date(issuedAtMs).toISOString(),
    expires_at: new Date(exp * 1000).toISOString(),
  };
}

async function verifyVenueToken(
  token: string,
): Promise<{ venueId: string; contactPhone: string; claimId?: string }> {
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
    claimId: stringValue(payload.claim_id),
  };
}

async function authorizeVenueSession(
  req: Request,
  _supabase: ReturnType<typeof adminClient>,
  rawSession: unknown,
  venueId: string,
): Promise<{ venueId: string; contactPhone: string; claimId?: string }> {
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
      claimId: stringValue(bearerClaims.claim_id),
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

async function persistApprovedVenueClaim(
  supabase: ReturnType<typeof adminClient>,
  claim: JsonRecord,
  reviewedAt: string,
  reviewedBy?: string,
): Promise<void> {
  const claimId = stringValue(claim.id);
  if (!claimId) {
    throw new HttpError(500, "Claim approval is missing a claim id.");
  }

  const { error } = await supabase
    .from("dinein_venue_claims")
    .update(buildApprovedClaimUpdate(reviewedAt, reviewedBy))
    .eq("id", claimId);

  if (error) {
    console.error("[dinein-api] approve claim failed", error);
    throw new HttpError(500, "Could not approve the claim.");
  }
}

async function persistApprovedVenueLinkage(
  supabase: ReturnType<typeof adminClient>,
  claim: JsonRecord,
  approvedAt: string,
  options?: {
    activateVenue?: boolean;
  },
): Promise<void> {
  const venueId = stringValue(claim.venue_id);
  if (!venueId) {
    throw new HttpError(500, "Approved claim is missing a venue id.");
  }

  const currentVenue = await venueSnapshot(supabase, venueId);
  const updatePayload: JsonRecord = {
    ...buildApprovedVenueLinkage(claim, approvedAt),
  };
  if (!stringValue(currentVenue.phone) && claimContactPhone(claim)) {
    updatePayload.phone = claimContactPhone(claim);
  }
  if (options?.activateVenue !== false) {
    updatePayload.status = "active";
    const nextVenue = {
      ...currentVenue,
      ...updatePayload,
      status: "active",
    };
    updatePayload.ordering_enabled = venueOrderingReadiness(nextVenue).ready;
  }

  const { error } = await supabase
    .from("dinein_venues")
    .update(updatePayload)
    .eq("id", venueId);

  if (error) {
    console.error("[dinein-api] approved venue linkage update failed", error);
    throw new HttpError(
      500,
      options?.activateVenue === false
        ? "Could not update the approved venue linkage."
        : "Claim approved but venue could not be activated.",
    );
  }
}

async function persistVenueAccessAudit(
  supabase: ReturnType<typeof adminClient>,
  claim: JsonRecord,
  args: {
    issuedAt: string;
    verifiedAt?: string;
    normalizedPhone?: string;
    challengeId?: string;
    approvedAt?: string;
    verificationMethod?: string;
    verifiedBy?: string;
    verificationNote?: string | null;
  },
): Promise<void> {
  const claimId = stringValue(claim.id);
  const venueId = stringValue(claim.venue_id);
  if (!claimId || !venueId) {
    throw new HttpError(500, "Venue access audit is missing claim linkage.");
  }

  const { error: claimError } = await supabase
    .from("dinein_venue_claims")
    .update(buildClaimAccessAuditUpdate(args))
    .eq("id", claimId);

  if (claimError) {
    console.error("[dinein-api] claim access audit update failed", claimError);
    throw new HttpError(500, "Could not record venue claim access.");
  }

  const currentVenue = await venueSnapshot(supabase, venueId);
  const venueAuditUpdate: JsonRecord = {
    ...buildVenueAccessAuditUpdate(claim, args),
  };
  if (!stringValue(currentVenue.phone) && claimContactPhone(claim)) {
    venueAuditUpdate.phone = claimContactPhone(claim);
  }

  const { error: venueError } = await supabase
    .from("dinein_venues")
    .update(venueAuditUpdate)
    .eq("id", venueId);

  if (venueError) {
    console.error("[dinein-api] venue access audit update failed", venueError);
    throw new HttpError(500, "Could not record venue access linkage.");
  }
}

async function upsertVenueOwnerProfileRole(
  supabase: ReturnType<typeof adminClient>,
  claimantId: string | undefined,
): Promise<void> {
  if (!claimantId) return;

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
    return;
  }

  if (profileData?.id) {
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
    return;
  }

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

function sanitizeVenueDraft(
  rawDraft: unknown,
  fallbackCountry: CountryCode = "MT",
): JsonRecord {
  const draft = asRecord(rawDraft);
  const name = requireString(draft, "name");

  return {
    name,
    slug: slugify(stringValue(draft.slug) ?? name),
    category: stringValue(draft.category) ?? "restaurant",
    description: stringValue(draft.description) ?? "",
    address: stringValue(draft.address) ?? "",
    phone: stringValue(draft.phone) ?? stringValue(draft.contact_phone) ??
      stringValue(draft.contactPhone) ?? null,
    email: stringValue(draft.email) ?? stringValue(draft.contact_email) ??
      stringValue(draft.contactEmail) ?? null,
    website_url: stringValue(draft.website_url) ??
      stringValue(draft.websiteUrl) ?? null,
    image_url: stringValue(draft.image_url) ?? stringValue(draft.imageUrl) ??
      null,
    country: normalizeCountryCode(draft.country, fallbackCountry),
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
  applyString("website_url");
  applyString("reservation_url");
  applyString("revolut_url");
  applyString("wifi_ssid");
  applyString("wifi_password");

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
    const status = requireString(updates, "status");
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

function publicVenueListPayload(rawVenue: unknown): JsonRecord {
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
    wifi_ssid: stringValue(venue.wifi_ssid) ?? null,
    wifi_password: stringValue(venue.wifi_password) ?? null,
    wifi_security: stringValue(venue.wifi_security) ?? null,
  };
}

function venueStatus(rawVenue: unknown): string {
  return stringValue(asRecord(rawVenue).status) ?? "active";
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

async function assertVenueDraftDoesNotConflict(
  supabase: ReturnType<typeof adminClient>,
  draft: JsonRecord,
): Promise<void> {
  const draftName = stringValue(draft.name) ?? "This venue";
  const draftSlug = stringValue(draft.slug) ?? slugify(draftName);

  const { data, error } = await supabase
    .from("dinein_venues")
    .select("id, name, status, owner_id, approved_claim_id")
    .in("status", ["active", "pending_claim", "pending_activation"])
    .or(buildVenueConflictOrClause(draftName, draftSlug))
    .order("created_at", { ascending: false })
    .limit(10);

  if (error) {
    console.error("[dinein-api] pending venue conflict lookup failed", error);
    throw new HttpError(500, "Could not validate the venue before claim.");
  }

  const rows = Array.isArray(data) ? data : data ? [data] : [];
  const candidate = rows.find((venue) =>
    isStrongOnboardingVenueMatch(draftName, venue)
  );
  if (!candidate) {
    return;
  }

  const venue = asRecord(candidate);
  const venueName = stringValue(venue.name) ?? draftName;
  const ownerId = stringValue(venue.owner_id);
  const status = stringValue(venue.status) ?? "active";

  if (status == "active" && venueHasLinkedAccess(venue)) {
    throw new HttpError(
      409,
      `Venue "${venueName}" is already live on DineIn and cannot be claimed from onboarding.`,
    );
  }

  if (status == "active") {
    throw new HttpError(
      409,
      `Venue "${venueName}" already exists on DineIn. Search and select the existing listing instead of creating a new one.`,
    );
  }

  throw new HttpError(
    409,
    `Venue "${venueName}" already has a pending onboarding record on DineIn.`,
  );
}

async function findUnavailableOnboardingVenueMatch(
  supabase: ReturnType<typeof adminClient>,
  query: string,
  countryCode: CountryCode,
): Promise<JsonRecord | null> {
  const searchQuery = normalizeVenueSearchQuery(query);
  if (!searchQuery) return null;

  const { data, error } = await supabase
    .from("dinein_venues")
    .select("id, name, slug, status, owner_id, approved_claim_id")
    .eq("country", countryCode)
    .in("status", ["active", "pending_claim", "pending_activation"])
    .or(buildVenueSearchOrClause(searchQuery))
    .order("name", { ascending: true })
    .limit(10);

  if (error) {
    console.error(
      "[dinein-api] onboarding unavailable venue lookup failed",
      error,
    );
    throw new HttpError(500, "Could not validate onboarding venue search.");
  }

  for (const candidate of data ?? []) {
    const venue = asRecord(candidate);
    if (!isStrongOnboardingVenueMatch(searchQuery, venue)) {
      continue;
    }

    const status = stringValue(venue.status) ?? "active";
    const name = stringValue(venue.name) ?? searchQuery;

    if (status == "active" && venueHasLinkedAccess(venue)) {
      return { name, reason: "already_live", status };
    }

    if (status == "pending_claim" || status == "pending_activation") {
      return { name, reason: "already_onboarding", status };
    }
  }

  return null;
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
  body: JsonRecord,
): Promise<Response> {
  const countryCode = requestCountryCode(body);
  const limit = normalizeListLimit(body.limit);
  const offset = normalizeListOffset(body.offset);
  const { data, error } = await supabase
    .from("dinein_venues")
    .select("*")
    .eq("country", countryCode)
    .neq("status", "deleted")
    .neq("status", "suspended");

  if (error) {
    console.error("[dinein-api] get venues failed", error);
    throw new HttpError(500, "Could not load venues.");
  }

  const venues = (data ?? [])
    .filter((venue) => isGuestVisibleVenue(venue))
    .sort((left, right) => {
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

  return ok(visible.map(publicVenueListPayload));
}

async function handleGetClaimableVenues(
  supabase: ReturnType<typeof adminClient>,
  body: JsonRecord,
): Promise<Response> {
  const countryCode = requestCountryCode(body);
  const limit = normalizeListLimit(body.limit);
  const offset = normalizeListOffset(body.offset);
  const searchQuery = normalizeVenueSearchQuery(
    body.query ?? body.search ?? body.term,
  );

  let query = supabase
    .from("dinein_venues")
    .select("*")
    .eq("country", countryCode)
    .eq("status", "active")
    .is("owner_id", null)
    .is("approved_claim_id", null)
    .order("rating", { ascending: false })
    .order("rating_count", { ascending: false })
    .order("name", { ascending: true });

  if (searchQuery) {
    query = query.or(buildVenueSearchOrClause(searchQuery));
  }

  if (limit != null) {
    query = query.range(offset, offset + limit - 1);
  }

  const { data, error } = await query;
  if (error) {
    console.error("[dinein-api] get claimable venues failed", error);
    throw new HttpError(500, "Could not load claimable venues.");
  }

  return ok((data ?? []).map(publicVenueListPayload));
}

async function handleSearchOnboardingVenues(
  supabase: ReturnType<typeof adminClient>,
  body: JsonRecord,
): Promise<Response> {
  const countryCode = requestCountryCode(body);
  const searchQuery = normalizeVenueSearchQuery(
    body.query ?? body.search ?? body.term,
  );
  if (!searchQuery) {
    return ok({
      results: [],
      blockedMatch: null,
    });
  }

  const limit = normalizeListLimit(body.limit, 20) ?? 10;
  const { data, error } = await supabase
    .from("dinein_venues")
    .select("*")
    .eq("country", countryCode)
    .eq("status", "active")
    .is("owner_id", null)
    .is("approved_claim_id", null)
    .or(buildVenueSearchOrClause(searchQuery))
    .order("rating", { ascending: false })
    .order("rating_count", { ascending: false })
    .order("name", { ascending: true })
    .limit(limit);

  if (error) {
    console.error("[dinein-api] onboarding venue search failed", error);
    throw new HttpError(500, "Could not search onboarding venues.");
  }

  const blockedMatch = await findUnavailableOnboardingVenueMatch(
    supabase,
    searchQuery,
    countryCode,
  );

  return ok({
    results: (data ?? []).map(publicVenueListPayload),
    blockedMatch,
  });
}

async function handleGetAllVenues(
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

async function handleGetVenueBySlug(
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

async function handleGetVenueById(
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

async function handleGetVenueForOwner(
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

  const currentVenue = mode == "admin" || "status" in updates
    ? await venueSnapshot(supabase, venueId)
    : null;

  if (mode == "admin") {
    const persistedVenue = currentVenue ??
      await venueSnapshot(supabase, venueId);
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

async function handleCreatePendingClaimVenue(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  // Require contact info to prevent anonymous venue creation abuse
  const draft = asRecord(body.draft);
  const contactPhone = stringValue(draft.contact_phone) ??
    stringValue(body.contactPhone) ?? stringValue(body.contact_phone);
  const contactEmail = stringValue(draft.email) ?? stringValue(body.email);
  if (!contactPhone && !contactEmail) {
    throw new HttpError(
      400,
      "Contact phone or email is required to create a venue claim.",
    );
  }

  const sanitizedDraft = sanitizeVenueDraft(
    body.draft,
    requestCountryCode(body),
  );
  await assertVenueDraftDoesNotConflict(supabase, sanitizedDraft);
  const created = await uniqueVenueInsert(supabase, sanitizedDraft);
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

// ─── CLAIM APPROVAL TOKEN ISSUANCE (admin only) ───
async function handleAutoApproveOnboardingClaim(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const adminId = await requireAdmin(supabase, req);
  const claimId = requireString(body, "claimId", "claim_id");
  const venueId = requireString(body, "venueId", "venue_id");
  const contactPhone = stringValue(body.contactPhone) ??
    stringValue(body.contact_phone) ?? "";

  // Load the claim
  const { data: claimData, error: claimError } = await supabase
    .from("dinein_venue_claims")
    .select("*")
    .eq("id", claimId)
    .maybeSingle();

  if (claimError) {
    console.error("[dinein-api] auto-approve claim lookup failed", claimError);
    throw new HttpError(500, "Could not load the claim.");
  }
  if (!claimData) {
    throw new HttpError(404, "Claim not found.");
  }

  const claim = asRecord(claimData);
  const claimStatus = stringValue(claim.status);
  if (claimStatus !== "pending") {
    throw new HttpError(400, `Claim is already ${claimStatus ?? "processed"}.`);
  }

  const claimVenueId = stringValue(claim.venue_id);
  if (claimVenueId && claimVenueId !== venueId) {
    throw new HttpError(403, "Venue ID does not match the claim.");
  }

  // Approve the claim
  const approvedAt = new Date().toISOString();
  await persistApprovedVenueClaim(supabase, claim, approvedAt, adminId);
  await persistApprovedVenueLinkage(supabase, claim, approvedAt);

  const claimantId = stringValue(claim.claimant_id);
  await upsertVenueOwnerProfileRole(supabase, claimantId);

  // Load venue name for token
  const { data: venueData } = await supabase
    .from("dinein_venues")
    .select("name")
    .eq("id", venueId)
    .maybeSingle();

  const venueName = stringValue(asRecord(venueData ?? {}).name) ?? "";
  const phone = contactPhone || stringValue(claim.contact_phone) ||
    stringValue(claim.whatsapp_number) || "";

  // Issue venue access token
  const token = await issueVenueToken(venueId, phone, venueName, {
    claimId,
  });
  await persistVenueAccessAudit(supabase, claim, {
    issuedAt: token.issued_at,
    approvedAt,
  });

  return ok({
    venue_name: venueName,
    venue_token: token,
  });
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
  const claimStatus = stringValue(claim.status) ?? "pending";
  if (claimStatus !== "pending") {
    throw new HttpError(400, `Claim is already ${claimStatus}.`);
  }

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

  const approvedAt = new Date().toISOString();
  await persistApprovedVenueClaim(supabase, claim, approvedAt, adminId);
  const claimantId = stringValue(claim.claimant_id);
  await persistApprovedVenueLinkage(supabase, claim, approvedAt);
  await upsertVenueOwnerProfileRole(supabase, claimantId);

  return ok({
    approved: true,
    activated: true,
    claim_id: claimId,
    venue_id: claimVenueId,
    venue_status: "active",
    venueStatus: "active",
    owner_assigned: claimantId != null,
    ownerAssigned: claimantId != null,
    claim_linked: true,
    claimLinked: true,
  });
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

async function handleSetMenuItemHighlights(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const venueId = requireString(body, "venueId", "venue_id");
  await authorizeVenueMutation(supabase, req, venueId, body.venue_session);

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

async function handleReplaceVenueMenu(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const venueId = requireString(body, "venueId", "venue_id");
  await authorizeVenueMutation(supabase, req, venueId, body.venue_session);

  const items = Array.isArray(body.items) ? body.items : [];
  const sanitized = items.map((item) => sanitizeMenuItemInsert(item, venueId));

  // Delete existing menu items for this venue
  const { error: deleteError } = await supabase
    .from("dinein_menu_items")
    .delete()
    .eq("venue_id", venueId);

  if (deleteError) {
    console.error("[dinein-api] delete venue menu items failed", deleteError);
    throw new HttpError(500, "Could not clear existing menu items.");
  }

  // Insert new items
  if (sanitized.length > 0) {
    const { error: insertError } = await supabase
      .from("dinein_menu_items")
      .insert(sanitized);

    if (insertError) {
      console.error(
        "[dinein-api] replace venue menu insert failed",
        insertError,
      );
      throw new HttpError(500, "Could not insert replacement menu items.");
    }
  }

  return ok(true, 201);
}

async function handleOcrExtractMenu(
  supabase: ReturnType<typeof adminClient>,
  _req: Request,
  body: JsonRecord,
): Promise<Response> {
  const authHeader = _req.headers.get("Authorization");
  const isServiceRole = decodeJwtRole(authHeader) === "service_role";
  let isAuthorized = isServiceRole;

  if (!isAuthorized) {
    const aid = await adminUserId(supabase, _req).catch(() => null);
    if (aid) isAuthorized = true;
  }

  if (!isAuthorized) {
    const venueClaims = await venueSessionClaims(_req).catch(() => null);
    if (venueClaims?.venue_id) isAuthorized = true;
  }

  if (!isAuthorized) {
    const onboardingClaims = await onboardingMenuClaims(body).catch(() => null);
    if (onboardingClaims?.phone) isAuthorized = true;
  }

  if (!isAuthorized) {
    throw new HttpError(401, "Authentication required to extract menus.");
  }

  const fileUrl = requireString(body, "fileUrl", "file_url");
  if (!isAllowedMenuUploadUrl(fileUrl, getEnv("SUPABASE_URL"))) {
    throw new HttpError(
      400,
      "Menu extraction only accepts signed uploads from the menu-uploads bucket.",
    );
  }
  const geminiApiKey = optionalEnv("GEMINI_API_KEY");
  if (!geminiApiKey) {
    throw new HttpError(500, "GEMINI_API_KEY is not configured.");
  }

  // Fetch the file from the URL
  let fileBytes: Uint8Array;
  let mimeType = "image/jpeg";
  try {
    const fileResponse = await fetch(fileUrl);
    if (!fileResponse.ok) {
      throw new HttpError(
        400,
        `Could not fetch file: ${fileResponse.statusText}`,
      );
    }
    mimeType = normalizeMenuUploadContentType(
      fileResponse.headers.get("content-type"),
    ) ?? "image/jpeg";
    fileBytes = new Uint8Array(await fileResponse.arrayBuffer());
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError(400, "Could not download the uploaded file.");
  }
  if (fileBytes.byteLength == 0) {
    throw new HttpError(400, "Uploaded menu file is empty.");
  }
  if (fileBytes.byteLength > 10 * 1024 * 1024) {
    throw new HttpError(413, "Uploaded menu file exceeds the 10MB limit.");
  }

  // Convert to base64 for Gemini
  let binaryString = "";
  for (const byte of fileBytes) {
    binaryString += String.fromCharCode(byte);
  }
  const base64Data = btoa(binaryString);

  const ocrPrompt = `
Analyze this restaurant menu image or document. Extract ALL menu items into a structured JSON array.

For each item, extract:
- "name": the dish/drink name (string, required)
- "description": a brief description if visible (string, can be empty)
- "price": the price as a number (e.g. 12.50) — use 0 if not visible
- "category": the menu section/category (e.g. "Starters", "Main Course", "Desserts", "Drinks") — infer from context if not explicitly labeled
- "requires_review": true (always true — human should verify OCR output)

Rules:
- Extract EVERY item you can identify, even if partially visible
- Prices should be numbers without currency symbols
- Categories should be Title Case
- If the menu is in a non-English language, translate item names and descriptions to English
- Return ONLY a valid JSON array, no other text

Example output:
[{"name":"Grilled Salmon","description":"Fresh Atlantic salmon with lemon butter","price":24.50,"category":"Main Course","requires_review":true}]
  `.trim();

  // Call Gemini Vision API
  const geminiModel = "gemini-2.5-flash";
  const geminiUrl =
    `https://generativelanguage.googleapis.com/v1beta/models/${geminiModel}:generateContent?key=${geminiApiKey}`;

  const geminiBody = {
    contents: [{
      parts: [
        { text: ocrPrompt },
        {
          inline_data: {
            mime_type: mimeType.startsWith("application/pdf")
              ? "application/pdf"
              : mimeType,
            data: base64Data,
          },
        },
      ],
    }],
    generationConfig: {
      temperature: 0.1,
      maxOutputTokens: 8192,
      responseMimeType: "application/json",
    },
  };

  let extractedItems: JsonRecord[] = [];
  try {
    const geminiResponse = await fetch(geminiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(geminiBody),
    });

    if (!geminiResponse.ok) {
      const errorBody = await geminiResponse.text();
      console.error("[dinein-api] Gemini OCR failed", errorBody);
      throw new HttpError(502, "Menu extraction failed. Please try again.");
    }

    const geminiData = await geminiResponse.json();
    const textContent =
      geminiData?.candidates?.[0]?.content?.parts?.[0]?.text ?? "[]";

    // Parse the JSON response
    const parsed = JSON.parse(textContent);
    extractedItems = Array.isArray(parsed) ? parsed : [];
  } catch (error) {
    if (error instanceof HttpError) throw error;
    console.error("[dinein-api] OCR extraction error", error);
    throw new HttpError(502, "Could not extract menu items from the file.");
  }

  // Normalize extracted items
  const items = extractedItems.map((item) => ({
    name: stringValue(item.name) ?? "Unnamed Item",
    description: stringValue(item.description) ?? "",
    price: roundCurrency(numberValue(item.price) ?? 0),
    category: stringValue(item.category) ?? "General",
    tags: [],
    requires_review: true,
  }));

  return ok({ items, count: items.length });
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

async function handleGenerateVenueProfileImage(
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

async function handleBackfillVenueProfileImages(
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

async function handleUploadMenuFile(
  supabase: ReturnType<typeof adminClient>,
  _req: Request,
  body: JsonRecord,
): Promise<Response> {
  const authHeader = _req.headers.get("Authorization");
  const isServiceRole = decodeJwtRole(authHeader) === "service_role";
  let isAuthorized = isServiceRole;

  if (!isAuthorized) {
    const aid = await adminUserId(supabase, _req).catch(() => null);
    if (aid) isAuthorized = true;
  }

  if (!isAuthorized) {
    const venueClaims = await venueSessionClaims(_req).catch(() => null);
    if (venueClaims?.venue_id) isAuthorized = true;
  }

  if (!isAuthorized) {
    const onboardingClaims = await onboardingMenuClaims(body).catch(() => null);
    if (onboardingClaims?.phone) isAuthorized = true;
  }

  if (!isAuthorized) {
    throw new HttpError(401, "Authentication required to upload menu files.");
  }

  const fileName = sanitizeStorageFileName(
    stringValue(body.fileName) ?? stringValue(body.file_name) ?? "menu-upload",
  );
  const contentType = normalizeMenuUploadContentType(
    stringValue(body.contentType) ?? stringValue(body.content_type),
  );
  if (!contentType) {
    throw new HttpError(
      400,
      "Unsupported file type. Allowed: JPEG, PNG, WebP, HEIC, PDF.",
    );
  }

  const fileData = requireString(body, "fileData", "file_data");
  const bytes = decodeBase64Bytes(fileData);
  if (bytes.byteLength == 0) {
    throw new HttpError(400, "Menu upload is empty.");
  }
  if (bytes.byteLength > 10 * 1024 * 1024) {
    throw new HttpError(413, "Menu upload exceeds the 10MB limit.");
  }

  const storagePath =
    `uploads/${Date.now()}-${crypto.randomUUID()}-${fileName}`;
  const { error: uploadError } = await supabase.storage
    .from("menu-uploads")
    .upload(storagePath, bytes, {
      contentType,
      upsert: false,
    });
  if (uploadError) {
    console.error("[dinein-api] menu upload failed", uploadError);
    throw new HttpError(500, "Could not upload the menu file.");
  }

  const { data: signedUrlData, error: signedUrlError } = await supabase.storage
    .from("menu-uploads")
    .createSignedUrl(storagePath, 600);
  if (signedUrlError || !signedUrlData?.signedUrl) {
    console.error(
      "[dinein-api] menu upload signed url failed",
      signedUrlError,
    );
    throw new HttpError(500, "Could not finalize the menu upload.");
  }

  return ok({
    path: storagePath,
    signed_url: signedUrlData.signedUrl,
    signedUrl: signedUrlData.signedUrl,
  }, 201);
}

async function handleSearchGoogleMaps(
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
  const rateLimitKey = assertGoogleMapsSearchRateLimit(req, nowMs);
  if (rateLimitKey) {
    recordGoogleMapsSearchRateLimit(rateLimitKey, nowMs);
  }

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

async function handleGetVenueNotificationSettings(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const venueId = requireString(body, "venueId", "venue_id");
  await authorizeVenueMutation(supabase, req, venueId, body.venue_session);
  return ok(await venueNotificationSettingsSnapshot(supabase, venueId));
}

async function handleUpdateVenueNotificationSettings(
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

async function handleRegisterPushDevice(
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

async function handleUnregisterPushDevice(
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

async function handleSendWave(
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

  const anonymousRateLimitKey = user == null
    ? assertAnonymousWaveRateLimit(req, venueId, now.getTime())
    : null;

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

  if (anonymousRateLimitKey != null) {
    recordAnonymousWaveRateLimit(anonymousRateLimitKey, now.getTime());
  }

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

async function handleGetBellRequests(
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

async function handleResolveBellRequest(
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

async function handleGetOrdersForVenue(
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

  return ok(await attachVenueImagesToOrders(supabase, data ?? []));
}

async function handleImageHealth(
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

  return ok(await attachVenueImagesToOrders(supabase, data ?? []));
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

async function handleUpdateOrderStatus(
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

async function handleIssueVenueToken(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  await requireAdmin(supabase, req);
  const contactPhone = requireString(body, "contactPhone", "contact_phone");
  const venueId = requireString(body, "venueId", "venue_id");

  // Verify the caller has an approved claim for this venue
  const lookup = buildContactLookup(contactPhone);
  if (lookup.kind !== "phone") {
    throw new HttpError(400, "A valid phone number is required.");
  }

  const { data, error } = await supabase
    .from("dinein_venue_claims")
    .select("*")
    .eq("venue_id", venueId)
    .eq("status", "approved")
    .order("created_at", { ascending: false });

  if (error) {
    console.error("[dinein-api] venue token claim lookup failed", error);
    throw new HttpError(500, "Could not verify venue access.");
  }

  const approvedClaim = (data ?? []).map(asRecord).find((claim) =>
    claimMatchesContact(claim, lookup)
  );
  if (!approvedClaim) {
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

  const token = await issueVenueToken(venueId, lookup.normalized, venueName, {
    claimId: stringValue(approvedClaim.id),
  });
  await persistVenueAccessAudit(supabase, approvedClaim, {
    issuedAt: token.issued_at,
  });
  return ok(token);
}

async function handleConfirmVenueAccess(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const isServiceRole =
    decodeJwtRole(req.headers.get("Authorization")) == "service_role";
  const verifiedBy = isServiceRole
    ? "service_role"
    : await requireAdmin(supabase, req);

  const contactPhone = requireString(body, "contactPhone", "contact_phone");
  const venueId = requireString(body, "venueId", "venue_id");
  const verificationNote = stringValue(
    body.verificationNote ?? body.verification_note ?? body.note,
  ) ?? "Admin confirmed venue access without OTP.";
  const lookup = buildContactLookup(contactPhone);
  if (lookup.kind !== "phone") {
    throw new HttpError(400, "A valid phone number is required.");
  }

  const { data, error } = await supabase
    .from("dinein_venue_claims")
    .select("*")
    .eq("venue_id", venueId)
    .eq("status", "approved")
    .order("created_at", { ascending: false });

  if (error) {
    console.error(
      "[dinein-api] confirm venue access claim lookup failed",
      error,
    );
    throw new HttpError(500, "Could not verify venue access.");
  }

  const approvedClaim = (data ?? []).map(asRecord).find((claim) =>
    claimMatchesContact(claim, lookup)
  );
  if (!approvedClaim) {
    throw new HttpError(
      404,
      "No approved claim found for this venue and phone number.",
    );
  }

  const { data: venueData, error: venueError } = await supabase
    .from("dinein_venues")
    .select("name")
    .eq("id", venueId)
    .maybeSingle();

  if (venueError) {
    console.error(
      "[dinein-api] confirm venue access venue lookup failed",
      venueError,
    );
    throw new HttpError(500, "Could not load the venue.");
  }

  const venueName = stringValue(asRecord(venueData ?? {}).name) ?? "";
  const verifiedAt = new Date().toISOString();
  const token = await issueVenueToken(venueId, lookup.normalized, venueName, {
    claimId: stringValue(approvedClaim.id),
    issuedAt: verifiedAt,
  });
  await persistVenueAccessAudit(supabase, approvedClaim, {
    issuedAt: token.issued_at,
    verifiedAt,
    normalizedPhone: lookup.normalized,
    verificationMethod: "admin_override",
    verifiedBy,
    verificationNote,
  });

  const nextVenue = await venueSnapshot(supabase, venueId);
  const readiness = venueOrderingReadiness(nextVenue);
  return ok({
    venue_token: token,
    verified_at: verifiedAt,
    verification_method: "admin_override",
    verified_by: verifiedBy,
    verification_note: verificationNote,
    ordering_ready: readiness.ready,
    readiness_reasons: readiness.reasons,
    supported_payment_methods: readiness.supportedPaymentMethods,
  });
}

export async function handleAppRequest(req: Request): Promise<Response> {
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
        return await handleGetVenues(supabase, body);
      case "get_claimable_venues":
        return await handleGetClaimableVenues(supabase, body);
      case "search_onboarding_venues":
        return await handleSearchOnboardingVenues(supabase, body);
      case "get_all_venues":
        return await handleGetAllVenues(supabase, req, body);
      case "get_venue_by_slug":
        return await handleGetVenueBySlug(supabase, req, body);
      case "get_venue_by_id":
        return await handleGetVenueById(supabase, req, body);
      case "get_venue_for_owner":
        return await handleGetVenueForOwner(supabase, req, body);
      case "update_venue":
        return await handleUpdateVenue(supabase, req, body);
      case "create_pending_claim_venue":
        return await handleCreatePendingClaimVenue(supabase, req, body);
      case "upload_menu_file":
        return await handleUploadMenuFile(supabase, req, body);
      case "submit_claim":
        return await handleSubmitClaim(supabase, req, body);
      case "get_pending_claims":
        return await handleGetPendingClaims(supabase, req);
      case "get_latest_claim_by_contact":
        return await handleGetLatestClaimByContact(supabase, req, body);
      case "approve_claim":
        return await handleApproveClaim(supabase, req, body);
      case "auto_approve_onboarding_claim":
        return await handleAutoApproveOnboardingClaim(supabase, req, body);
      case "reject_claim":
        return await handleRejectClaim(supabase, req, body);
      case "get_menu_items":
        return await handleGetMenuItems(supabase, req, body);
      case "toggle_menu_item_availability":
        return await handleToggleMenuItemAvailability(supabase, req, body);
      case "create_menu_item":
        return await handleCreateMenuItem(supabase, req, body);
      case "update_menu_item":
        return await handleUpdateMenuItem(supabase, req, body);
      case "delete_menu_item":
        return await handleDeleteMenuItem(supabase, req, body);
      case "set_menu_item_highlights":
        return await handleSetMenuItemHighlights(supabase, req, body);
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
      case "generate_venue_profile_image":
        return await handleGenerateVenueProfileImage(supabase, req, body);
      case "backfill_venue_profile_images":
        return await handleBackfillVenueProfileImages(supabase, req, body);
      case "get_venue_notification_settings":
        return await handleGetVenueNotificationSettings(supabase, req, body);
      case "update_venue_notification_settings":
        return await handleUpdateVenueNotificationSettings(supabase, req, body);
      case "register_push_device":
        return await handleRegisterPushDevice(supabase, req, body);
      case "unregister_push_device":
        return await handleUnregisterPushDevice(supabase, req, body);
      case "place_order":
        return await handlePlaceOrder(supabase, req, body);
      case "send_wave":
        return await handleSendWave(supabase, req, body);
      case "get_bell_requests":
        return await handleGetBellRequests(supabase, req, body);
      case "resolve_bell_request":
        return await handleResolveBellRequest(supabase, req, body);
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
      case "confirm_venue_access":
        return await handleConfirmVenueAccess(supabase, req, body);
      case "issue_venue_token":
        return await handleIssueVenueToken(supabase, req, body);
      case "search_google_maps":
        return await handleSearchGoogleMaps(req, body);
      case "ocr_extract_menu":
        return await handleOcrExtractMenu(supabase, req, body);
      case "replace_venue_menu":
        return await handleReplaceVenueMenu(supabase, req, body);
      case "image_health":
        return await handleImageHealth(supabase, req);
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

    if (error instanceof VenueProfileImageHttpError) {
      return fail(error.message, error.status, asRecord(error.details));
    }

    console.error("[dinein-api] unhandled error", error);
    return fail(
      error instanceof Error ? error.message : "Unexpected server error.",
      500,
    );
  }
}

Deno.serve(handleAppRequest);
