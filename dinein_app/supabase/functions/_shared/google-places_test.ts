import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.208.0/assert/mod.ts";

import {
  buildGooglePlacePhotoPath,
  buildGooglePlacePhotoUri,
  normalizeGooglePlaceSnapshot,
} from "./google-places.ts";

Deno.test("buildGooglePlacePhotoUri builds a media URL for Places photos", () => {
  const uri = buildGooglePlacePhotoUri(
    "places/test-place/photos/photo-123",
    "api-key",
    1800,
  );

  assertStringIncludes(
    uri,
    "https://places.googleapis.com/v1/places/test-place/photos/photo-123/media",
  );
  assertStringIncludes(uri, "maxWidthPx=1800");
  assertStringIncludes(uri, "key=api-key");
});

Deno.test("buildGooglePlacePhotoPath omits API key material", () => {
  const path = buildGooglePlacePhotoPath(
    "places/test-place/photos/photo-123",
    1800,
  );

  assertStringIncludes(
    path,
    "https://places.googleapis.com/v1/places/test-place/photos/photo-123/media",
  );
  assertStringIncludes(path, "maxWidthPx=1800");
  assertEquals(path.includes("key="), false);
});

Deno.test("normalizeGooglePlaceSnapshot parses place details and photo metadata", () => {
  const snapshot = normalizeGooglePlaceSnapshot({
    id: "place-123",
    name: "places/place-123",
    displayName: { text: "The SkySports Lounge" },
    formattedAddress: "Kigali, Rwanda",
    shortFormattedAddress: "Kigali",
    nationalPhoneNumber: "+250795588248",
    websiteUri: "https://skysports.example.com",
    googleMapsUri: "https://maps.google.com/?cid=123",
    primaryType: "sports_bar",
    types: ["sports_bar", "bar", "restaurant"],
    rating: 4.6,
    userRatingCount: 87,
    priceLevel: "$$",
    location: { latitude: -1.9441, longitude: 30.0619 },
    photos: [
      {
        name: "places/place-123/photos/photo-1",
        widthPx: 2048,
        heightPx: 1365,
        authorAttributions: [
          {
            displayName: "Photographer",
            uri: "https://maps.google.com/contrib/test",
          },
        ],
      },
    ],
  }, "api-key");

  assertEquals(snapshot.placeId, "place-123");
  assertEquals(snapshot.resourceName, "places/place-123");
  assertEquals(snapshot.displayName, "The SkySports Lounge");
  assertEquals(snapshot.formattedAddress, "Kigali, Rwanda");
  assertEquals(snapshot.primaryType, "sports_bar");
  assertEquals(snapshot.types, ["sports_bar", "bar", "restaurant"]);
  assertEquals(snapshot.location, { latitude: -1.9441, longitude: 30.0619 });
  assertEquals(snapshot.photos.length, 1);
  assertStringIncludes(
    snapshot.photos[0].photo_path,
    "https://places.googleapis.com/v1/places/place-123/photos/photo-1/media",
  );
  assertEquals(snapshot.photos[0].photo_path.includes("key="), false);
  assertEquals(
    snapshot.photos[0].author_attributions[0].display_name,
    "Photographer",
  );
});
