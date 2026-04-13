import {
  type JsonRecord,
  adminClient,
  anonymousWaveRateLimitKey,
  asRecord,
  authorizeVenueMutation,
  buildBellRequestPushNotification,
  currentUser,
  dispatchVenueOperationalAlert,
  HttpError,
  normalizeWaveTableNumber,
  ok,
  requireString,
} from "../core.ts";
import { stringValue } from "../../_shared/env.ts";
import {
  assertRateLimit,
  recordRateLimit,
  WAVE_RATE_LIMIT,
} from "../rate-limit.ts";

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

function bellRequestSchemaMismatch(error: unknown): boolean {
  if (!error || typeof error !== "object") return false;
  const record = error as Record<string, unknown>;
  const text = [
    record.code,
    record.message,
    record.details,
    record.hint,
  ].filter((value) => typeof value === "string" && value.length > 0).join(" ")
    .toLowerCase();
  return text.includes("bell_requests") &&
    (text.includes("does not exist") ||
      text.includes("schema cache") ||
      text.includes("could not find the table") ||
      text.includes("could not find the column"));
}

function bellRequestFailure(error: unknown, message: string): HttpError {
  if (bellRequestSchemaMismatch(error)) {
    return new HttpError(
      500,
      "Bell requests are not configured correctly for this project.",
      { code: "bell_requests_not_configured" },
    );
  }

  return new HttpError(500, message);
}

// Bell/wave handlers — table call system
// Actions: send_wave, get_bell_requests, resolve_bell_request
export async function handleSendWave(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const venueId = requireString(body, "venueId", "venue_id");
  const tableNumber = normalizeWaveTableNumber(
    body.tableNumber ?? body.table_number,
  );

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
    throw bellRequestFailure(
      existingError,
      "Could not create the wave request.",
    );
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
    throw bellRequestFailure(error, "Could not create the wave request.");
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
    throw bellRequestFailure(error, "Could not load bell requests.");
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
    throw bellRequestFailure(error, "Could not resolve the bell request.");
  }

  return ok(true);
}
