import {
  type JsonRecord,
  adminClient,
  asRecord,
  booleanValue,
  canVenueAcceptGuestOrders,
  ensureUniqueVenueAccessPhone,
  ensureUniqueVenueSlug,
  hasVerifiedServiceRoleRequest,
  HttpError,
  isGuestVisibleVenue,
  normalizeCountryCode,
  normalizeListLimit,
  normalizeListOffset,
  ok,
  publicVenueListPayload,
  requestCountryCode,
  requireAdmin,
  requireSelfOrAdmin,
  requireString,
  sanitizeVenueUpdates,
  venueDistanceKm,
  venueMatchesQuery,
  venueOrderingReadiness,
  venueSnapshot,
  venueStatus,
  authorizeVenueMutation,
} from "../../_shared/core-monolith.ts";
import { numberValue, stringValue } from "../../_shared/env.ts";

// Venue handlers — CRUD operations for venues
// Actions: get_venues, get_all_venues, create_venue, get_venue_by_slug,
//          get_venue_by_id, get_venue_for_owner, update_venue
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
    console.error("[venue-api] get venues failed", error);
    throw new HttpError(500, "Could not load venues.");
  }

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
    const categories = [
      ...new Set(
        venues
          .map((venue) => stringValue(asRecord(venue).category)?.trim() ?? "")
          .filter((value) => value.length > 0),
      ),
    ]
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
    console.error("[venue-api] get all venues failed", error);
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
    owner_whatsapp_number: stringValue(updates.owner_whatsapp_number) ?? null,
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
    console.error("[venue-api] create venue failed", error);
    throw new HttpError(500, "Could not create the venue.");
  }

  return ok(data, 201);
}

export async function handleGetVenueBySlug(
  supabase: ReturnType<typeof adminClient>,
  _req: Request,
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
    console.error("[venue-api] get venue by slug failed", error);
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

  return ok(venue);
}

export async function handleGetVenueById(
  supabase: ReturnType<typeof adminClient>,
  _req: Request,
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
    console.error("[venue-api] get venue by id failed", error);
    throw new HttpError(500, "Could not load the venue.");
  }

  if (!data) {
    return ok(null);
  }

  return ok(data);
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
    console.error("[venue-api] get venue for owner failed", error);
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
    ? (await hasVerifiedServiceRoleRequest(req)
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
    if ("owner_whatsapp_number" in updates) {
      const nextAccessPhone = stringValue(updates.owner_whatsapp_number);
      const previousAccessPhone = stringValue(
        persistedVenue.owner_whatsapp_number,
      );
      const accessPhoneChanged = nextAccessPhone != previousAccessPhone;

      if (nextAccessPhone && accessPhoneChanged) {
        await ensureUniqueVenueAccessPhone(
          supabase,
          nextAccessPhone,
          venueId,
        );
      }

      updates.owner_whatsapp_number = nextAccessPhone;
    }

    const nextVenue = { ...persistedVenue, ...updates };
    const readiness = venueOrderingReadiness(nextVenue);
    const explicitEnable = updates.ordering_enabled === true;
    const wasAlreadyEnabled = booleanValue(persistedVenue.ordering_enabled) ??
      false;

    if (explicitEnable && !wasAlreadyEnabled && !readiness.ready) {
      throw new HttpError(
        409,
        "Venue is not ready to accept guest orders.",
        {
          code: "venue_not_order_ready",
          readiness_reasons: readiness.reasons,
        },
      );
    }

    if (wasAlreadyEnabled && !readiness.ready) {
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
    console.error("[venue-api] update venue failed", error);
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

  if (adminActorId == "service_role") {
    return ok(data ?? true);
  }

  return ok(data ?? true);
}
