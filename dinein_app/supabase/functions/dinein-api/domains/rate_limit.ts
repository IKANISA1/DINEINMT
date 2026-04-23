const ANONYMOUS_WAVE_RATE_LIMIT_WINDOW_MS = 5 * 60 * 1000;
const ANONYMOUS_WAVE_RATE_LIMIT_MAX_REQUESTS = 3;
const GOOGLE_MAPS_SEARCH_RATE_LIMIT_WINDOW_MS = 15 * 60 * 1000;
const GOOGLE_MAPS_SEARCH_RATE_LIMIT_MAX_REQUESTS = 20;
const anonymousWaveRateLimitBuckets = new Map<string, number[]>();
const googleMapsSearchRateLimitBuckets = new Map<string, number[]>();
export function anonymousWaveRateLimitKey(
  req: Request,
  venueId: string,
): string | null {
  const ip = clientIpAddress(req);
  if (!ip) return null;

  const userAgent = req.headers.get("user-agent")?.trim() ?? "unknown";
  return `${venueId}:${ip}:${userAgent.slice(0, 160)}`;
}
function pruneAnonymousWaveRateLimitBucket(
  key: string,
  nowMs: number,
): number[] {
  const windowStart = nowMs - ANONYMOUS_WAVE_RATE_LIMIT_WINDOW_MS;
  const recent = (anonymousWaveRateLimitBuckets.get(key) ?? []).filter((
    timestamp,
  ) => timestamp >= windowStart);

  if (recent.length == 0) {
    anonymousWaveRateLimitBuckets.delete(key);
  } else {
    anonymousWaveRateLimitBuckets.set(key, recent);
  }

  return recent;
}
function assertAnonymousWaveRateLimit(
  req: Request,
  venueId: string,
  nowMs: number,
): string | null {
  const key = anonymousWaveRateLimitKey(req, venueId);
  if (!key) return null;

  const recent = pruneAnonymousWaveRateLimitBucket(key, nowMs);
  if (recent.length >= ANONYMOUS_WAVE_RATE_LIMIT_MAX_REQUESTS) {
    throw new HttpError(
      429,
      "Too many staff requests from this device. Please wait a moment and try again.",
      { code: "wave_rate_limited" },
    );
  }

  return key;
}
function recordAnonymousWaveRateLimit(key: string, nowMs: number): void {
  const recent = pruneAnonymousWaveRateLimitBucket(key, nowMs);
  recent.push(nowMs);
  anonymousWaveRateLimitBuckets.set(key, recent);
}
export function resetWaveRateLimitState(): void {
  anonymousWaveRateLimitBuckets.clear();
}
export function googleMapsSearchRateLimitKey(req: Request): string | null {
  const ip = clientIpAddress(req);
  if (!ip) return null;

  const userAgent = req.headers.get("user-agent")?.trim() ?? "unknown";
  return `${ip}:${userAgent.slice(0, 160)}`;
}
function pruneGoogleMapsSearchRateLimitBucket(
  key: string,
  nowMs: number,
): number[] {
  const windowStart = nowMs - GOOGLE_MAPS_SEARCH_RATE_LIMIT_WINDOW_MS;
  const recent = (googleMapsSearchRateLimitBuckets.get(key) ?? []).filter((
    timestamp,
  ) => timestamp >= windowStart);

  if (recent.length == 0) {
    googleMapsSearchRateLimitBuckets.delete(key);
  } else {
    googleMapsSearchRateLimitBuckets.set(key, recent);
  }

  return recent;
}
function assertGoogleMapsSearchRateLimit(
  req: Request,
  nowMs: number,
): string | null {
  const key = googleMapsSearchRateLimitKey(req);
  if (!key) return null;

  const recent = pruneGoogleMapsSearchRateLimitBucket(key, nowMs);
  if (recent.length >= GOOGLE_MAPS_SEARCH_RATE_LIMIT_MAX_REQUESTS) {
    throw new HttpError(
      429,
      "Too many venue search requests from this device. Please wait a moment and try again.",
      { code: "google_maps_search_rate_limited" },
    );
  }

  return key;
}
function recordGoogleMapsSearchRateLimit(key: string, nowMs: number): void {
  const recent = pruneGoogleMapsSearchRateLimitBucket(key, nowMs);
  recent.push(nowMs);
  googleMapsSearchRateLimitBuckets.set(key, recent);
}
export function resetGoogleMapsSearchRateLimitState(): void {
  googleMapsSearchRateLimitBuckets.clear();
}

import { assertRateLimit, GOOGLE_MAPS_SEARCH_RATE_LIMIT, recordRateLimit, WAVE_RATE_LIMIT } from "../../_shared/rate-limit.ts";
import { clientIpAddress } from "../core.ts";
import { HttpError } from "../core.ts";
