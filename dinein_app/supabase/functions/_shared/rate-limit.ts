/**
 * Durable (DB-backed) rate limiting for DineIn API actions.
 *
 * Uses `dinein_rate_limit_buckets` table to persist rate limit state across
 * cold starts and function instances.
 *
 * Falls back to in-memory rate limiting if the DB operation fails (graceful
 * degradation — never blocks a request due to an infra error).
 */

import { createClient } from "npm:@supabase/supabase-js@2";

// ─── Types ───

type SupabaseClient = any;

interface RateLimitConfig {
  /** Rate limit action name, e.g. "wave" or "google_maps_search" */
  action: string;
  /** Sliding window size in milliseconds */
  windowMs: number;
  /** Maximum requests allowed within the window */
  maxRequests: number;
  /** Error message to throw if rate limited */
  errorMessage: string;
  /** Error detail code for the client */
  errorCode: string;
}

// ─── In-memory fallback (same as the original implementation) ───

const inMemoryBuckets = new Map<string, number[]>();

function pruneInMemoryBucket(
  compositeKey: string,
  windowMs: number,
  nowMs: number,
): number[] {
  const windowStart = nowMs - windowMs;
  const recent = (inMemoryBuckets.get(compositeKey) ?? []).filter(
    (ts) => ts >= windowStart,
  );
  if (recent.length === 0) {
    inMemoryBuckets.delete(compositeKey);
  } else {
    inMemoryBuckets.set(compositeKey, recent);
  }
  return recent;
}

// ─── DB-backed rate limiting ───

/**
 * Check if a request is within the rate limit. If it exceeds the limit, throws
 * an error with status 429.
 *
 * @returns The subject key used (needed for `recordRateLimit`)
 */
export async function assertRateLimit(
  supabase: SupabaseClient,
  subjectKey: string | null,
  config: RateLimitConfig,
  nowMs: number,
): Promise<string | null> {
  if (!subjectKey) return null;

  const compositeKey = `${config.action}:${subjectKey}`;

  try {
    // Try DB-backed check
    const windowStart = nowMs - config.windowMs;

    const { data, error } = await supabase
      .from("dinein_rate_limit_buckets")
      .select("request_timestamps")
      .eq("subject_key", subjectKey)
      .eq("action", config.action)
      .maybeSingle();

    if (error) {
      console.warn(
        `[rate-limit] DB read failed for ${config.action}, falling back to in-memory`,
        error.message,
      );
      // Fall back to in-memory
      const recent = pruneInMemoryBucket(compositeKey, config.windowMs, nowMs);
      if (recent.length >= config.maxRequests) {
        throwRateLimitError(config);
      }
      return subjectKey;
    }

    const timestamps: number[] = (data?.request_timestamps ?? []).filter(
      (ts: number) => ts >= windowStart,
    );

    if (timestamps.length >= config.maxRequests) {
      throwRateLimitError(config);
    }
  } catch (e) {
    // Re-throw HttpError (rate limit exceeded)
    if (e && typeof e === "object" && "status" in e) throw e;

    // DB failure → fall back to in-memory
    console.warn(
      `[rate-limit] DB operation failed for ${config.action}, falling back to in-memory`,
    );
    const recent = pruneInMemoryBucket(compositeKey, config.windowMs, nowMs);
    if (recent.length >= config.maxRequests) {
      throwRateLimitError(config);
    }
  }

  return subjectKey;
}

/**
 * Record a successful request for rate limiting purposes.
 */
export async function recordRateLimit(
  supabase: SupabaseClient,
  subjectKey: string | null,
  config: RateLimitConfig,
  nowMs: number,
): Promise<void> {
  if (!subjectKey) return;

  const compositeKey = `${config.action}:${subjectKey}`;
  const windowStart = nowMs - config.windowMs;

  try {
    // Upsert: fetch existing timestamps, prune, append, write back
    const { data } = await supabase
      .from("dinein_rate_limit_buckets")
      .select("request_timestamps")
      .eq("subject_key", subjectKey)
      .eq("action", config.action)
      .maybeSingle();

    const existing: number[] = (data?.request_timestamps ?? []).filter(
      (ts: number) => ts >= windowStart,
    );
    existing.push(nowMs);

    await supabase
      .from("dinein_rate_limit_buckets")
      .upsert(
        {
          subject_key: subjectKey,
          action: config.action,
          request_timestamps: existing,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "subject_key,action" },
      );
  } catch (e) {
    // DB failure → fall back to in-memory
    console.warn(
      `[rate-limit] DB write failed for ${config.action}, recording in-memory only`,
      e,
    );
    const recent = pruneInMemoryBucket(compositeKey, config.windowMs, nowMs);
    recent.push(nowMs);
    inMemoryBuckets.set(compositeKey, recent);
  }
}

/**
 * Clear all in-memory rate limit state (for testing).
 */
export function resetInMemoryRateLimitState(): void {
  inMemoryBuckets.clear();
}

// ─── Helpers ───

function throwRateLimitError(config: RateLimitConfig): never {
  // Using a plain object with status property to match HttpError pattern
  const error = new Error(config.errorMessage) as Error & {
    status: number;
    details?: Record<string, unknown>;
  };
  error.status = 429;
  error.details = { code: config.errorCode };
  throw error;
}

// ─── Pre-configured rate limit configs ───

export const WAVE_RATE_LIMIT: RateLimitConfig = {
  action: "wave",
  windowMs: 5 * 60 * 1000, // 5 minutes
  maxRequests: 3,
  errorMessage:
    "Too many staff requests from this device. Please wait a moment and try again.",
  errorCode: "wave_rate_limited",
};

export const GOOGLE_MAPS_SEARCH_RATE_LIMIT: RateLimitConfig = {
  action: "google_maps_search",
  windowMs: 15 * 60 * 1000, // 15 minutes
  maxRequests: 20,
  errorMessage:
    "Too many venue search requests from this device. Please wait a moment and try again.",
  errorCode: "google_maps_search_rate_limited",
};
