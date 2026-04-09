export type Json = Record<string, unknown>;

export interface GooglePlaceAuthorAttribution {
  display_name: string | null;
  uri: string | null;
  photo_uri: string | null;
}

export interface GooglePlacePhotoMetadata {
  name: string;
  photo_path: string;
  width_px: number | null;
  height_px: number | null;
  author_attributions: GooglePlaceAuthorAttribution[];
}

export interface GooglePlaceSnapshot {
  placeId: string | null;
  resourceName: string | null;
  displayName: string | null;
  formattedAddress: string | null;
  shortFormattedAddress: string | null;
  nationalPhoneNumber: string | null;
  websiteUri: string | null;
  googleMapsUri: string | null;
  primaryType: string | null;
  types: string[];
  rating: number | null;
  userRatingCount: number | null;
  priceLevel: string | null;
  location: Json | null;
  photos: GooglePlacePhotoMetadata[];
}

export interface FetchGooglePlaceDetailsOptions {
  apiKey: string;
  placeId?: string | null;
  resourceName?: string | null;
  maxPhotoWidthPx?: number;
  fetchImpl?: typeof fetch;
  timeoutMs?: number;
}

export interface SearchGooglePlaceByTextOptions {
  apiKey: string;
  query: string;
  pageSize?: number;
  maxPhotoWidthPx?: number;
  fetchImpl?: typeof fetch;
  timeoutMs?: number;
}

const externalRequestTimeoutMs = 15000;

export async function fetchGooglePlaceDetails(
  options: FetchGooglePlaceDetailsOptions,
): Promise<GooglePlaceSnapshot | null> {
  const apiKey = options.apiKey.trim();
  const path = normalizePlacePath(options.placeId, options.resourceName);
  if (!apiKey || !path) return null;

  const response = await fetchWithTimeout(
    `https://places.googleapis.com/v1/${path}`,
    {
      method: "GET",
      headers: {
        "content-type": "application/json",
        "X-Goog-Api-Key": apiKey,
        "X-Goog-FieldMask": [
          "id",
          "name",
          "displayName",
          "formattedAddress",
          "shortFormattedAddress",
          "location",
          "nationalPhoneNumber",
          "websiteUri",
          "googleMapsUri",
          "primaryType",
          "types",
          "rating",
          "userRatingCount",
          "priceLevel",
          "photos",
        ].join(","),
      },
    },
    options.timeoutMs,
    options.fetchImpl,
  );

  if (!response.ok) {
    return null;
  }

  const payload = normalizeGooglePlaceSnapshot(
    await safeJson(response),
    apiKey,
    options.maxPhotoWidthPx,
  );

  return payload.placeId || payload.resourceName || payload.displayName
    ? payload
    : null;
}

export async function searchGooglePlaceByText(
  options: SearchGooglePlaceByTextOptions,
): Promise<GooglePlaceSnapshot | null> {
  const apiKey = options.apiKey.trim();
  const query = options.query.trim();
  if (!apiKey || query.length < 2) return null;

  const response = await fetchWithTimeout(
    "https://places.googleapis.com/v1/places:searchText",
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "X-Goog-Api-Key": apiKey,
        "X-Goog-FieldMask": [
          "places.id",
          "places.name",
          "places.displayName",
          "places.formattedAddress",
          "places.shortFormattedAddress",
          "places.location",
          "places.nationalPhoneNumber",
          "places.websiteUri",
          "places.googleMapsUri",
          "places.primaryType",
          "places.types",
          "places.rating",
          "places.userRatingCount",
          "places.priceLevel",
          "places.photos",
        ].join(","),
      },
      body: JSON.stringify({
        textQuery: query,
        pageSize: Math.max(1, Math.min(3, options.pageSize ?? 1)),
      }),
    },
    options.timeoutMs,
    options.fetchImpl,
  );

  if (!response.ok) {
    return null;
  }

  const payload = await safeJson(response);
  const firstPlace = asRecord(asArray(payload.places)[0]);
  if (Object.keys(firstPlace).length === 0) return null;

  return normalizeGooglePlaceSnapshot(
    firstPlace,
    apiKey,
    options.maxPhotoWidthPx,
  );
}

export function normalizeGooglePlaceSnapshot(
  value: unknown,
  apiKey: string,
  maxPhotoWidthPx = 1600,
): GooglePlaceSnapshot {
  const row = asRecord(value);
  const resourceName = stringOrNull(row.name);
  const placeId = stringOrNull(row.id) ??
    resourceName?.replace(/^places\//, "") ??
    null;

  return {
    placeId,
    resourceName,
    displayName: stringOrNull(asRecord(row.displayName).text),
    formattedAddress: stringOrNull(row.formattedAddress),
    shortFormattedAddress: stringOrNull(row.shortFormattedAddress),
    nationalPhoneNumber: stringOrNull(row.nationalPhoneNumber),
    websiteUri: sanitizeUrl(stringValue(row.websiteUri)),
    googleMapsUri: sanitizeUrl(stringValue(row.googleMapsUri)),
    primaryType: stringOrNull(row.primaryType),
    types: asStringArray(row.types),
    rating: clampRating(numberOrNull(row.rating)),
    userRatingCount: normalizeCount(numberOrNull(row.userRatingCount)),
    priceLevel: stringOrNull(row.priceLevel),
    location: normalizeLocation(row.location),
    photos: normalizePlacePhotos(row.photos, maxPhotoWidthPx),
  };
}

export function buildGooglePlacePhotoUri(
  photoName: string,
  apiKey: string,
  maxPhotoWidthPx = 1600,
): string {
  const url = new URL(buildGooglePlacePhotoPath(photoName, maxPhotoWidthPx));
  url.searchParams.set("key", apiKey);
  return url.toString();
}

export function buildGooglePlacePhotoPath(
  photoName: string,
  maxPhotoWidthPx = 1600,
): string {
  const normalizedWidth = Math.max(400, Math.min(2400, maxPhotoWidthPx));
  return `https://places.googleapis.com/v1/${photoName}/media?maxWidthPx=${normalizedWidth}`;
}

function normalizePlacePhotos(
  value: unknown,
  maxPhotoWidthPx: number,
): GooglePlacePhotoMetadata[] {
  const seen = new Set<string>();
  return asArray(value)
    .map((entry) => asRecord(entry))
    .map((entry) => {
      const name = stringOrNull(entry.name);
      if (!name) return null;
      return {
        name,
        photo_path: buildGooglePlacePhotoPath(name, maxPhotoWidthPx),
        width_px: numberOrNull(entry.widthPx),
        height_px: numberOrNull(entry.heightPx),
        author_attributions: asArray(entry.authorAttributions)
          .map((author) => asRecord(author))
          .map((author) => ({
            display_name: stringOrNull(author.displayName),
            uri: sanitizeUrl(stringValue(author.uri)),
            photo_uri: sanitizeUrl(stringValue(author.photoUri)),
          }))
          .filter((author) =>
            author.display_name || author.uri || author.photo_uri
          ),
      } satisfies GooglePlacePhotoMetadata;
    })
    .filter((entry): entry is GooglePlacePhotoMetadata => Boolean(entry))
    .filter((entry) => {
      if (seen.has(entry.name)) return false;
      seen.add(entry.name);
      return true;
    })
    .slice(0, 6);
}

function normalizePlacePath(
  placeId?: string | null,
  resourceName?: string | null,
): string | null {
  const resource = resourceName?.trim();
  if (resource) {
    return resource.startsWith("places/") ? resource : `places/${resource}`;
  }

  const id = placeId?.trim();
  return id ? `places/${id}` : null;
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
  fetchImpl: typeof fetch = fetch,
): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetchImpl(input, {
      ...init,
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timeout);
  }
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
  return Math.max(0, Math.min(5, value));
}

function normalizeCount(value: number | null): number | null {
  if (value == null) return null;
  return Math.max(0, Math.round(value));
}

function normalizeLocation(value: unknown): Json | null {
  const row = asRecord(value);
  const latitude = numberOrNull(row.latitude);
  const longitude = numberOrNull(row.longitude);
  if (latitude == null || longitude == null) return null;
  return { latitude, longitude };
}

function sanitizeUrl(value: string | undefined): string | null {
  if (!value) return null;
  try {
    const url = new URL(value);
    if (!["http:", "https:"].includes(url.protocol)) return null;
    return url.toString();
  } catch (_) {
    return null;
  }
}
