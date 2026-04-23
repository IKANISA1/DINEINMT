import {
  type JsonRecord,
  adminClient,
  asRecord,
  authorizeVenueMutation,
  booleanValue,
  normalizePushPlatform,
  ok,
  requireString,
  resolveVenueNotificationContactPhone,
  sanitizePushToken,
  syncVenuePushRegistrationFlags,
  venueNotificationSettingsSnapshot,
  upsertVenueNotificationSettings,
} from "../../_shared/core-monolith.ts";
import { HttpError } from "../../_shared/core-monolith.ts";
import { stringValue } from "../../_shared/env.ts";

// Notification handlers — push device registration + venue notification settings
// Actions: get_venue_notification_settings, update_venue_notification_settings,
//          register_push_device, unregister_push_device
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
      "[venue-api] push registration token cleanup failed",
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
      "[venue-api] push registration device cleanup failed",
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
    console.error("[venue-api] register push device failed", error);
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
    console.error("[venue-api] unregister push device failed", error);
    throw new HttpError(500, "Could not unregister the push device.");
  }

  return ok(true);
}
