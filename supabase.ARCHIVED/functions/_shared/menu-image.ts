import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

export interface FunctionEnv {
  supabaseUrl: string;
  supabaseAnonKey: string;
  supabaseServiceRoleKey: string;
  geminiApiKey: string;
  geminiImageModels: string[];
  menuImageBucket: string;
  cronSecret: string | null;
}

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

export interface InvocationActor {
  kind: "cron" | "service" | "user";
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
  const supabaseServiceRoleKey =
    Deno.env.get("SERVICE_ROLE_KEY")?.trim() ??
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
    throw new HttpError(401, "Missing Authorization header.");
  }

  const client = createRequestScopedClient(req, env);
  const { data, error } = await client.auth.getUser();

  if (error || !data.user) {
    throw new HttpError(401, "Unable to resolve the authenticated user.");
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
): Promise<void> {
  if (actor.kind === "user" && actor.userId !== venue.owner_id) {
    throw new HttpError(403, "You do not have access to this venue.");
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

  await updateGenerationState(adminClient, item.id, {
    image_status: "generating",
    image_error: null,
    updated_at: new Date().toISOString(),
  });

  const prompt = buildMenuImagePrompt(item, venue);
  const nextAttempt = (item.image_attempts ?? 0) + 1;

  try {
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

    if (
      item.image_storage_path &&
      item.image_storage_path !== storagePath
    ) {
      await adminClient.storage
        .from(env.menuImageBucket)
        .remove([item.image_storage_path]);
    }

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

function buildMenuImagePrompt(
  item: MenuItemRecord,
  venue: VenueRecord,
): string {
  const venueCategory = venue.category?.trim() || "restaurant";
  const itemCategory = item.category?.trim() || "signature dish";
  const itemDescription = item.description?.trim() ||
    "Chef-special plated dish.";
  const venueDescription = venue.description?.trim() ||
    "Premium hospitality venue with an elevated dining atmosphere.";
  const tags = (item.tags ?? []).map((tag) => tag.trim()).filter(Boolean);
  const tagsLine = tags.length > 0 ? tags.join(", ") : "none";

  let lighting =
    "moody appetizing editorial lighting with soft highlights, dark depth, and refined contrast";
  let plating =
    "centered luxury plating on premium tableware, photographed for a polished mobile menu card";

  const combinedContext = `${venueCategory} ${venueDescription}`.toLowerCase();

  if (
    combinedContext.includes("cafe") ||
    combinedContext.includes("coffee") ||
    combinedContext.includes("bakery")
  ) {
    lighting =
      "warm premium cafe lighting with natural highlights, steam, and clean morning atmosphere";
    plating =
      "tasteful editorial cafe presentation on ceramic or wood with restrained styling";
  } else if (
    combinedContext.includes("bar") ||
    combinedContext.includes("lounge") ||
    combinedContext.includes("pub")
  ) {
    lighting =
      "cinematic evening hospitality lighting with amber warmth and elegant low-key shadows";
    plating =
      "stylish premium bar-food presentation with clean composition and strong texture";
  }

  return `
Create a photorealistic food image for a premium restaurant mobile app menu.

Item name: ${item.name}
Item category: ${itemCategory}
Item description: ${itemDescription}
Venue name: ${venue.name}
Venue category: ${venueCategory}
Venue atmosphere: ${venueDescription}
Tags: ${tagsLine}

Art direction:
- High-end editorial food photography.
- Square 1:1 composition designed for a luxury dark mobile UI.
- ${lighting}.
- ${plating}.
- The dish must be centered and clearly readable in a menu card crop.
- Use realistic ingredients, believable garnish, accurate textures, and restaurant plating proportions.
- Background should feel elegant, dark, warm, and modern, suitable for a premium hospitality app with gold, charcoal, mint, and slate visual language.

Do not include:
- Text, logos, labels, watermarks, borders, collage layouts, or split screens.
- Hands, faces, diners, cash, menus, or phones.
- Fake props that block the food.
- Oversaturated colors or cartoon styling.
`.trim();
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
          generationConfig: {
            responseModalities: ["IMAGE"],
            imageConfig: {
              aspectRatio: "1:1",
              imageSize: "1K",
            },
          },
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
