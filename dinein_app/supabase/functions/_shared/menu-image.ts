import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { buildGeminiImageGenerationConfig } from "./gemini-image-config.ts";

export interface FunctionEnv {
  supabaseUrl: string;
  supabaseAnonKey: string;
  supabaseServiceRoleKey: string;
  geminiApiKey: string;
  geminiImageModels: string[];
  menuImageBucket: string;
  cronSecret: string | null;
}

export type Json = Record<string, unknown>;

export interface MenuItemRecord {
  id: string;
  venue_id: string;
  name: string;
  description: string | null;
  category: string | null;
  image_url: string | null;
  image_source: string | null;
  image_status: string | null;
  image_model: string | null;
  image_error: string | null;
  image_attempts: number | null;
  image_locked: boolean | null;
  image_storage_path: string | null;
  tags: string[] | null;
}

export interface VenueRecord {
  id: string;
  name: string;
  category: string | null;
  description: string | null;
  owner_id: string | null;
}

export interface VenueSessionInput {
  venue_id?: string;
  contact_phone?: string;
}

export interface InvocationActor {
  kind: "cron" | "service" | "user" | "anonymous";
  userId?: string;
}

export interface ProcessMenuImageOptions {
  adminClient: ReturnType<typeof createAdminClient>;
  env: FunctionEnv;
  item: MenuItemRecord;
  venue: VenueRecord;
  forceRegenerate?: boolean;
}

export interface MenuImageProcessResult {
  status: "success" | "skipped";
  itemId: string;
  venueId: string;
  imageStatus: "ready" | "pending" | "generating" | "failed";
  imageSource: "manual" | "ai_gemini" | null;
  imageUrl: string | null;
  storagePath: string | null;
  model: string | null;
  reason?: string;
}

interface ReusableMenuImageRecord {
  id: string;
  image_url: string;
  image_storage_path: string;
  image_model: string | null;
}

export class HttpError extends Error {
  constructor(
    public readonly status: number,
    message: string,
    public readonly details?: unknown,
  ) {
    super(message);
  }
}

export function getFunctionEnv(): FunctionEnv {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim() ?? "";
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")?.trim() ?? "";
  const supabaseServiceRoleKey = Deno.env.get("SERVICE_ROLE_KEY")?.trim() ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() ?? "";
  const geminiApiKey = Deno.env.get("GEMINI_API_KEY")?.trim() ?? "";

  if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey) {
    throw new HttpError(
      500,
      "Missing Supabase environment variables for menu image generation.",
    );
  }

  if (!geminiApiKey) {
    throw new HttpError(
      500,
      "Missing GEMINI_API_KEY for menu image generation.",
    );
  }

  return {
    supabaseUrl,
    supabaseAnonKey,
    supabaseServiceRoleKey,
    geminiApiKey,
    geminiImageModels: (
      Deno.env.get("GEMINI_IMAGE_MODELS") ??
        "gemini-3.1-flash-image-preview,gemini-2.5-flash-image"
    )
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean),
    menuImageBucket: Deno.env.get("MENU_IMAGE_BUCKET")?.trim() || "menu-images",
    cronSecret: Deno.env.get("MENU_IMAGE_CRON_SECRET")?.trim() || null,
  };
}

export function createAdminClient(env: FunctionEnv) {
  return createClient(env.supabaseUrl, env.supabaseServiceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}

export function createRequestScopedClient(req: Request, env: FunctionEnv) {
  return createClient(env.supabaseUrl, env.supabaseAnonKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
    global: {
      headers: {
        Authorization: req.headers.get("Authorization") ?? "",
      },
    },
  });
}

export async function resolveInvocationActor(
  req: Request,
  env: FunctionEnv,
): Promise<InvocationActor> {
  const cronSecret = req.headers.get("x-cron-secret");
  if (env.cronSecret && cronSecret === env.cronSecret) {
    return { kind: "cron" };
  }

  const authHeader = req.headers.get("Authorization");
  const serviceRole = decodeJwtRole(authHeader);
  if (serviceRole === "service_role") {
    return { kind: "service" };
  }

  if (!authHeader) {
    return { kind: "anonymous" };
  }

  const client = createRequestScopedClient(req, env);
  const { data, error } = await client.auth.getUser();

  if (error || !data.user) {
    return { kind: "anonymous" };
  }

  return {
    kind: "user",
    userId: data.user.id,
  };
}

export async function fetchMenuItem(
  adminClient: ReturnType<typeof createAdminClient>,
  itemId: string,
): Promise<MenuItemRecord> {
  const { data, error } = await adminClient
    .from("dinein_menu_items")
    .select(
      "id, venue_id, name, description, category, image_url, image_source, image_status, image_model, image_error, image_attempts, image_locked, image_storage_path, tags",
    )
    .eq("id", itemId)
    .maybeSingle();

  if (error) {
    throw new HttpError(
      500,
      `Unable to load menu item "${itemId}": ${error.message}`,
      error,
    );
  }

  if (!data) {
    throw new HttpError(404, `Menu item "${itemId}" was not found.`);
  }

  return data as MenuItemRecord;
}

export async function fetchVenue(
  adminClient: ReturnType<typeof createAdminClient>,
  venueId: string,
): Promise<VenueRecord> {
  const { data, error } = await adminClient
    .from("dinein_venues")
    .select("id, name, category, description, owner_id")
    .eq("id", venueId)
    .maybeSingle();

  if (error) {
    throw new HttpError(
      500,
      `Unable to load venue "${venueId}": ${error.message}`,
      error,
    );
  }

  if (!data) {
    throw new HttpError(404, `Venue "${venueId}" was not found.`);
  }

  return data as VenueRecord;
}

export async function assertVenueAccess(
  actor: InvocationActor,
  venue: VenueRecord,
  adminClient: ReturnType<typeof createAdminClient>,
  body: Json,
): Promise<void> {
  if (actor.kind === "cron" || actor.kind === "service") {
    return;
  }

  if (actor.kind === "user" && actor.userId) {
    const role = await fetchUserRole(adminClient, actor.userId);
    if (role === "admin" || venue.owner_id === actor.userId) {
      return;
    }
  }

  const venueSession = getVenueSession(body);
  if (!venueSession?.venue_id || !venueSession.contact_phone) {
    throw new HttpError(401, "Venue session required.");
  }

  if (venueSession.venue_id !== venue.id) {
    throw new HttpError(403, "Venue session does not match requested venue.");
  }

  const approvedClaim = await getApprovedClaimForVenueContact(
    adminClient,
    venue.id,
    normalizeContact(venueSession.contact_phone),
  );

  if (!approvedClaim) {
    throw new HttpError(403, "Venue access not granted.");
  }
}

export async function processMenuItemImageGeneration(
  options: ProcessMenuImageOptions,
): Promise<MenuImageProcessResult> {
  const { adminClient, env, item, venue, forceRegenerate = false } = options;

  const hasExistingImage = Boolean(item.image_url?.trim());
  const imageLocked = item.image_locked == true;
  const imageSource = item.image_source;

  if (imageLocked) {
    return {
      status: "skipped",
      itemId: item.id,
      venueId: item.venue_id,
      imageStatus: normalizeImageStatus(item.image_status),
      imageSource: normalizeImageSource(imageSource),
      imageUrl: item.image_url,
      storagePath: item.image_storage_path,
      model: item.image_model,
      reason: "image_locked",
    };
  }

  if (hasExistingImage && imageSource === "manual") {
    await normalizeExistingMenuImageState(adminClient, item);
    return {
      status: "skipped",
      itemId: item.id,
      venueId: item.venue_id,
      imageStatus: normalizeImageStatus(item.image_status),
      imageSource: "manual",
      imageUrl: item.image_url,
      storagePath: item.image_storage_path,
      model: item.image_model,
      reason: "manual_image_exists",
    };
  }

  if (!forceRegenerate && item.image_status === "generating") {
    return {
      status: "skipped",
      itemId: item.id,
      venueId: item.venue_id,
      imageStatus: "generating",
      imageSource: normalizeImageSource(imageSource),
      imageUrl: item.image_url,
      storagePath: item.image_storage_path,
      model: item.image_model,
      reason: "already_generating",
    };
  }

  if (
    hasExistingImage &&
    imageSource === "ai_gemini" &&
    !forceRegenerate
  ) {
    await normalizeExistingMenuImageState(adminClient, item);
    return {
      status: "skipped",
      itemId: item.id,
      venueId: item.venue_id,
      imageStatus: "ready",
      imageSource: "ai_gemini",
      imageUrl: item.image_url,
      storagePath: item.image_storage_path,
      model: item.image_model,
      reason: "ai_image_exists",
    };
  }

  if (hasExistingImage && !forceRegenerate) {
    await normalizeExistingMenuImageState(adminClient, item);
    return {
      status: "skipped",
      itemId: item.id,
      venueId: item.venue_id,
      imageStatus: "ready",
      imageSource: normalizeImageSource(imageSource),
      imageUrl: item.image_url,
      storagePath: item.image_storage_path,
      model: item.image_model,
      reason: "existing_image_exists",
    };
  }

  await updateGenerationState(adminClient, item.id, {
    image_status: "generating",
    image_error: null,
    updated_at: new Date().toISOString(),
  });

  const prompt = buildMenuImagePrompt(item, venue);
  const nextAttempt = (item.image_attempts ?? 0) + 1;

  try {
    if (!forceRegenerate) {
      const reusableImage = await findReusableMenuImage(adminClient, item);
      if (reusableImage) {
        return await cloneReusableMenuImage({
          adminClient,
          bucket: env.menuImageBucket,
          item,
          prompt,
          nextAttempt,
          reusableImage,
        });
      }
    }

    const generated = await generateGeminiImage({
      apiKey: env.geminiApiKey,
      models: env.geminiImageModels,
      prompt,
    });

    const extension = extensionForMimeType(generated.mimeType);
    const storagePath =
      `menu-items/${item.venue_id}/${item.id}/generated-${Date.now()}.${extension}`;

    const { error: uploadError } = await adminClient.storage
      .from(env.menuImageBucket)
      .upload(storagePath, generated.bytes, {
        contentType: generated.mimeType,
        upsert: false,
      });

    if (uploadError) {
      throw new HttpError(
        502,
        `Unable to upload the generated image to storage: ${uploadError.message}`,
        uploadError,
      );
    }

    await cleanupPreviousImage(
      adminClient,
      env.menuImageBucket,
      item,
      storagePath,
    );

    const {
      data: { publicUrl },
    } = adminClient.storage.from(env.menuImageBucket).getPublicUrl(storagePath);

    await updateGenerationState(adminClient, item.id, {
      image_url: publicUrl,
      image_source: "ai_gemini",
      image_status: "ready",
      image_model: generated.model,
      image_prompt: prompt,
      image_generated_at: new Date().toISOString(),
      image_error: null,
      image_attempts: nextAttempt,
      image_storage_path: storagePath,
      updated_at: new Date().toISOString(),
    });

    return {
      status: "success",
      itemId: item.id,
      venueId: item.venue_id,
      imageStatus: "ready",
      imageSource: "ai_gemini",
      imageUrl: publicUrl,
      storagePath,
      model: generated.model,
    };
  } catch (error) {
    const message = getErrorMessage(error);

    await updateGenerationState(adminClient, item.id, {
      image_status: "failed",
      image_error: message,
      image_attempts: nextAttempt,
      updated_at: new Date().toISOString(),
    });

    throw error;
  }
}

async function findReusableMenuImage(
  adminClient: ReturnType<typeof createAdminClient>,
  item: MenuItemRecord,
): Promise<ReusableMenuImageRecord | null> {
  const { data, error } = await adminClient
    .from("dinein_menu_items")
    .select("id, image_url, image_storage_path, image_model")
    .neq("id", item.id)
    .eq("name", item.name)
    .eq("category", item.category ?? "Uncategorized")
    .eq("description", item.description ?? "")
    .eq("image_status", "ready")
    .eq("image_source", "ai_gemini")
    .not("image_url", "is", null)
    .not("image_storage_path", "is", null)
    .order("updated_at", { ascending: false })
    .limit(1);

  if (error) {
    throw new HttpError(
      500,
      `Unable to look up reusable menu images: ${error.message}`,
      error,
    );
  }

  const candidate = (data?.[0] as ReusableMenuImageRecord | undefined) ?? null;
  if (!candidate?.image_url?.trim() || !candidate.image_storage_path?.trim()) {
    return null;
  }

  return candidate;
}

async function cloneReusableMenuImage({
  adminClient,
  bucket,
  item,
  prompt,
  nextAttempt,
  reusableImage,
}: {
  adminClient: ReturnType<typeof createAdminClient>;
  bucket: string;
  item: MenuItemRecord;
  prompt: string;
  nextAttempt: number;
  reusableImage: ReusableMenuImageRecord;
}): Promise<MenuImageProcessResult> {
  const extension = extensionFromStoragePath(reusableImage.image_storage_path);
  const storagePath =
    `menu-items/${item.venue_id}/${item.id}/reused-${Date.now()}.${extension}`;

  const { error: copyError } = await adminClient.storage
    .from(bucket)
    .copy(reusableImage.image_storage_path, storagePath);

  if (copyError) {
    throw new HttpError(
      502,
      `Unable to clone an existing menu image from storage: ${copyError.message}`,
      copyError,
    );
  }

  await cleanupPreviousImage(adminClient, bucket, item, storagePath);

  const {
    data: { publicUrl },
  } = adminClient.storage.from(bucket).getPublicUrl(storagePath);

  await updateGenerationState(adminClient, item.id, {
    image_url: publicUrl,
    image_source: "ai_gemini",
    image_status: "ready",
    image_model: reusableImage.image_model,
    image_prompt: prompt,
    image_generated_at: new Date().toISOString(),
    image_error: null,
    image_attempts: nextAttempt,
    image_storage_path: storagePath,
    updated_at: new Date().toISOString(),
  });

  return {
    status: "success",
    itemId: item.id,
    venueId: item.venue_id,
    imageStatus: "ready",
    imageSource: "ai_gemini",
    imageUrl: publicUrl,
    storagePath,
    model: reusableImage.image_model,
  };
}

async function cleanupPreviousImage(
  adminClient: ReturnType<typeof createAdminClient>,
  bucket: string,
  item: MenuItemRecord,
  nextStoragePath: string,
): Promise<void> {
  const previousStoragePath = item.image_storage_path?.trim();
  if (!previousStoragePath || previousStoragePath === nextStoragePath) {
    return;
  }

  const { count, error } = await adminClient
    .from("dinein_menu_items")
    .select("id", { count: "exact", head: true })
    .eq("image_storage_path", previousStoragePath)
    .neq("id", item.id);

  if (error) {
    throw new HttpError(
      500,
      `Unable to verify previous image references: ${error.message}`,
      error,
    );
  }

  if ((count ?? 0) > 0) {
    return;
  }

  await adminClient.storage
    .from(bucket)
    .remove([previousStoragePath]);
}

export function getErrorMessage(error: unknown): string {
  if (error instanceof HttpError) {
    return error.message;
  }

  if (error instanceof Error) {
    return error.message;
  }

  return String(error);
}

function decodeJwtRole(authHeader: string | null): string | null {
  if (!authHeader?.startsWith("Bearer ")) return null;

  const token = authHeader.substring("Bearer ".length).trim();
  const parts = token.split(".");
  if (parts.length != 3) return null;

  try {
    const payload = JSON.parse(decodeBase64Url(parts[1]));
    return typeof payload.role === "string" ? payload.role : null;
  } catch (_) {
    return null;
  }
}

function decodeBase64Url(value: string): string {
  const normalized = value.replaceAll("-", "+").replaceAll("_", "/");
  const padded = normalized.padEnd(
    normalized.length + ((4 - normalized.length % 4) % 4),
    "=",
  );
  return atob(padded);
}

function normalizeContact(value: unknown): string {
  if (typeof value !== "string") return "";
  const trimmed = value.trim();
  const startsWithPlus = trimmed.startsWith("+");
  const digits = trimmed.replaceAll(/[^0-9]/g, "");
  if (!digits) return trimmed;
  return startsWithPlus ? `+${digits}` : digits;
}

async function fetchUserRole(
  adminClient: ReturnType<typeof createAdminClient>,
  userId: string,
): Promise<string | null> {
  const { data, error } = await adminClient
    .from("dinein_profiles")
    .select("role")
    .eq("id", userId)
    .maybeSingle();

  if (error) {
    throw new HttpError(500, error.message, error);
  }

  return (data?.role as string | null) ?? null;
}

async function getApprovedClaimForVenueContact(
  adminClient: ReturnType<typeof createAdminClient>,
  venueId: string,
  contact: string,
): Promise<unknown | null> {
  const fields = ["whatsapp_number", "contact_phone", "email"];

  for (const field of fields) {
    const { data, error } = await adminClient
      .from("dinein_venue_claims")
      .select("*")
      .eq("venue_id", venueId)
      .eq(field, contact)
      .eq("status", "approved")
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (error) {
      continue;
    }

    if (data) {
      return data;
    }
  }

  return null;
}

function getVenueSession(body: Json): VenueSessionInput | null {
  const raw = body.venue_session;
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    return null;
  }
  return raw as VenueSessionInput;
}

function normalizeImageStatus(
  value: string | null,
): "pending" | "generating" | "ready" | "failed" {
  switch (value) {
    case "generating":
    case "ready":
    case "failed":
      return value;
    default:
      return "pending";
  }
}

function normalizeImageSource(
  value: string | null,
): "manual" | "ai_gemini" | null {
  switch (value) {
    case "manual":
    case "ai_gemini":
      return value;
    default:
      return null;
  }
}

function extensionForMimeType(mimeType: string): string {
  switch (mimeType) {
    case "image/jpeg":
      return "jpg";
    case "image/webp":
      return "webp";
    default:
      return "png";
  }
}

function extensionFromStoragePath(storagePath: string): string {
  const trimmed = storagePath.trim();
  const dotIndex = trimmed.lastIndexOf(".");
  if (dotIndex <= -1 || dotIndex == trimmed.length - 1) {
    return "jpg";
  }
  return trimmed.substring(dotIndex + 1).toLowerCase();
}

async function updateGenerationState(
  adminClient: ReturnType<typeof createAdminClient>,
  itemId: string,
  updates: Record<string, unknown>,
): Promise<void> {
  const { error } = await adminClient
    .from("dinein_menu_items")
    .update(updates)
    .eq("id", itemId);

  if (error) {
    throw new HttpError(
      500,
      `Unable to update the menu item generation state: ${error.message}`,
      error,
    );
  }
}

async function normalizeExistingMenuImageState(
  adminClient: ReturnType<typeof createAdminClient>,
  item: MenuItemRecord,
): Promise<void> {
  if (
    normalizeImageStatus(item.image_status) === "ready" && !item.image_error
  ) {
    return;
  }

  await updateGenerationState(adminClient, item.id, {
    image_status: "ready",
    image_error: null,
    updated_at: new Date().toISOString(),
  });
}

function buildMenuImagePrompt(
  item: MenuItemRecord,
  venue: VenueRecord,
): string {
  const venueCategory = venue.category?.trim() || "Restaurants";
  const itemCategory = item.category?.trim() || "menu item";
  const itemDescription = item.description?.trim() ||
    "Premium menu item.";
  const venueDescription = venue.description?.trim() ||
    "Premium hospitality venue with a refined, dark, elevated atmosphere.";
  const tags = (item.tags ?? []).map((tag) => tag.trim()).filter(Boolean);
  const tagsLine = tags.length > 0 ? tags.join(", ") : "none";
  const visualKind = classifyMenuVisualKind(item, venue);
  const artDirection = buildMenuArtDirection(visualKind, venue);
  const isDrink = isBeverageKind(visualKind);
  const typeLabel = isDrink ? "BEVERAGE / DRINK" : "FOOD / PLATED DISH";
  const cuisineHint = detectCuisineHint(item, venue);

  return `
Create a photorealistic premium menu image for a luxury dark-mode hospitality mobile app.

═══ ITEM TYPE CLASSIFICATION (MOST CRITICAL RULE) ═══
This item is classified as: ${typeLabel}
Visual kind: ${visualKind}
${
    isDrink
      ? `THIS IS A DRINK. You MUST show a beverage — a glass, bottle, cup, or can.
   You MUST NOT show any plated food, dishes, bowls of food, or meal presentations.
   If the name says "Cisk Lager", show a beer. If it says "Mojito", show a cocktail.
   NEVER show food when the item is a drink. This is the #1 rule.`
      : `THIS IS FOOD. You MUST show a plated dish or dessert.
   You MUST NOT show drinks as the hero subject.
   If the name says "Margherita Pizza", show a pizza. If it says "Ftira", show Maltese ftira bread.
   The food must be the unmistakable hero of the image.`
  }

═══ PRIMARY SUBJECT (ground truth — do not deviate) ═══
Dish/drink name: "${item.name}"
Category: "${itemCategory}"
Description: "${itemDescription}"
Tags: ${tagsLine}

The image MUST depict EXACTLY what the name and description say.
- If the name is "Margherita Pizza", show a Margherita pizza, not generic pasta.
- If the description says "grilled", show grill marks. If "fried", show fried texture.
- If "vegetarian" or "vegan" tag is present, absolutely NO meat visible.
- The name is ground truth. Never reinterpret or substitute.

═══ VENUE CONTEXT ═══
Venue: ${venue.name}
Venue type: ${venueCategory}
Atmosphere: ${venueDescription}

═══ APP DESIGN SYSTEM (match this mood, do NOT render UI) ═══
The image will appear inside a dark mobile menu card with these properties:
- Card background: near-black (#1A1C1E)
- App background: dark charcoal (#121416)
- Primary accent: warm gold (#E1C28E)
- Secondary accent: mint green (#A1D494)
- Tertiary accent: soft lavender (#B9C6E9)
- Overall mood: premium, dark, refined, modern luxury

The image must harmonize with this dark palette:
- Background and edge tones should blend toward dark charcoal (#121416 to #1A1C1E).
- Use dark vignetting or shallow depth of field so image edges dissolve into the card.
- Avoid bright white, pure white, or high-contrast edges that would clash with the dark card.
- Warm tones (amber, gold, copper) are preferred over cool blues or stark whites.

═══ ART DIRECTION ═══
Visual target: ${artDirection.visualTarget}
- Square 1:1 composition optimized for a 96×96px thumbnail and 220px hero crop.
- ${artDirection.lighting}
- ${artDirection.styling}
- ${artDirection.subject}
- ${artDirection.background}
${cuisineHint ? `- Cuisine styling: ${cuisineHint}` : ""}
- Center the main subject. It must be immediately recognizable even at small thumbnail size.
- Use realistic scale, believable texture, and credible hospitality presentation.

═══ HARD EXCLUSIONS (never violate) ═══
${
    isDrink
      ? "- ABSOLUTELY NO FOOD. No plates, no bowls, no plated dishes, no side dishes, no garnish plates."
      : "- ABSOLUTELY NO DRINKS as the hero subject. No glasses, bottles, or cups as the main focus."
  }
- No text overlays, watermarks, logos, borders, price tags, menus, or collage layouts.
- No people, hands, phones, cash, receipts, or table clutter.
- No cartoon styling, surreal plating, AI artifacts, or oversaturated neon color.
- No ingredients not mentioned in the description.
- No chopsticks unless the cuisine is clearly Asian.
- Do not add extra items — show ONE hero subject, not a table spread.
`.trim();
}

function isBeverageKind(kind: MenuVisualKind): boolean {
  return [
    "packaged_beer",
    "draft_beer",
    "cocktail",
    "wine",
    "spirits",
    "coffee",
    "tea",
    "soft_drink",
  ].includes(kind);
}

function detectCuisineHint(
  item: MenuItemRecord,
  venue: VenueRecord,
): string | null {
  // Use item-level data primarily; venue context for ambience only
  const context = normalizePromptText(
    [
      item.name,
      item.category,
      item.description,
      (item.tags ?? []).join(" "),
    ].filter(Boolean).join(" "),
  );

  // Rwandan / East African (must be checked first for RW venues)
  if (
    matchesAny(context, [
      "rwandan",
      "brochette",
      "brochettes",
      "isombe",
      "ugali",
      "ubugali",
      "matoke",
      "ibitoke",
      "ibihaza",
      "sambaza",
      "agatogo",
      "igisafuliya",
      "akabenz",
      "nyama choma",
      "kachumbari",
      "pili pili",
      "mandazi",
      "chapati",
      "mishikaki",
      "dodo",
      "amaranth",
      "cassava",
      "plantain",
      "tilapia",
      "nile perch",
      "pilau",
      "groundnut",
      "peanut stew",
      "rolex",
      "east african",
      "urwagwa",
      "ikigage",
      "ubuki",
      "icyayi",
    ])
  ) {
    return "Rwandan/East African — warm charcoal-grill tones, rustic dark wood or banana-leaf surfaces, generous communal portions, earthy warm palette with green and ochre accents.";
  }

  if (
    matchesAny(context, [
      "maltese",
      "ftira",
      "pastizzi",
      "rabbit",
      "fenek",
      "lampuki",
      "bigilla",
      "gbejniet",
      "mediterranean",
      "sicilian",
    ])
  ) {
    return "Mediterranean/Maltese — warm natural sunlight tones, limestone or terracotta surfaces, rustic ceramic plates, earthy olive and ochre palette.";
  }

  if (
    matchesAny(context, [
      "japanese",
      "sushi",
      "ramen",
      "tempura",
      "izakaya",
      "poke",
      "bento",
      "miso",
      "katsu",
      "thai",
      "pad thai",
      "kimchi",
      "korean",
      "dim sum",
      "wonton",
      "noodle",
      "dumpling",
      "asian",
      "chinese",
      "vietnamese",
    ])
  ) {
    return "Asian — moody evening light, dark ceramic or lacquer surfaces, precise minimalist plating, bamboo or slate textures.";
  }

  if (
    matchesAny(context, [
      "italian",
      "pasta",
      "risotto",
      "bruschetta",
      "tiramisu",
      "al forno",
      "prosciutto",
      "antipasti",
      "calzone",
      "gnocchi",
      "osso buco",
      "carpaccio",
    ])
  ) {
    return "Italian — golden warmth, classic white or cream crockery, rustic-refined presentation, olive wood accents.";
  }

  if (
    matchesAny(context, [
      "bbq",
      "barbecue",
      "ribs",
      "brisket",
      "pulled pork",
      "smoked",
      "burger",
      "steak",
      "grill",
    ])
  ) {
    return "American/BBQ — warm rustic tones, dark wood or cast iron surfaces, hearty generous portions, smoky atmosphere.";
  }

  if (
    matchesAny(context, [
      "middle eastern",
      "shawarma",
      "falafel",
      "hummus",
      "kebab",
      "tabbouleh",
      "mezze",
      "labneh",
      "pita",
      "baklava",
      "tahini",
    ])
  ) {
    return "Middle Eastern — warm golden light, hammered copper or ceramic serving dishes, colorful spice tones, generous plating.";
  }

  if (
    matchesAny(context, [
      "indian",
      "curry",
      "tikka",
      "masala",
      "naan",
      "biryani",
      "samosa",
      "dal",
      "tandoori",
      "paneer",
      "chai",
    ])
  ) {
    return "Indian — rich warm tones, brass or copper serving bowls, vibrant spice colors, layered textures.";
  }

  return null;
}

type MenuVisualKind =
  | "plated_food"
  | "dessert"
  | "packaged_beer"
  | "draft_beer"
  | "cocktail"
  | "wine"
  | "spirits"
  | "coffee"
  | "tea"
  | "soft_drink";

interface MenuArtDirection {
  visualTarget: string;
  lighting: string;
  styling: string;
  subject: string;
  background: string;
}

function classifyMenuVisualKind(
  item: MenuItemRecord,
  _venue: VenueRecord,
): MenuVisualKind {
  const tags = (item.tags ?? []).join(" ");
  // IMPORTANT: Only use item-level data for classification.
  // Including venue.category / venue.description causes
  // misclassification (e.g. a burger at a "bar" gets tagged as beer).
  const itemCategory = normalizePromptText(item.category ?? "");
  const itemName = normalizePromptText(item.name ?? "");
  const context = normalizePromptText(
    [
      item.name,
      item.category,
      item.description,
      tags,
    ].filter(Boolean).join(" "),
  );

  // ─── CATEGORY-FIRST OVERRIDE ─────────────────────────────────────
  // Food categories must NEVER be classified as drinks, even when
  // the description mentions accompaniments like "served with wine sauce"
  // or "breakfast … juice and coffee".
  const foodCategoryPrefixes = [
    "mains", "main", "breakfast", "lunch", "dinner",
    "soup", "soups", "salad", "salads", "starter", "starters",
    "appetizer", "appetizers", "sandwich", "sandwiches", "wrap", "wraps",
    "burger", "burgers", "pizza", "pasta", "grill", "bbq",
    "sides", "side", "accompaniment", "accompaniments",
    "rwandan traditional", "hotel buffet", "indian cuisine",
    "seafood", "fish",
  ];
  const dessertCategoryPrefixes = [
    "dessert", "desserts", "pastry", "pastries", "bakery",
  ];

  if (dessertCategoryPrefixes.some((p) => itemCategory.startsWith(p) || itemCategory.includes(p))) {
    return "dessert";
  }

  if (foodCategoryPrefixes.some((p) => itemCategory.startsWith(p) || itemCategory.includes(p))) {
    return "plated_food";
  }

  // ─── DRINK KEYWORD MATCHING (only reached for non-food categories) ─
  if (
    matchesAny(context, [
      "beer",
      "lager",
      "ale",
      "ipa",
      "stout",
      "porter",
      "pilsner",
      "pale ale",
      "cider",
      "cisk",
      "hopleaf",
      "blue label",
      "lacto",
      "wheat beer",
      "amber ale",
      "craft beer",
    ])
  ) {
    if (matchesAny(context, ["draft", "draught", "tap", "pint", "on tap"])) {
      return "draft_beer";
    }
    return "packaged_beer";
  }

  if (
    matchesAny(context, [
      "cocktail",
      "mocktail",
      "mojito",
      "margarita",
      "martini",
      "negroni",
      "spritz",
      "aperol spritz",
      "old fashioned",
      "gin tonic",
      "gin and tonic",
      "sour",
      "daiquiri",
      "cosmopolitan",
      "manhattan",
      "bellini",
      "sangria",
      "pina colada",
      "caipirinha",
      "long island",
    ])
  ) {
    return "cocktail";
  }

  if (
    matchesAny(context, [
      "wine",
      "prosecco",
      "champagne",
      "chardonnay",
      "merlot",
      "cabernet",
      "pinot",
      "sauvignon",
      "rose",
      "rosé",
    ])
  ) {
    return "wine";
  }

  if (
    matchesAny(context, [
      "whisky",
      "whiskey",
      "vodka",
      "rum",
      "gin",
      "tequila",
      "mezcal",
      "cognac",
      "brandy",
      "liqueur",
      "digestif",
      "spirit",
      "shot",
      "limoncello",
      "grappa",
      "aperitif",
      "aperol",
      "campari",
      "amaro",
      "sambuca",
      "absinthe",
      "vermouth",
      "port",
      "sherry",
      "bourbon",
      "scotch",
      "single malt",
    ])
  ) {
    return "spirits";
  }

  if (
    matchesAny(context, [
      "coffee",
      "espresso",
      "americano",
      "cappuccino",
      "latte",
      "flat white",
      "macchiato",
      "mocha",
      "frappe",
      "iced coffee",
      "affogato",
      "cortado",
      "ristretto",
      "cold brew",
      "irish coffee",
    ])
  ) {
    return "coffee";
  }

  if (
    matchesAny(context, [
      "tea",
      "matcha",
      "chai",
      "earl grey",
      "herbal",
      "green tea",
      "oolong",
      "chamomile",
      "peppermint",
      "infusion",
    ])
  ) {
    return "tea";
  }

  if (
    matchesAny(context, [
      "beverage",
      "beverages",
      "drink",
      "drinks",
      "soft drinks",
      "fanta",
      "coke",
      "coca cola",
      "pepsi",
      "sprite",
      "schweppes",
      "7up",
      "red bull",
      "monster",
      "cola",
      "soda",
      "soft drink",
      "juice",
      "lemonade",
      "tonic",
      "sparkling water",
      "still water",
      "energy drink",
      "kombucha",
      "smoothie",
      "milkshake",
      "kinnie",
      "zest",
      "san pellegrino",
      "perrier",
      "acqua panna",
      "orangina",
      "iced tea",
      "squash",
      "cordial",
    ])
  ) {
    return "soft_drink";
  }

  if (
    matchesAny(context, [
      "dessert",
      "cake",
      "brownie",
      "tiramisu",
      "cheesecake",
      "ice cream",
      "gelato",
      "sorbet",
      "pudding",
      "croissant",
      "pastry",
      "cookie",
      "waffle",
      "pancake",
      "imqaret",
      "helwa tat-tork",
      "qaghaq tal-ghasel",
      "kannoli",
      "cannoli",
      "profiterole",
      "panna cotta",
      "creme brulee",
      "mousse",
      "tart",
      "eclair",
      "macaron",
      "baklava",
      "churro",
    ])
  ) {
    return "dessert";
  }

  return "plated_food";
}

function buildMenuArtDirection(
  visualKind: MenuVisualKind,
  venue: VenueRecord,
): MenuArtDirection {
  const venueContext = normalizePromptText(
    [
      venue.category,
      venue.description,
    ].filter(Boolean).join(" "),
  );
  const barLike = matchesAny(venueContext, ["bar", "pub", "lounge", "night"]);
  const cafeLike = matchesAny(venueContext, ["cafe", "coffee", "bakery"]);

  switch (visualKind) {
    case "packaged_beer":
      return {
        visualTarget: "chilled packaged beer hero shot",
        lighting: barLike
          ? "Use cinematic evening bar lighting with amber highlights and crisp condensation detail."
          : "Use premium commercial beverage lighting with sharp reflections and clean contrast.",
        styling:
          "Treat this as beverage product photography, not plated food. The named beer should be the hero object, shown as a chilled bottle or can, with correct serving context and optional clean glassware only if appropriate.",
        subject:
          "Show the beverage itself clearly and accurately, with realistic liquid color, condensation, and credible packaging cues aligned with the item name and description.",
        background:
          "Use a refined bar counter or premium hospitality surface. Background tones must blend toward dark charcoal (#121416 to #1A1C1E) with warm brass or amber accents. Apply dark vignetting at edges.",
      };
    case "draft_beer":
      return {
        visualTarget: "freshly poured draft beer",
        lighting:
          "Use premium evening hospitality lighting with warm highlights passing through the beer and a crisp, believable head.",
        styling:
          "Center a freshly poured draft beer in appropriate glassware with realistic foam, clarity, and temperature cues. No food on the plate or table.",
        subject:
          "The drink must be unmistakably beer-first, with the pour and glassware presented cleanly for a menu card crop.",
        background:
          "Use a clean bar surface or taproom-inspired luxury backdrop. Background tones must blend toward dark charcoal (#121416 to #1A1C1E) with warm amber depth. Dark vignette at edges.",
      };
    case "cocktail":
      return {
        visualTarget: "signature cocktail hero shot",
        lighting:
          "Use moody cocktail-bar lighting with precise highlights on the glass, liquid, and garnish.",
        styling:
          "Show one hero cocktail in correct glassware with garnish only when it matches the drink style. No plated food, no extra drinks, no messy bar clutter.",
        subject:
          "Make the beverage color, ice, garnish, and glass proportions feel credible and premium.",
        background:
          "Use a refined dark-luxury bar setting with subtle brass or stone. Background tones must blend toward near-black (#121416) so the drink glows against the dark card. Dark vignette at edges.",
      };
    case "wine":
      return {
        visualTarget: "premium wine serve",
        lighting:
          "Use soft refined hospitality lighting with controlled reflections on the glass and bottle.",
        styling:
          "Center a premium wine serve with appropriate glassware and, when relevant, part of the bottle. Keep the composition restrained and elegant.",
        subject:
          "Accurately represent the wine style from the item name and description. No unrelated food or cheese boards unless explicitly part of the item.",
        background:
          "Use a high-end restaurant or lounge backdrop. Background tones must fade to dark charcoal (#121416 to #1A1C1E) with warm depth. Dark vignette at edges.",
      };
    case "spirits":
      return {
        visualTarget: "premium spirit pour or bottle serve",
        lighting:
          "Use strong editorial lighting that defines the bottle, glass, and liquid while preserving a premium nightlife mood.",
        styling:
          "Treat this as a spirit service image with bottle and/or neat pour, correct glassware, and no unrelated plated food.",
        subject:
          "The spirit itself must read clearly as the hero, with realistic liquid tone and restrained garnish if appropriate.",
        background:
          "Use a polished dark bar backdrop. All background tones must blend toward near-black (#121416) with warm amber highlights only. Shallow depth of field and dark vignette at edges.",
      };
    case "coffee":
      return {
        visualTarget: "premium coffee beverage",
        lighting: cafeLike
          ? "Use warm morning cafe light with soft steam, ceramic texture, and natural highlights."
          : "Use clean editorial beverage lighting with warmth and gentle contrast.",
        styling:
          "Focus on the coffee beverage itself in appropriate cupware or glassware, with crema or foam detail when relevant. Do not add unrelated full meals.",
        subject:
          "The drink must feel premium, fresh, and realistic for a hospitality menu card.",
        background:
          "Use a refined cafe or lounge surface with wood, stone, or ceramic textures. Background tones must blend toward dark charcoal (#121416 to #1A1C1E). Dark vignette at edges.",
      };
    case "tea":
      return {
        visualTarget: "premium tea beverage",
        lighting:
          "Use soft calming hospitality lighting with subtle steam and elegant glass or ceramic reflections.",
        styling:
          "Center the tea service cleanly with the beverage as the hero. Keep props minimal and avoid unrelated food.",
        subject:
          "The infusion color, cupware, and temperature cues should be realistic and premium.",
        background:
          "Use a calm upscale cafe or hotel-lounge backdrop. Background tones must blend toward dark charcoal (#121416 to #1A1C1E) with clean depth. Dark vignette at edges.",
      };
    case "soft_drink":
      return {
        visualTarget: "chilled non-alcoholic beverage hero shot",
        lighting:
          "Use crisp commercial beverage lighting with clean reflections, ice detail, and refreshing contrast.",
        styling:
          "Show the named drink as a bottle, can, or served glass according to the item description. No plated food and no unrelated snacks.",
        subject:
          "The beverage itself must be clearly recognizable, cold, and premium rather than generic food photography.",
        background:
          "Use a polished hospitality surface or premium bar/cafe counter. Background tones must blend toward dark charcoal (#121416 to #1A1C1E). Dark vignette at edges.",
      };
    case "dessert":
      return {
        visualTarget: "premium dessert plating",
        lighting:
          "Use elegant editorial dessert lighting with soft highlights, controlled shadows, and rich texture definition.",
        styling:
          "Treat this as refined dessert photography with plated presentation sized correctly for a menu crop.",
        subject:
          "Keep the dessert centered and realistic, with accurate garnish, sauce, crumb, or cream detail only where appropriate.",
        background:
          "Use an upscale dining surface. Background tones must blend toward dark charcoal (#121416 to #1A1C1E) with warm modern depth. Dark vignette at edges.",
      };
    case "plated_food":
    default:
      return {
        visualTarget: "premium plated food",
        lighting:
          "Use high-end editorial food lighting with appetizing contrast, realistic highlights, and dark refined depth.",
        styling:
          "Show one hero plated dish with premium tableware, accurate portioning, and restrained garnish suited to the item.",
        subject:
          "The food itself must be the hero, centered and instantly legible in a mobile menu card crop.",
        background:
          "Use an elegant, warm, modern hospitality background. Background tones must blend toward dark charcoal (#121416 to #1A1C1E) with subtle warm accents. Dark vignette at edges.",
      };
  }
}

function normalizePromptText(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
}

function matchesAny(value: string, phrases: string[]): boolean {
  return phrases.some((phrase) => {
    const normalized = normalizePromptText(phrase);
    // Use word-boundary matching to avoid false positives like
    // "wine sauce" matching "wine" or "chapati" matching "chai"
    const escaped = normalized.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const wordBoundaryRegex = new RegExp(`(?:^|\\s|[^a-z0-9])${escaped}(?:\\s|[^a-z0-9]|$)`);
    return wordBoundaryRegex.test(value);
  });
}

interface GeminiImagePayload {
  bytes: Uint8Array;
  mimeType: string;
  model: string;
}

async function generateGeminiImage({
  apiKey,
  models,
  prompt,
}: {
  apiKey: string;
  models: string[];
  prompt: string;
}): Promise<GeminiImagePayload> {
  let lastError = "Gemini did not return an image.";

  for (const model of models) {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": apiKey,
        },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                {
                  text: prompt,
                },
              ],
            },
          ],
          generationConfig: buildGeminiImageGenerationConfig({
            aspectRatio: "1:1",
            imageSize: "1K",
          }),
        }),
      },
    );

    if (!response.ok) {
      lastError = await extractGeminiError(response);
      continue;
    }

    const json = await response.json();
    const payload = extractInlineImage(json);
    if (payload) {
      return {
        ...payload,
        model,
      };
    }

    lastError = `Model "${model}" returned no inline image payload.`;
  }

  throw new HttpError(502, lastError);
}

async function extractGeminiError(response: Response): Promise<string> {
  try {
    const payload = await response.json();
    return (
      payload?.error?.message ||
      `Gemini request failed with HTTP ${response.status}.`
    );
  } catch (_) {
    return `Gemini request failed with HTTP ${response.status}.`;
  }
}

function extractInlineImage(
  payload: unknown,
): { bytes: Uint8Array; mimeType: string } | null {
  if (!payload || typeof payload !== "object") return null;
  const candidates = (payload as { candidates?: unknown[] }).candidates ?? [];

  for (const candidate of candidates) {
    if (!candidate || typeof candidate !== "object") continue;
    const content = (candidate as { content?: { parts?: unknown[] } }).content;
    const parts = content?.parts ?? [];
    for (const part of parts) {
      if (!part || typeof part !== "object") continue;
      const inlineData = (
        part as { inlineData?: { data?: string; mimeType?: string } }
      ).inlineData;
      const data = inlineData?.data;
      if (!data) continue;
      return {
        bytes: decodeBase64ToBytes(data),
        mimeType: inlineData?.mimeType || "image/png",
      };
    }
  }

  return null;
}

function decodeBase64ToBytes(base64: string): Uint8Array {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}
