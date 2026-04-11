import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  fetchGooglePlaceDetails,
  type GooglePlaceSnapshot,
  searchGooglePlaceByText,
} from "./google-places.ts";
import { verifySupabaseServiceRoleHeader } from "./signed-jwt.ts";

export interface VenueEnrichmentEnv {
  supabaseUrl: string;
  supabaseServiceRoleKey: string;
  geminiApiKey: string;
  googleMapsApiKey: string | null;
  venueEnrichmentModels: string[];
  cronSecret: string | null;
}

export type Json = Record<string, unknown>;

export interface VenueRecord {
  id: string;
  name: string;
  slug: string;
  updated_at?: string | null;
  category: string | null;
  description: string | null;
  address: string | null;
  phone: string | null;
  email: string | null;
  image_url: string | null;
  image_source: string | null;
  image_status: string | null;
  image_model: string | null;
  image_prompt: string | null;
  image_generated_at: string | null;
  image_error: string | null;
  image_attempts: number | null;
  image_locked: boolean | null;
  image_storage_path: string | null;
  status: string | null;
  rating: number | null;
  rating_count: number | null;
  country: string | null;
  opening_hours: Json | null;
  owner_id: string | null;
  website_url: string | null;
  reservation_url: string | null;
  social_links: Json | null;
  reviews: unknown[] | null;
  google_place_id: string | null;
  google_place_resource_name: string | null;
  google_maps_uri: string | null;
  google_maps_links: Json | null;
  google_primary_type: string | null;
  google_types: string[] | null;
  google_business_status: string | null;
  google_location: Json | null;
  google_opening_hours: Json | null;
  google_price_level: string | null;
  google_review_summary: string | null;
  google_review_summary_disclosure: string | null;
  google_review_summary_uri: string | null;
  google_place_summary: string | null;
  google_place_summary_disclosure: string | null;
  google_photos: unknown[] | null;
  google_attributions: unknown[] | null;
  search_summary: string | null;
  search_sources: unknown[] | null;
  search_queries: string[] | null;
  deep_research_status: string | null;
  deep_research_summary: string | null;
  deep_research_sources: unknown[] | null;
  deep_research_error: string | null;
  deep_research_interaction_id: string | null;
  deep_research_updated_at: string | null;
  deep_research_attempts: number | null;
  deep_research_model: string | null;
  deep_research_last_observed_status: string | null;
  deep_research_last_http_status: number | null;
  deep_research_last_polled_at: string | null;
  deep_research_last_provider_error: string | null;
  deep_research_debug: Json | null;
  enrichment_status: string | null;
  enrichment_error: string | null;
  enrichment_attempts: number | null;
  enrichment_locked: boolean | null;
  last_enriched_at: string | null;
  enrichment_confidence: number | null;
  category_source: string | null;
}

export interface ProcessVenueEnrichmentOptions {
  adminClient: ReturnType<typeof createVenueAdminClient>;
  env: VenueEnrichmentEnv;
  venue: VenueRecord;
  overwriteExisting?: boolean;
  forcePlaceRefresh?: boolean;
  skipSearchGrounding?: boolean;
}

export interface VenueEnrichmentResult {
  status: "success" | "skipped";
  venueId: string;
  enrichmentStatus: "ready" | "pending" | "enriching" | "failed";
  googlePlaceId: string | null;
  category: string | null;
  imageUrl: string | null;
  websiteUrl: string | null;
  confidence: number | null;
  updatedFields: string[];
  reason?: string;
}

interface MapsGroundingResult {
  googlePlaceId: string | null;
  googlePlaceResourceName: string | null;
  googleMapsUri: string | null;
  formattedAddress: string | null;
  contactPhone: string | null;
  officialWebsite: string | null;
  primaryType: string | null;
  types: string[];
  businessStatus: string | null;
  priceLevel: string | null;
  rating: number | null;
  ratingCount: number | null;
  reviewSummary: string | null;
  placeSummary: string | null;
  openingHours: string[];
  location: Json | null;
  reviews: Json[];
  canonicalCategory: string | null;
  confidence: number | null;
  sources: Json[];
  photos: Json[];
}

interface SearchGroundingResult {
  canonicalCategory: string | null;
  description: string | null;
  officialWebsite: string | null;
  reservationUrl: string | null;
  instagramUrl: string | null;
  facebookUrl: string | null;
  tiktokUrl: string | null;
  formattedAddress: string | null;
  contactPhone: string | null;
  googleMapsUri: string | null;
  rating: number | null;
  ratingCount: number | null;
  priceLevel: string | null;
  reviewSummary: string | null;
  confidence: number | null;
  queries: string[];
  sources: Json[];
}

interface WebsiteMetadata {
  imageUrl: string | null;
  description: string | null;
  phone: string | null;
  address: string | null;
  socialLinks: Json;
  rating: number | null;
  ratingCount: number | null;
  priceLevel: string | null;
}

const venueSelect =
  "id, name, slug, updated_at, category, description, address, phone, email, image_url, image_source, image_status, image_model, image_prompt, image_generated_at, image_error, image_attempts, image_locked, image_storage_path, status, rating, rating_count, country, opening_hours, owner_id, website_url, reservation_url, social_links, reviews, google_place_id, google_place_resource_name, google_maps_uri, google_maps_links, google_primary_type, google_types, google_business_status, google_location, google_opening_hours, google_price_level, google_review_summary, google_review_summary_disclosure, google_review_summary_uri, google_place_summary, google_place_summary_disclosure, google_photos, google_attributions, search_summary, search_sources, search_queries, deep_research_status, deep_research_summary, deep_research_sources, deep_research_error, deep_research_interaction_id, deep_research_updated_at, deep_research_attempts, deep_research_model, deep_research_last_observed_status, deep_research_last_http_status, deep_research_last_polled_at, deep_research_last_provider_error, deep_research_debug, enrichment_status, enrichment_error, enrichment_attempts, enrichment_locked, last_enriched_at, enrichment_confidence, category_source";

const googleSearchSchema = {
  type: "object",
  properties: {
    canonicalCategory: {
      type: "string",
      enum: ["Bar", "Bar & Restaurants", "Restaurants", "Hotels", ""],
    },
    description: { type: "string" },
    officialWebsite: { type: "string" },
    reservationUrl: { type: "string" },
    instagramUrl: { type: "string" },
    facebookUrl: { type: "string" },
    tiktokUrl: { type: "string" },
    formattedAddress: { type: "string" },
    contactPhone: { type: "string" },
    googleMapsUri: { type: "string" },
    rating: { type: "number" },
    ratingCount: { type: "number" },
    priceLevel: { type: "string" },
    reviewSummary: { type: "string" },
    confidence: { type: "number" },
  },
  required: [
    "canonicalCategory",
    "description",
    "officialWebsite",
    "reservationUrl",
    "instagramUrl",
    "facebookUrl",
    "tiktokUrl",
    "formattedAddress",
    "contactPhone",
    "googleMapsUri",
    "rating",
    "ratingCount",
    "priceLevel",
    "reviewSummary",
    "confidence",
  ],
} as const;

const googleMapsGroundingSchema = {
  type: "object",
  properties: {
    canonicalCategory: {
      type: "string",
      enum: ["Bar", "Bar & Restaurants", "Restaurants", "Hotels", ""],
    },
    googlePlaceId: { type: "string" },
    googlePlaceResourceName: { type: "string" },
    googleMapsUri: { type: "string" },
    formattedAddress: { type: "string" },
    contactPhone: { type: "string" },
    officialWebsite: { type: "string" },
    primaryType: { type: "string" },
    types: {
      type: "array",
      items: { type: "string" },
    },
    businessStatus: { type: "string" },
    priceLevel: { type: "string" },
    rating: { type: "number" },
    ratingCount: { type: "number" },
    reviewSummary: { type: "string" },
    placeSummary: { type: "string" },
    openingHours: {
      type: "array",
      items: { type: "string" },
    },
    location: {
      type: "object",
      properties: {
        latitude: { type: ["number", "null"] },
        longitude: { type: ["number", "null"] },
      },
      required: ["latitude", "longitude"],
    },
    reviews: {
      type: "array",
      items: {
        type: "object",
        properties: {
          author: { type: "string" },
          rating: { type: "number" },
          text: { type: "string" },
          publishTime: { type: "string" },
          googleMapsUri: { type: "string" },
        },
        required: ["author", "rating", "text", "publishTime", "googleMapsUri"],
      },
    },
    confidence: { type: "number" },
  },
  required: [
    "canonicalCategory",
    "googlePlaceId",
    "googlePlaceResourceName",
    "googleMapsUri",
    "formattedAddress",
    "contactPhone",
    "officialWebsite",
    "primaryType",
    "types",
    "businessStatus",
    "priceLevel",
    "rating",
    "ratingCount",
    "reviewSummary",
    "placeSummary",
    "openingHours",
    "location",
    "reviews",
    "confidence",
  ],
} as const;

const barTypes = new Set([
  "bar",
  "bar_and_grill",
  "beer_garden",
  "brewpub",
  "cocktail_bar",
  "gastropub",
  "hookah_bar",
  "irish_pub",
  "lounge_bar",
  "night_club",
  "pub",
  "snack_bar",
  "sports_bar",
  "wine_bar",
]);

const hotelTypes = new Set([
  "bed_and_breakfast",
  "extended_stay_hotel",
  "guest_house",
  "hostel",
  "hotel",
  "inn",
  "lodging",
  "motel",
  "private_guest_room",
  "resort_hotel",
]);

const externalRequestTimeoutMs = 60000;
const staleEnrichmentWindowMs = 30 * 60 * 1000;

export class HttpError extends Error {
  constructor(
    public readonly status: number,
    message: string,
    public readonly details?: unknown,
  ) {
    super(message);
  }
}

export function getVenueEnrichmentEnv(): VenueEnrichmentEnv {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim() ?? "";
  const supabaseServiceRoleKey = Deno.env.get("SERVICE_ROLE_KEY")?.trim() ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() ?? "";
  const geminiApiKey = Deno.env.get("GEMINI_API_KEY")?.trim() ?? "";
  const googleMapsApiKey = Deno.env.get("GOOGLE_MAPS_API_KEY")?.trim() ||
    geminiApiKey ||
    null;
  if (!supabaseUrl || !supabaseServiceRoleKey) {
    throw new HttpError(
      500,
      "Missing Supabase environment variables for venue enrichment.",
    );
  }

  if (!geminiApiKey) {
    throw new HttpError(500, "Missing GEMINI_API_KEY for venue enrichment.");
  }

  return {
    supabaseUrl,
    supabaseServiceRoleKey,
    geminiApiKey,
    googleMapsApiKey,
    venueEnrichmentModels: (
      Deno.env.get("GEMINI_VENUE_MODELS") ??
        "gemini-2.5-flash,gemini-2.5-flash-lite"
    ).split(",").map((value) => value.trim()).filter(Boolean),
    cronSecret: Deno.env.get("VENUE_ENRICHMENT_CRON_SECRET")?.trim() || null,
  };
}

export function createVenueAdminClient(env: VenueEnrichmentEnv) {
  return createClient(env.supabaseUrl, env.supabaseServiceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}

export async function requireServiceOrCronInvocation(
  req: Request,
  env: VenueEnrichmentEnv,
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

export async function fetchVenueForEnrichment(
  adminClient: ReturnType<typeof createVenueAdminClient>,
  venueId: string,
): Promise<VenueRecord> {
  const { data, error } = await adminClient
    .from("dinein_venues")
    .select(venueSelect)
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

export function normalizeVenueEnrichmentLimit(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) return 1;
  return Math.max(1, Math.min(2, Math.floor(value)));
}

export function venueNeedsEnrichment(
  venue: VenueRecord,
  overwriteExisting = false,
): boolean {
  if (venue.enrichment_locked) {
    return false;
  }

  if (overwriteExisting) {
    return true;
  }

  const hasSearchBackfill = !isBlankString(venue.search_summary) ||
    hasUnknownArrayContent(venue.search_sources);

  const missingPrimaryFields = [
    venue.address,
    venue.image_url,
    venue.website_url,
  ].some(isBlankString);

  const missingProviderFields = [
    venue.google_place_id,
    venue.google_maps_uri,
    venue.google_primary_type,
  ].some(isBlankString) && !hasSearchBackfill;
  const missingPlacePhotos = !hasUnknownArrayContent(venue.google_photos) &&
    [venue.google_place_id, venue.google_maps_uri].some((value) =>
      !isBlankString(value)
    );

  const weakRating = (venue.rating_count ?? 0) <= 0 || (venue.rating ?? 0) <= 0;
  const hasNoReviews = (!Array.isArray(venue.reviews) ||
    venue.reviews.length == 0) &&
    isBlankString(venue.google_review_summary);
  const failedPreviously = venue.enrichment_status === "failed";

  return missingPrimaryFields || missingProviderFields || weakRating ||
    hasNoReviews || missingPlacePhotos || failedPreviously;
}

export function isVenueEnrichmentInFlight(venue: VenueRecord): boolean {
  if (venue.enrichment_status !== "enriching") {
    return false;
  }

  const startedAt = parseIsoTime(venue.last_enriched_at);
  if (startedAt == null) {
    return true;
  }

  return Date.now() - startedAt < staleEnrichmentWindowMs;
}

export async function processVenueEnrichment(
  options: ProcessVenueEnrichmentOptions,
): Promise<VenueEnrichmentResult> {
  const {
    adminClient,
    env,
    venue,
    overwriteExisting = false,
    forcePlaceRefresh = false,
    skipSearchGrounding = false,
  } = options;

  if (venue.enrichment_locked) {
    return {
      status: "skipped",
      venueId: venue.id,
      enrichmentStatus: "ready",
      googlePlaceId: venue.google_place_id,
      category: venue.category,
      imageUrl: venue.image_url,
      websiteUrl: venue.website_url,
      confidence: venue.enrichment_confidence,
      updatedFields: [],
      reason: "Venue enrichment is locked.",
    };
  }

  if (!overwriteExisting && !venueNeedsEnrichment(venue, false)) {
    return {
      status: "skipped",
      venueId: venue.id,
      enrichmentStatus: "ready",
      googlePlaceId: venue.google_place_id,
      category: venue.category,
      imageUrl: venue.image_url,
      websiteUrl: venue.website_url,
      confidence: venue.enrichment_confidence,
      updatedFields: [],
      reason: "Venue already has the required enrichment fields.",
    };
  }

  const nextAttempt = (venue.enrichment_attempts ?? 0) + 1;
  await updateVenueEnrichmentState(adminClient, venue.id, {
    enrichment_status: "enriching",
    enrichment_error: null,
    enrichment_attempts: nextAttempt,
    last_enriched_at: new Date().toISOString(),
  });

  try {
    let mapsGrounding: MapsGroundingResult | null = null;
    let mapsConfidence = venue.enrichment_confidence ?? 0.45;
    let normalizedCategory = normalizeGroundedCategory(
      venue.category,
      "Restaurants",
    );
    let mapsLookupError: string | null = null;

    try {
      mapsGrounding = await enrichWithGoogleMapsGrounding(
        env,
        venue,
        forcePlaceRefresh,
      );
      normalizedCategory = normalizeVenueCategory(
        mapsGrounding.primaryType,
        mapsGrounding.types,
        venue.category,
      );
      mapsConfidence = mapsGrounding.confidence ??
        venue.enrichment_confidence ??
        0.82;
    } catch (error) {
      mapsLookupError = getErrorMessage(error);
      console.warn(
        "[venue-enrichment] google maps grounding failed, falling back to search-only enrichment",
        venue.id,
        mapsLookupError,
      );
    }

    if (env.googleMapsApiKey) {
      try {
        const placeSnapshot = await fetchGooglePlacesContext(
          env,
          venue,
          mapsGrounding,
        );
        if (placeSnapshot) {
          mapsGrounding = mergeMapsGroundingWithPlaceSnapshot(
            mapsGrounding,
            placeSnapshot,
            venue,
          );
          normalizedCategory = normalizeVenueCategory(
            mapsGrounding.primaryType,
            mapsGrounding.types,
            venue.category,
          );
          mapsConfidence = Math.max(
            mapsConfidence,
            mapsGrounding.confidence ?? 0.76,
          );
        }
      } catch (error) {
        console.warn(
          "[venue-enrichment] google places hydration skipped",
          venue.id,
          getErrorMessage(error),
        );
      }
    }

    const searchGrounding = skipSearchGrounding
      ? null
      : await enrichWithGoogleSearch(
        env,
        venue,
        mapsGrounding,
        normalizedCategory,
        mapsLookupError,
      )
        .catch((error) => {
          console.error(
            "[venue-enrichment] google search grounding failed",
            error,
          );
          return null;
        });

    if (
      mapsGrounding == null &&
      searchGrounding == null
    ) {
      throw new HttpError(
        502,
        mapsLookupError ??
          `Venue enrichment failed for "${venue.name}" without search fallback.`,
      );
    }

    const websiteMetadata = await fetchWebsiteMetadata(
      searchGrounding?.officialWebsite ??
        mapsGrounding?.officialWebsite ??
        venue.website_url,
    )
      .catch((error) => {
        console.warn(
          "[venue-enrichment] website metadata fetch skipped",
          venue.id,
          getErrorMessage(error),
        );
        return null;
      });

    const update = mapsGrounding
      ? buildVenueUpdate(
        venue,
        mapsGrounding,
        mapsConfidence,
        searchGrounding,
        websiteMetadata,
        normalizedCategory,
        overwriteExisting,
      )
      : buildSearchOnlyVenueUpdate(
        venue,
        searchGrounding,
        websiteMetadata,
        normalizedCategory,
        overwriteExisting,
      );
    const updatedFields = Object.keys(update);

    await adminClient
      .from("dinein_venues")
      .update(update)
      .eq("id", venue.id)
      .throwOnError();

    return {
      status: "success",
      venueId: venue.id,
      enrichmentStatus: "ready",
      googlePlaceId: stringOrNull(update.google_place_id) ??
        mapsGrounding?.googlePlaceId ??
        null,
      category: stringOrNull(update.category) ?? normalizedCategory,
      imageUrl: stringOrNull(update.image_url) ?? venue.image_url,
      websiteUrl: stringOrNull(update.website_url) ?? venue.website_url,
      confidence: numberOrNull(update.enrichment_confidence),
      updatedFields,
    };
  } catch (error) {
    const message = getErrorMessage(error);
    await updateVenueEnrichmentState(adminClient, venue.id, {
      enrichment_status: "failed",
      enrichment_error: message,
    });
    throw error;
  }
}

export function getErrorMessage(error: unknown): string {
  if (error instanceof HttpError) return error.message;
  if (error instanceof Error) return error.message;
  return String(error);
}

function buildVenueUpdate(
  venue: VenueRecord,
  mapsGrounding: MapsGroundingResult,
  mapsConfidence: number,
  searchGrounding: SearchGroundingResult | null,
  websiteMetadata: WebsiteMetadata | null,
  normalizedCategory: string,
  overwriteExisting: boolean,
): Json {
  const update: Json = {
    google_place_id: mapsGrounding.googlePlaceId,
    google_place_resource_name: mapsGrounding.googlePlaceResourceName,
    google_maps_uri: mapsGrounding.googleMapsUri ??
      searchGrounding?.googleMapsUri,
    google_maps_links: buildGoogleMapsLinks(mapsGrounding),
    google_primary_type: mapsGrounding.primaryType,
    google_types: mapsGrounding.types,
    google_business_status: mapsGrounding.businessStatus,
    google_location: mapsGrounding.location,
    google_opening_hours: buildGoogleOpeningHours(mapsGrounding.openingHours),
    google_price_level: mapsGrounding.priceLevel ??
      searchGrounding?.priceLevel ?? websiteMetadata?.priceLevel,
    google_review_summary: mapsGrounding.reviewSummary ??
      searchGrounding?.reviewSummary,
    google_review_summary_disclosure: mapsGrounding.reviewSummary
      ? "Grounded with Google Maps via Gemini."
      : null,
    google_review_summary_uri: mapsGrounding.googleMapsUri,
    google_place_summary: mapsGrounding.placeSummary,
    google_place_summary_disclosure: mapsGrounding.placeSummary
      ? "Grounded with Google Maps via Gemini."
      : null,
    google_photos: mapsGrounding.photos.length > 0
      ? mapsGrounding.photos
      : null,
    google_attributions: mapGroundingSourcesToAttributions(
      mapsGrounding.sources,
    ),
    search_summary: searchGrounding?.description ?? null,
    search_sources: searchGrounding?.sources ?? null,
    search_queries: searchGrounding?.queries ?? null,
    enrichment_status: "ready",
    enrichment_error: null,
    last_enriched_at: new Date().toISOString(),
    enrichment_confidence: buildConfidence(mapsConfidence, searchGrounding),
  };

  const formattedAddress = mapsGrounding.formattedAddress ??
    websiteMetadata?.address ?? searchGrounding?.formattedAddress;
  const phone = mapsGrounding.contactPhone ?? searchGrounding?.contactPhone ??
    websiteMetadata?.phone;
  const website = mapsGrounding.officialWebsite ??
    searchGrounding?.officialWebsite;
  const reservationUrl = sanitizeUrl(searchGrounding?.reservationUrl);
  const primaryPhoto = websiteMetadata?.imageUrl;
  const summaryDescription = stringOrNull(update.google_place_summary) ??
    searchGrounding?.description ?? websiteMetadata?.description;
  const category = searchGrounding?.canonicalCategory || normalizedCategory;
  const socialLinks = mergeSocialLinks(
    buildSocialLinks(searchGrounding),
    websiteMetadata?.socialLinks ?? {},
  );

  if (formattedAddress && shouldWriteText(venue.address, overwriteExisting)) {
    update.address = formattedAddress;
  }

  if (phone && shouldWriteText(venue.phone, overwriteExisting)) {
    update.phone = phone;
  }

  if (website && shouldWriteText(venue.website_url, overwriteExisting)) {
    update.website_url = website;
  }

  if (
    reservationUrl &&
    shouldWriteText(venue.reservation_url, overwriteExisting)
  ) {
    update.reservation_url = reservationUrl;
  }

  if (
    Object.keys(socialLinks).length > 0 &&
    (overwriteExisting || !hasJsonContent(venue.social_links))
  ) {
    update.social_links = socialLinks;
  }

  if (
    primaryPhoto && shouldWriteDiscoveredVenueImage(venue, overwriteExisting)
  ) {
    update.image_url = primaryPhoto;
    update.image_status = "ready";
    update.image_error = null;
  }

  if (
    summaryDescription &&
    shouldWriteText(venue.description, overwriteExisting)
  ) {
    update.description = summaryDescription;
  }

  if (category && (overwriteExisting || !isCanonicalCategory(venue.category))) {
    update.category = category;
    update.category_source = searchGrounding?.canonicalCategory
      ? "ai_gemini"
      : "ai_gemini";
  }

  const rating = mapsGrounding.rating ?? searchGrounding?.rating ??
    websiteMetadata?.rating;
  if (rating != null) {
    update.rating = rating;
  }

  const ratingCount = mapsGrounding.ratingCount ??
    searchGrounding?.ratingCount ?? websiteMetadata?.ratingCount;
  if (ratingCount != null) {
    update.rating_count = Math.max(0, Math.round(ratingCount));
  }

  if (
    buildGoogleOpeningHours(mapsGrounding.openingHours) &&
    (overwriteExisting || !hasJsonContent(venue.opening_hours))
  ) {
    update.opening_hours = buildGoogleOpeningHours(mapsGrounding.openingHours);
  }

  if (
    mapsGrounding.reviews.length > 0 &&
    (overwriteExisting || !hasReviewContent(venue.reviews))
  ) {
    update.reviews = mapsGrounding.reviews;
  }

  return update;
}

async function enrichWithGoogleMapsGrounding(
  env: VenueEnrichmentEnv,
  venue: VenueRecord,
  _forceRefresh: boolean,
): Promise<MapsGroundingResult> {
  const prompt = [
    "You are enriching a hospitality venue record for a production marketplace.",
    "Use only grounded Google Maps results from the built-in googleMaps tool.",
    "Never invent facts, links, ratings, reviews, or place identifiers.",
    "If a value cannot be verified from grounded Google Maps results, return an empty string, 0, null, or an empty array.",
    "Resolve the single best Google Maps match for this venue using the provided name, address, category, and country hints.",
    "Canonical categories allowed: Bar, Bar & Restaurants, Restaurants, Hotels.",
    "",
    `Venue name: ${venue.name}`,
    `Current category: ${venue.category ?? ""}`,
    `Current description: ${venue.description ?? ""}`,
    `Current address: ${venue.address ?? ""}`,
    `Country code: ${venue.country ?? ""}`,
    "",
    "Return only a JSON object with this exact shape:",
    "{",
    '  "canonicalCategory": "Bar | Bar & Restaurants | Restaurants | Hotels | \\"\\"",',
    '  "googlePlaceId": "",',
    '  "googlePlaceResourceName": "",',
    '  "googleMapsUri": "",',
    '  "formattedAddress": "",',
    '  "contactPhone": "",',
    '  "officialWebsite": "",',
    '  "primaryType": "",',
    '  "types": [],',
    '  "businessStatus": "",',
    '  "priceLevel": "",',
    '  "rating": 0,',
    '  "ratingCount": 0,',
    '  "reviewSummary": "",',
    '  "placeSummary": "",',
    '  "openingHours": [],',
    '  "location": { "latitude": null, "longitude": null },',
    '  "reviews": [{"author":"", "rating":0, "text":"", "publishTime":"", "googleMapsUri":""}],',
    '  "confidence": 0',
    "}",
  ].join("\n");

  for (const model of env.venueEnrichmentModels) {
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
          contents: [{
            role: "user",
            parts: [{ text: prompt }],
          }],
          tools: [{ googleMaps: {} }],
          generationConfig: {
            responseMimeType: "application/json",
            responseJsonSchema: googleMapsGroundingSchema,
          },
        }),
      },
    );

    if (!response.ok) {
      const body = await safeJson(response);
      console.warn(
        "[venue-enrichment] google maps grounding model failed",
        model,
        body,
      );
      continue;
    }

    const body = asRecord(await response.json());
    const candidate = asRecord(asArray(body.candidates)[0]);
    const jsonText = extractJsonPayloadFromCandidate(candidate);
    const parsed = jsonText ? parseJsonObjectText(jsonText) : null;
    const sources = extractMapsGroundingSources(
      asRecord(candidate.groundingMetadata),
    );

    const grounded = normalizeMapsGroundingResult(parsed, sources, venue);
    if (
      grounded.googleMapsUri ||
      grounded.googlePlaceId ||
      grounded.formattedAddress ||
      grounded.sources.length > 0
    ) {
      return grounded;
    }
  }

  throw new HttpError(
    502,
    `Google Maps grounding failed to resolve a venue match for "${venue.name}".`,
  );
}

function extractJsonPayloadFromCandidate(candidate: Json): string | null {
  const parts = asArray(asRecord(candidate.content).parts);
  const text = parts
    .map((entry) => stringOrNull(asRecord(entry).text))
    .filter((entry): entry is string => Boolean(entry))
    .join("\n")
    .trim();
  return text.length > 0 ? text : null;
}

function parseJsonObjectText(value: string): Json | null {
  const candidates = [
    value.trim(),
    stripMarkdownCodeFence(value),
    extractBalancedJsonObject(value),
  ].filter((entry): entry is string =>
    Boolean(entry && entry.trim().length > 0)
  );

  for (const candidate of candidates) {
    try {
      return asRecord(JSON.parse(candidate));
    } catch (_) {
      continue;
    }
  }

  return null;
}

function stripMarkdownCodeFence(value: string): string {
  const match = value.match(/```(?:json)?\s*([\s\S]*?)```/i);
  return match?.[1]?.trim() ?? value.trim();
}

function extractBalancedJsonObject(value: string): string | null {
  const source = stripMarkdownCodeFence(value);
  const startIndex = source.indexOf("{");
  if (startIndex < 0) return null;

  let depth = 0;
  let inString = false;
  let escaped = false;
  for (let index = startIndex; index < source.length; index += 1) {
    const char = source[index];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char === "\\") {
        escaped = true;
      } else if (char === '"') {
        inString = false;
      }
      continue;
    }

    if (char === '"') {
      inString = true;
      continue;
    }

    if (char === "{") {
      depth += 1;
      continue;
    }

    if (char === "}") {
      depth -= 1;
      if (depth === 0) {
        return source.slice(startIndex, index + 1);
      }
    }
  }

  return null;
}

function extractMapsGroundingSources(groundingMetadata: Json): Json[] {
  return asArray(groundingMetadata.groundingChunks)
    .map((entry) => asRecord(asRecord(entry).maps))
    .map((entry) => ({
      uri: sanitizeUrl(stringValue(entry.uri)),
      title: stringOrNull(entry.title),
      place_id: stringOrNull(entry.placeId),
      place_answer_sources: asArray(entry.placeAnswerSources).map((source) =>
        asRecord(source)
      ),
      review_answer_sources: asArray(entry.reviewAnswerSources).map((source) =>
        asRecord(source)
      ),
    }))
    .filter((entry) => entry.uri || entry.title || entry.place_id);
}

function normalizeMapsGroundingResult(
  parsed: Json | null,
  sources: Json[],
  venue: VenueRecord,
): MapsGroundingResult {
  const parsedValue = parsed ?? {};
  const sourcePlaceId = firstGroundedPlaceId(sources);
  const normalizedIds = normalizePlaceIdentifiers(
    stringOrNull(parsedValue.googlePlaceId) ?? sourcePlaceId,
    stringOrNull(parsedValue.googlePlaceResourceName) ?? sourcePlaceId,
  );
  const googleMapsUri = sanitizeUrl(stringValue(parsedValue.googleMapsUri)) ??
    sanitizeUrl(stringValue(sources[0]?.uri));
  const primaryType = stringOrNull(parsedValue.primaryType);
  const types = asStringArray(parsedValue.types);
  const normalizedCategory = normalizeVenueCategory(
    primaryType,
    types,
    venue.category,
  );

  return {
    googlePlaceId: normalizedIds.placeId,
    googlePlaceResourceName: normalizedIds.resourceName,
    googleMapsUri,
    formattedAddress: stringOrNull(parsedValue.formattedAddress),
    contactPhone: stringOrNull(parsedValue.contactPhone),
    officialWebsite: sanitizeUrl(stringValue(parsedValue.officialWebsite)),
    primaryType,
    types,
    businessStatus: stringOrNull(parsedValue.businessStatus),
    priceLevel: stringOrNull(parsedValue.priceLevel),
    rating: clampRating(numberOrNull(parsedValue.rating)),
    ratingCount: normalizeCount(numberOrNull(parsedValue.ratingCount)),
    reviewSummary: cleanSummary(stringValue(parsedValue.reviewSummary), 16),
    placeSummary: cleanSummary(stringValue(parsedValue.placeSummary), 24),
    openingHours: normalizeOpeningHours(parsedValue.openingHours),
    location: normalizeLocation(parsedValue.location),
    reviews: normalizeGroundedReviews(parsedValue.reviews),
    canonicalCategory: normalizeGroundedCategory(
      stringValue(parsedValue.canonicalCategory),
      normalizedCategory,
    ),
    confidence: clampConfidence(numberOrNull(parsedValue.confidence)),
    sources,
    photos: [],
  };
}

async function fetchGooglePlacesContext(
  env: VenueEnrichmentEnv,
  venue: VenueRecord,
  mapsGrounding: MapsGroundingResult | null,
): Promise<GooglePlaceSnapshot | null> {
  const apiKey = env.googleMapsApiKey?.trim();
  if (!apiKey) return null;

  const directSnapshot = await fetchGooglePlaceDetails({
    apiKey,
    placeId: mapsGrounding?.googlePlaceId,
    resourceName: mapsGrounding?.googlePlaceResourceName,
  });
  if (directSnapshot) return directSnapshot;

  const query = buildGooglePlaceSearchTextQuery(venue, mapsGrounding);
  if (!query) return null;

  return await searchGooglePlaceByText({
    apiKey,
    query,
    pageSize: 1,
  });
}

function buildGooglePlaceSearchTextQuery(
  venue: VenueRecord,
  mapsGrounding: MapsGroundingResult | null,
): string | null {
  const parts = [
    venue.name,
    mapsGrounding?.formattedAddress,
    venue.address,
    venue.country === "RW" ? "Rwanda" : venue.country === "MT" ? "Malta" : null,
  ]
    .map((entry) => stringOrNull(entry))
    .filter((entry): entry is string => Boolean(entry))
    .map((entry) => entry.trim())
    .filter((entry, index, self) =>
      entry.length > 0 && self.indexOf(entry) === index
    );

  return parts.length > 0 ? parts.join(", ") : null;
}

function mergeMapsGroundingWithPlaceSnapshot(
  mapsGrounding: MapsGroundingResult | null,
  snapshot: GooglePlaceSnapshot,
  venue: VenueRecord,
): MapsGroundingResult {
  const fallback = mapsGrounding ?? normalizeMapsGroundingResult(
    null,
    [],
    venue,
  );
  const primaryType = snapshot.primaryType ?? fallback.primaryType;
  const types = snapshot.types.length > 0 ? snapshot.types : fallback.types;
  const canonicalCategory = normalizeVenueCategory(
    primaryType,
    types,
    venue.category,
  );
  const sourceUri = snapshot.googleMapsUri ?? fallback.googleMapsUri;
  const mergedSources = [
    ...fallback.sources,
    ...(sourceUri || snapshot.placeId || snapshot.displayName
      ? [
        {
          uri: sourceUri,
          title: snapshot.displayName,
          place_id: snapshot.placeId,
        } satisfies Json,
      ]
      : []),
  ].filter((entry, index, self) =>
    self.findIndex((candidate) =>
      stringOrNull(candidate.place_id) === stringOrNull(entry.place_id) &&
      stringOrNull(candidate.uri) === stringOrNull(entry.uri)
    ) === index
  );

  return {
    googlePlaceId: snapshot.placeId ?? fallback.googlePlaceId,
    googlePlaceResourceName: snapshot.resourceName ??
      fallback.googlePlaceResourceName,
    googleMapsUri: snapshot.googleMapsUri ?? fallback.googleMapsUri,
    formattedAddress: snapshot.formattedAddress ?? fallback.formattedAddress,
    contactPhone: snapshot.nationalPhoneNumber ?? fallback.contactPhone,
    officialWebsite: snapshot.websiteUri ?? fallback.officialWebsite,
    primaryType,
    types,
    businessStatus: fallback.businessStatus,
    priceLevel: snapshot.priceLevel ?? fallback.priceLevel,
    rating: snapshot.rating ?? fallback.rating,
    ratingCount: snapshot.userRatingCount ?? fallback.ratingCount,
    reviewSummary: fallback.reviewSummary,
    placeSummary: fallback.placeSummary,
    openingHours: fallback.openingHours,
    location: snapshot.location ?? fallback.location,
    reviews: fallback.reviews,
    canonicalCategory,
    confidence: fallback.confidence ?? 0.76,
    sources: mergedSources,
    photos: snapshot.photos as unknown as Json[],
  };
}

function firstGroundedPlaceId(sources: Json[]): string | null {
  for (const source of sources) {
    const placeId = stringOrNull(source.place_id);
    if (placeId) return placeId;
  }
  return null;
}

function normalizePlaceIdentifiers(
  googlePlaceId: string | null,
  googlePlaceResourceName: string | null,
): { placeId: string | null; resourceName: string | null } {
  const resourceName = googlePlaceResourceName?.startsWith("places/")
    ? googlePlaceResourceName
    : googlePlaceId?.startsWith("places/")
    ? googlePlaceId
    : null;
  const rawPlaceId = googlePlaceId?.startsWith("places/")
    ? googlePlaceId.substring("places/".length)
    : googlePlaceId;
  const placeId = rawPlaceId?.trim() ||
    resourceName?.substring("places/".length) ||
    null;
  return {
    placeId,
    resourceName,
  };
}

function normalizeOpeningHours(value: unknown): string[] {
  const raw = asArray(value)
    .map((entry) => stringOrNull(entry))
    .filter((entry): entry is string => Boolean(entry))
    .map((entry) => entry.replace(/\s+/g, " ").trim())
    .filter((entry) => entry.length > 0);
  return [...new Set(raw)].slice(0, 7);
}

function normalizeLocation(value: unknown): Json | null {
  const row = asRecord(value);
  const latitude = numberOrNull(row.latitude);
  const longitude = numberOrNull(row.longitude);
  if (latitude == null || longitude == null) return null;
  return {
    latitude,
    longitude,
  };
}

function normalizeGroundedReviews(value: unknown): Json[] {
  return asArray(value)
    .map((entry) => asRecord(entry))
    .map((entry) => ({
      author: stringOrNull(entry.author) ?? "Google Maps user",
      rating: clampRating(numberOrNull(entry.rating)) ?? 0,
      text: cleanSummary(stringValue(entry.text), 20),
      publish_time: stringOrNull(entry.publishTime),
      google_maps_uri: sanitizeUrl(stringValue(entry.googleMapsUri)),
      provider: "google_maps",
    }))
    .filter((entry) => Boolean(entry.text))
    .slice(0, 5);
}

async function enrichWithGoogleSearch(
  env: VenueEnrichmentEnv,
  venue: VenueRecord,
  mapsGrounding: MapsGroundingResult | null,
  normalizedCategory: string,
  mapsLookupError: string | null,
): Promise<SearchGroundingResult> {
  const prompt = [
    "You are enriching a hospitality venue record for a production marketplace.",
    "Use only grounded Google Search results. Never invent links or facts.",
    "Return empty strings when a value cannot be verified from search results.",
    "Return 0 when a numeric value cannot be verified from search results.",
    "Canonical categories allowed: Bar, Bar & Restaurants, Restaurants, Hotels.",
    "",
    `Venue name: ${venue.name}`,
    `Current category: ${venue.category ?? ""}`,
    `Current address: ${venue.address ?? ""}`,
    `Country code: ${venue.country ?? ""}`,
    `Grounded Google Maps address: ${mapsGrounding?.formattedAddress ?? ""}`,
    `Grounded Google Maps primary type: ${mapsGrounding?.primaryType ?? ""}`,
    `Grounded Google Maps website: ${mapsGrounding?.officialWebsite ?? ""}`,
    `Grounded Google Maps summary: ${mapsGrounding?.placeSummary ?? ""}`,
    `Suggested canonical category from grounded Maps data: ${normalizedCategory}`,
    `Google Maps grounding status: ${mapsLookupError ?? "available"}`,
    "",
    "Find the venue's official website if one exists, a direct reservation URL if one exists, and major social profiles only when they clearly belong to the venue.",
    "Also find the best verified public address, phone number, Google Maps URL, public rating, public review count, public price level, and a short grounded review summary when available.",
    "Write a concise factual description between 140 and 280 characters. No hype, no marketing fluff.",
  ].join("\n");

  for (const model of env.venueEnrichmentModels) {
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
          contents: [{
            role: "user",
            parts: [{ text: prompt }],
          }],
          tools: [{ google_search: {} }],
          generationConfig: {
            responseMimeType: "application/json",
            responseJsonSchema: googleSearchSchema,
          },
        }),
      },
    );

    if (!response.ok) {
      const body = await safeJson(response);
      console.warn(
        "[venue-enrichment] google search grounding model failed",
        model,
        body,
      );
      continue;
    }

    const body = asRecord(await response.json());
    const candidate = asRecord(asArray(body.candidates)[0]);
    const content = asRecord(candidate.content);
    const parts = asArray(content.parts);
    const jsonText = stringValue(asRecord(parts[0]).text);
    if (!jsonText) {
      continue;
    }

    let parsed: Json;
    try {
      parsed = asRecord(JSON.parse(jsonText));
    } catch (_) {
      continue;
    }

    const groundingMetadata = asRecord(candidate.groundingMetadata);
    const queries = asArray(groundingMetadata.webSearchQueries)
      .map((entry) => stringValue(entry))
      .filter((entry): entry is string => Boolean(entry));
    const sources = asArray(groundingMetadata.groundingChunks)
      .map((entry) => asRecord(asRecord(entry).web))
      .map((entry) => ({
        uri: stringOrNull(entry.uri),
        title: stringOrNull(entry.title),
      }))
      .filter((entry) => entry.uri || entry.title);

    return {
      canonicalCategory: normalizeGroundedCategory(
        stringValue(parsed.canonicalCategory),
        normalizedCategory,
      ),
      description: cleanDescription(stringValue(parsed.description)),
      officialWebsite: sanitizeUrl(stringValue(parsed.officialWebsite)),
      reservationUrl: sanitizeUrl(stringValue(parsed.reservationUrl)),
      instagramUrl: sanitizeUrl(stringValue(parsed.instagramUrl)),
      facebookUrl: sanitizeUrl(stringValue(parsed.facebookUrl)),
      tiktokUrl: sanitizeUrl(stringValue(parsed.tiktokUrl)),
      formattedAddress: stringOrNull(parsed.formattedAddress),
      contactPhone: stringOrNull(parsed.contactPhone),
      googleMapsUri: sanitizeUrl(stringValue(parsed.googleMapsUri)),
      rating: clampRating(numberOrNull(parsed.rating)),
      ratingCount: normalizeCount(numberOrNull(parsed.ratingCount)),
      priceLevel: stringOrNull(parsed.priceLevel),
      reviewSummary: cleanSummary(stringValue(parsed.reviewSummary), 16),
      confidence: clampConfidence(numberOrNull(parsed.confidence)),
      queries,
      sources,
    };
  }

  throw new HttpError(
    502,
    "Google Search grounding failed for all configured models.",
  );
}

function normalizeVenueCategory(
  primaryType: unknown,
  types: string[],
  fallbackCategory: string | null,
): string {
  const normalizedTypes = new Set<string>(
    [stringValue(primaryType), ...types]
      .filter((value): value is string => Boolean(value))
      .map((value) => value.toLowerCase()),
  );
  const fallback = normalizeGroundedCategory(fallbackCategory, "Restaurants");

  const hasHotel = [...normalizedTypes].some((value) => hotelTypes.has(value));
  if (hasHotel) {
    return "Hotels";
  }

  const hasBar = [...normalizedTypes].some((value) => barTypes.has(value));
  const hasRestaurant = [...normalizedTypes].some((value) =>
    value === "restaurant" || value.endsWith("_restaurant") ||
    value === "cafe" || value === "fine_dining_restaurant" ||
    value === "food_court" || value === "cafeteria" || value === "bistro"
  );

  if (hasBar && hasRestaurant) {
    return "Bar & Restaurants";
  }

  if (hasBar) {
    return "Bar";
  }

  if (hasRestaurant) {
    return "Restaurants";
  }

  return fallback;
}

function normalizeGroundedCategory(
  value: string | null | undefined,
  fallback: string,
): string {
  const normalized = (value ?? "").trim().toLowerCase();
  if (!normalized) return fallback;
  if (normalized.includes("hotel")) return "Hotels";
  if (normalized.includes("bar") && normalized.includes("restaurant")) {
    return "Bar & Restaurants";
  }
  if (normalized.includes("bar")) return "Bar";
  if (normalized.includes("restaurant")) return "Restaurants";
  return fallback;
}

function buildSocialLinks(searchGrounding: SearchGroundingResult | null): Json {
  const socialLinks: Json = {};
  if (!searchGrounding) return socialLinks;

  const entries = [
    ["instagram", searchGrounding.instagramUrl],
    ["facebook", searchGrounding.facebookUrl],
    ["tiktok", searchGrounding.tiktokUrl],
  ] as const;

  for (const [key, value] of entries) {
    if (value) socialLinks[key] = value;
  }

  return socialLinks;
}

function mergeSocialLinks(primary: Json, secondary: Json): Json {
  const merged: Json = { ...secondary, ...primary };
  return Object.fromEntries(
    Object.entries(merged).filter(([, value]) =>
      typeof value === "string" && value.trim().length > 0
    ),
  );
}

function buildSearchOnlyVenueUpdate(
  venue: VenueRecord,
  searchGrounding: SearchGroundingResult | null,
  websiteMetadata: WebsiteMetadata | null,
  normalizedCategory: string,
  overwriteExisting: boolean,
): Json {
  if (!searchGrounding) {
    throw new HttpError(
      502,
      `Search grounding did not return usable enrichment data for "${venue.name}".`,
    );
  }

  const update: Json = {
    search_summary: searchGrounding.description ?? null,
    search_sources: searchGrounding.sources,
    search_queries: searchGrounding.queries,
    enrichment_status: "ready",
    enrichment_error: null,
    last_enriched_at: new Date().toISOString(),
    enrichment_confidence: buildConfidence(0.35, searchGrounding),
  };

  const category = searchGrounding.canonicalCategory || normalizedCategory;
  const socialLinks = mergeSocialLinks(
    buildSocialLinks(searchGrounding),
    websiteMetadata?.socialLinks ?? {},
  );

  if (
    (searchGrounding.formattedAddress ?? websiteMetadata?.address) &&
    shouldWriteText(venue.address, overwriteExisting)
  ) {
    update.address = searchGrounding.formattedAddress ??
      websiteMetadata?.address;
  }

  if (
    (searchGrounding.contactPhone ?? websiteMetadata?.phone) &&
    shouldWriteText(venue.phone, overwriteExisting)
  ) {
    update.phone = searchGrounding.contactPhone ?? websiteMetadata?.phone;
  }

  if (
    searchGrounding.officialWebsite &&
    shouldWriteText(venue.website_url, overwriteExisting)
  ) {
    update.website_url = searchGrounding.officialWebsite;
  }

  if (
    searchGrounding.reservationUrl &&
    shouldWriteText(venue.reservation_url, overwriteExisting)
  ) {
    update.reservation_url = searchGrounding.reservationUrl;
  }

  if (
    Object.keys(socialLinks).length > 0 &&
    (overwriteExisting || !hasJsonContent(venue.social_links))
  ) {
    update.social_links = socialLinks;
  }

  if (
    (searchGrounding.description ?? websiteMetadata?.description) &&
    shouldWriteText(venue.description, overwriteExisting)
  ) {
    update.description = searchGrounding.description ??
      websiteMetadata?.description;
  }

  if (category && (overwriteExisting || !isCanonicalCategory(venue.category))) {
    update.category = category;
    update.category_source = "ai_gemini";
  }

  if (searchGrounding.googleMapsUri) {
    update.google_maps_uri = searchGrounding.googleMapsUri;
  }

  if (
    searchGrounding.priceLevel && shouldWriteText(
      venue.google_price_level,
      overwriteExisting,
    )
  ) {
    update.google_price_level = searchGrounding.priceLevel;
  }

  if (
    searchGrounding.reviewSummary &&
    shouldWriteText(venue.google_review_summary, overwriteExisting)
  ) {
    update.google_review_summary = searchGrounding.reviewSummary;
  }

  const rating = searchGrounding.rating ?? websiteMetadata?.rating;
  if (rating != null && rating > 0) {
    update.rating = rating;
  }

  const ratingCount = searchGrounding.ratingCount ??
    websiteMetadata?.ratingCount;
  if (ratingCount != null && ratingCount > 0) {
    update.rating_count = ratingCount;
  }

  if (
    websiteMetadata?.imageUrl &&
    shouldWriteDiscoveredVenueImage(venue, overwriteExisting)
  ) {
    update.image_url = websiteMetadata.imageUrl;
    update.image_status = "ready";
    update.image_error = null;
  }

  return update;
}

function buildGoogleMapsLinks(
  mapsGrounding: MapsGroundingResult,
): Json | null {
  const uris = mapsGrounding.sources
    .map((entry) => sanitizeUrl(stringValue(entry.uri)))
    .filter((entry): entry is string => Boolean(entry));
  const links: Json = {};

  if (mapsGrounding.googleMapsUri) {
    links.placeUri = mapsGrounding.googleMapsUri;
  }

  if (uris.length > 0) {
    links.sourceUris = [...new Set(uris)];
  }

  return Object.keys(links).length > 0 ? links : null;
}

function buildGoogleOpeningHours(openingHours: string[]): Json | null {
  if (openingHours.length === 0) return null;
  return {
    weekday_text: openingHours,
  };
}

function mapGroundingSourcesToAttributions(sources: Json[]): Json[] | null {
  const attributions = sources.map((entry) => ({
    provider: "Google Maps",
    provider_uri: sanitizeUrl(stringValue(entry.uri)),
    title: stringOrNull(entry.title),
    place_id: stringOrNull(entry.place_id),
  })).filter((entry) => entry.provider_uri || entry.title || entry.place_id);

  return attributions.length > 0 ? attributions : null;
}

function buildConfidence(
  placeConfidence: number,
  searchGrounding: SearchGroundingResult | null,
): number {
  const searchConfidence = searchGrounding?.confidence ?? null;
  if (searchConfidence == null) return clampConfidence(placeConfidence) ?? 0.55;
  return clampConfidence(placeConfidence * 0.7 + searchConfidence * 0.3) ??
    0.55;
}

async function updateVenueEnrichmentState(
  adminClient: ReturnType<typeof createVenueAdminClient>,
  venueId: string,
  update: Json,
) {
  const { error } = await adminClient
    .from("dinein_venues")
    .update(update)
    .eq("id", venueId);

  if (error) {
    throw new HttpError(
      500,
      `Unable to update venue enrichment state: ${error.message}`,
      error,
    );
  }
}

async function fetchWebsiteMetadata(
  websiteUrl: string | null | undefined,
): Promise<WebsiteMetadata | null> {
  const initialUrl = sanitizeUrl(websiteUrl);
  if (!initialUrl) return null;

  const candidates = [initialUrl];
  try {
    const rootUrl = new URL(initialUrl).origin;
    if (!candidates.includes(rootUrl)) {
      candidates.push(rootUrl);
    }
  } catch (_) {
    // Ignore URL normalization failures.
  }

  let merged = emptyWebsiteMetadata();
  for (const candidate of candidates) {
    try {
      const response = await fetchWithTimeout(candidate, {
        headers: {
          "user-agent":
            "Mozilla/5.0 (compatible; DineInBot/1.0; +https://dinein.app)",
          "accept":
            "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        },
      }, 10000);

      if (!response.ok) continue;
      const html = await response.text();
      merged = mergeWebsiteMetadata(
        merged,
        parseWebsiteMetadata(candidate, html),
      );
    } catch (_) {
      continue;
    }
  }

  merged.imageUrl = await validateWebsiteImageCandidate(merged.imageUrl);
  return hasWebsiteMetadata(merged) ? merged : null;
}

function parseWebsiteMetadata(pageUrl: string, html: string): WebsiteMetadata {
  const metadata = emptyWebsiteMetadata();
  metadata.imageUrl = normalizeWebsiteImageCandidateUrl(resolveUrl(
    pageUrl,
    extractMetaContent(
      html,
      /<meta[^>]+(?:property|name)=["'](?:og:image|twitter:image)["'][^>]+content=["']([^"']+)["']/i,
    ),
  ));
  metadata.description = cleanDescription(
    extractMetaContent(
      html,
      /<meta[^>]+(?:name|property)=["'](?:description|og:description|twitter:description)["'][^>]+content=["']([^"']+)["']/i,
    ) ?? undefined,
  );

  for (const jsonLd of extractJsonLdBlocks(html)) {
    const parsed = parseJsonLdMetadata(pageUrl, jsonLd);
    metadata.imageUrl ??= parsed.imageUrl;
    metadata.description ??= parsed.description;
    metadata.phone ??= parsed.phone;
    metadata.address ??= parsed.address;
    metadata.socialLinks = mergeSocialLinks(
      metadata.socialLinks,
      parsed.socialLinks,
    );
    metadata.rating ??= parsed.rating;
    metadata.ratingCount ??= parsed.ratingCount;
    metadata.priceLevel ??= parsed.priceLevel;
  }

  return metadata;
}

function parseJsonLdMetadata(
  pageUrl: string,
  jsonLd: unknown,
): WebsiteMetadata {
  let metadata = emptyWebsiteMetadata();
  for (const entry of flattenJsonLd(jsonLd)) {
    const row = asRecord(entry);
    const image = normalizeWebsiteImageCandidateUrl(resolveUrl(
      pageUrl,
      stringOrNull(row.image) ??
        stringOrNull(asArray(row.image)[0]) ??
        nestedString(row.image, "url"),
    ));
    const aggregateRating = asRecord(row.aggregateRating);
    const next = {
      imageUrl: image,
      description: cleanDescription(stringOrNull(row.description) ?? undefined),
      phone: stringOrNull(row.telephone),
      address: formatPostalAddress(asRecord(row.address)),
      socialLinks: socialLinksFromSameAs(asArray(row.sameAs)),
      rating: clampRating(
        numberOrNull(aggregateRating.ratingValue) ??
          numberOrNull(row.ratingValue),
      ),
      ratingCount: normalizeCount(
        numberOrNull(aggregateRating.reviewCount) ??
          numberOrNull(aggregateRating.ratingCount) ??
          numberOrNull(row.reviewCount),
      ),
      priceLevel: stringOrNull(row.priceRange),
    } satisfies WebsiteMetadata;
    metadata = mergeWebsiteMetadata(metadata, next);
  }
  return metadata;
}

function normalizeWebsiteImageCandidateUrl(
  value: string | null | undefined,
): string | null {
  const url = sanitizeUrl(value);
  if (!url) return null;

  const normalized = url.toLowerCase();
  if (
    [
      "logo",
      "brandmark",
      "favicon",
      "icon",
      "avatar",
      "badge",
      "sprite",
      "mask-icon",
      "apple-touch",
      "android-chrome",
      "monogram",
    ].some((needle) => normalized.includes(needle))
  ) {
    return null;
  }

  if (normalized.endsWith(".svg") || normalized.endsWith(".ico")) {
    return null;
  }

  return url;
}

async function validateWebsiteImageCandidate(
  value: string | null | undefined,
): Promise<string | null> {
  const url = normalizeWebsiteImageCandidateUrl(value);
  if (!url) return null;

  try {
    const response = await fetchWithTimeout(
      url,
      {
        headers: {
          "accept": "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
        },
      },
      10000,
    );
    if (!response.ok) {
      return null;
    }

    const contentType = response.headers.get("content-type")?.split(";")[0]
      ?.trim().toLowerCase() ?? "";
    if (!["image/jpeg", "image/png", "image/webp"].includes(contentType)) {
      return null;
    }

    const contentLength = Number.parseInt(
      response.headers.get("content-length") ?? "",
      10,
    );
    if (Number.isFinite(contentLength) && contentLength < 15_000) {
      return null;
    }

    const bytes = new Uint8Array(await response.arrayBuffer());
    if (bytes.length < 15_000 || bytes.length > 8_000_000) {
      return null;
    }

    const dimensions = imageDimensions(bytes, contentType);
    if (!dimensions) {
      return null;
    }

    const { width, height } = dimensions;
    if (width < 480 || height < 320) {
      return null;
    }

    const aspectRatio = width / height;
    if (aspectRatio < 0.6 || aspectRatio > 3.2) {
      return null;
    }

    return url;
  } catch (_) {
    return null;
  }
}

function imageDimensions(
  bytes: Uint8Array,
  mimeType: string,
): { width: number; height: number } | null {
  switch (mimeType) {
    case "image/png":
      return pngDimensions(bytes);
    case "image/jpeg":
      return jpegDimensions(bytes);
    case "image/webp":
      return webpDimensions(bytes);
    default:
      return null;
  }
}

function pngDimensions(
  bytes: Uint8Array,
): { width: number; height: number } | null {
  if (bytes.length < 24) return null;
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  for (let index = 0; index < signature.length; index += 1) {
    if (bytes[index] !== signature[index]) return null;
  }
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  return {
    width: view.getUint32(16),
    height: view.getUint32(20),
  };
}

function jpegDimensions(
  bytes: Uint8Array,
): { width: number; height: number } | null {
  if (bytes.length < 4 || bytes[0] !== 0xff || bytes[1] !== 0xd8) return null;

  let offset = 2;
  while (offset + 9 < bytes.length) {
    if (bytes[offset] !== 0xff) {
      offset += 1;
      continue;
    }
    const marker = bytes[offset + 1];
    if (marker === 0xd9 || marker === 0xda) {
      break;
    }
    const blockLength = (bytes[offset + 2] << 8) + bytes[offset + 3];
    if (blockLength < 2 || offset + blockLength + 1 >= bytes.length) {
      break;
    }
    if (
      (marker >= 0xc0 && marker <= 0xc3) ||
      (marker >= 0xc5 && marker <= 0xc7) ||
      (marker >= 0xc9 && marker <= 0xcb) ||
      (marker >= 0xcd && marker <= 0xcf)
    ) {
      const height = (bytes[offset + 5] << 8) + bytes[offset + 6];
      const width = (bytes[offset + 7] << 8) + bytes[offset + 8];
      return { width, height };
    }
    offset += blockLength + 2;
  }

  return null;
}

function webpDimensions(
  bytes: Uint8Array,
): { width: number; height: number } | null {
  if (
    bytes.length < 30 ||
    readAscii(bytes, 0, 4) !== "RIFF" ||
    readAscii(bytes, 8, 4) !== "WEBP"
  ) {
    return null;
  }

  const chunk = readAscii(bytes, 12, 4);
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);

  if (chunk === "VP8 ") {
    if (bytes.length < 30) return null;
    return {
      width: view.getUint16(26, true) & 0x3fff,
      height: view.getUint16(28, true) & 0x3fff,
    };
  }

  if (chunk === "VP8L") {
    if (bytes.length < 25) return null;
    const bits = view.getUint32(21, true);
    return {
      width: (bits & 0x3fff) + 1,
      height: ((bits >> 14) & 0x3fff) + 1,
    };
  }

  if (chunk === "VP8X") {
    if (bytes.length < 30) return null;
    return {
      width: 1 + bytes[24] + (bytes[25] << 8) + (bytes[26] << 16),
      height: 1 + bytes[27] + (bytes[28] << 8) + (bytes[29] << 16),
    };
  }

  return null;
}

function readAscii(bytes: Uint8Array, start: number, length: number): string {
  return String.fromCharCode(...bytes.slice(start, start + length));
}

function extractJsonLdBlocks(html: string): unknown[] {
  const matches = html.matchAll(
    /<script[^>]+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi,
  );
  const blocks: unknown[] = [];
  for (const match of matches) {
    const raw = match[1]?.trim();
    if (!raw) continue;
    try {
      blocks.push(JSON.parse(raw));
    } catch (_) {
      continue;
    }
  }
  return blocks;
}

function flattenJsonLd(value: unknown): unknown[] {
  if (Array.isArray(value)) {
    return value.flatMap((entry) => flattenJsonLd(entry));
  }
  const row = asRecord(value);
  const graph = asArray(row["@graph"]);
  if (graph.length > 0) {
    return graph.flatMap((entry) => flattenJsonLd(entry));
  }
  return [value];
}

function emptyWebsiteMetadata(): WebsiteMetadata {
  return {
    imageUrl: null,
    description: null,
    phone: null,
    address: null,
    socialLinks: {},
    rating: null,
    ratingCount: null,
    priceLevel: null,
  };
}

function hasWebsiteMetadata(metadata: WebsiteMetadata): boolean {
  return Boolean(
    metadata.imageUrl ||
      metadata.description ||
      metadata.phone ||
      metadata.address ||
      metadata.rating != null ||
      metadata.ratingCount != null ||
      metadata.priceLevel ||
      Object.keys(metadata.socialLinks).length > 0,
  );
}

function mergeWebsiteMetadata(
  base: WebsiteMetadata,
  next: WebsiteMetadata,
): WebsiteMetadata {
  return {
    imageUrl: base.imageUrl ?? next.imageUrl,
    description: base.description ?? next.description,
    phone: base.phone ?? next.phone,
    address: base.address ?? next.address,
    socialLinks: mergeSocialLinks(base.socialLinks, next.socialLinks),
    rating: base.rating ?? next.rating,
    ratingCount: base.ratingCount ?? next.ratingCount,
    priceLevel: base.priceLevel ?? next.priceLevel,
  };
}

function extractMetaContent(html: string, pattern: RegExp): string | null {
  const match = html.match(pattern);
  return stringOrNull(match?.[1]);
}

function resolveUrl(
  baseUrl: string,
  value: string | null | undefined,
): string | null {
  const sanitized = sanitizeUrl(value);
  if (sanitized) return sanitized;
  const raw = stringOrNull(value);
  if (!raw) return null;
  try {
    return sanitizeUrl(new URL(raw, baseUrl).toString());
  } catch (_) {
    return null;
  }
}

function socialLinksFromSameAs(values: unknown[]): Json {
  const links: Json = {};
  for (const value of values) {
    const url = sanitizeUrl(stringOrNull(value));
    if (!url) continue;
    const host = safeHostname(url);
    if (host.includes("instagram.com")) {
      links.instagram = url;
    } else if (host.includes("facebook.com")) {
      links.facebook = url;
    } else if (host.includes("tiktok.com")) {
      links.tiktok = url;
    }
  }
  return links;
}

function formatPostalAddress(address: Json): string | null {
  const parts = [
    stringOrNull(address.streetAddress),
    stringOrNull(address.addressLocality),
    stringOrNull(address.addressRegion),
    stringOrNull(address.postalCode),
    stringOrNull(address.addressCountry),
  ].filter((value): value is string => Boolean(value));
  return parts.length > 0 ? parts.join(", ") : null;
}

async function safeJson(response: Response): Promise<Json> {
  try {
    return asRecord(await response.json());
  } catch (_) {
    return {};
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
      throw new HttpError(504, "External enrichment request timed out.");
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}

function nestedString(value: unknown, key: string): string | null {
  return stringOrNull(asRecord(value)[key]);
}

function asRecord(value: unknown): Json {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Json
    : {};
}

function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function asStringArray(value: unknown): string[] {
  return asArray(value)
    .map((entry) => stringValue(entry))
    .filter((entry): entry is string => Boolean(entry));
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

function numberOrNull(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function clampRating(value: number | null): number | null {
  if (value == null) return null;
  return Math.min(5, Math.max(0, value));
}

function normalizeCount(value: number | null): number | null {
  if (value == null) return null;
  return Math.max(0, Math.round(value));
}

function hasJsonContent(value: Json | null): boolean {
  return value != null && Object.keys(value).length > 0;
}

function hasReviewContent(value: unknown[] | null): boolean {
  return Array.isArray(value) && value.length > 0;
}

function hasUnknownArrayContent(value: unknown[] | null): boolean {
  return Array.isArray(value) && value.length > 0;
}

function isBlankString(value: string | null | undefined): boolean {
  return !value || value.trim().length === 0;
}

function shouldWriteText(
  current: string | null | undefined,
  overwrite: boolean,
): boolean {
  return overwrite || isBlankString(current);
}

function shouldWriteDiscoveredVenueImage(
  venue: VenueRecord,
  overwrite: boolean,
): boolean {
  if (venue.image_locked) return false;
  if (venue.image_source === "manual" || venue.image_source === "ai_gemini") {
    return false;
  }
  return shouldWriteText(venue.image_url, overwrite);
}

function isCanonicalCategory(value: string | null | undefined): boolean {
  if (!value) return false;
  return ["Bar", "Bar & Restaurants", "Restaurants", "Hotels"].includes(
    value.trim(),
  );
}

function sanitizeUrl(value: string | null | undefined): string | null {
  if (!value) return null;
  const trimmed = value.trim();
  if (!trimmed.startsWith("http://") && !trimmed.startsWith("https://")) {
    return null;
  }
  try {
    return new URL(trimmed).toString();
  } catch (_) {
    return null;
  }
}

function safeHostname(value: string): string {
  try {
    return new URL(value).hostname.toLowerCase();
  } catch (_) {
    return "";
  }
}

function cleanDescription(value: string | undefined): string | null {
  if (!value) return null;
  const trimmed = value.trim().replace(/\s+/g, " ");
  if (trimmed.length < 40) return null;
  return trimmed.slice(0, 280);
}

function cleanSummary(
  value: string | undefined,
  minLength = 16,
  maxLength = 280,
): string | null {
  if (!value) return null;
  const trimmed = value.trim().replace(/\s+/g, " ");
  if (trimmed.length < minLength) return null;
  return trimmed.slice(0, maxLength);
}

function clampConfidence(value: number | null): number | null {
  if (value == null || !Number.isFinite(value)) return null;
  return Math.max(0, Math.min(1, Math.round(value * 1000) / 1000));
}

function parseIsoTime(value: string | null | undefined): number | null {
  if (!value || value.trim().length === 0) {
    return null;
  }
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? parsed : null;
}
