import {
  type JsonRecord,
  adminClient,
  asRecord,
  authorizeVenueMutation,
  booleanValue,
  canVenueAcceptGuestOrders,
  hasPrivateVenueAccess,
  HttpError,
  isGuestVisibleVenue,
  isServiceRoleRequest,
  adminManagedMenuGroupSeed,
  menuItemAdminSnapshot,
  menuItemVenueId,
  ok,
  publicMenuItemPayload,
  requireString,
  sanitizeAdminMenuUpdates,
  sanitizeMenuItemInsert,
  sanitizeMenuItemUpdates,
  syncAdminManagedGroupSharedFields,
} from "../core.ts";
import { stringValue } from "../../_shared/env.ts";

// Menu handlers — menu item CRUD + AI ingestion
// Actions: get_menu_items, get_menu_item_by_id, toggle_menu_item_availability,
//          create_menu_item, update_menu_item, delete_menu_item, set_menu_item_highlights,
//          ingest_menu_document
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
  ).catch(() => false);

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
  if (mode == "admin" && !(await isServiceRoleRequest(req))) {
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
  if (mode == "admin" && !(await isServiceRoleRequest(req))) {
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
  if (mode == "admin" && !(await isServiceRoleRequest(req))) {
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
  if (mode == "admin" && !(await isServiceRoleRequest(req))) {
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

export { handleIngestMenuDocument } from "./image.ts";
