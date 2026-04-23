import { stringValue, HttpError, requireString, JsonRecord, asRecord, booleanValue, orderItemCount, formatOrderTotal, adminClient, venueSnapshot, firebaseMessagingAccessToken, venueOwnerWhatsAppNumber, buildWhatsAppTemplatePayload, postWhatsAppMessage, buildWhatsAppTextPayload } from "../core.ts";
import * as Core from "../core.ts";
export function normalizePushPlatform(value: unknown): string {
  const normalized = (stringValue(value) ?? "").trim().toLowerCase();
  if (!pushPlatforms.has(normalized)) {
    throw new HttpError(400, `Unsupported push platform: ${value}`);
  }
  return normalized;
}
export function sanitizePushToken(value: unknown): string {
  const token = requireString({ value }, "value").trim();
  if (token.length < 32) {
    throw new HttpError(400, "Push token is invalid.");
  }
  return token;
}
export function defaultVenueNotificationSettings(): JsonRecord {
  return {
    order_push_enabled: true,
    whatsapp_updates_enabled: true,
  };
}
export function normalizeVenueNotificationSettingsInput(value: unknown): JsonRecord {
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
export function notificationData(
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
export function isInvalidPushTokenError(value: unknown): boolean {
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
export function buildNewOrderPushNotification(
  order: JsonRecord,
  venueCountry?: string | null
): VenuePushNotificationPayload {
  const venueId = stringValue(order.venue_id);
  const orderId = stringValue(order.id);
  const orderNumber = stringValue(order.order_number) ?? "New";
  const tableNumber = stringValue(order.table_number) ?? "unknown";
  const itemCount = Math.max(1, orderItemCount(order.items));
  const totalLabel = formatOrderTotal(order.total, venueCountry);

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
export function buildBellRequestPushNotification(
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
export async function venueNotificationSettingsSnapshot(
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
export async function upsertVenueNotificationSettings(
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
export async function syncVenuePushRegistrationFlags(
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
export async function resolveVenueNotificationContactPhone(
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
    stringValue(venue.phone) ??
    null;
}
export async function activeVenuePushRegistrations(
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
export async function sendVenuePushNotification(
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
export async function prunePushRegistrations(
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
export const pushPlatforms = new Set(["android", "ios", "web"]);
export const VENUE_PUSH_ALERT_ROUTE_ORDERS = "/venue/orders";
export const VENUE_PUSH_ALERT_ROUTE_WAVES = "/venue/waves";
export type VenuePushNotificationPayload = {
  title: string;
  body: string;
  data: Record<string, string>;
};
export async function dispatchVenueOperationalAlert(
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
export async function dispatchVenueWhatsAppAlert(
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
