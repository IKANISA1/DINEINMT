import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { buildGooglePlacePhotoUri } from "./google-places.ts";
import { verifySupabaseServiceRoleHeader } from "./signed-jwt.ts";
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
  googleMapsApiKey: string | null;
  venueImageModels: string[];
  venueImageVerifierModels: string[];
  venueImageBucket: string;
  venueImageReferenceLimit: number;
  venueDeepResearchAgent: string | null;
  venueDeepResearchPollMs: number;
  venueDeepResearchMaxWaitMs: number;
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

interface VenueImageVerificationPayload {
  matches: boolean;
  hero_subject:
    | "venue_scene"
    | "food_or_drink_product"
    | "people"
    | "text_or_signage"
    | "unclear";
  locality_match: boolean;
  readable_text_present: boolean;
  issues: string[];
  reason: string;
}

interface VenueImageVerificationPromptOptions {
  venue: VenueRecord;
  referenceImageCount: number;
  deepResearchSummary?: string | null;
}

interface VenueReferenceImagePayload {
  data: string;
  mimeType: string;
  sourceUrl: string;
}

interface VenueSceneDirection {
  scene: string;
  lighting: string;
  styling: string;
  background: string;
}

interface VenueDeepResearchResult {
  summary: string;
  sourceUrls: string[];
}

interface VenueDeepResearchDiagnostics {
  lastObservedStatus: string | null;
  httpStatus: number | null;
  lastPolledAt: string | null;
  providerError: string | null;
}

type VenueDeepResearchStatus =
  | "pending"
  | "in_progress"
  | "ready"
  | "failed";

interface VenueDeepResearchReadyResult extends VenueDeepResearchResult {
  status: "ready";
  diagnostics: VenueDeepResearchDiagnostics;
}

interface VenueDeepResearchPendingResult {
  status: "pending";
  reason: string;
  diagnostics: VenueDeepResearchDiagnostics;
}

interface VenueDeepResearchFailedResult {
  status: "failed";
  error: string;
  diagnostics: VenueDeepResearchDiagnostics;
}

const externalRequestTimeoutMs = 60000;
const staleVenueImageWindowMs = 30 * 60 * 1000;
const staleVenueDeepResearchWindowMs = 45 * 60 * 1000;
const venueProfileImagePromptVersion = "venue-profile-image-v3";
const defaultVenueDeepResearchAgent = "deep-research-pro-preview-12-2025";
const defaultVenueDeepResearchMaxWaitMs = 60000;
const venueDeepResearchInlinePollBudgetMs = 20000;

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
  const googleMapsApiKey = Deno.env.get("GOOGLE_MAPS_API_KEY")?.trim() ?? "";

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

  if (!googleMapsApiKey) {
    throw new HttpError(
      500,
      "Missing GOOGLE_MAPS_API_KEY for venue profile image generation.",
    );
  }

  return {
    supabaseUrl,
    supabaseServiceRoleKey,
    geminiApiKey,
    googleMapsApiKey,
    venueImageModels: (
      Deno.env.get("GEMINI_VENUE_IMAGE_MODELS") ??
        "gemini-2.5-flash-image"
    )
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean),
    venueImageVerifierModels: (
      Deno.env.get("GEMINI_VENUE_IMAGE_VERIFIER_MODELS") ??
        "gemini-2.5-flash,gemini-2.5-flash-lite"
    )
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean),
    venueImageBucket: Deno.env.get("VENUE_IMAGE_BUCKET")?.trim() ||
      "venue-images",
    venueImageReferenceLimit: Math.max(
      1,
      Math.min(
        4,
        Number.parseInt(
          Deno.env.get("VENUE_IMAGE_REFERENCE_LIMIT")?.trim() ?? "3",
          10,
        ) || 3,
      ),
    ),
    venueDeepResearchAgent:
      Deno.env.get("GEMINI_VENUE_DEEP_RESEARCH_AGENT")?.trim() ||
      defaultVenueDeepResearchAgent,
    venueDeepResearchPollMs: Math.max(
      1000,
      Number.parseInt(
        Deno.env.get("GEMINI_VENUE_DEEP_RESEARCH_POLL_MS")?.trim() ?? "5000",
        10,
      ) || 5000,
    ),
    venueDeepResearchMaxWaitMs: Math.max(
      5000,
      Number.parseInt(
        Deno.env.get("GEMINI_VENUE_DEEP_RESEARCH_MAX_WAIT_MS")?.trim() ??
          `${defaultVenueDeepResearchMaxWaitMs}`,
        10,
      ) || defaultVenueDeepResearchMaxWaitMs,
    ),
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

export async function requireServiceOrCronInvocation(
  req: Request,
  env: VenueProfileImageEnv,
): Promise<void> {
  const cronSecret = req.headers.get("x-cron-secret");
  if (env.cronSecret && cronSecret === env.cronSecret) {
    return;
  }

  if (await verifySupabaseServiceRoleHeader(req.headers.get("Authorization"))) {
    return;
  }

  throw new HttpError(401, "Service role or cron secret required.");
}

export async function requireServiceInvocation(req: Request): Promise<void> {
  if (await verifySupabaseServiceRoleHeader(req.headers.get("Authorization"))) {
    return;
  }

  throw new HttpError(401, "Service role required.");
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
  if (normalizeVenueImageSource(venue.image_source) === "manual") return false;

  if (forceRegenerate) {
    return true;
  }

  if (hasVenueImage(venue)) {
    return normalizeVenueImageSource(venue.image_source) !== "ai_gemini" ||
      normalizeVenueImageStatus(venue.image_status) === "failed";
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
  const hasMapsGrounding = hasVenueMapsGrounding(venue);

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

function hasVenueMapsGrounding(venue: VenueRecord): boolean {
  return [
    venue.google_place_id,
    venue.google_maps_uri,
    venue.google_place_summary,
  ].some(hasText) || hasListContent(venue.google_attributions);
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
  const nowIso = () => new Date().toISOString();

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

  try {
    let groundedVenue = venue;
    const needsReferenceGrounding = countVenueReferenceImages(groundedVenue) ===
      0;
    if (
      forceGroundingRefresh ||
      !hasGroundedVenueImageContext(groundedVenue, skipSearchGrounding) ||
      needsReferenceGrounding
    ) {
      groundedVenue = await ensureGroundedVenueContext(
        adminClient,
        groundedVenue,
        forceGroundingRefresh,
        skipSearchGrounding,
      );
    }

    if (!hasVenueMapsGrounding(groundedVenue)) {
      throw new HttpError(
        412,
        "Grounded Google Maps venue data is required before generating a profile image.",
      );
    }

    const deepResearch = await ensureVenueDeepResearch({
      adminClient,
      env,
      venue: groundedVenue,
      forceRefresh: forceGroundingRefresh,
    });
    if (deepResearch.status === "pending") {
      const pendingAt = nowIso();
      await updateVenueImageState(adminClient, groundedVenue.id, {
        image_status: "pending",
        image_error: deepResearch.reason,
        updated_at: pendingAt,
      });
      return {
        status: "skipped",
        venueId: groundedVenue.id,
        imageStatus: "pending",
        imageSource: normalizeVenueImageSource(groundedVenue.image_source),
        imageUrl: groundedVenue.image_url,
        storagePath: groundedVenue.image_storage_path,
        model: groundedVenue.image_model,
        reason: "deep_research_pending",
      };
    }

    await updateVenueImageState(adminClient, groundedVenue.id, {
      image_status: "generating",
      image_error: null,
      updated_at: nowIso(),
    });

    const referenceImageUrls = extractVenueReferenceImageUrls(
      groundedVenue,
      env.venueImageReferenceLimit,
      env.googleMapsApiKey,
    );
    const referenceImages = await loadVenueReferenceImages(referenceImageUrls);
    const prompt = buildVenueProfileImagePrompt(groundedVenue, {
      referenceImageCount: referenceImages.length,
      deepResearchSummary: deepResearch.summary,
    });
    const generated = await generateGeminiVenueImage({
      apiKey: env.geminiApiKey,
      models: env.venueImageModels,
      prompt,
      referenceImages,
      verification: {
        models: env.venueImageVerifierModels,
        venue: groundedVenue,
        referenceImages,
      },
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
      image_locked: true,
      image_storage_path: storagePath,
      updated_at: nowIso(),
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
      updated_at: nowIso(),
    });
    throw error;
  }
}

export interface VenueProfileImagePromptOptions {
  referenceImageCount?: number;
  deepResearchSummary?: string | null;
}

export function buildVenueProfileImagePrompt(
  venue: VenueRecord,
  options: VenueProfileImagePromptOptions = {},
): string {
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
  const localityCue = buildVenueLocalityCue(venue);
  const visualEvidenceCue = buildVenueVisualEvidenceCue(venue);
  const deepResearchCue = cleanPromptText(options.deepResearchSummary) || "";
  const referenceInstruction =
    options.referenceImageCount && options.referenceImageCount > 0
      ? `Use the ${options.referenceImageCount} attached public venue reference image(s) as factual guidance for the venue's architecture, facade, interior materials, lighting mood, streetscape, and geographic setting.`
      : "No reference images are attached, so rely strictly on the grounded venue facts and locality rules below.";

  return `
Create a photorealistic, production-safe venue profile hero image for a hospitality marketplace app.

Prompt version: ${venueProfileImagePromptVersion}

The image must represent the venue itself, not a food product shot.
Use only the grounded venue facts and attached public reference images below. Do not invent amenities, views, architecture, decor, or regional context that are not supported by the grounded facts or visual references.
Prefer an accurate but modest scene over a dramatic but invented one.
Do not convert a casual or everyday venue into a luxury-resort stock image unless the grounded facts clearly support that.

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

═══ LOCALITY & VISUAL IDENTITY ═══
- ${localityCue}
- ${visualEvidenceCue}
- ${referenceInstruction}
${deepResearchCue ? `- Deep research note: "${deepResearchCue}"` : ""}
- Use venue context to stay faithful to the real space, materials, scale, and neighbourhood feel.
- Avoid generic Mediterranean stock scenery for Malta and avoid generic East African skyline tropes for Rwanda unless the grounded references specifically support them.

═══ IMAGE GOAL ═══
Generate the most relevant hero image for the venue profile based on the grounded facts above.
Focus on the venue space, atmosphere, facade, or signature hospitality setting that best represents this specific venue.
Do not make a dish, cocktail, coffee cup, or menu item the hero subject unless the grounded venue facts clearly describe a counter scene where it supports the venue environment.
The result should feel venue-specific and locally believable, not interchangeable with an unrelated bar, restaurant, or hotel.

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
- Do not copy brand marks, signage lettering, or copyrighted artwork from the reference images.
- Do not genericize the locale; the scene must read as the grounded venue country and setting.
- No surreal interiors, fantasy architecture, neon cyberpunk styling, exaggerated luxury cues, or generic stock-scene polish not grounded in the venue facts.
- No collage layout. One coherent scene only.
  `.trim();
}

const venueImageVerificationSchema = {
  type: "object",
  properties: {
    matches: { type: "boolean" },
    hero_subject: {
      type: "string",
      enum: [
        "venue_scene",
        "food_or_drink_product",
        "people",
        "text_or_signage",
        "unclear",
      ],
    },
    locality_match: { type: "boolean" },
    readable_text_present: { type: "boolean" },
    issues: {
      type: "array",
      items: { type: "string" },
    },
    reason: { type: "string" },
  },
  required: [
    "matches",
    "hero_subject",
    "locality_match",
    "readable_text_present",
    "issues",
    "reason",
  ],
} as const;

export function buildVenueImageVerificationPrompt(
  args: VenueImageVerificationPromptOptions,
): string {
  const localityCue = buildVenueLocalityCue(args.venue);
  const sceneDirection = buildVenueSceneDirection(args.venue);
  const deepResearchCue = cleanPromptText(args.deepResearchSummary) || "";

  return `
You are reviewing a generated hospitality venue profile image for production.
Return JSON only.

Prompt version: ${venueProfileImagePromptVersion}
Venue name: ${args.venue.name}
Venue category: ${args.venue.category ?? ""}
Venue Google Maps primary type: ${args.venue.google_primary_type ?? ""}
Grounded venue summary: ${
    cleanPromptText(args.venue.google_place_summary) ||
    cleanPromptText(args.venue.search_summary) ||
    cleanPromptText(args.venue.description) || ""
  }
Address hint: ${cleanPromptText(args.venue.address) || ""}
Locality rule: ${localityCue}
Scene target: ${sceneDirection.scene}

Evaluation rules:
- The first image after this prompt is the generated candidate.
- ${
    args.referenceImageCount > 0
      ? `The next ${args.referenceImageCount} image(s) are grounded public venue references.`
      : "No reference images are attached."
  }
- Accept only if the hero subject is a venue scene, facade, terrace, lobby, dining room, bar interior, or other hospitality environment.
- Reject if the hero subject is a plated dish, isolated drink product, kitchen prep, or menu item close-up.
- Reject if people are the hero subject.
- Reject if readable signage text or logos are prominent.
- Reject if the scene feels geographically inconsistent with the grounded locality.
- Reject if the scene looks like a generic stock hotel/bar/restaurant image that is not specific to the grounded venue cues or references.
- Reject if the scene adds unsupported grandeur, architecture, or decor not grounded in the supplied venue facts.
${deepResearchCue ? `- Deep research note: ${deepResearchCue}` : ""}

Set hero_subject to one of: venue_scene, food_or_drink_product, people, text_or_signage, unclear.
issues should use short labels such as "wrong_subject", "people_hero", "readable_text", "locality_mismatch", "generic_stock_scene", "unsupported_grandeur", or "unclear_subject".
`.trim();
}

export function normalizeVenueImageVerificationVerdict(
  verdict: VenueImageVerificationPayload,
): VenueImageVerificationPayload {
  const issues = new Set(
    verdict.issues.filter((entry) => entry.trim().length > 0).map((entry) =>
      entry.trim()
    ),
  );
  const hardFailures: string[] = [];

  if (verdict.hero_subject !== "venue_scene") {
    const issue = verdict.hero_subject === "text_or_signage"
      ? "readable_text"
      : verdict.hero_subject === "people"
      ? "people_hero"
      : verdict.hero_subject === "food_or_drink_product"
      ? "wrong_subject"
      : "unclear_subject";
    issues.add(issue);
    hardFailures.push(`hero subject is ${verdict.hero_subject}`);
  }

  if (!verdict.locality_match) {
    issues.add("locality_mismatch");
    hardFailures.push("locality does not match grounded venue context");
  }

  if (verdict.readable_text_present) {
    issues.add("readable_text");
    hardFailures.push("readable text or signage is present");
  }

  if (hardFailures.length === 0) {
    return {
      ...verdict,
      issues: Array.from(issues).slice(0, 8),
    };
  }

  return {
    ...verdict,
    matches: false,
    issues: Array.from(issues).slice(0, 8),
    reason: hardFailures.join("; "),
  };
}

export function getErrorMessage(error: unknown): string {
  if (error instanceof HttpError) return error.message;
  if (error instanceof Error) return error.message;
  return String(error);
}

export function buildVenueLocalityCue(venue: VenueRecord): string {
  const address = cleanPromptText(venue.address);
  switch ((venue.country ?? "").trim().toUpperCase()) {
    case "RW":
      return [
        "The venue must read as Rwanda",
        address
          ? `and specifically align with the grounded address "${address}"`
          : "",
        "with a realistic contemporary Rwandan or Kigali hospitality setting, East African urban context, local greenery, and architecture consistent with public venue photos and grounded venue data.",
      ].filter(Boolean).join(" ");
    case "MT":
      return [
        "The venue must read as Malta",
        address
          ? `and specifically align with the grounded address "${address}"`
          : "",
        "with realistic Maltese Mediterranean architecture, limestone textures, coastal or historic urban atmosphere where appropriate, and a streetscape consistent with public venue photos and grounded venue data.",
      ].filter(Boolean).join(" ");
    default:
      return address
        ? `The venue must align with the grounded address "${address}" and its real local streetscape, architecture, and environment.`
        : "The venue must align with its grounded local streetscape, architecture, and environment.";
  }
}

export function buildVenueVisualEvidenceCue(venue: VenueRecord): string {
  const photoCount = countVenueReferenceImages(venue);
  if (photoCount > 0) {
    return `There are ${photoCount} public venue reference images available. Use them to anchor the facade, interior materials, lighting mood, streetscape, and environmental context of the generated scene.`;
  }

  return "No public venue reference image is attached, so lean on the grounded Google Maps and Google Search venue summaries without drifting into a generic hospitality stock scene.";
}

async function ensureVenueDeepResearch(args: {
  adminClient: ReturnType<typeof createVenueProfileImageAdminClient>;
  env: VenueProfileImageEnv;
  venue: VenueRecord;
  forceRefresh?: boolean;
}): Promise<VenueDeepResearchReadyResult | VenueDeepResearchPendingResult> {
  const { adminClient, env, venue, forceRefresh = false } = args;
  let deepResearchDebug = normalizeDeepResearchDebug(venue.deep_research_debug);
  const recordEvent = (event: Json): Json => {
    deepResearchDebug = appendVenueDeepResearchEvent(deepResearchDebug, event);
    return deepResearchDebug;
  };

  if (!env.venueDeepResearchAgent || env.venueDeepResearchMaxWaitMs <= 0) {
    throw new HttpError(
      500,
      "Gemini deep research is disabled for venue profile image generation.",
    );
  }

  if (hasReadyVenueDeepResearch(venue) && !forceRefresh) {
    return {
      status: "ready",
      summary: venue.deep_research_summary!.trim(),
      sourceUrls: normalizeDeepResearchSources(venue.deep_research_sources),
      diagnostics: {
        lastObservedStatus: venue.deep_research_last_observed_status ?? "ready",
        httpStatus: venue.deep_research_last_http_status ?? null,
        lastPolledAt: venue.deep_research_last_polled_at ??
          venue.deep_research_updated_at ?? null,
        providerError: venue.deep_research_last_provider_error ?? null,
      },
    };
  }

  let interactionId = venue.deep_research_interaction_id?.trim() || null;
  let interactionStatus = normalizeVenueDeepResearchStatus(
    venue.deep_research_status,
  );
  const staleInteraction = Boolean(
    interactionId &&
      !forceRefresh &&
      interactionStatus !== "failed" &&
      !isVenueDeepResearchInFlight(venue),
  );

  if (staleInteraction) {
    const staleAt = new Date().toISOString();
    await updateVenueDeepResearchState(adminClient, venue.id, {
      deep_research_status: "failed",
      deep_research_error:
        "Previous Gemini deep research interaction stalled without completion and was restarted.",
      deep_research_last_observed_status:
        venue.deep_research_last_observed_status ??
          venue.deep_research_status ?? "in_progress",
      deep_research_last_polled_at: staleAt,
      deep_research_last_provider_error:
        venue.deep_research_last_provider_error ?? null,
      deep_research_debug: recordEvent({
        timestamp: staleAt,
        phase: "stale_restart",
        outcome: "failed",
        interaction_id: interactionId,
        observed_status: venue.deep_research_last_observed_status ??
          venue.deep_research_status ?? "in_progress",
        provider_error:
          "Previous Gemini deep research interaction stalled without completion and was restarted.",
      }),
    });
    interactionId = null;
    interactionStatus = "failed";
  }

  if (
    !interactionId ||
    forceRefresh ||
    interactionStatus === "failed"
  ) {
    let created;
    try {
      created = await createVenueDeepResearchInteraction(env, venue);
    } catch (error) {
      const diagnostics = extractVenueDeepResearchDiagnostics(error);
      const failedAt = diagnostics.lastPolledAt ?? new Date().toISOString();
      const message = diagnostics.providerError ?? getErrorMessage(error);
      await updateVenueDeepResearchState(adminClient, venue.id, {
        deep_research_status: "failed",
        deep_research_error: message,
        deep_research_last_observed_status: diagnostics.lastObservedStatus ??
          "create_failed",
        deep_research_last_http_status: diagnostics.httpStatus,
        deep_research_last_polled_at: failedAt,
        deep_research_last_provider_error: diagnostics.providerError,
        deep_research_debug: recordEvent({
          timestamp: failedAt,
          phase: "create",
          outcome: "failed",
          observed_status: diagnostics.lastObservedStatus ?? "create_failed",
          http_status: diagnostics.httpStatus,
          provider_error: diagnostics.providerError ?? message,
        }),
      });
      throw error;
    }

    interactionId = created.interactionId;
    interactionStatus = created.status;
    const createdAt = created.diagnostics.lastPolledAt ??
      new Date().toISOString();
    await updateVenueDeepResearchState(adminClient, venue.id, {
      deep_research_status: interactionStatus,
      deep_research_error: null,
      deep_research_interaction_id: interactionId,
      deep_research_attempts: (venue.deep_research_attempts ?? 0) + 1,
      deep_research_model: env.venueDeepResearchAgent,
      deep_research_updated_at: createdAt,
      deep_research_last_observed_status:
        created.diagnostics.lastObservedStatus ?? interactionStatus,
      deep_research_last_http_status: created.diagnostics.httpStatus,
      deep_research_last_polled_at: createdAt,
      deep_research_last_provider_error: created.diagnostics.providerError,
      deep_research_debug: recordEvent({
        timestamp: createdAt,
        phase: "create",
        outcome: created.result ? "ready" : "started",
        interaction_id: interactionId,
        observed_status: created.diagnostics.lastObservedStatus ??
          interactionStatus,
        http_status: created.diagnostics.httpStatus,
        provider_error: created.diagnostics.providerError,
      }),
    });

    if (created.result) {
      return await finalizeVenueDeepResearch(
        adminClient,
        venue.id,
        env.venueDeepResearchAgent,
        created.result,
        deepResearchDebug,
      );
    }
  }

  const polled = await pollVenueDeepResearchInteraction(
    env,
    interactionId,
  );

  if (polled.status === "ready") {
    return await finalizeVenueDeepResearch(
      adminClient,
      venue.id,
      env.venueDeepResearchAgent,
      polled,
      recordEvent({
        timestamp: polled.diagnostics.lastPolledAt ?? new Date().toISOString(),
        phase: "poll",
        outcome: "ready",
        interaction_id: interactionId,
        observed_status: polled.diagnostics.lastObservedStatus ?? "ready",
        http_status: polled.diagnostics.httpStatus,
        provider_error: polled.diagnostics.providerError,
      }),
    );
  }

  if (polled.status === "failed") {
    const failedAt = polled.diagnostics.lastPolledAt ??
      new Date().toISOString();
    await updateVenueDeepResearchState(adminClient, venue.id, {
      deep_research_status: "failed",
      deep_research_error: polled.error,
      deep_research_interaction_id: interactionId,
      deep_research_model: env.venueDeepResearchAgent,
      deep_research_updated_at: failedAt,
      deep_research_last_observed_status:
        polled.diagnostics.lastObservedStatus ?? "failed",
      deep_research_last_http_status: polled.diagnostics.httpStatus,
      deep_research_last_polled_at: failedAt,
      deep_research_last_provider_error: polled.diagnostics.providerError,
      deep_research_debug: recordEvent({
        timestamp: failedAt,
        phase: "poll",
        outcome: "failed",
        interaction_id: interactionId,
        observed_status: polled.diagnostics.lastObservedStatus ?? "failed",
        http_status: polled.diagnostics.httpStatus,
        provider_error: polled.diagnostics.providerError ?? polled.error,
      }),
    });
    throw new HttpError(
      502,
      `Gemini deep research failed: ${polled.error}`,
    );
  }

  const pendingAt = polled.diagnostics.lastPolledAt ?? new Date().toISOString();
  await updateVenueDeepResearchState(adminClient, venue.id, {
    deep_research_status: "in_progress",
    deep_research_error: null,
    deep_research_interaction_id: interactionId,
    deep_research_model: env.venueDeepResearchAgent,
    deep_research_updated_at: pendingAt,
    deep_research_last_observed_status: polled.diagnostics.lastObservedStatus ??
      "in_progress",
    deep_research_last_http_status: polled.diagnostics.httpStatus,
    deep_research_last_polled_at: pendingAt,
    deep_research_last_provider_error: polled.diagnostics.providerError,
    deep_research_debug: recordEvent({
      timestamp: pendingAt,
      phase: "poll",
      outcome: "pending",
      interaction_id: interactionId,
      observed_status: polled.diagnostics.lastObservedStatus ?? "in_progress",
      http_status: polled.diagnostics.httpStatus,
      provider_error: polled.diagnostics.providerError,
    }),
  });

  return {
    status: "pending",
    reason:
      "Gemini deep research is still running in the background for this venue. Retry the manual image generation shortly.",
    diagnostics: polled.diagnostics,
  };
}

function buildVenueDeepResearchPrompt(venue: VenueRecord): string {
  return [
    "Research this hospitality venue for brand-image generation.",
    "Prioritize verified public information that helps depict the real venue faithfully.",
    "Focus on venue identity, facade, interior atmosphere, locality, architecture, materials, streetscape, landscape, and any recurring visual cues visible in public sources.",
    "Prefer Google Maps, official website, major review sources, and public venue photos.",
    "Do not invent facts. If something is uncertain, omit it.",
    "",
    `Venue name: ${venue.name}`,
    `Country code: ${venue.country ?? ""}`,
    `Address: ${venue.address ?? ""}`,
    `Category: ${venue.category ?? ""}`,
    `Google Maps summary: ${venue.google_place_summary ?? ""}`,
    `Google review summary: ${venue.google_review_summary ?? ""}`,
    `Google Maps URI: ${venue.google_maps_uri ?? ""}`,
    `Official website: ${venue.website_url ?? ""}`,
    "",
    "Return a concise factual report that prioritizes:",
    "1. venue identity and positioning",
    "2. facade, architecture, materials, terrace/interior layout, and lighting mood",
    "3. neighbourhood or streetscape cues that matter visually",
    "4. recurring visual details visible in public photos or place descriptions",
    "5. any explicit reasons the venue should not be depicted as luxury, beachside, rooftop, hotel, or nightlife if those cues are not supported",
    "",
    "Include source URLs inline when possible.",
  ].join("\n");
}

function extractInteractionText(interaction: Json): string | null {
  const texts: string[] = [];
  const directOutput = stringOrNull(asRecord(interaction.output).text);
  if (directOutput) {
    texts.push(directOutput);
  }
  for (const output of asArray(interaction.outputs)) {
    const row = asRecord(output);
    const directText = stringOrNull(row.text);
    if (directText) {
      texts.push(directText);
    }

    const parts = asArray(asRecord(row.content).parts);
    for (const part of parts) {
      const text = stringOrNull(asRecord(part).text);
      if (text) {
        texts.push(text);
      }
    }
  }

  const combined = texts.join("\n\n").trim();
  return combined.length > 0 ? combined : null;
}

async function createVenueDeepResearchInteraction(
  env: VenueProfileImageEnv,
  venue: VenueRecord,
): Promise<{
  interactionId: string;
  status: VenueDeepResearchStatus;
  result?: VenueDeepResearchReadyResult;
  diagnostics: VenueDeepResearchDiagnostics;
}> {
  const requestedAt = new Date().toISOString();
  const createResponse = await fetchWithTimeout(
    "https://generativelanguage.googleapis.com/v1beta/interactions",
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-goog-api-key": env.geminiApiKey,
      },
      body: JSON.stringify({
        agent: env.venueDeepResearchAgent,
        background: true,
        store: true,
        input: buildVenueDeepResearchPrompt(venue),
      }),
    },
    20000,
  );

  if (!createResponse.ok) {
    const providerError = await extractGeminiError(createResponse);
    throw new HttpError(
      502,
      `Unable to start Gemini deep research: ${providerError}`,
      {
        deepResearch: {
          lastObservedStatus: "create_failed",
          httpStatus: createResponse.status,
          lastPolledAt: requestedAt,
          providerError,
        },
      },
    );
  }

  const interaction = asRecord(await safeJson(createResponse));
  const interactionId = stringOrNull(interaction.id);
  if (!interactionId) {
    throw new HttpError(
      502,
      "Gemini deep research did not return an interaction id.",
      {
        deepResearch: {
          lastObservedStatus: stringOrNull(interaction.status) ??
            "missing_interaction_id",
          httpStatus: createResponse.status,
          lastPolledAt: requestedAt,
          providerError: extractInteractionError(interaction),
        },
      },
    );
  }

  const result = finalizeDeepResearchInteraction(interaction, {
    httpStatus: createResponse.status,
    lastPolledAt: requestedAt,
  });
  return {
    interactionId,
    status: result?.status ?? "pending",
    result: result?.status === "ready" ? result : undefined,
    diagnostics: result?.diagnostics ?? {
      lastObservedStatus: stringOrNull(interaction.status) ?? "pending",
      httpStatus: createResponse.status,
      lastPolledAt: requestedAt,
      providerError: extractInteractionError(interaction),
    },
  };
}

async function pollVenueDeepResearchInteraction(
  env: VenueProfileImageEnv,
  interactionId: string,
): Promise<
  | VenueDeepResearchReadyResult
  | VenueDeepResearchPendingResult
  | VenueDeepResearchFailedResult
> {
  const deadline = Date.now() +
    Math.min(
      env.venueDeepResearchMaxWaitMs,
      venueDeepResearchInlinePollBudgetMs,
    );
  let lastDiagnostics: VenueDeepResearchDiagnostics = {
    lastObservedStatus: "in_progress",
    httpStatus: null,
    lastPolledAt: null,
    providerError: null,
  };

  while (Date.now() < deadline) {
    const pollAt = new Date().toISOString();
    const pollResponse = await fetchWithTimeout(
      `https://generativelanguage.googleapis.com/v1beta/interactions/${
        encodeURIComponent(interactionId)
      }`,
      {
        method: "GET",
        headers: {
          "content-type": "application/json",
          "x-goog-api-key": env.geminiApiKey,
        },
      },
      Math.min(env.venueDeepResearchPollMs + 5000, 15000),
    );
    if (!pollResponse.ok) {
      const providerError = await extractGeminiError(pollResponse);
      return {
        status: "failed",
        error: `Unable to poll Gemini deep research: ${providerError}`,
        diagnostics: {
          lastObservedStatus: "poll_failed",
          httpStatus: pollResponse.status,
          lastPolledAt: pollAt,
          providerError,
        },
      };
    }

    const interaction = asRecord(await safeJson(pollResponse));
    const result = finalizeDeepResearchInteraction(interaction, {
      httpStatus: pollResponse.status,
      lastPolledAt: pollAt,
    });
    lastDiagnostics = result?.diagnostics ?? {
      lastObservedStatus: stringOrNull(interaction.status) ?? "in_progress",
      httpStatus: pollResponse.status,
      lastPolledAt: pollAt,
      providerError: extractInteractionError(interaction),
    };
    if (result) {
      return result;
    }

    await delay(env.venueDeepResearchPollMs);
  }

  return {
    status: "pending",
    reason:
      "Gemini deep research is still running in the background for this venue. Retry the manual image generation shortly.",
    diagnostics: {
      ...lastDiagnostics,
      lastPolledAt: new Date().toISOString(),
    },
  };
}

function finalizeDeepResearchInteraction(
  interaction: Json,
  baseDiagnostics: Partial<VenueDeepResearchDiagnostics> = {},
):
  | VenueDeepResearchReadyResult
  | VenueDeepResearchPendingResult
  | VenueDeepResearchFailedResult
  | null {
  const rawStatus = stringOrNull(interaction.status);
  const status = normalizeVenueDeepResearchStatus(rawStatus);
  const diagnostics: VenueDeepResearchDiagnostics = {
    lastObservedStatus: rawStatus ?? baseDiagnostics.lastObservedStatus ?? null,
    httpStatus: baseDiagnostics.httpStatus ?? null,
    lastPolledAt: baseDiagnostics.lastPolledAt ?? new Date().toISOString(),
    providerError: extractInteractionError(interaction) ??
      baseDiagnostics.providerError ?? null,
  };
  if (status === "ready") {
    const report = extractInteractionText(interaction);
    if (!report) {
      return {
        status: "failed",
        error: "Gemini deep research completed without a usable text report.",
        diagnostics: {
          ...diagnostics,
          providerError:
            "Gemini deep research completed without a usable text report.",
        },
      };
    }
    return {
      status: "ready",
      summary: summarizeDeepResearchReport(report),
      sourceUrls: extractUrlsFromText(report),
      diagnostics,
    };
  }

  if (status === "failed") {
    return {
      status: "failed",
      error: extractInteractionError(interaction) ??
        "Gemini deep research failed without an error message.",
      diagnostics,
    };
  }

  if (status === "pending" || status === "in_progress") {
    return {
      status: "pending",
      reason:
        "Gemini deep research is still running in the background for this venue. Retry the manual image generation shortly.",
      diagnostics,
    };
  }

  return null;
}

async function finalizeVenueDeepResearch(
  adminClient: ReturnType<typeof createVenueProfileImageAdminClient>,
  venueId: string,
  model: string,
  result: VenueDeepResearchReadyResult,
  deepResearchDebug?: Json,
): Promise<VenueDeepResearchReadyResult> {
  const finalizedAt = result.diagnostics.lastPolledAt ??
    new Date().toISOString();
  await updateVenueDeepResearchState(adminClient, venueId, {
    deep_research_status: "ready",
    deep_research_summary: result.summary,
    deep_research_sources: result.sourceUrls,
    deep_research_error: null,
    deep_research_interaction_id: null,
    deep_research_model: model,
    deep_research_updated_at: finalizedAt,
    deep_research_last_observed_status: result.diagnostics.lastObservedStatus ??
      "ready",
    deep_research_last_http_status: result.diagnostics.httpStatus,
    deep_research_last_polled_at: finalizedAt,
    deep_research_last_provider_error: null,
    ...(deepResearchDebug ? { deep_research_debug: deepResearchDebug } : {}),
  });

  return result;
}

async function updateVenueDeepResearchState(
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
      `Unable to update the venue deep research state: ${error.message}`,
      error,
    );
  }
}

function extractInteractionError(interaction: Json): string | null {
  const direct = stringOrNull(interaction.error);
  if (direct) return direct;

  const nested = asRecord(interaction.error);
  return stringOrNull(nested.message) ??
    stringOrNull(nested.status) ??
    stringOrNull(nested.code);
}

function summarizeDeepResearchReport(report: string): string {
  const cleaned = report
    .replace(/\[[^\]]+\]\([^)]+\)/g, "")
    .replace(/^#+\s+/gm, "")
    .replace(/\s+/g, " ")
    .trim();
  if (cleaned.length <= 540) {
    return cleaned;
  }
  return `${cleaned.slice(0, 537).trimEnd()}...`;
}

function extractUrlsFromText(value: string): string[] {
  const matches = value.match(/https?:\/\/[^\s)>\]]+/g) ?? [];
  return [...new Set(matches)].slice(0, 8);
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
  referenceImages,
  verification,
}: {
  apiKey: string;
  models: string[];
  prompt: string;
  referenceImages: VenueReferenceImagePayload[];
  verification?: {
    models: string[];
    venue: VenueRecord;
    referenceImages: VenueReferenceImagePayload[];
  };
}): Promise<GeminiImagePayload> {
  let lastError = "Gemini did not return a venue image.";

  for (const model of models) {
    const parts = [
      ...referenceImages.map((reference) => ({
        inlineData: {
          data: reference.data,
          mimeType: reference.mimeType,
        },
      })),
      { text: prompt },
    ];
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
            parts,
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
      if (verification) {
        const verdict = await verifyGeneratedVenueImage({
          apiKey,
          models: verification.models,
          imageBytes: payload.bytes,
          mimeType: payload.mimeType,
          venue: verification.venue,
          referenceImages: verification.referenceImages,
        });
        if (verdict && !verdict.matches) {
          lastError =
            `Model "${model}" generated an invalid venue image (${verdict.hero_subject}): ${verdict.reason}`;
          continue;
        }
      }

      return {
        ...payload,
        model,
      };
    }

    lastError = `Model "${model}" returned no inline image payload.`;
  }

  throw new HttpError(502, lastError);
}

async function verifyGeneratedVenueImage(args: {
  apiKey: string;
  models: string[];
  imageBytes: Uint8Array;
  mimeType: string;
  venue: VenueRecord;
  referenceImages: VenueReferenceImagePayload[];
}): Promise<VenueImageVerificationPayload | null> {
  const prompt = buildVenueImageVerificationPrompt({
    venue: args.venue,
    referenceImageCount: args.referenceImages.length,
    deepResearchSummary: args.venue.deep_research_summary,
  });
  const parts = [
    { text: prompt },
    {
      inlineData: {
        mimeType: args.mimeType,
        data: encodeBytesToBase64(args.imageBytes),
      },
    },
    ...args.referenceImages.map((reference) => ({
      inlineData: {
        data: reference.data,
        mimeType: reference.mimeType,
      },
    })),
  ];

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
          contents: [{
            role: "user",
            parts,
          }],
          generationConfig: {
            responseMimeType: "application/json",
            responseJsonSchema: venueImageVerificationSchema,
          },
        }),
      },
      20000,
    );

    if (!response.ok) {
      continue;
    }

    const body = asRecord(await response.json());
    const candidate = asRecord(asArray(body.candidates)[0]);
    const content = asRecord(candidate.content);
    const text = stringOrNull(asRecord(asArray(content.parts)[0]).text);
    const parsed = text ? parseJsonObjectText(text) : null;
    if (!parsed) {
      continue;
    }

    const heroSubject = stringOrNull(parsed.hero_subject);
    const issues = Array.isArray(parsed.issues)
      ? parsed.issues.filter((entry): entry is string =>
        typeof entry === "string" && entry.trim().length > 0
      ).map((entry) => entry.trim()).slice(0, 8)
      : [];
    if (
      typeof parsed.matches !== "boolean" ||
      !heroSubject ||
      ![
        "venue_scene",
        "food_or_drink_product",
        "people",
        "text_or_signage",
        "unclear",
      ].includes(heroSubject) ||
      typeof parsed.locality_match !== "boolean" ||
      typeof parsed.readable_text_present !== "boolean"
    ) {
      continue;
    }

    return normalizeVenueImageVerificationVerdict({
      matches: parsed.matches,
      hero_subject:
        heroSubject as VenueImageVerificationPayload["hero_subject"],
      locality_match: parsed.locality_match,
      readable_text_present: parsed.readable_text_present,
      issues,
      reason: stringOrNull(parsed.reason) || "No verification reason supplied.",
    });
  }

  return null;
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
  const shouldLockGeneratedImage =
    normalizeVenueImageSource(venue.image_source) === "ai_gemini" &&
    venue.image_locked !== true;
  const shouldNormalizeStatus =
    normalizeVenueImageStatus(venue.image_status) !== "ready" ||
    Boolean(venue.image_error);

  if (!shouldNormalizeStatus && !shouldLockGeneratedImage) {
    return;
  }

  const updates: Json = {
    updated_at: new Date().toISOString(),
  };

  if (shouldNormalizeStatus) {
    updates.image_status = "ready";
    updates.image_error = null;
  }

  if (shouldLockGeneratedImage) {
    updates.image_locked = true;
  }

  await updateVenueImageState(adminClient, venue.id, updates);
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
      venue.deep_research_summary,
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
    const barStyling = matchesAny(context, [
        "stage",
        "dj",
        "live music",
        "pool table",
        "pool tables",
        "billiards",
      ])
      ? "Emphasize the bar counter together with any grounded performance or recreation cues, such as a stage or pool-table area, rather than a single drink close-up."
      : "Emphasize the bar counter, seating, shelving, or signature interior architecture rather than a single drink close-up.";
    return {
      scene:
        "Show a venue-appropriate bar or lounge environment with the venue space as the hero subject.",
      lighting:
        "Use moody evening hospitality lighting with warm amber highlights and realistic low-light contrast.",
      styling: barStyling,
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

export function extractVenueReferenceImageUrls(
  venue: VenueRecord,
  limit = 3,
  googleMapsApiKey?: string | null,
): string[] {
  const urls: string[] = [];
  const normalizedLimit = Math.max(0, Math.min(6, limit));
  const mapsApiKey = googleMapsApiKey?.trim() || null;

  for (const photo of asArray(venue.google_photos)) {
    const row = asRecord(photo);
    const url = cleanReferenceImageUrl(
      (mapsApiKey && stringOrNull(row.name))
        ? buildGooglePlacePhotoUri(stringOrNull(row.name)!, mapsApiKey)
        : null,
    ) ?? cleanReferenceImageUrl(
      buildGooglePlacePhotoUrlFromStoredPath(
        stringOrNull(row.photo_path) ?? stringOrNull(row.photoPath),
        mapsApiKey,
      ),
    ) ?? cleanReferenceImageUrl(
      stringOrNull(row.photo_uri) ?? stringOrNull(row.photoUri) ??
        stringOrNull(row.uri),
    );
    if (url && !urls.includes(url)) {
      urls.push(url);
    }
    if (urls.length >= normalizedLimit) {
      return urls;
    }
  }

  const discoveredImageUrl = cleanReferenceImageUrl(venue.image_url);
  if (
    discoveredImageUrl &&
    normalizeVenueImageSource(venue.image_source) == null &&
    !urls.includes(discoveredImageUrl)
  ) {
    urls.push(discoveredImageUrl);
  }

  return urls.slice(0, normalizedLimit);
}

export function countVenueReferenceImages(venue: VenueRecord): number {
  let count = 0;
  for (const photo of asArray(venue.google_photos)) {
    const row = asRecord(photo);
    if (
      stringOrNull(row.name) ||
      stringOrNull(row.photo_path) ||
      stringOrNull(row.photoPath) ||
      stringOrNull(row.photo_uri) ||
      stringOrNull(row.photoUri) ||
      stringOrNull(row.uri)
    ) {
      count += 1;
    }
  }
  if (
    count === 0 &&
    cleanReferenceImageUrl(venue.image_url) &&
    normalizeVenueImageSource(venue.image_source) == null
  ) {
    return 1;
  }
  return count;
}

function buildGooglePlacePhotoUrlFromStoredPath(
  path: string | null,
  googleMapsApiKey: string | null,
): string | null {
  const candidate = path?.trim();
  if (!candidate || !googleMapsApiKey) {
    return null;
  }
  try {
    const url = new URL(candidate);
    url.searchParams.set("key", googleMapsApiKey);
    return url.toString();
  } catch (_) {
    return null;
  }
}

async function loadVenueReferenceImages(
  urls: string[],
): Promise<VenueReferenceImagePayload[]> {
  const results: VenueReferenceImagePayload[] = [];
  for (const url of urls) {
    try {
      const reference = await fetchVenueReferenceImage(url);
      if (reference) {
        results.push(reference);
      }
    } catch (_) {
      continue;
    }
  }
  return results;
}

async function fetchVenueReferenceImage(
  url: string,
): Promise<VenueReferenceImagePayload | null> {
  const response = await fetchWithTimeout(url, undefined, 12000);
  if (!response.ok) return null;

  const mimeType = normalizeReferenceImageMimeType(
    response.headers.get("content-type"),
  );
  if (!mimeType) return null;

  const contentLength = Number.parseInt(
    response.headers.get("content-length") ?? "",
    10,
  );
  if (Number.isFinite(contentLength) && contentLength > 6_000_000) {
    return null;
  }

  const bytes = new Uint8Array(await response.arrayBuffer());
  if (bytes.length == 0 || bytes.length > 6_000_000) {
    return null;
  }

  return {
    data: encodeBytesToBase64(bytes),
    mimeType,
    sourceUrl: url,
  };
}

function cleanReferenceImageUrl(
  value: string | null | undefined,
): string | null {
  const candidate = value?.trim();
  if (!candidate) return null;
  const normalized = candidate.toLowerCase();
  if (
    normalized.endsWith(".svg") ||
    normalized.includes("logo") ||
    normalized.includes("favicon") ||
    normalized.includes("icon") ||
    normalized.includes("avatar")
  ) {
    return null;
  }

  try {
    const url = new URL(candidate);
    if (!["http:", "https:"].includes(url.protocol)) {
      return null;
    }
    return url.toString();
  } catch (_) {
    return null;
  }
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

export function normalizeVenueDeepResearchStatus(
  value: string | null,
): VenueDeepResearchStatus {
  switch ((value ?? "").trim().toLowerCase()) {
    case "in_progress":
    case "running":
    case "queued":
      return "in_progress";
    case "completed":
    case "ready":
      return "ready";
    case "failed":
    case "cancelled":
      return "failed";
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

export function hasReadyVenueDeepResearch(venue: VenueRecord): boolean {
  if (!hasText(venue.deep_research_summary)) {
    return false;
  }

  if (
    normalizeVenueDeepResearchStatus(venue.deep_research_status) !== "ready"
  ) {
    return false;
  }

  const researchUpdatedAt = parseIsoTime(venue.deep_research_updated_at);
  const enrichedAt = parseIsoTime(venue.last_enriched_at);
  if (researchUpdatedAt == null) {
    return false;
  }
  if (enrichedAt != null && researchUpdatedAt < enrichedAt) {
    return false;
  }

  return true;
}

function isVenueDeepResearchInFlight(venue: VenueRecord): boolean {
  const status = normalizeVenueDeepResearchStatus(venue.deep_research_status);
  if (status !== "pending" && status !== "in_progress") {
    return false;
  }

  const updatedAt = parseIsoTime(venue.deep_research_updated_at);
  if (updatedAt == null) {
    return hasText(venue.deep_research_interaction_id);
  }

  return Date.now() - updatedAt < staleVenueDeepResearchWindowMs;
}

function normalizeDeepResearchSources(value: unknown): string[] {
  return asArray(value)
    .map((entry) => {
      if (typeof entry === "string") {
        return entry.trim();
      }
      const row = asRecord(entry);
      return stringOrNull(row.url) ?? stringOrNull(row.uri) ?? "";
    })
    .filter((entry) => entry.length > 0)
    .slice(0, 12);
}

function normalizeDeepResearchDebug(value: unknown): Json {
  const current = asRecord(value);
  const events = asArray(current.events)
    .map((entry) => asRecord(entry))
    .filter((entry) => Object.keys(entry).length > 0)
    .slice(-9);

  return {
    ...current,
    events,
  };
}

function appendVenueDeepResearchEvent(current: Json, event: Json): Json {
  const events = asArray(current.events)
    .map((entry) => asRecord(entry))
    .filter((entry) => Object.keys(entry).length > 0)
    .slice(-9);

  return {
    ...current,
    last_event: event,
    events: [...events, event],
  };
}

function extractVenueDeepResearchDiagnostics(
  error: unknown,
): VenueDeepResearchDiagnostics {
  const details = error instanceof HttpError ? asRecord(error.details) : {};
  const deepResearch = asRecord(details.deepResearch);

  const httpStatus = typeof deepResearch.httpStatus === "number" &&
      Number.isFinite(deepResearch.httpStatus)
    ? deepResearch.httpStatus
    : null;

  return {
    lastObservedStatus: stringOrNull(deepResearch.lastObservedStatus) ??
      "failed",
    httpStatus,
    lastPolledAt: stringOrNull(deepResearch.lastPolledAt) ??
      new Date().toISOString(),
    providerError: stringOrNull(deepResearch.providerError) ??
      (error instanceof Error ? error.message : String(error)),
  };
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

function normalizeReferenceImageMimeType(value: string | null): string | null {
  const normalized = value?.split(";")[0]?.trim().toLowerCase() ?? "";
  switch (normalized) {
    case "image/jpeg":
    case "image/png":
    case "image/webp":
      return normalized;
    default:
      return null;
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

async function safeJson(response: Response): Promise<Json> {
  try {
    return asRecord(await response.json());
  } catch (_) {
    return {};
  }
}

function parseJsonObjectText(value: string): Json | null {
  const trimmed = value.trim();
  if (trimmed.length === 0) return null;

  const candidates = [
    trimmed,
    trimmed.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "").trim(),
  ];

  for (const candidate of candidates) {
    try {
      const parsed = JSON.parse(candidate);
      return asRecord(parsed);
    } catch (_) {
      continue;
    }
  }

  return null;
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

function encodeBytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunkSize = 0x8000;
  for (let index = 0; index < bytes.length; index += chunkSize) {
    const slice = bytes.subarray(index, index + chunkSize);
    binary += String.fromCharCode(...slice);
  }
  return btoa(binary);
}

function parseIsoTime(value: string | null | undefined): number | null {
  if (!value) return null;
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function asRecord(value: unknown): Json {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Json
    : {};
}

function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function stringValue(value: unknown): string | undefined {
  if (typeof value === "string") {
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : undefined;
  }
  if (typeof value === "number" || typeof value === "boolean") {
    return String(value);
  }
  return undefined;
}

function stringOrNull(value: unknown): string | null {
  return stringValue(value) ?? null;
}
