import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { buildGeminiImageGenerationConfig } from "./gemini-image-config.ts";
import {
  buildFallbackMenuItemResearchProfile,
  buildMenuItemResearchPrompt,
  extractJsonPayloadFromCandidate,
  extractResearchSourceUrls,
  inferMenuItemClass,
  type MenuItemClass,
  type MenuItemResearchProfile,
  menuItemResearchSchema,
  normalizeMenuItemClass,
  parseJsonObjectText,
  parseMenuItemResearchProfile,
  resolveMenuItemClass,
} from "./menu-item-context.ts";
import { verifySupabaseServiceRoleHeader } from "./signed-jwt.ts";

export interface FunctionEnv {
  supabaseUrl: string;
  supabaseAnonKey: string;
  supabaseServiceRoleKey: string;
  geminiApiKey: string;
  geminiImageModels: string[];
  menuItemResearchModels: string[];
  menuImageVerifierModels: string[];
  menuImageBucket: string;
  cronSecret: string | null;
}

export type Json = Record<string, unknown>;

export interface MenuItemRecord {
  id: string;
  venue_id: string;
  updated_at?: string | null;
  name: string;
  description: string | null;
  category: string | null;
  class: string | null;
  menu_context: Json | null;
  menu_context_status: string | null;
  menu_context_error: string | null;
  menu_context_model: string | null;
  menu_context_attempts: number | null;
  menu_context_locked: boolean | null;
  menu_context_updated_at: string | null;
  image_url: string | null;
  image_source: string | null;
  image_status: string | null;
  image_model: string | null;
  image_prompt: string | null;
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
  phone: string | null;
  owner_whatsapp_number: string | null;
}

export interface VenueSessionInput {
  access_token?: string;
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

export interface MenuImageAuditIssue {
  code:
    | "missing_image"
    | "image_failed"
    | "image_fetch_failed"
    | "image_verification_mismatch"
    | "image_prompt_metadata_stale"
    | "image_verification_unavailable";
  severity: "error" | "warning";
  message: string;
}

export interface AuditMenuImageOptions {
  adminClient: ReturnType<typeof createAdminClient>;
  env: FunctionEnv;
  item: MenuItemRecord;
  venue: VenueRecord;
  forceRefreshContext?: boolean;
  regenerateMismatch?: boolean;
  regenerateManual?: boolean;
}

export interface MenuImageAuditResult {
  itemId: string;
  venueId: string;
  itemName: string;
  category: string | null;
  imageUrl: string | null;
  imageSource: "manual" | "ai_gemini" | null;
  imageStatus: "pending" | "generating" | "ready" | "failed";
  imageLocked: boolean;
  itemClass: MenuItemClass;
  visualKind: MenuVisualKind;
  promptClass: MenuItemClass | null;
  promptVisualKind: MenuVisualKind | null;
  verification: MenuImageVerificationPayload | null;
  issues: MenuImageAuditIssue[];
  auditStatus: "clean" | "warning" | "mismatch";
  needsRegeneration: boolean;
  regenerationBlockedReason: string | null;
  regenerationAttempted: boolean;
  regenerationResult: MenuImageProcessResult | null;
}

const staleMenuImageWindowMs = 30 * 60 * 1000;
const menuImagePromptVersion = "menu-image-v3";
const menuImageDarkCardPolicy = {
  cardBackground: "#1A1C1E",
  appBackground: "#121416",
  primaryAccent: "#E1C28E",
  secondaryAccent: "#A1D494",
  tertiaryAccent: "#B9C6E9",
  mood: "premium, dark, refined, modern luxury",
} as const;

export function shouldRegenerateAuditedMenuImage(
  issues: MenuImageAuditIssue[],
): boolean {
  return issues.some((issue) =>
    issue.severity === "error" &&
    [
      "missing_image",
      "image_failed",
      "image_fetch_failed",
      "image_verification_mismatch",
    ].includes(issue.code)
  );
}

export function auditRegenerationBlockedReason(args: {
  needsRegeneration: boolean;
  imageLocked: boolean;
  imageSource: "manual" | "ai_gemini" | null;
  regenerateManual: boolean;
}): string | null {
  if (!args.needsRegeneration) return null;
  if (args.imageLocked) return "image_locked";
  if (args.imageSource === "manual" && !args.regenerateManual) {
    return "manual_image_requires_override";
  }
  return null;
}

interface ReusableMenuImageRecord {
  id: string;
  image_url: string;
  image_storage_path: string;
  image_model: string | null;
  image_prompt: string | null;
}

const externalRequestTimeoutMs = 60000;
const auditImageFetchTimeoutMs = 15000;

type MenuItemSignalSnapshot = Pick<
  MenuItemRecord,
  "name" | "category" | "description" | "tags" | "class"
>;

export interface MenuItemContextProcessResult {
  status: "success" | "skipped";
  itemId: string;
  venueId: string;
  menuContextStatus: "pending" | "researching" | "ready" | "failed";
  itemClass: MenuItemClass;
  profile: MenuItemResearchProfile;
  model: string | null;
  reason?: string;
}

export function menuItemSignalClass(
  item: MenuItemSignalSnapshot,
): MenuItemClass {
  const explicitClass = normalizeMenuItemClass(item.class);
  if (explicitClass) return explicitClass;

  return inferMenuItemClass({
    name: item.name,
    category: item.category,
    description: item.description,
    tags: item.tags,
    class: null,
    menu_context: null,
  });
}

export function shouldRefreshMenuItemContext(
  item: MenuItemSignalSnapshot,
  profile: MenuItemResearchProfile | null,
): boolean {
  if (!profile) return false;

  const explicitClass = normalizeMenuItemClass(item.class);
  if (explicitClass) {
    return profile.class !== explicitClass;
  }

  // `inferMenuItemClass` defaults to food, so only treat a drinks result as a
  // strong enough signal to invalidate a stale stored profile automatically.
  return menuItemSignalClass(item) === "drinks" && profile.class !== "drinks";
}

function escapePromptRegex(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function extractPromptLineValue(
  prompt: string | null | undefined,
  label: string,
): string | null {
  const source = prompt?.trim();
  if (!source) return null;

  const regex = new RegExp(`^${escapePromptRegex(label)}:\\s*(.+)$`, "im");
  const match = source.match(regex);
  return match?.[1]?.trim() ?? null;
}

export function extractMenuImagePromptClass(
  prompt: string | null | undefined,
): MenuItemClass | null {
  const rawValue = extractPromptLineValue(prompt, "This item is classified as");
  const normalized = normalizePromptText(rawValue ?? "");
  if (!normalized) return null;
  if (normalized.includes("drink") || normalized.includes("beverage")) {
    return "drinks";
  }
  if (normalized.includes("food") || normalized.includes("dish")) {
    return "food";
  }
  return normalizeMenuItemClass(rawValue);
}

export function extractMenuImagePromptVisualKind(
  prompt: string | null | undefined,
): MenuVisualKind | null {
  const value = normalizePromptText(
    extractPromptLineValue(prompt, "Visual kind") ?? "",
  );
  if (!value) return null;

  const validKinds: MenuVisualKind[] = [
    "plated_food",
    "dessert",
    "packaged_beer",
    "draft_beer",
    "cocktail",
    "wine",
    "spirits",
    "coffee",
    "tea",
    "soft_drink",
  ];

  return validKinds.includes(value as MenuVisualKind)
    ? (value as MenuVisualKind)
    : null;
}

export function extractMenuImagePromptVersion(
  prompt: string | null | undefined,
): string | null {
  return extractPromptLineValue(prompt, "Prompt version");
}

export function isMenuImagePromptCompatible(
  prompt: string | null | undefined,
  args: {
    itemClass: MenuItemClass;
    visualKind: MenuVisualKind;
  },
): boolean {
  return extractMenuImagePromptVersion(prompt) === menuImagePromptVersion &&
    extractMenuImagePromptClass(prompt) === args.itemClass &&
    extractMenuImagePromptVisualKind(prompt) === args.visualKind;
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
  if (await verifySupabaseServiceRoleHeader(authHeader)) {
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

export function isMenuImageGenerationInFlight(item: MenuItemRecord): boolean {
  if (item.image_status !== "generating") {
    return false;
  }

  const updatedAt = parseIsoTime(item.updated_at);
  if (updatedAt == null) {
    return false;
  }

  return Date.now() - updatedAt < staleMenuImageWindowMs;
}

export function menuImageBackfillEligibilityFilter(
  forceRegenerate: boolean,
): string {
  return forceRegenerate
    ? "image_url.is.null,image_status.eq.failed,image_status.eq.generating,image_source.eq.ai_gemini"
    : "image_url.is.null,image_status.eq.failed,image_status.eq.generating";
}

export async function fetchMenuItem(
  adminClient: ReturnType<typeof createAdminClient>,
  itemId: string,
): Promise<MenuItemRecord> {
  const { data, error } = await adminClient
    .from("dinein_menu_items")
    .select(
      "id, venue_id, updated_at, name, description, category, class, menu_context, menu_context_status, menu_context_error, menu_context_model, menu_context_attempts, menu_context_locked, menu_context_updated_at, image_url, image_source, image_status, image_model, image_prompt, image_error, image_attempts, image_locked, image_storage_path, tags",
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
    .select(
      "id, name, category, description, owner_id, phone, owner_whatsapp_number",
    )
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
  const accessToken = venueSession?.access_token?.trim();
  if (!accessToken) {
    throw new HttpError(401, "Venue session required.");
  }

  const session = await verifyVenueAccessToken(accessToken);
  if (session.venueId !== venue.id) {
    throw new HttpError(403, "Venue session does not match requested venue.");
  }

  if (!venueMatchesContact(venue, session.contactPhone)) {
    throw new HttpError(403, "Venue access not granted.");
  }
}

export async function ensureMenuItemContext(
  options: {
    adminClient: ReturnType<typeof createAdminClient>;
    env: FunctionEnv;
    item: MenuItemRecord;
    venue: VenueRecord;
    forceRefresh?: boolean;
  },
): Promise<MenuItemContextProcessResult> {
  const { adminClient, env, item, venue, forceRefresh = false } = options;
  const profile = parseMenuItemResearchProfile(item.menu_context);
  const itemClass = menuItemSignalClass(item);
  const staleStoredProfile = shouldRefreshMenuItemContext(item, profile);
  const effectiveProfile = staleStoredProfile ? null : profile;
  const resolvedProfileClass = effectiveProfile?.class ?? itemClass;
  const menuContextReady = item.menu_context_status === "ready" &&
    effectiveProfile && !forceRefresh;

  if (item.menu_context_locked == true && !forceRefresh) {
    if (normalizeMenuItemClass(item.class) !== resolvedProfileClass) {
      await updateMenuContextState(adminClient, item.id, {
        class: resolvedProfileClass,
        updated_at: new Date().toISOString(),
      });
    }

    return {
      status: "skipped",
      itemId: item.id,
      venueId: item.venue_id,
      menuContextStatus: item.menu_context_status === "failed"
        ? "failed"
        : "ready",
      itemClass: resolvedProfileClass,
      profile: effectiveProfile ?? buildFallbackMenuItemResearchProfile({
        item,
        itemClass: resolvedProfileClass,
        visualKind: classifyMenuVisualKind(
          item,
          venue,
          resolvedProfileClass,
          effectiveProfile,
        ),
      }),
      model: item.menu_context_model,
      reason: staleStoredProfile
        ? "menu_context_locked_stale"
        : "menu_context_locked",
    };
  }

  if (menuContextReady) {
    if (normalizeMenuItemClass(item.class) !== resolvedProfileClass) {
      await updateMenuContextState(adminClient, item.id, {
        class: resolvedProfileClass,
        updated_at: new Date().toISOString(),
      });
    }

    return {
      status: "skipped",
      itemId: item.id,
      venueId: item.venue_id,
      menuContextStatus: "ready",
      itemClass: resolvedProfileClass,
      profile: effectiveProfile as MenuItemResearchProfile,
      model: item.menu_context_model,
      reason: "menu_context_ready",
    };
  }

  const nextAttempt = (item.menu_context_attempts ?? 0) + 1;
  const startedAt = new Date().toISOString();

  await updateMenuContextState(adminClient, item.id, {
    class: resolvedProfileClass,
    menu_context_status: "researching",
    menu_context_error: null,
    menu_context_attempts: nextAttempt,
    menu_context_updated_at: startedAt,
    updated_at: startedAt,
  });

  const prompt = buildMenuItemResearchPrompt({
    item,
    venueName: venue.name,
    venueCategory: venue.category,
    venueDescription: venue.description,
  });

  const fallbackProfile = buildFallbackMenuItemResearchProfile({
    item,
    itemClass: resolvedProfileClass,
    visualKind: classifyMenuVisualKind(
      item,
      venue,
      resolvedProfileClass,
      effectiveProfile,
    ),
  });

  let lastError = "Menu item research did not return a usable profile.";

  for (const model of env.menuItemResearchModels) {
    const response = await fetchWithTimeout(
      `https://generativelanguage.googleapis.com/v1beta/models/${
        encodeURIComponent(model)
      }:generateContent`,
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-goog-api-key": env.geminiApiKey,
        },
        body: JSON.stringify({
          contents: [
            {
              role: "user",
              parts: [{ text: prompt }],
            },
          ],
          tools: [{ google_search: {} }],
          generationConfig: {
            responseMimeType: "application/json",
            responseJsonSchema: menuItemResearchSchema,
          },
        }),
      },
    );

    if (!response.ok) {
      lastError = await extractGeminiError(response);
      continue;
    }

    const body = await response.json();
    const candidate = normalizeCandidateObject((body as Json).candidates);
    if (!candidate) {
      lastError = `Model "${model}" returned no candidate payload.`;
      continue;
    }

    const jsonText = extractJsonPayloadFromCandidate(candidate);
    const parsedProfile = jsonText
      ? parseMenuItemResearchProfile(parseJsonObjectText(jsonText))
      : null;
    if (!parsedProfile) {
      lastError = `Model "${model}" returned an invalid menu profile.`;
      continue;
    }

    const sourceUrls = [
      ...extractResearchSourceUrls(candidate),
      ...parsedProfile.source_urls,
    ];
    const profileToStore: MenuItemResearchProfile = {
      ...parsedProfile,
      source_urls: [...new Set(sourceUrls)].filter(Boolean).slice(0, 12),
    };

    await updateMenuContextState(adminClient, item.id, {
      class: profileToStore.class,
      menu_context: profileToStore,
      menu_context_status: "ready",
      menu_context_error: null,
      menu_context_model: model,
      menu_context_attempts: nextAttempt,
      menu_context_updated_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    });

    return {
      status: "success",
      itemId: item.id,
      venueId: item.venue_id,
      menuContextStatus: "ready",
      itemClass: profileToStore.class,
      profile: profileToStore,
      model,
      reason: "google_search_grounded",
    };
  }

  await updateMenuContextState(adminClient, item.id, {
    class: fallbackProfile.class,
    menu_context: fallbackProfile,
    menu_context_status: "failed",
    menu_context_error: lastError,
    menu_context_model: env.menuItemResearchModels[0] ?? null,
    menu_context_attempts: nextAttempt,
    menu_context_updated_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  });

  return {
    status: "success",
    itemId: item.id,
    venueId: item.venue_id,
    menuContextStatus: "failed",
    itemClass: fallbackProfile.class,
    profile: fallbackProfile,
    model: env.menuItemResearchModels[0] ?? null,
    reason: "heuristic_fallback",
  };
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

  if (hasExistingImage && imageSource === "manual" && !forceRegenerate) {
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

  if (!forceRegenerate && isMenuImageGenerationInFlight(item)) {
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

  const context = await ensureMenuItemContext({
    adminClient,
    env,
    item,
    venue,
    forceRefresh: forceRegenerate,
  });
  const existingImageReference = hasExistingImage
    ? await loadExistingMenuImageReference({
      adminClient,
      env,
      item,
    })
    : null;

  const visualKind = classifyMenuVisualKind(
    item,
    venue,
    context.itemClass,
    context.profile,
  );
  const prompt = buildMenuImagePrompt(
    item,
    venue,
    context.profile,
    context.itemClass,
    {
      hasExistingImageReference: existingImageReference != null,
    },
  );

  if (
    hasExistingImage &&
    imageSource === "ai_gemini" &&
    !forceRegenerate &&
    isMenuImagePromptCompatible(item.image_prompt, {
      itemClass: context.itemClass,
      visualKind,
    })
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

  if (hasExistingImage && imageSource !== "ai_gemini" && !forceRegenerate) {
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

  const nextAttempt = (item.image_attempts ?? 0) + 1;

  try {
    if (!forceRegenerate) {
      const reusableImage = await findReusableMenuImage(
        adminClient,
        item,
        context.itemClass,
        visualKind,
      );
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
      referenceImages: existingImageReference ? [existingImageReference] : [],
      verification: {
        models: env.menuImageVerifierModels,
        item,
        itemClass: context.itemClass,
        visualKind,
        profile: context.profile,
      },
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
      image_locked: true,
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

export async function auditMenuItemImage(
  options: AuditMenuImageOptions,
): Promise<MenuImageAuditResult> {
  const {
    adminClient,
    env,
    item,
    venue,
    forceRefreshContext = false,
    regenerateMismatch = false,
    regenerateManual = false,
  } = options;

  const issues: MenuImageAuditIssue[] = [];
  const imageSource = normalizeImageSource(item.image_source);
  const imageStatus = normalizeImageStatus(item.image_status);
  const imageLocked = item.image_locked === true;
  const hasImage = Boolean(item.image_url?.trim());

  const context = await ensureMenuItemContext({
    adminClient,
    env,
    item,
    venue,
    forceRefresh: forceRefreshContext,
  });
  const visualKind = classifyMenuVisualKind(
    item,
    venue,
    context.itemClass,
    context.profile,
  );
  const promptClass = extractMenuImagePromptClass(item.image_prompt);
  const promptVisualKind = extractMenuImagePromptVisualKind(item.image_prompt);

  let verification: MenuImageVerificationPayload | null = null;

  if (!hasImage) {
    issues.push({
      code: "missing_image",
      severity: "error",
      message: "No image is currently stored for this menu item.",
    });
  } else {
    if (imageStatus === "failed") {
      issues.push({
        code: "image_failed",
        severity: "error",
        message: item.image_error?.trim() ||
          "The stored image is marked as failed.",
      });
    }

    if (
      imageSource === "ai_gemini" &&
      !isMenuImagePromptCompatible(item.image_prompt, {
        itemClass: context.itemClass,
        visualKind,
      })
    ) {
      issues.push({
        code: "image_prompt_metadata_stale",
        severity: "warning",
        message:
          "The stored AI prompt metadata does not match the current prompt version, item class, or visual kind.",
      });
    }

    try {
      const payload = await downloadMenuItemImageBytes({
        adminClient,
        env,
        item,
      });

      verification = await verifyGeneratedMenuImage({
        apiKey: env.geminiApiKey,
        models: env.menuImageVerifierModels,
        imageBytes: payload.bytes,
        mimeType: payload.mimeType,
        item,
        itemClass: context.itemClass,
        visualKind,
        profile: context.profile,
      });

      if (!verification) {
        issues.push({
          code: "image_verification_unavailable",
          severity: "warning",
          message:
            "The image verifier could not return a decision for this image.",
        });
      } else if (!verification.matches) {
        issues.push({
          code: "image_verification_mismatch",
          severity: "error",
          message:
            `Verifier observed ${verification.observed_subject} (${verification.observed_class}): ${verification.reason}${
              verification.issues.length > 0
                ? ` [${verification.issues.join(", ")}]`
                : ""
            }`,
        });
      }
    } catch (error) {
      issues.push({
        code: "image_fetch_failed",
        severity: "error",
        message: getErrorMessage(error),
      });
    }
  }

  const hasMismatch = issues.some((issue) => issue.severity === "error");
  const needsRegeneration = shouldRegenerateAuditedMenuImage(issues);
  const regenerationBlockedReason = auditRegenerationBlockedReason({
    needsRegeneration,
    imageLocked,
    imageSource,
    regenerateManual,
  });

  let regenerationAttempted = false;
  let regenerationResult: MenuImageProcessResult | null = null;
  if (
    regenerateMismatch &&
    needsRegeneration &&
    regenerationBlockedReason == null
  ) {
    regenerationAttempted = true;
    regenerationResult = await processMenuItemImageGeneration({
      adminClient,
      env,
      item,
      venue,
      forceRegenerate: true,
    });
  }

  const auditStatus = hasMismatch
    ? "mismatch"
    : issues.length > 0
    ? "warning"
    : "clean";

  return {
    itemId: item.id,
    venueId: item.venue_id,
    itemName: item.name,
    category: item.category,
    imageUrl: item.image_url,
    imageSource,
    imageStatus,
    imageLocked,
    itemClass: context.itemClass,
    visualKind,
    promptClass,
    promptVisualKind,
    verification,
    issues,
    auditStatus,
    needsRegeneration,
    regenerationBlockedReason,
    regenerationAttempted,
    regenerationResult,
  };
}

async function findReusableMenuImage(
  adminClient: ReturnType<typeof createAdminClient>,
  item: MenuItemRecord,
  itemClass: MenuItemClass,
  visualKind: MenuVisualKind,
): Promise<ReusableMenuImageRecord | null> {
  const { data, error } = await adminClient
    .from("dinein_menu_items")
    .select("id, image_url, image_storage_path, image_model, image_prompt")
    .neq("id", item.id)
    .eq("class", itemClass)
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

  if (
    !isMenuImagePromptCompatible(candidate.image_prompt, {
      itemClass,
      visualKind,
    })
  ) {
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
    image_locked: true,
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

function decodeBase64Url(value: string): string {
  const normalized = value.replaceAll("-", "+").replaceAll("_", "/");
  const padded = normalized.padEnd(
    normalized.length + ((4 - normalized.length % 4) % 4),
    "=",
  );
  return atob(padded);
}

function venueSessionSecret(): string {
  const secret = Deno.env.get("DINEIN_VENUE_SESSION_SECRET")?.trim() ??
    Deno.env.get("VENUE_OTP_JWT_SECRET")?.trim() ??
    "";
  if (!secret) {
    throw new HttpError(
      500,
      "Missing venue session signing secret for menu image access.",
    );
  }
  return secret;
}

async function hmacSha256Base64Url(
  value: string,
  secret: string,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(value),
  );
  const bytes = new Uint8Array(signature);
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(
    /=+$/g,
    "",
  );
}

function normalizeContact(value: unknown): string {
  if (typeof value !== "string") return "";
  const trimmed = value.trim();
  const startsWithPlus = trimmed.startsWith("+");
  const digits = trimmed.replaceAll(/[^0-9]/g, "");
  if (!digits) return trimmed;
  return startsWithPlus ? `+${digits}` : digits;
}

function digitsOnly(value: string): string {
  return value.replaceAll(/[^0-9]/g, "");
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

function venueMatchesContact(
  venue: VenueRecord,
  contactPhone: string,
): boolean {
  const target = digitsOnly(normalizeContact(contactPhone));
  if (!target) return false;
  return [venue.phone, venue.owner_whatsapp_number].some((value) =>
    digitsOnly(value ?? "") === target
  );
}

async function verifyVenueAccessToken(
  token: string,
): Promise<{ venueId: string; contactPhone: string }> {
  const parts = token.split(".");
  if (parts.length !== 3) {
    throw new HttpError(403, "Invalid venue access token.");
  }

  const [encodedHeader, encodedPayload, encodedSignature] = parts;
  const signingInput = `${encodedHeader}.${encodedPayload}`;
  const expectedSignature = await hmacSha256Base64Url(
    signingInput,
    venueSessionSecret(),
  );

  if (expectedSignature !== encodedSignature) {
    throw new HttpError(403, "Venue access token signature is invalid.");
  }

  let payload: Json;
  try {
    payload = JSON.parse(decodeBase64Url(encodedPayload)) as Json;
  } catch {
    throw new HttpError(403, "Venue access token payload is malformed.");
  }

  if (payload.aud !== "dinein-venue") {
    throw new HttpError(403, "Venue access token audience is invalid.");
  }

  if (
    typeof payload.exp === "number" &&
    Math.floor(Date.now() / 1000) >= payload.exp
  ) {
    throw new HttpError(
      401,
      "Venue access token has expired. Please log in again.",
    );
  }

  const venueId = typeof payload.venue_id === "string"
    ? payload.venue_id
    : null;
  const contactPhone = typeof payload.phone === "string" ? payload.phone : null;

  if (!venueId || !contactPhone) {
    throw new HttpError(403, "Venue access token is missing required claims.");
  }

  return { venueId, contactPhone };
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
  const shouldLockGeneratedImage =
    normalizeImageSource(item.image_source) === "ai_gemini" &&
    item.image_locked !== true;
  const shouldNormalizeStatus =
    normalizeImageStatus(item.image_status) !== "ready" ||
    Boolean(item.image_error);

  if (!shouldNormalizeStatus && !shouldLockGeneratedImage) {
    return;
  }

  const updates: Record<string, unknown> = {
    updated_at: new Date().toISOString(),
  };

  if (shouldNormalizeStatus) {
    updates.image_status = "ready";
    updates.image_error = null;
  }

  if (shouldLockGeneratedImage) {
    updates.image_locked = true;
  }

  await updateGenerationState(adminClient, item.id, updates);
}

async function updateMenuContextState(
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
      `Unable to update the menu item research state: ${error.message}`,
      error,
    );
  }
}

async function fetchWithTimeout(
  input: RequestInfo | URL,
  init: RequestInit,
  timeoutMs = externalRequestTimeoutMs,
): Promise<Response> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

  try {
    return await fetch(input, {
      ...init,
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timeoutId);
  }
}

function normalizeCandidateObject(value: unknown): Json | null {
  if (Array.isArray(value)) {
    const first = value.find(isRecord);
    return first ? (first as Json) : null;
  }

  return isRecord(value) ? (value as Json) : null;
}

export function buildMenuImagePrompt(
  item: MenuItemRecord,
  venue: VenueRecord,
  profile: MenuItemResearchProfile | null,
  itemClass: MenuItemClass,
  options: {
    hasExistingImageReference?: boolean;
  } = {},
): string {
  const venueCategory = venue.category?.trim() || "Restaurants";
  const itemCategory = item.category?.trim() || "menu item";
  const itemDescription = item.description?.trim() ||
    "Premium menu item.";
  const venueDescription = venue.description?.trim() ||
    "Premium hospitality venue with a refined, dark, elevated atmosphere.";
  const tags = (item.tags ?? []).map((tag) => tag.trim()).filter(Boolean);
  const tagsLine = tags.length > 0 ? tags.join(", ") : "none";
  const resolvedClass = normalizeMenuItemClass(item.class) ?? itemClass;
  const resolvedProfile = profile ?? buildFallbackMenuItemResearchProfile({
    item,
    itemClass: resolvedClass,
    visualKind: classifyMenuVisualKind(item, venue, resolvedClass, null),
  });
  const visualKind = classifyMenuVisualKind(
    item,
    venue,
    resolvedClass,
    resolvedProfile,
  );
  const artDirection = buildMenuArtDirection(visualKind, venue);
  const isDrink = isBeverageKind(visualKind);
  const typeLabel = isDrink ? "BEVERAGE / DRINK" : "FOOD / PLATED DISH";
  const cuisineHint = detectCuisineHint(item, venue);
  const keywordSignals = resolvedProfile.keyword_signals.length > 0
    ? resolvedProfile.keyword_signals.join(", ")
    : "none";
  const sourceUrls = resolvedProfile.source_urls.length > 0
    ? resolvedProfile.source_urls.map((url) => `- ${url}`).join("\n")
    : "- none";
  const visualDirections = resolvedProfile.visual_directions.length > 0
    ? resolvedProfile.visual_directions.map((entry) => `- ${entry}`).join("\n")
    : "- none";
  const visualDoNot = resolvedProfile.visual_do_not.length > 0
    ? resolvedProfile.visual_do_not.map((entry) => `- ${entry}`).join("\n")
    : "- none";
  const existingImageReferenceCue = options.hasExistingImageReference
    ? `A current menu image is attached as a secondary reference.
- Use it only as supporting evidence for plating, serving vessel, portioning, and presentation cues.
- Never let the attached image override the item name, class, category, description, or grounded research profile.
- If the attached image conflicts with the grounded text, follow the grounded text and ignore the conflicting image details.`
    : "No current menu image is attached.";

  return `
Create a photorealistic production-safe menu image for a dark hospitality mobile app.

Prompt version: ${menuImagePromptVersion}

═══ EVIDENCE HIERARCHY (DO NOT BREAK) ═══
Use these sources in strict order of priority:
1. Menu item name
2. Menu item description and tags
3. Canonical research profile below
4. Venue context only for ambience, never for item substitution

If the evidence is limited, keep the image simple and literal.
Prefer an understated but accurate dish or drink over a dramatic but invented composition.
Do NOT upscale a humble, local, street-food, tavern, bar-snack, or everyday item into a fine-dining luxury plating unless the grounded item text clearly supports that.
Do NOT invent ingredients, garnishes, side dishes, glassware style, serving vessel, regional cues, or preparation details that are not supported by the grounded menu text or canonical profile.
If the item is culturally specific, preserve that locality faithfully instead of replacing it with a generic international stock-photo version.

═══ EXISTING MENU IMAGE REFERENCE ═══
${existingImageReferenceCue}

═══ ITEM TYPE CLASSIFICATION (MOST CRITICAL RULE) ═══
This item is classified as: ${typeLabel}
Visual kind: ${visualKind}
Resolved class: ${resolvedProfile.class}
Research confidence: ${resolvedProfile.confidence}
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
Canonical name: "${resolvedProfile.canonical_name}"
Canonical category: "${resolvedProfile.canonical_category}"
Canonical description: "${resolvedProfile.canonical_description}"
Visual subject: "${resolvedProfile.visual_subject}"
Serving style: "${resolvedProfile.serving_style}"
Keyword signals: ${keywordSignals}
Research summary: ${resolvedProfile.research_summary}
Source URLs:
${sourceUrls}

The image MUST depict EXACTLY what the name and description say.
- If the name is "Margherita Pizza", show a Margherita pizza, not generic pasta.
- If the description says "grilled", show grill marks. If "fried", show fried texture.
- If "vegetarian" or "vegan" tag is present, absolutely NO meat visible.
- The name is ground truth. Never reinterpret or substitute.
${visualDirections}
${visualDoNot}

═══ VENUE CONTEXT ═══
Venue: ${venue.name}
Venue type: ${venueCategory}
Atmosphere: ${venueDescription}
Use venue context only to shape lighting mood, background restraint, and hospitality atmosphere.
The venue must never change what the item itself is.

═══ APP DESIGN SYSTEM (match this mood, do NOT render UI) ═══
The image will appear inside a dark mobile menu card with these properties:
- Card background: near-black (${menuImageDarkCardPolicy.cardBackground})
- App background: dark charcoal (${menuImageDarkCardPolicy.appBackground})
- Primary accent: warm gold (${menuImageDarkCardPolicy.primaryAccent})
- Secondary accent: mint green (${menuImageDarkCardPolicy.secondaryAccent})
- Tertiary accent: soft lavender (${menuImageDarkCardPolicy.tertiaryAccent})
- Overall mood: ${menuImageDarkCardPolicy.mood}

The image must harmonize with this dark palette:
- Background and edge tones should blend toward dark charcoal (${menuImageDarkCardPolicy.appBackground} to ${menuImageDarkCardPolicy.cardBackground}).
- Use dark vignetting or shallow depth of field so image edges dissolve into the card.
- Avoid bright white, pure white, or high-contrast edges that would clash with the dark card.
- Warm tones (amber, gold, copper) are preferred over cool blues or stark whites.
- Keep the palette believable and appetizing, not glossy, neon, or over-processed.

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
- Make the hero subject feel like a real item served by this venue, not a generic stock-photo substitute.

═══ HARD EXCLUSIONS (never violate) ═══
${
    isDrink
      ? "- ABSOLUTELY NO FOOD. No plates, no bowls, no plated dishes, no side dishes, no garnish plates."
      : "- ABSOLUTELY NO DRINKS as the hero subject. No glasses, bottles, or cups as the main focus."
  }
- No text overlays, watermarks, logos, borders, price tags, menus, or collage layouts.
- No people, hands, phones, cash, receipts, or table clutter.
- No cartoon styling, surreal plating, AI artifacts, or oversaturated neon color.
- No generic stock-photo styling, no unsupported luxury cues, and no theatrical garnish or prop styling unless the item text explicitly supports it.
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

export type MenuVisualKind =
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

export function classifyMenuVisualKind(
  item: MenuItemRecord,
  _venue: VenueRecord,
  itemClass?: MenuItemClass | null,
  profile?: MenuItemResearchProfile | null,
): MenuVisualKind {
  const tags = (item.tags ?? []).join(" ");
  // IMPORTANT: Only use item-level data for classification.
  // Including venue.category / venue.description causes
  // misclassification (e.g. a burger at a "bar" gets tagged as beer).
  const itemCategory = normalizePromptText(item.category ?? "");
  const context = normalizePromptText(
    [
      item.name,
      item.category,
      item.description,
      tags,
      profile?.canonical_name,
      profile?.canonical_category,
      profile?.canonical_description,
      profile?.visual_subject,
      profile?.serving_style,
      profile?.research_summary,
      ...(profile?.keyword_signals ?? []),
    ].filter(Boolean).join(" "),
  );
  const resolvedClass = normalizeMenuItemClass(itemClass) ??
    resolveMenuItemClass(item);

  const foodCategoryPrefixes = [
    "mains",
    "main",
    "breakfast",
    "lunch",
    "dinner",
    "soup",
    "soups",
    "salad",
    "salads",
    "starter",
    "starters",
    "appetizer",
    "appetizers",
    "sandwich",
    "sandwiches",
    "wrap",
    "wraps",
    "burger",
    "burgers",
    "pizza",
    "pasta",
    "grill",
    "bbq",
    "sides",
    "side",
    "accompaniment",
    "accompaniments",
    "rwandan traditional",
    "hotel buffet",
    "indian cuisine",
    "seafood",
    "fish",
  ];
  const dessertCategoryPrefixes = [
    "dessert",
    "desserts",
    "pastry",
    "pastries",
    "bakery",
  ];

  if (
    dessertCategoryPrefixes.some((p) =>
      itemCategory.startsWith(p) || itemCategory.includes(p)
    )
  ) {
    return "dessert";
  }

  if (
    resolvedClass === "food" ||
    foodCategoryPrefixes.some((p) =>
      itemCategory.startsWith(p) || itemCategory.includes(p)
    )
  ) {
    return "plated_food";
  }

  if (
    matchesAny(context, [
      "shandy",
      "lager and lemonade",
    ])
  ) {
    return "cocktail";
  }

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
    const explicitPackagedBeerSignals = matchesAny(context, [
      "bottled beer",
      "beer bottle",
      "beer can",
      "bottle of",
      "can of",
      "330ml bottle",
      "500ml bottle",
      "iconic green bottle",
      "accompanied by a bottle",
      "accompanied by the bottle",
    ]) ||
      matchesAny(itemCategory, [
        "bottled beer",
        "bottled beers",
        "bottled beer & ciders",
        "bottled beers & ciders",
        "ciders",
      ]);
    const genericPackagedBeerSignals = matchesAny(context, [
      "bottle",
      "bottled",
      "can",
      "canned",
      "cider",
    ]);
    const draftBeerSignals = matchesAny(context, [
      "draft",
      "draught",
      "on tap",
      "tap handle",
      "beer tap",
      "taproom",
      "keg",
    ]) ||
      matchesAny(itemCategory, ["draft beer", "draught beer", "on tap"]);
    if (draftBeerSignals && !explicitPackagedBeerSignals) {
      return "draft_beer";
    }
    return explicitPackagedBeerSignals || genericPackagedBeerSignals
      ? "packaged_beer"
      : "draft_beer";
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
    resolvedClass === "drinks" ||
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

  return resolvedClass === "drinks" ? "soft_drink" : "plated_food";
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
    const wordBoundaryRegex = new RegExp(
      `(?:^|\\s|[^a-z0-9])${escaped}(?:\\s|[^a-z0-9]|$)`,
    );
    return wordBoundaryRegex.test(value);
  });
}

interface GeminiImagePayload {
  bytes: Uint8Array;
  mimeType: string;
  model: string;
}

interface MenuImageReferencePayload {
  data: string;
  mimeType: string;
}

export interface MenuImageVerificationPayload {
  matches: boolean;
  observed_class: "food" | "drinks" | "unclear";
  observed_subject: string;
  issues: string[];
  reason: string;
}

const menuImageVerificationSchema = {
  type: "object",
  properties: {
    matches: { type: "boolean" },
    observed_class: {
      type: "string",
      enum: ["food", "drinks", "unclear"],
    },
    observed_subject: { type: "string" },
    issues: {
      type: "array",
      items: { type: "string" },
    },
    reason: { type: "string" },
  },
  required: [
    "matches",
    "observed_class",
    "observed_subject",
    "issues",
    "reason",
  ],
} as const;

function buildMenuImageVerificationPrompt(args: {
  item: MenuItemRecord;
  itemClass: MenuItemClass;
  visualKind: MenuVisualKind;
  profile: MenuItemResearchProfile;
}): string {
  const expectedSubject = args.itemClass === "drinks"
    ? "a beverage only"
    : "a plated dish or dessert only";
  const visualDoNot = args.profile.visual_do_not.length > 0
    ? args.profile.visual_do_not.map((entry) => `- ${entry}`).join("\n")
    : "- none";

  return `
You are reviewing a generated hospitality menu image for production.
Return JSON only.

Prompt version: ${menuImagePromptVersion}
Expected class: ${args.itemClass}
Expected visual kind: ${args.visualKind}
Menu item: ${args.item.name}
Category: ${args.item.category ?? ""}
Description: ${args.item.description ?? ""}
Canonical name: ${args.profile.canonical_name}
Canonical description: ${args.profile.canonical_description}
Visual subject: ${args.profile.visual_subject}
Serving style: ${args.profile.serving_style}
Forbidden details:
${visualDoNot}

Check only the hero subject in the image.
- The hero subject must be ${expectedSubject}.
- Mark matches=false if the image shows the opposite class, if the hero subject is unclear, or if the image shows the wrong named menu item.
- Mark matches=false if the hero subject contradicts the canonical description or forbidden details.
- Mark matches=false if the image looks like a generic stock-photo substitute instead of the named item and grounded serving style.
- Mark matches=false if the image adds unsupported luxury garnish, props, or presentation that are not grounded in the canonical item.
- Ignore lighting and polish unless they obscure the subject itself.
- observed_subject should name what the image most likely shows in one short phrase.
- issues should list short machine-readable findings such as "wrong_class", "wrong_named_item", "unclear_subject", "forbidden_detail", "wrong_serving_style", "generic_stock_scene", or "overstyled_not_grounded".
`.trim();
}

function encodeBytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunkSize = 0x8000;
  for (let index = 0; index < bytes.length; index += chunkSize) {
    const chunk = bytes.subarray(index, index + chunkSize);
    binary += String.fromCharCode(...chunk);
  }
  return btoa(binary);
}

async function verifyGeneratedMenuImage(args: {
  apiKey: string;
  models: string[];
  imageBytes: Uint8Array;
  mimeType: string;
  item: MenuItemRecord;
  itemClass: MenuItemClass;
  visualKind: MenuVisualKind;
  profile: MenuItemResearchProfile;
}): Promise<MenuImageVerificationPayload | null> {
  const prompt = buildMenuImageVerificationPrompt({
    item: args.item,
    itemClass: args.itemClass,
    visualKind: args.visualKind,
    profile: args.profile,
  });
  const encodedImage = encodeBytesToBase64(args.imageBytes);

  for (const model of args.models) {
    const response = await fetchWithTimeout(
      `https://generativelanguage.googleapis.com/v1beta/models/${
        encodeURIComponent(model)
      }:generateContent`,
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-goog-api-key": args.apiKey,
        },
        body: JSON.stringify({
          contents: [
            {
              role: "user",
              parts: [
                { text: prompt },
                {
                  inlineData: {
                    mimeType: args.mimeType,
                    data: encodedImage,
                  },
                },
              ],
            },
          ],
          generationConfig: {
            responseMimeType: "application/json",
            responseJsonSchema: menuImageVerificationSchema,
          },
        }),
      },
    );

    if (!response.ok) {
      continue;
    }

    const body = await response.json();
    const candidate = normalizeCandidateObject((body as Json).candidates);
    if (!candidate) continue;

    const jsonText = extractJsonPayloadFromCandidate(candidate);
    const parsed = jsonText ? parseJsonObjectText(jsonText) : null;
    if (!parsed || !isRecord(parsed)) continue;

    const observedClass = typeof parsed.observed_class === "string"
      ? parsed.observed_class.trim()
      : null;
    const observedSubject = typeof parsed.observed_subject === "string"
      ? parsed.observed_subject.trim()
      : "";
    const issues = Array.isArray(parsed.issues)
      ? parsed.issues.filter((entry): entry is string =>
        typeof entry === "string" && entry.trim().length > 0
      ).map((entry) => entry.trim()).slice(0, 8)
      : [];
    if (
      typeof parsed.matches !== "boolean" ||
      !observedClass ||
      !["food", "drinks", "unclear"].includes(observedClass) ||
      observedSubject.length === 0
    ) {
      continue;
    }

    return {
      matches: parsed.matches,
      observed_class: observedClass as "food" | "drinks" | "unclear",
      observed_subject: observedSubject,
      issues,
      reason:
        typeof parsed.reason === "string" && parsed.reason.trim().length > 0
          ? parsed.reason.trim()
          : "No verification reason supplied.",
    };
  }

  return null;
}

async function downloadMenuItemImageBytes(args: {
  adminClient: ReturnType<typeof createAdminClient>;
  env: FunctionEnv;
  item: MenuItemRecord;
}): Promise<{ bytes: Uint8Array; mimeType: string }> {
  const storagePath = args.item.image_storage_path?.trim();
  if (storagePath) {
    const { data, error } = await args.adminClient.storage
      .from(args.env.menuImageBucket)
      .download(storagePath);

    if (!error && data) {
      const buffer = await data.arrayBuffer();
      return {
        bytes: new Uint8Array(buffer),
        mimeType: data.type || mimeTypeFromPath(storagePath),
      };
    }
  }

  const imageUrl = args.item.image_url?.trim();
  if (!imageUrl) {
    throw new HttpError(404, "Menu item has no image URL to audit.");
  }

  const response = await fetchWithTimeout(
    imageUrl,
    { method: "GET" },
    auditImageFetchTimeoutMs,
  );
  if (!response.ok) {
    throw new HttpError(
      502,
      `Could not download the current image: HTTP ${response.status}.`,
    );
  }

  const bytes = new Uint8Array(await response.arrayBuffer());
  return {
    bytes,
    mimeType: response.headers.get("content-type")?.split(";")[0]?.trim() ||
      mimeTypeFromPath(imageUrl),
  };
}

async function loadExistingMenuImageReference(args: {
  adminClient: ReturnType<typeof createAdminClient>;
  env: FunctionEnv;
  item: MenuItemRecord;
}): Promise<MenuImageReferencePayload | null> {
  const imageUrl = args.item.image_url?.trim();
  if (!imageUrl) {
    return null;
  }

  try {
    const payload = await downloadMenuItemImageBytes(args);
    return {
      data: encodeBytesToBase64(payload.bytes),
      mimeType: payload.mimeType,
    };
  } catch (_) {
    return null;
  }
}

function mimeTypeFromPath(value: string): string {
  const normalized = value.toLowerCase();
  if (normalized.endsWith(".png")) return "image/png";
  if (normalized.endsWith(".webp")) return "image/webp";
  return "image/jpeg";
}

async function generateGeminiImage({
  apiKey,
  models,
  prompt,
  referenceImages,
  verification,
}: {
  apiKey: string;
  models: string[];
  prompt: string;
  referenceImages: MenuImageReferencePayload[];
  verification?: {
    models: string[];
    item: MenuItemRecord;
    itemClass: MenuItemClass;
    visualKind: MenuVisualKind;
    profile: MenuItemResearchProfile;
  };
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
                ...referenceImages.map((reference) => ({
                  inlineData: {
                    data: reference.data,
                    mimeType: reference.mimeType,
                  },
                })),
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
    if (!payload) {
      lastError = `Model "${model}" returned no inline image payload.`;
      continue;
    }

    if (verification) {
      const verdict = await verifyGeneratedMenuImage({
        apiKey,
        models: verification.models,
        imageBytes: payload.bytes,
        mimeType: payload.mimeType,
        item: verification.item,
        itemClass: verification.itemClass,
        visualKind: verification.visualKind,
        profile: verification.profile,
      });

      if (verdict && !verdict.matches) {
        lastError =
          `Model "${model}" generated ${verdict.observed_subject} (${verdict.observed_class}) for ${verification.itemClass}: ${verdict.reason}`;
        continue;
      }
    }

    return {
      ...payload,
      model,
    };
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

function parseIsoTime(value: string | null | undefined): number | null {
  if (!value || value.trim().length === 0) {
    return null;
  }
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function isRecord(value: unknown): value is Json {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}
