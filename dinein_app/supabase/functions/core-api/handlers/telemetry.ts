import {
  type JsonRecord,
  adminClient,
  asRecord,
  currentUser,
  ok,
  requestCountryCode,
  requireString,
} from "../../_shared/core-monolith.ts";
import { stringValue } from "../../_shared/env.ts";

// Telemetry handlers — guest analytics
// Actions: track_guest_event
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
    console.error("[core-api] track guest event failed", error);
    // Guest analytics must never degrade the browse/order flow. Production can
    // legitimately lag a migration on one region, so treat telemetry writes as
    // best-effort and keep the client path clean.
    return ok(false, 202);
  }

  return ok(true, 201);
}
