import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  createVenueAdminClient,
  fetchVenueForEnrichment,
  getErrorMessage as getVenueEnrichmentErrorMessage,
  getVenueEnrichmentEnv,
  isVenueEnrichmentInFlight,
  processVenueEnrichment,
  type VenueRecord,
} from "./venue-enrichment.ts";
import { buildGeminiImageGenerationConfig } from "./gemini-image-config.ts";

export interface VenueProfileImageEnv {
  supabaseUrl: string;
  supabaseServiceRoleKey: string;
  geminiApiKey: string;
  venueImageModels: string[];
  venueImageBucket: string;
  cronSecret: string | null;
}

export type Json = Record<string, unknown>;

export interface VenueProfileImageProcessOptions {
  adminClient: ReturnType<typeof createVenueProfileImageAdminClient>;
  env: VenueProfileImageEnv;
  venue: VenueRecord;
  forceRegenerate?: boolean;
  forceGroundingRefresh?: boolean;
  skipSearchGrounding?: boolean;
}

export interface VenueProfileImageProcessResult {
  status: "success" | "skipped";
  venueId: string;
  imageStatus: "ready" | "pending" | "generating" | "failed";
  imageSource: "manual" | "ai_gemini" | null;
  imageUrl: string | null;
  storagePath: string | null;
  model: string | null;
  reason?: string;
}

interface GeminiImagePayload {
  bytes: Uint8Array;
  mimeType: string;
  model: string;
}

interface VenueSceneDirection {
  scene: string;
  lighting: string;
  styling: string;
  background: string;
}

const externalRequestTimeoutMs = 60000;
const staleVenueImageWindowMs = 30 * 60 * 1000;

export class HttpError extends Error {
  constructor(
    public readonly status: number,
    message: string,
    public readonly details?: unknown,
  ) {
    super(message);
  }
}

export function getVenueProfileImageEnv(): VenueProfileImageEnv {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim() ?? "";
  const supabaseServiceRoleKey = Deno.env.get("SERVICE_ROLE_KEY")?.trim() ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() ?? "";
  const geminiApiKey = Deno.env.get("GEMINI_API_KEY")?.trim() ?? "";

  if (!supabaseUrl || !supabaseServiceRoleKey) {
    throw new HttpError(
      500,
      "Missing Supabase environment variables for venue profile image generation.",
    );
  }

  if (!geminiApiKey) {
    throw new HttpError(
      500,
      "Missing GEMINI_API_KEY for venue profile image generation.",
    );
  }

  return {
    supabaseUrl,
    supabaseServiceRoleKey,
    geminiApiKey,
    venueImageModels: (
      Deno.env.get("GEMINI_VENUE_IMAGE_MODELS") ??
        "gemini-2.5-flash-image"
    )
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean),
    venueImageBucket: Deno.env.get("VENUE_IMAGE_BUCKET")?.trim() ||
      "venue-images",
    cronSecret: Deno.env.get("VENUE_IMAGE_CRON_SECRET")?.trim() || null,
  };
}

export function createVenueProfileImageAdminClient(env: VenueProfileImageEnv) {
  return createClient(env.supabaseUrl, env.supabaseServiceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}

export function requireServiceOrCronInvocation(
  req: Request,
  env: VenueProfileImageEnv,
) {
  const cronSecret = req.headers.get("x-cron-secret");
  if (env.cronSecret && cronSecret === env.cronSecret) {
    return;
  }

  if (decodeJwtRole(req.headers.get("Authorization")) === "service_role") {
    return;
  }

  throw new HttpError(401, "Service role or cron secret required.");
}

export function normalizeVenueProfileImageLimit(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) return 4;
  return Math.max(1, Math.min(8, Math.floor(value)));
}

export function venueNeedsProfileImageGeneration(
  venue: VenueRecord,
  forceRegenerate = false,
): boolean {
  if (venue.image_locked) return false;

  if (forceRegenerate) {
    if (normalizeVenueImageSource(venue.image_source) === "manual") {
      return false;
    }
    return true;
  }

  if (hasVenueImage(venue)) {
    return normalizeVenueImageStatus(venue.image_status) === "failed";
  }

  return true;
}

export function isVenueProfileImageGenerationInFlight(
  venue: VenueRecord,
): boolean {
  if (venue.image_status !== "generating") {
    return false;
  }

  const updatedAt = parseIsoTime(venue.updated_at);
  if (updatedAt == null) {
    return true;
  }

  return Date.now() - updatedAt < staleVenueImageWindowMs;
}

export function hasGroundedVenueImageContext(
  venue: VenueRecord,
  skipSearchGrounding = false,
): boolean {
  const hasMapsGrounding = [
    venue.google_place_id,
    venue.google_maps_uri,
    venue.google_place_summary,
  ].some(hasText) ||
    hasListContent(venue.google_attributions);

  if (!hasMapsGrounding) {
    return false;
  }

  const hasDescriptiveGrounding = [
    venue.search_summary,
    venue.google_place_summary,
    venue.google_review_summary,
    venue.description,
  ].some(hasText) || hasListContent(venue.search_sources);

  if (skipSearchGrounding) {
    return hasDescriptiveGrounding;
  }

  return hasDescriptiveGrounding;
}

export async function processVenueProfileImageGeneration(
  options: VenueProfileImageProcessOptions,
): Promise<VenueProfileImageProcessResult> {
  const {
    adminClient,
    env,
    venue,
    forceRegenerate = false,
    forceGroundingRefresh = false,
    skipSearchGrounding = false,
  } = options;

  const hasExistingImage = hasVenueImage(venue);
  const imageSource = normalizeVenueImageSource(venue.image_source);
  const nextAttempt = (venue.image_attempts ?? 0) + 1;

  if (venue.image_locked) {
    return skippedVenueImageResult(venue, "image_locked");
  }

  if (hasExistingImage && imageSource === "manual") {
    await normalizeExistingVenueImageState(adminClient, venue);
    return skippedVenueImageResult(venue, "manual_image_exists");
  }

  if (!forceRegenerate && isVenueProfileImageGenerationInFlight(venue)) {
    return skippedVenueImageResult(venue, "already_generating");
  }

  if (hasExistingImage && imageSource === "ai_gemini" && !forceRegenerate) {
    await normalizeExistingVenueImageState(adminClient, venue);
    return skippedVenueImageResult(venue, "ai_image_exists");
  }

  if (hasExistingImage && imageSource == null && !forceRegenerate) {
    await normalizeExistingVenueImageState(adminClient, venue);
    return skippedVenueImageResult(venue, "existing_image_exists");
  }

  await updateVenueImageState(adminClient, venue.id, {
    image_status: "generating",
    image_error: null,
    updated_at: new Date().toISOString(),
  });

  try {
    let groundedVenue = venue;
    if (
      forceGroundingRefresh ||
      !hasGroundedVenueImageContext(groundedVenue, skipSearchGrounding)
    ) {
      groundedVenue = await ensureGroundedVenueContext(
        adminClient,
        groundedVenue,
        forceGroundingRefresh,
        skipSearchGrounding,
      );
    }

    if (!hasGroundedVenueImageContext(groundedVenue, skipSearchGrounding)) {
      throw new HttpError(
        412,
        skipSearchGrounding
          ? "Grounded Google Maps venue data with descriptive venue context is required before generating a profile image."
          : "Grounded Google Maps or Google Search descriptive venue context is required before generating a profile image.",
      );
    }

    const prompt = buildVenueProfileImagePrompt(groundedVenue);
    const generated = await generateGeminiVenueImage({
      apiKey: env.geminiApiKey,
      models: env.venueImageModels,
      prompt,
    });

    const extension = extensionForMimeType(generated.mimeType);
    const storagePath =
      `venues/${groundedVenue.id}/profile/generated-${Date.now()}.${extension}`;

    const { error: uploadError } = await adminClient.storage
      .from(env.venueImageBucket)
      .upload(storagePath, generated.bytes, {
        contentType: generated.mimeType,
        upsert: false,
      });

    if (uploadError) {
      throw new HttpError(
        502,
        `Unable to upload the generated venue image to storage: ${uploadError.message}`,
        uploadError,
      );
    }

    await cleanupPreviousVenueImage(
      adminClient,
      env.venueImageBucket,
      venue,
      storagePath,
    );

    const {
      data: { publicUrl },
    } = adminClient.storage.from(env.venueImageBucket).getPublicUrl(
      storagePath,
    );

    await updateVenueImageState(adminClient, groundedVenue.id, {
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
      venueId: groundedVenue.id,
      imageStatus: "ready",
      imageSource: "ai_gemini",
      imageUrl: publicUrl,
      storagePath,
      model: generated.model,
    };
  } catch (error) {
    const message = getErrorMessage(error);
    await updateVenueImageState(adminClient, venue.id, {
      image_status: "failed",
      image_error: message,
      image_attempts: nextAttempt,
      updated_at: new Date().toISOString(),
    });
    throw error;
  }
}

export function buildVenueProfileImagePrompt(venue: VenueRecord): string {
  const category = venue.category?.trim() || "Restaurants";
  const primaryType = venue.google_primary_type?.trim() || "";
  const placeSummary = cleanPromptText(venue.google_place_summary) ||
    cleanPromptText(venue.google_review_summary) ||
    cleanPromptText(venue.search_summary) ||
    cleanPromptText(venue.description) ||
    "Premium hospitality venue.";
  const searchSummary = cleanPromptText(venue.search_summary) ||
    cleanPromptText(venue.description) || "";
  const address = cleanPromptText(venue.address) || "";
  const priceLevel = cleanPromptText(venue.google_price_level) || "";
  const rating = venue.rating != null && venue.rating > 0
    ? `${venue.rating.toFixed(1)} / 5`
    : "";
  const ratingCount = venue.rating_count != null && venue.rating_count > 0
    ? `${venue.rating_count}`
    : "";
  const sceneDirection = buildVenueSceneDirection(venue);

  return `
Create a photorealistic venue profile hero image for a hospitality marketplace app.

The image must represent the venue itself, not a food product shot.
Use only the grounded venue facts below. Do not invent amenities, views, architecture, or decor that are not supported by the grounded facts.

═══ GROUNDED VENUE FACTS ═══
Venue name: "${venue.name}"
Canonical category: "${category}"
Google Maps primary type: "${primaryType}"
Grounded Google Maps summary: "${placeSummary}"
Grounded Google Search summary: "${searchSummary}"
Address hint: "${address}"
Price level hint: "${priceLevel}"
Public rating: "${rating}"
Public review count: "${ratingCount}"

═══ IMAGE GOAL ═══
Generate the most relevant hero image for the venue profile based on the grounded facts above.
Focus on the venue space, atmosphere, facade, or signature hospitality setting that best represents the venue.
Do not make a dish, cocktail, coffee cup, or menu item the hero subject unless the grounded venue facts clearly describe a counter scene where it supports the venue environment.

═══ COMPOSITION ═══
- Landscape 16:9 composition optimized for a mobile profile cover image.
- ${sceneDirection.scene}
- ${sceneDirection.lighting}
- ${sceneDirection.styling}
- ${sceneDirection.background}
- Keep the scene immediately readable at small cover-image size.

═══ HARD RULES ═══
- No readable logos, signage text, menus, watermarks, or captions.
- No people as the hero subject. If any guests appear, they must be distant and non-identifiable.
- No plated dish close-up, isolated drink product shot, or kitchen prep scene as the main image.
- No surreal interiors, fantasy architecture, neon cyberpunk styling, or exaggerated luxury cues not grounded in the venue facts.
- No collage layout. One coherent scene only.
`.trim();
}

export function getErrorMessage(error: unknown): string {
  if (error instanceof HttpError) return error.message;
  if (error instanceof Error) return error.message;
  return String(error);
}

async function ensureGroundedVenueContext(
  adminClient: ReturnType<typeof createVenueProfileImageAdminClient>,
  venue: VenueRecord,
  forceGroundingRefresh: boolean,
  skipSearchGrounding: boolean,
): Promise<VenueRecord> {
  if (isVenueEnrichmentInFlight(venue) && !forceGroundingRefresh) {
    if (hasGroundedVenueImageContext(venue, skipSearchGrounding)) {
      return venue;
    }
    throw new HttpError(
      409,
      "Venue grounding refresh is already running. Retry after enrichment finishes.",
    );
  }

  try {
    await processVenueEnrichment({
      adminClient: adminClient as unknown as ReturnType<
        typeof createVenueAdminClient
      >,
      env: getVenueEnrichmentEnv(),
      venue,
      overwriteExisting: forceGroundingRefresh,
      forcePlaceRefresh: forceGroundingRefresh,
      skipSearchGrounding,
    });
  } catch (error) {
    if (!hasGroundedVenueImageContext(venue, skipSearchGrounding)) {
      throw new HttpError(
        502,
        `Unable to refresh grounded venue data: ${
          getVenueEnrichmentErrorMessage(error)
        }`,
        error,
      );
    }
  }

  return await fetchVenueForEnrichment(
    adminClient as unknown as ReturnType<typeof createVenueAdminClient>,
    venue.id,
  );
}

async function generateGeminiVenueImage({
  apiKey,
  models,
  prompt,
}: {
  apiKey: string;
  models: string[];
  prompt: string;
}): Promise<GeminiImagePayload> {
  let lastError = "Gemini did not return a venue image.";

  for (const model of models) {
    const response = await fetchWithTimeout(
      `https://generativelanguage.googleapis.com/v1beta/models/${
        encodeURIComponent(model)
      }:generateContent`,
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-goog-api-key": apiKey,
        },
        body: JSON.stringify({
          contents: [{
            parts: [{ text: prompt }],
          }],
          generationConfig: buildGeminiImageGenerationConfig({
            aspectRatio: "16:9",
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

async function cleanupPreviousVenueImage(
  adminClient: ReturnType<typeof createVenueProfileImageAdminClient>,
  bucket: string,
  venue: VenueRecord,
  nextStoragePath: string,
): Promise<void> {
  const previousStoragePath = venue.image_storage_path?.trim();
  if (!previousStoragePath || previousStoragePath === nextStoragePath) {
    return;
  }

  const { count, error } = await adminClient
    .from("dinein_venues")
    .select("id", { count: "exact", head: true })
    .eq("image_storage_path", previousStoragePath)
    .neq("id", venue.id);

  if (error) {
    throw new HttpError(
      500,
      `Unable to verify previous venue image references: ${error.message}`,
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

async function updateVenueImageState(
  adminClient: ReturnType<typeof createVenueProfileImageAdminClient>,
  venueId: string,
  updates: Json,
): Promise<void> {
  const { error } = await adminClient
    .from("dinein_venues")
    .update(updates)
    .eq("id", venueId);

  if (error) {
    throw new HttpError(
      500,
      `Unable to update the venue image generation state: ${error.message}`,
      error,
    );
  }
}

async function normalizeExistingVenueImageState(
  adminClient: ReturnType<typeof createVenueProfileImageAdminClient>,
  venue: VenueRecord,
): Promise<void> {
  if (
    normalizeVenueImageStatus(venue.image_status) === "ready" &&
    !venue.image_error
  ) {
    return;
  }

  await updateVenueImageState(adminClient, venue.id, {
    image_status: "ready",
    image_error: null,
    updated_at: new Date().toISOString(),
  });
}

function skippedVenueImageResult(
  venue: VenueRecord,
  reason: string,
): VenueProfileImageProcessResult {
  return {
    status: "skipped",
    venueId: venue.id,
    imageStatus: normalizeVenueImageStatus(venue.image_status),
    imageSource: normalizeVenueImageSource(venue.image_source),
    imageUrl: venue.image_url,
    storagePath: venue.image_storage_path,
    model: venue.image_model,
    reason,
  };
}

function buildVenueSceneDirection(venue: VenueRecord): VenueSceneDirection {
  const context = normalizePromptText(
    [
      venue.category,
      venue.google_primary_type,
      venue.google_place_summary,
      venue.google_review_summary,
      venue.search_summary,
      venue.description,
    ].filter(Boolean).join(" "),
  );

  if (
    matchesAny(context, [
      "rooftop",
      "sky bar",
      "skybar",
      "terrace",
      "panoramic",
    ])
  ) {
    return {
      scene:
        "Show a refined rooftop or terrace hospitality scene that emphasizes the venue setting instead of food.",
      lighting:
        "Use premium golden-hour or blue-hour lighting with realistic city or skyline depth when supported by the grounded facts.",
      styling:
        "Favor upscale seating, clean table layouts, and a polished venue atmosphere.",
      background:
        "Keep the environment elegant and architectural with depth, not a close-up tabletop shot.",
    };
  }

  if (
    matchesAny(context, [
      "waterfront",
      "harbour",
      "harbor",
      "marina",
      "sea view",
      "seafront",
      "beach",
      "bay",
    ])
  ) {
    return {
      scene:
        "Show the venue in a waterfront-facing hospitality setting with the venue environment as the hero.",
      lighting:
        "Use warm natural light or premium dusk lighting with believable reflections and coastal atmosphere when grounded by the venue facts.",
      styling:
        "Favor an inviting venue terrace, facade, or dining space with restrained luxury.",
      background:
        "Let the coastal environment support the venue scene without turning the image into a landscape postcard.",
    };
  }

  if (
    matchesAny(context, ["hotel", "resort", "lobby", "suite", "boutique hotel"])
  ) {
    return {
      scene:
        "Show a polished hotel facade, entrance, lobby, or signature hospitality interior that represents the venue brand.",
      lighting:
        "Use elegant architectural lighting with warm highlights and believable premium materials.",
      styling:
        "Focus on hospitality design details, arrival experience, and upscale ambiance.",
      background:
        "Keep the frame architectural and atmospheric, not food-centric.",
    };
  }

  if (
    matchesAny(context, [
      "bar",
      "pub",
      "cocktail",
      "lounge",
      "night club",
      "nightclub",
      "wine bar",
    ])
  ) {
    return {
      scene:
        "Show a premium bar or lounge environment with the venue space as the hero subject.",
      lighting:
        "Use moody evening hospitality lighting with warm amber highlights and realistic low-light contrast.",
      styling:
        "Emphasize the bar counter, seating, shelving, or signature interior architecture rather than a single drink close-up.",
      background:
        "Keep the background immersive and intimate, with depth and a believable nightlife atmosphere.",
    };
  }

  if (matchesAny(context, ["cafe", "bakery", "brunch", "coffee"])) {
    return {
      scene:
        "Show a warm cafe or bakery environment that communicates the venue's space and personality.",
      lighting:
        "Use soft natural or morning hospitality lighting with realistic warmth and texture.",
      styling:
        "Highlight the venue interior, seating, counter, or storefront rather than a product close-up.",
      background:
        "Keep the environment inviting and coherent, with architectural depth.",
    };
  }

  return {
    scene:
      "Show the venue's most representative hospitality environment, facade, or dining-room scene as the hero.",
    lighting:
      "Use premium hospitality lighting with realistic warmth, clean contrast, and architectural depth.",
    styling:
      "Favor a polished venue interior or exterior scene that reflects the grounded venue facts and category.",
    background:
      "Keep the image venue-first and atmospheric, not a close crop of a dish or drink.",
  };
}

function normalizeVenueImageStatus(
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

function normalizeVenueImageSource(
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

function hasVenueImage(venue: VenueRecord): boolean {
  return hasText(venue.image_url);
}

function hasText(value: string | null | undefined): boolean {
  return Boolean(value && value.trim().length > 0);
}

function hasListContent(value: unknown[] | null | undefined): boolean {
  return Array.isArray(value) && value.length > 0;
}

function normalizePromptText(value: string): string {
  return value.toLowerCase().replace(/\s+/g, " ").trim();
}

function cleanPromptText(value: string | null | undefined): string {
  if (!value) return "";
  return value.replace(/\s+/g, " ").trim();
}

function matchesAny(value: string, needles: string[]): boolean {
  return needles.some((needle) => value.includes(needle));
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

async function fetchWithTimeout(
  input: Request | URL | string,
  init?: RequestInit,
  timeoutMs = externalRequestTimeoutMs,
): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(input, {
      ...init,
      signal: controller.signal,
    });
  } catch (error) {
    if (error instanceof DOMException && error.name === "AbortError") {
      throw new HttpError(504, "External venue image request timed out.");
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
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
  if (!value) return null;
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? parsed : null;
}
