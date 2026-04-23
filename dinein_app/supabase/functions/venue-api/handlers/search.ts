import {
  type JsonRecord,
  adminClient,
  asRecord,
  countryLabel,
  googleMapsSearchRateLimitKey,
  ok,
  requestCountryCode,
  requireString,
} from "../../_shared/core-monolith.ts";
import { optionalEnv, stringValue } from "../../_shared/env.ts";
import {
  assertRateLimit,
  GOOGLE_MAPS_SEARCH_RATE_LIMIT,
  recordRateLimit,
} from "../../_shared/rate-limit.ts";

// Search handlers — Google Maps venue search
// Actions: search_google_maps
export async function handleSearchGoogleMaps(
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const query = requireString(body, "query").trim();
  if (query.length < 2) {
    return ok([]);
  }

  const geminiApiKey = optionalEnv("GEMINI_API_KEY");
  if (!geminiApiKey) {
    return ok([]);
  }

  const nowMs = Date.now();
  const searchSubjectKey = googleMapsSearchRateLimitKey(req);
  await assertRateLimit(
    adminClient(),
    searchSubjectKey,
    GOOGLE_MAPS_SEARCH_RATE_LIMIT,
    nowMs,
  );
  await recordRateLimit(
    adminClient(),
    searchSubjectKey,
    GOOGLE_MAPS_SEARCH_RATE_LIMIT,
    nowMs,
  );

  const country = countryLabel(requestCountryCode(body));
  const models = (
    Deno.env.get("GEMINI_VENUE_MODELS") ??
      "gemini-2.5-flash,gemini-2.5-flash-lite"
  ).split(",").map((value) => value.trim()).filter(Boolean);

  const prompt = [
    "You are searching for hospitality venues on Google Maps.",
    "Use only grounded Google Maps results from the built-in googleMaps tool.",
    "Never invent venues, ratings, phone numbers, or addresses.",
    "",
    `Search query: ${query}`,
    `Country: ${country}`,
    "",
    "Return up to 5 venues as a JSON array.",
    "Each venue should include name, address, category, rating, ratingCount, phone, website, placeId, and googleMapsUri when available.",
    "Return only valid JSON.",
  ].join("\n");

  for (const model of models) {
    try {
      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${
          encodeURIComponent(model)
        }:generateContent`,
        {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-goog-api-key": geminiApiKey,
          },
          body: JSON.stringify({
            contents: [{ role: "user", parts: [{ text: prompt }] }],
            tools: [{ googleMaps: {} }],
          }),
        },
      );
      if (!response.ok) {
        continue;
      }

      const json = asRecord(await response.json());
      const candidate = asRecord((json.candidates as unknown[] ?? [])[0]);
      const content = asRecord(candidate.content);
      const parts = (content.parts as unknown[] | undefined) ?? [];
      const text = parts
        .map((part) => stringValue(asRecord(part).text))
        .filter((value): value is string => Boolean(value))
        .join("\n")
        .trim();
      if (!text) {
        continue;
      }

      const cleaned = text
        .replace(/```(?:json)?\s*/gi, "")
        .replace(/```/g, "")
        .trim();
      try {
        const parsed = JSON.parse(cleaned);
        if (Array.isArray(parsed)) {
          return ok(parsed);
        }
        if (
          parsed && typeof parsed == "object" && Array.isArray(parsed.results)
        ) {
          return ok(parsed.results);
        }
        return ok([parsed]);
      } catch {
        const arrayMatch = cleaned.match(/\[[\s\S]*\]/);
        if (arrayMatch) {
          try {
            return ok(JSON.parse(arrayMatch[0]));
          } catch {
            continue;
          }
        }
      }
    } catch {
      continue;
    }
  }

  return ok([]);
}
