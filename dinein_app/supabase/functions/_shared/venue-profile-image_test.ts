import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.208.0/assert/mod.ts";

import type { VenueRecord } from "./venue-enrichment.ts";
import {
  buildVenueImageVerificationPrompt,
  buildVenueLocalityCue,
  buildVenueProfileImagePrompt,
  countVenueReferenceImages,
  extractVenueReferenceImageUrls,
  hasGroundedVenueImageContext,
  hasReadyVenueDeepResearch,
  isVenueProfileImageGenerationInFlight,
  normalizeVenueDeepResearchStatus,
  normalizeVenueImageVerificationVerdict,
  venueNeedsProfileImageGeneration,
} from "./venue-profile-image.ts";

function makeVenue(overrides: Partial<VenueRecord> = {}): VenueRecord {
  return {
    id: "venue-1",
    name: "Skyline Lounge",
    slug: "skyline-lounge",
    updated_at: "2026-03-21T10:05:00.000Z",
    category: "Bar",
    description: "A rooftop cocktail lounge with panoramic harbour views.",
    address: "Valletta Waterfront, Malta",
    phone: null,
    email: null,
    image_url: null,
    image_source: null,
    image_status: "pending",
    image_model: null,
    image_prompt: null,
    image_generated_at: null,
    image_error: null,
    image_attempts: 0,
    image_locked: false,
    image_storage_path: null,
    status: "active",
    rating: 4.7,
    rating_count: 128,
    country: "MT",
    opening_hours: null,
    owner_id: "owner-1",
    website_url: "https://example.com",
    reservation_url: null,
    social_links: null,
    reviews: null,
    google_place_id: "place-123",
    google_place_resource_name: "places/place-123",
    google_maps_uri: "https://maps.google.com/?cid=123",
    google_maps_links: null,
    google_primary_type: "bar",
    google_types: ["bar", "restaurant"],
    google_business_status: "OPERATIONAL",
    google_location: null,
    google_opening_hours: null,
    google_price_level: "$$$",
    google_review_summary:
      "Guests praise the sunset terrace and polished cocktails.",
    google_review_summary_disclosure: null,
    google_review_summary_uri: null,
    google_place_summary:
      "Rooftop bar with harbour views and elegant terrace seating.",
    google_place_summary_disclosure: null,
    google_photos: null,
    google_attributions: [{ uri: "https://maps.google.com/?cid=123" }],
    search_summary:
      "Upscale rooftop destination known for sunset drinks and panoramic city views.",
    search_sources: [{ uri: "https://example.com/review" }],
    search_queries: ["Skyline Lounge Malta"],
    deep_research_status: "ready",
    deep_research_summary:
      "Public sources describe a limestone-fronted rooftop venue with harbour-facing terrace seating and polished evening lighting.",
    deep_research_sources: ["https://example.com/research"],
    deep_research_error: null,
    deep_research_interaction_id: null,
    deep_research_updated_at: "2026-03-21T10:01:00.000Z",
    deep_research_attempts: 1,
    deep_research_model: "deep-research-pro-preview-12-2025",
    deep_research_last_observed_status: "completed",
    deep_research_last_http_status: 200,
    deep_research_last_polled_at: "2026-03-21T10:01:00.000Z",
    deep_research_last_provider_error: null,
    deep_research_debug: null,
    enrichment_status: "ready",
    enrichment_error: null,
    enrichment_attempts: 1,
    enrichment_locked: false,
    last_enriched_at: "2026-03-21T10:00:00.000Z",
    enrichment_confidence: 0.92,
    category_source: "ai_gemini",
    ...overrides,
  };
}

Deno.test("venueNeedsProfileImageGeneration treats unknown-source images as regeneratable while preserving manual and locked images", () => {
  assertEquals(
    venueNeedsProfileImageGeneration(
      makeVenue({ image_url: "https://example.com/manual.jpg" }),
    ),
    true,
  );
  assertEquals(
    venueNeedsProfileImageGeneration(
      makeVenue({
        image_url: "https://example.com/failed.jpg",
        image_status: "failed",
      }),
    ),
    true,
  );
  assertEquals(
    venueNeedsProfileImageGeneration(
      makeVenue({
        image_url: "https://example.com/manual.jpg",
        image_source: "manual",
      }),
    ),
    false,
  );
  assertEquals(
    venueNeedsProfileImageGeneration(
      makeVenue({
        image_url: "https://example.com/generated.jpg",
        image_source: "ai_gemini",
        image_status: "ready",
      }),
      true,
    ),
    true,
  );
  assertEquals(
    venueNeedsProfileImageGeneration(
      makeVenue({
        image_url: "https://example.com/discovered.jpg",
        image_source: null,
        image_status: "ready",
      }),
    ),
    true,
  );
  assertEquals(
    venueNeedsProfileImageGeneration(
      makeVenue({
        image_url: "https://example.com/locked.jpg",
        image_locked: true,
      }),
      true,
    ),
    false,
  );
});

Deno.test("hasGroundedVenueImageContext requires maps grounding and descriptive context", () => {
  const mapsOnly = makeVenue({
    search_summary: null,
    search_sources: null,
  });
  assertEquals(hasGroundedVenueImageContext(mapsOnly), true);
  assertEquals(hasGroundedVenueImageContext(mapsOnly, true), true);

  const noDescriptiveContext = makeVenue({
    search_summary: null,
    search_sources: null,
    google_place_summary: null,
    google_review_summary: null,
    description: null,
  });
  assertEquals(hasGroundedVenueImageContext(noDescriptiveContext), false);
  assertEquals(hasGroundedVenueImageContext(noDescriptiveContext, true), false);

  const noMaps = makeVenue({
    google_place_id: null,
    google_maps_uri: null,
    google_place_summary: null,
    google_attributions: null,
  });
  assertEquals(hasGroundedVenueImageContext(noMaps, true), false);
  assertEquals(hasGroundedVenueImageContext(makeVenue()), true);
});

Deno.test("isVenueProfileImageGenerationInFlight expires stale generating rows", () => {
  assertEquals(
    isVenueProfileImageGenerationInFlight(
      makeVenue({
        image_status: "generating",
        updated_at: new Date().toISOString(),
      }),
    ),
    true,
  );
  assertEquals(
    isVenueProfileImageGenerationInFlight(
      makeVenue({
        image_status: "generating",
        updated_at: "2026-01-01T00:00:00.000Z",
      }),
    ),
    false,
  );
});

Deno.test("buildVenueProfileImagePrompt incorporates grounded venue cues", () => {
  const prompt = buildVenueProfileImagePrompt(
    makeVenue({
      google_photos: [
        {
          name: "places/test/photos/1",
          photo_path:
            "https://places.googleapis.com/v1/places/test/photos/1/media?maxWidthPx=1600",
        },
      ],
    }),
    {
      referenceImageCount: 1,
      deepResearchSummary:
        "Public sources consistently describe a limestone-fronted rooftop bar with harbour-facing terrace seating.",
    },
  );

  assertStringIncludes(prompt, 'Venue name: "Skyline Lounge"');
  assertStringIncludes(prompt, "Prompt version: venue-profile-image-v3");
  assertStringIncludes(
    prompt,
    'Grounded Google Maps summary: "Rooftop bar with harbour views and elegant terrace seating."',
  );
  assertStringIncludes(
    prompt,
    "Show a refined rooftop or terrace hospitality scene",
  );
  assertStringIncludes(prompt, "The venue must read as Malta");
  assertStringIncludes(prompt, "attached public venue reference image");
  assertStringIncludes(
    prompt,
    'Deep research note: "Public sources consistently describe a limestone-fronted rooftop bar with harbour-facing terrace seating."',
  );
  assertStringIncludes(prompt, "No plated dish close-up");
  assertStringIncludes(
    prompt,
    "Prefer an accurate but modest scene over a dramatic but invented one.",
  );
  assertStringIncludes(
    prompt,
    "generic Mediterranean stock scenery for Malta",
  );
});

Deno.test("buildVenueProfileImagePrompt avoids premium bias for grounded local bars", () => {
  const prompt = buildVenueProfileImagePrompt(
    makeVenue({
      name: "H2O Lounge",
      country: "RW",
      category: "Bar",
      google_primary_type: "lounge_bar",
      google_place_summary: "Premium hospitality venue.",
      google_review_summary: null,
      search_summary: null,
      description: null,
      address: "KK 433 st, Kigali, Rwanda",
      deep_research_summary:
        "Affordable vibrant local club and bar with a main bar counter, performance stage, pool tables, and parking.",
    }),
    {
      referenceImageCount: 4,
      deepResearchSummary:
        "Affordable vibrant local club and bar with a main bar counter, performance stage, pool tables, and parking.",
    },
  );

  assertStringIncludes(
    prompt,
    "Show a venue-appropriate bar or lounge environment",
  );
  assertStringIncludes(
    prompt,
    "stage or pool-table area",
  );
});

Deno.test("buildVenueImageVerificationPrompt includes deep research grounding", () => {
  const prompt = buildVenueImageVerificationPrompt({
    venue: makeVenue({
      deep_research_summary:
        "Affordable vibrant local club and bar with a performance stage and pool tables.",
    }),
    referenceImageCount: 3,
    deepResearchSummary:
      "Affordable vibrant local club and bar with a performance stage and pool tables.",
  });

  assertStringIncludes(
    prompt,
    "Deep research note: Affordable vibrant local club and bar with a performance stage and pool tables.",
  );
  assertStringIncludes(
    prompt,
    "Reject if readable signage text or logos are prominent.",
  );
});

Deno.test("normalizeVenueImageVerificationVerdict fails closed on readable text and locality mismatches", () => {
  const verdict = normalizeVenueImageVerificationVerdict({
    matches: true,
    hero_subject: "venue_scene",
    locality_match: false,
    readable_text_present: true,
    issues: [],
    reason: "Looks plausible overall.",
  });

  assertEquals(verdict.matches, false);
  assertEquals(verdict.locality_match, false);
  assertEquals(verdict.readable_text_present, true);
  assertEquals(verdict.issues.includes("readable_text"), true);
  assertEquals(verdict.issues.includes("locality_mismatch"), true);
  assertStringIncludes(verdict.reason, "readable text or signage is present");
});

Deno.test("buildVenueLocalityCue distinguishes Rwanda from Malta", () => {
  assertStringIncludes(
    buildVenueLocalityCue(
      makeVenue({ country: "RW", address: "Kigali, Rwanda" }),
    ),
    "The venue must read as Rwanda",
  );
  assertStringIncludes(
    buildVenueLocalityCue(
      makeVenue({ country: "MT", address: "Valletta Waterfront, Malta" }),
    ),
    "The venue must read as Malta",
  );
});

Deno.test("normalizeVenueDeepResearchStatus maps interaction states to persisted states", () => {
  assertEquals(normalizeVenueDeepResearchStatus("completed"), "ready");
  assertEquals(normalizeVenueDeepResearchStatus("in_progress"), "in_progress");
  assertEquals(normalizeVenueDeepResearchStatus("failed"), "failed");
  assertEquals(normalizeVenueDeepResearchStatus("queued"), "in_progress");
  assertEquals(normalizeVenueDeepResearchStatus(null), "pending");
});

Deno.test("hasReadyVenueDeepResearch requires fresh summary after enrichment", () => {
  assertEquals(hasReadyVenueDeepResearch(makeVenue()), true);
  assertEquals(
    hasReadyVenueDeepResearch(
      makeVenue({
        deep_research_status: "ready",
        deep_research_summary: null,
      }),
    ),
    false,
  );
  assertEquals(
    hasReadyVenueDeepResearch(
      makeVenue({
        deep_research_updated_at: "2026-03-21T09:59:00.000Z",
      }),
    ),
    false,
  );
});

Deno.test("extractVenueReferenceImageUrls prioritizes grounded Google place photos", () => {
  const urls = extractVenueReferenceImageUrls(
    makeVenue({
      google_photos: [
        {
          name: "places/test/photos/1",
          photo_path:
            "https://places.googleapis.com/v1/places/test/photos/1/media?maxWidthPx=1600",
        },
        {
          name: "places/test/photos/2",
          photo_path:
            "https://places.googleapis.com/v1/places/test/photos/2/media?maxWidthPx=1600",
        },
      ],
      image_url: "https://example.com/logo.png",
      image_source: null,
    }),
    2,
    "maps-key",
  );

  assertEquals(urls.length, 2);
  assertStringIncludes(
    urls[0],
    "https://places.googleapis.com/v1/places/test/photos/1/media",
  );
  assertStringIncludes(urls[0], "key=maps-key");
  assertStringIncludes(
    urls[1],
    "https://places.googleapis.com/v1/places/test/photos/2/media",
  );
  assertStringIncludes(urls[1], "key=maps-key");
});

Deno.test("countVenueReferenceImages counts stored Google photo metadata without signed URLs", () => {
  const venue = makeVenue({
    google_photos: [
      {
        name: "places/1/photos/a",
        photo_path:
          "https://places.googleapis.com/v1/places/1/photos/a/media?maxWidthPx=1600",
      },
    ],
  });

  assertEquals(countVenueReferenceImages(venue), 1);
});
