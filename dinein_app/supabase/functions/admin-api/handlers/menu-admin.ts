import {
  type JsonRecord,
  adminClient,
  asRecord,
  booleanValue,
  HttpError,
  normalizeStringList,
  ok,
  requireAdmin,
  requireString,
  resolveAdminAssignmentVenueIds,
  sanitizeAdminManagedMenuDraft,
  adminManagedMenuGroupSeed,
} from "../../_shared/core-monolith.ts";
import { numberValue, stringValue } from "../../_shared/env.ts";

// Admin menu handlers — queue, catalog, groups
// Actions: get_admin_menu_queue, get_admin_menu_catalog,
//          get_admin_menu_group_assignments, create_admin_menu_groups,
//          assign_admin_menu_group, delete_admin_menu_group
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
    console.error("[admin-api] get admin menu queue failed", error);
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
    console.error("[admin-api] get admin menu catalog failed", error);
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
    console.error("[admin-api] get admin menu assignments failed", error);
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
    console.error("[admin-api] create admin menu groups failed", error);
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
      "[admin-api] assign admin menu group lookup failed",
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
    console.error("[admin-api] assign admin menu group failed", error);
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
    console.error("[admin-api] delete admin menu group failed", error);
    throw new HttpError(500, "Could not delete the admin menu item.");
  }

  return ok(true);
}
