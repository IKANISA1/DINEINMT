import { stringValue, HttpError, numberValue, asRecord, defaultCountryCode, venueStatus, adminClient, optionalEnv, getEnv, base64UrlEncode, hmacSha256Base64Url, signedTokenClaims, booleanValue, requireString, JsonRecord } from "../core.ts";
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
export function orderItemCount(value: unknown): number {
  if (!Array.isArray(value)) return 0;
  return value.reduce((total, item) => {
    const quantity = numberValue(asRecord(item).quantity) ?? 0;
    return total + Math.max(0, Math.trunc(quantity));
  }, 0);
}
export function formatOrderTotal(value: unknown, countryCode?: string | null): string | null {
  const amount = numberValue(value);
  if (amount == undefined) return null;
  
  const cc = countryCode?.trim().toUpperCase();
  const isRwanda = cc === "RW" || (!cc && defaultCountryCode === "250");
  
  if (isRwanda) {
    return `RWF ${Math.round(amount).toLocaleString("en-US")}`;
  }
  return `EUR ${amount.toFixed(2)}`;
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
export function venueOrderingReadiness(rawVenue: unknown): {
  ready: boolean;
  reasons: string[];
  supportedPaymentMethods: string[];
} {
  const venue = asRecord(rawVenue);
  const reasons: string[] = [];
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
        return Boolean(stringValue(venue.momo_code));
      default:
        return false;
    }
  });

  if (venueStatus(venue) != "active") {
    reasons.push("venue_not_active");
  }
  if (!stringValue(venue.name)) {
    reasons.push("venue_name_required");
  }
  if (!stringValue(venue.address)) {
    reasons.push("venue_address_required");
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
export async function orderVenueId(
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
export async function orderStatusSnapshot(
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
export function orderReceiptSecret(): string {
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
export async function issueOrderReceiptToken(
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
export async function verifyOrderReceiptToken(
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
export function venueOrderingEnabled(rawVenue: unknown): boolean {
  return booleanValue(asRecord(rawVenue).ordering_enabled) ?? false;
}
export function venueSupportedPaymentMethods(rawVenue: unknown): string[] {
  return venueOrderingReadiness(rawVenue).supportedPaymentMethods;
}
export function canVenueAcceptGuestOrders(rawVenue: unknown): boolean {
  return venueOrderingEnabled(rawVenue) &&
    venueOrderingReadiness(rawVenue).ready;
}
export function sanitizeOrderItems(rawItems: unknown): SanitizedOrderItemInput[] {
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
export async function uniqueOrderInsert(
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
export const orderStatuses = new Set(["placed", "received", "served", "cancelled"]);
export const paymentMethods = new Set(["cash", "momo_ussd", "revolut_link"]);
export const orderPaymentStatuses = new Set([
  "pending",
  "confirmed",
  "not_required",
  "failed",
]);
export const ORDER_REALTIME_TOKEN_TTL_SECONDS = 30 * 60;
export type SanitizedOrderItemInput = {
  menuItemId: string;
  quantity: number;
  note: string | null;
};
