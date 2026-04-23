import {
  type JsonRecord,
  adminClient,
  asRecord,
  authorizeVenueMutation,
  countryLabel,
  handleAuditMenuItemImages,
  handleBackfillMenuImages,
  handleBackfillVenueProfileImages,
  handleBackfillVenueProfiles,
  handleEnrichVenueProfile,
  handleGenerateMenuItemImage,
  handleGenerateVenueProfileImage,
  handleImageHealth,
  HttpError,
  ok,
  requestCountryCode,
  requireString,
  venueSnapshot,
} from "../../_shared/core-monolith.ts";
import { numberValue, optionalEnv, stringValue } from "../../_shared/env.ts";
import {
  inferMenuItemClass,
  normalizeMenuItemClass,
} from "../../_shared/menu-item-context.ts";

// Image + enrichment handlers — AI image generation, venue enrichment
// Actions: generate_menu_item_image, backfill_menu_images, audit_menu_item_images,
//          enrich_venue_profile, backfill_venue_profiles,
//          generate_venue_profile_image, backfill_venue_profile_images, image_health
export {
  handleGenerateMenuItemImage,
  handleBackfillMenuImages,
  handleAuditMenuItemImages,
  handleEnrichVenueProfile,
  handleBackfillVenueProfiles,
  handleGenerateVenueProfileImage,
  handleBackfillVenueProfileImages,
  handleImageHealth,
};

function decodeBase64Image(
  base64Data: string,
): { bytes: Uint8Array; contentType: string; ext: string } {
  let raw = base64Data;
  let detectedType = "image/jpeg";
  const dataUriMatch = raw.match(
    /^data:(image\/(?:png|jpeg|webp));base64,/i,
  );
  if (dataUriMatch) {
    detectedType = dataUriMatch[1].toLowerCase();
    raw = raw.slice(dataUriMatch[0].length);
  }
  const ext = detectedType === "image/png"
    ? "png"
    : detectedType === "image/webp"
    ? "webp"
    : "jpg";

  const binaryString = atob(raw);
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return { bytes, contentType: detectedType, ext };
}

export async function handleUploadVenueImage(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const venueId = requireString(body, "venueId", "venue_id");
  await authorizeVenueMutation(supabase, req, venueId, body.venue_session);

  const imageData = requireString(body, "image_data");
  if (!imageData || imageData.length < 100) {
    throw new HttpError(
      400,
      "image_data is required and must be a valid base64 image.",
    );
  }

  if (imageData.length > 14_000_000) {
    throw new HttpError(413, "Image too large. Maximum 10MB.");
  }

  const { bytes, contentType, ext } = decodeBase64Image(imageData);
  const timestamp = Date.now();
  const storagePath = `${venueId}/${timestamp}.${ext}`;

  const { error: uploadError } = await supabase.storage
    .from("venue-images")
    .upload(storagePath, bytes, {
      contentType,
      upsert: false,
    });

  if (uploadError) {
    console.error("[menu-api] venue image upload failed", uploadError);
    throw new HttpError(500, "Could not upload the venue image.");
  }

  const { data: urlData } = supabase.storage
    .from("venue-images")
    .getPublicUrl(storagePath);
  const publicUrl = urlData?.publicUrl;

  if (!publicUrl) {
    throw new HttpError(
      500,
      "Upload succeeded but could not resolve public URL.",
    );
  }

  const { error: dbError } = await supabase
    .from("dinein_venues")
    .update({
      image_url: publicUrl,
      image_source: "manual",
      image_status: "ready",
      image_storage_path: storagePath,
      image_error: null,
      updated_at: new Date().toISOString(),
    })
    .eq("id", venueId);

  if (dbError) {
    console.error("[menu-api] venue image DB update failed", dbError);
    throw new HttpError(
      500,
      "Image uploaded but could not update venue record.",
    );
  }

  return ok({ image_url: publicUrl, storage_path: storagePath });
}

export async function handleUploadMenuItemImage(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const venueId = requireString(body, "venueId", "venue_id");
  const itemId = requireString(body, "itemId", "item_id");
  await authorizeVenueMutation(supabase, req, venueId, body.venue_session);

  const imageData = requireString(body, "image_data");
  if (!imageData || imageData.length < 100) {
    throw new HttpError(
      400,
      "image_data is required and must be a valid base64 image.",
    );
  }

  if (imageData.length > 14_000_000) {
    throw new HttpError(413, "Image too large. Maximum 10MB.");
  }

  const { bytes, contentType, ext } = decodeBase64Image(imageData);
  const timestamp = Date.now();
  const storagePath = `${venueId}/${itemId}/${timestamp}.${ext}`;

  const { error: uploadError } = await supabase.storage
    .from("menu-images")
    .upload(storagePath, bytes, {
      contentType,
      upsert: false,
    });

  if (uploadError) {
    console.error("[menu-api] menu item image upload failed", uploadError);
    throw new HttpError(500, "Could not upload the menu item image.");
  }

  const { data: urlData } = supabase.storage
    .from("menu-images")
    .getPublicUrl(storagePath);
  const publicUrl = urlData?.publicUrl;

  if (!publicUrl) {
    throw new HttpError(
      500,
      "Upload succeeded but could not resolve public URL.",
    );
  }

  const { error: dbError } = await supabase
    .from("dinein_menu_items")
    .update({
      image_url: publicUrl,
      image_source: "manual",
      image_status: "ready",
      image_storage_path: storagePath,
      image_error: null,
      image_locked: false,
      updated_at: new Date().toISOString(),
    })
    .eq("id", itemId)
    .eq("venue_id", venueId);

  if (dbError) {
    console.error("[menu-api] menu item image DB update failed", dbError);
    throw new HttpError(
      500,
      "Image uploaded but could not update menu item record.",
    );
  }

  return ok({ image_url: publicUrl, storage_path: storagePath });
}

const menuIngestMimeTypes = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/gif",
  "application/pdf",
  "text/plain",
  "text/csv",
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  "application/vnd.ms-excel",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "application/msword",
]);

function isGeminiMultimodalMime(mime: string): boolean {
  return mime.startsWith("image/") || mime == "application/pdf";
}

function buildMenuExtractionPrompt(
  venueName: string,
  countryCode: "MT" | "RW",
): string {
  const currency = countryCode == "RW" ? "RWF" : "EUR";
  const currencyHint = countryCode == "RW"
    ? "Prices are in Rwandan Francs (RWF). Typical range: 500–50,000 RWF."
    : "Prices are in Euros (EUR). Typical range: 2–50 EUR.";

  return [
    "You are a restaurant menu extraction specialist.",
    `You are analyzing a menu document from "${venueName}" in ${
      countryLabel(countryCode)
    }.`,
    "",
    "TASK: Extract ALL menu items from this document into a structured JSON array.",
    "",
    "For each item, extract:",
    '- "name": The dish/drink name (string, required)',
    '- "description": Brief description if visible (string, default "")',
    `- "price": Numeric price in ${currency} WITHOUT currency symbol (number, required)`,
    '- "category": The menu section/category (string, e.g. "Starters", "Mains", "Drinks", "Desserts")',
    '- "class": Either "food" or "drinks" based on the item type',
    "",
    currencyHint,
    "",
    "RULES:",
    "1. Return ONLY a valid JSON array of objects. No markdown, no explanation.",
    "2. If a price is not visible or unclear, set it to 0.",
    "3. Normalize category names (capitalize first letter, group similar items).",
    "4. For multi-size items (S/M/L), create ONE item with the most common/medium price.",
    "5. Skip headers, footers, restaurant info — extract only menu items.",
    "6. If the document contains NO menu items, return an empty array: []",
    "7. Clean up OCR artifacts (fix common typos, normalize spacing).",
    "",
    "Example output:",
    '[{"name":"Margherita Pizza","description":"Tomato, mozzarella, basil","price":12.50,"category":"Pizza","class":"food"}]',
  ].join("\n");
}

export async function handleIngestMenuDocument(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const venueId = requireString(body, "venueId", "venue_id");
  await authorizeVenueMutation(supabase, req, venueId, body.venue_session);

  const fileData = requireString(body, "file_data");
  const fileName = stringValue(body.file_name) ?? "menu";
  const mimeType = (stringValue(body.mime_type) ?? "application/octet-stream")
    .toLowerCase()
    .trim();

  if (!menuIngestMimeTypes.has(mimeType)) {
    throw new HttpError(
      400,
      `Unsupported file type: ${mimeType}. Supported: images, PDFs, Excel, CSV, Word documents.`,
      { code: "unsupported_file_type" },
    );
  }

  if (fileData.length > 14_000_000) {
    throw new HttpError(413, "File too large. Maximum 10MB.");
  }

  const geminiApiKey = optionalEnv("GEMINI_API_KEY");
  if (!geminiApiKey) {
    throw new HttpError(
      503,
      "Menu ingestion is not available (API key not configured).",
      { code: "gemini_not_configured" },
    );
  }

  const venue = await venueSnapshot(supabase, venueId);
  const venueName = stringValue(venue.name) ?? "Restaurant";
  const countryCode = requestCountryCode({
    country: body.country ?? venue.country,
  });

  const models = (
    Deno.env.get("GEMINI_MENU_INGEST_MODELS") ??
      "gemini-2.5-flash,gemini-2.5-flash-lite"
  ).split(",").map((value) => value.trim()).filter(Boolean);

  const prompt = buildMenuExtractionPrompt(venueName, countryCode);
  let contentParts: unknown[];

  if (isGeminiMultimodalMime(mimeType)) {
    let rawBase64 = fileData;
    const dataUriMatch = rawBase64.match(/^data:[^;]+;base64,/i);
    if (dataUriMatch) {
      rawBase64 = rawBase64.slice(dataUriMatch[0].length);
    }

    contentParts = [
      { text: prompt },
      {
        inlineData: {
          mimeType,
          data: rawBase64,
        },
      },
    ];
  } else {
    let rawBase64 = fileData;
    const dataUriPrefixMatch = rawBase64.match(/^data:[^;]+;base64,/i);
    if (dataUriPrefixMatch) {
      rawBase64 = rawBase64.slice(dataUriPrefixMatch[0].length);
    }

    let textContent: string;
    try {
      const binaryString = atob(rawBase64);
      const decoder = new TextDecoder("utf-8", { fatal: false });
      const bytes = new Uint8Array(binaryString.length);
      for (let i = 0; i < binaryString.length; i++) {
        bytes[i] = binaryString.charCodeAt(i);
      }
      textContent = decoder.decode(bytes);
    } catch {
      throw new HttpError(
        400,
        "Could not read the file contents. Ensure the file is not corrupted.",
        { code: "file_read_error" },
      );
    }

    if (textContent.length > 50_000) {
      textContent = textContent.slice(0, 50_000);
    }

    contentParts = [
      {
        text: [
          prompt,
          "",
          `--- FILE CONTENT (${fileName}) ---`,
          textContent,
          "--- END FILE CONTENT ---",
        ].join("\n"),
      },
    ];
  }

  let extractedItems: JsonRecord[] | null = null;

  for (const model of models) {
    try {
      console.log(
        `[menu-api] menu ingest: trying model ${model} for venue ${venueId}`,
      );
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
            contents: [{ role: "user", parts: contentParts }],
            generationConfig: {
              temperature: 0.1,
              maxOutputTokens: 8192,
            },
          }),
        },
      );

      if (!response.ok) {
        console.warn(
          `[menu-api] menu ingest: model ${model} returned ${response.status}`,
        );
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
        console.warn(
          `[menu-api] menu ingest: model ${model} returned empty text`,
        );
        continue;
      }

      const cleaned = text
        .replace(/```(?:json)?\s*/gi, "")
        .replace(/```/g, "")
        .trim();

      try {
        const parsed = JSON.parse(cleaned);
        if (Array.isArray(parsed)) {
          extractedItems = parsed.map((item) => asRecord(item));
          break;
        }
        if (
          parsed && typeof parsed == "object" && Array.isArray(parsed.items)
        ) {
          extractedItems = parsed.items.map((item: unknown) => asRecord(item));
          break;
        }
        if (
          parsed && typeof parsed == "object" &&
          Array.isArray(parsed.menu_items)
        ) {
          extractedItems = parsed.menu_items.map((item: unknown) =>
            asRecord(item)
          );
          break;
        }
      } catch {
        const arrayMatch = cleaned.match(/\[[\s\S]*\]/);
        if (arrayMatch) {
          try {
            extractedItems = JSON.parse(arrayMatch[0]).map(
              (item: unknown) => asRecord(item),
            );
            break;
          } catch {
            continue;
          }
        }
      }
    } catch (error) {
      console.error(`[menu-api] menu ingest: model ${model} error`, error);
      continue;
    }
  }

  if (!extractedItems || extractedItems.length == 0) {
    return ok({
      created_count: 0,
      skipped_count: 0,
      items: [],
      message: "No menu items could be extracted from the uploaded document.",
    });
  }

  const { data: existingItems } = await supabase
    .from("dinein_menu_items")
    .select("name, category")
    .eq("venue_id", venueId);

  const existingKeys = new Set(
    (existingItems ?? []).map(
      (item: { name: string; category: string }) =>
        `${(item.name ?? "").toLowerCase().trim()}::${
          (item.category ?? "").toLowerCase().trim()
        }`,
    ),
  );

  const validInserts: JsonRecord[] = [];
  let skippedCount = 0;

  for (const rawItem of extractedItems) {
    const name = stringValue(rawItem.name)?.trim();
    if (!name || name.length < 2) {
      skippedCount++;
      continue;
    }

    const category = stringValue(rawItem.category)?.trim() || "Uncategorized";
    const duplicateKey = `${name.toLowerCase()}::${category.toLowerCase()}`;

    if (existingKeys.has(duplicateKey)) {
      skippedCount++;
      continue;
    }

    existingKeys.add(duplicateKey);

    let price = numberValue(rawItem.price);
    if (price == undefined || !Number.isFinite(price) || price < 0) {
      price = 0;
    }

    const description = stringValue(rawItem.description)?.trim() ?? "";
    const itemClass = normalizeMenuItemClass(rawItem.class) ??
      inferMenuItemClass({
        name,
        category,
        description,
        tags: [],
        class: null,
      });

    validInserts.push({
      venue_id: venueId,
      name,
      description,
      price,
      category,
      class: itemClass,
      is_available: true,
      image_status: "pending",
      image_source: null,
      image_url: null,
      tags: [],
    });
  }

  if (validInserts.length == 0) {
    return ok({
      created_count: 0,
      skipped_count: skippedCount,
      items: [],
      message: skippedCount > 0
        ? `All ${skippedCount} extracted items were duplicates or invalid.`
        : "No valid menu items could be extracted.",
    });
  }

  const { data: insertedData, error: insertError } = await supabase
    .from("dinein_menu_items")
    .insert(validInserts)
    .select("*");

  if (insertError) {
    console.error("[menu-api] menu ingest bulk insert failed", insertError);
    throw new HttpError(500, "Could not create the extracted menu items.");
  }

  console.log(
    `[menu-api] menu ingest: created ${
      insertedData?.length ?? 0
    } items for venue ${venueId} (skipped ${skippedCount})`,
  );

  return ok(
    {
      created_count: insertedData?.length ?? 0,
      skipped_count: skippedCount,
      items: insertedData ?? [],
      message: `Successfully imported ${insertedData?.length ?? 0} menu items.`,
    },
    201,
  );
}
