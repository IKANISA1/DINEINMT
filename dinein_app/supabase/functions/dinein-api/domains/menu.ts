import { MenuImageHttpError_, adminClient, HttpError, stringValue, JsonRecord, asRecord, requireString, normalizeStringList, normalizeMenuItemClass, booleanValue, numberValue, inferMenuItemClass, normalizeHighlightRank, MenuImageEnv, getEnv, MenuItemRecord, authorizeVenueMutation, createMenuImageAdminClient, loadVenueForImageGeneration, processMenuItemImageGeneration, syncAdminManagedGroupImageFields, ok, menuImageBackfillEligibilityFilter, normalizeOffset, isServiceRoleRequest, requireAdmin, VenueRecord, auditMenuItemImage } from "../core.ts";
export const MenuImageHttpError = MenuImageHttpError_;
export const menuImageStatuses = new Set(["pending", "generating", "ready", "failed"]);
export const menuImageSources = new Set(["manual", "ai_gemini"]);
export async function menuItemVenueId(
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
export async function menuItemAdminSnapshot(
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
export async function adminManagedMenuGroupSeed(
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
export function sanitizeAdminManagedMenuDraft(rawItem: unknown): JsonRecord {
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
export function sanitizeAdminMenuUpdates(rawUpdates: unknown): JsonRecord {
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
export function publicMenuItemPayload(
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
export function sanitizeMenuItemInsert(
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
export function sanitizeMenuItemUpdates(rawUpdates: unknown): JsonRecord {
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
export function menuImageEnv(): MenuImageEnv {
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
export function normalizeMenuImageBackfillLimit(value: unknown): number {
  const parsed = numberValue(value);
  if (parsed == undefined || !Number.isFinite(parsed)) return 12;
  return Math.max(1, Math.min(25, Math.floor(parsed)));
}
export function normalizeMenuImageAuditLimit(value: unknown): number {
  const parsed = numberValue(value);
  if (parsed == undefined || !Number.isFinite(parsed)) return 5;
  return Math.max(1, Math.min(10, Math.floor(parsed)));
}
export async function loadMenuItemsForImageAudit(
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
      "id, venue_id, updated_at, name, description, category, class, menu_context, menu_context_status, menu_context_error, menu_context_model, menu_context_attempts, menu_context_locked, menu_context_updated_at, image_url, image_source, image_status, image_model, image_prompt, image_error, image_attempts, image_locked, image_storage_path, tags",
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
export async function loadMenuItemForImageGeneration(
  supabase: ReturnType<typeof adminClient>,
  venueId: string,
  itemId: string,
): Promise<MenuItemRecord> {
  const { data, error } = await supabase
    .from("dinein_menu_items")
    .select(
      "id, venue_id, updated_at, name, description, category, class, menu_context, menu_context_status, menu_context_error, menu_context_model, menu_context_attempts, menu_context_locked, menu_context_updated_at, image_url, image_source, image_status, image_model, image_prompt, image_error, image_attempts, image_locked, image_storage_path, tags",
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
      "id, venue_id, updated_at, name, description, category, class, menu_context, menu_context_status, menu_context_error, menu_context_model, menu_context_attempts, menu_context_locked, menu_context_updated_at, image_url, image_source, image_status, image_model, image_prompt, image_error, image_attempts, image_locked, image_storage_path, tags",
    )
    .eq("venue_id", venueId)
    .eq("image_locked", false)
    .order("id", { ascending: true })
    .limit(limit);

  query = query.or(menuImageBackfillEligibilityFilter(forceRegenerate));

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
  } else if (!(await isServiceRoleRequest(req))) {
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
