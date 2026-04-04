import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  generateOrderNumber,
  normalizePaymentMethod,
  normalizeVenueSupportedPaymentMethods,
  normalizeWaveTableNumber,
  orderPaymentStatusForMethod,
  resetGoogleMapsSearchRateLimitState,
  resetWaveRateLimitState,
  shouldGenerateAiVenueProfileImage,
} from "./index.ts";

// ─── Order Number Generation ───

Deno.test("generateOrderNumber produces 8-digit string", () => {
  const result = generateOrderNumber();
  assertEquals(typeof result, "string");
  assertEquals(result.length, 8);
  assertEquals(/^\d{8}$/.test(result), true);

  const num = Number.parseInt(result);
  assertEquals(num >= 10_000_000, true);
  assertEquals(num <= 99_999_999, true);
});

Deno.test("generateOrderNumber produces unique values", () => {
  const seen = new Set<string>();
  for (let i = 0; i < 100; i++) {
    seen.add(generateOrderNumber());
  }
  assertEquals(seen.size > 90, true);
});

// ─── Payment Method Normalization ───

Deno.test("normalizePaymentMethod maps cash variants", () => {
  assertEquals(normalizePaymentMethod("cash"), "cash");
  assertEquals(normalizePaymentMethod("Cash"), "cash");
  assertEquals(normalizePaymentMethod("CASH"), "cash");
});

Deno.test("normalizePaymentMethod maps revolut variants", () => {
  assertEquals(normalizePaymentMethod("revolut"), "revolut_link");
  assertEquals(normalizePaymentMethod("revolut_link"), "revolut_link");
  assertEquals(normalizePaymentMethod("revolutlink"), "revolut_link");
  assertEquals(normalizePaymentMethod("revolut_me"), "revolut_link");
});

Deno.test("normalizePaymentMethod maps momo variants", () => {
  assertEquals(normalizePaymentMethod("momo"), "momo_ussd");
  assertEquals(normalizePaymentMethod("momo_ussd"), "momo_ussd");
  assertEquals(normalizePaymentMethod("mobile_money"), "momo_ussd");
});

Deno.test("normalizePaymentMethod defaults undefined to cash", () => {
  assertEquals(normalizePaymentMethod(undefined), "cash");
  assertEquals(normalizePaymentMethod(null), "cash");
});

Deno.test("normalizePaymentMethod throws on unsupported method", () => {
  assertThrows(() => normalizePaymentMethod("credit_card"), Error);
  assertThrows(() => normalizePaymentMethod("paypal"), Error);
});

// ─── Payment Status For Method ───

Deno.test("orderPaymentStatusForMethod returns correct status per method", () => {
  assertEquals(orderPaymentStatusForMethod("cash"), "not_required");
  assertEquals(orderPaymentStatusForMethod("revolut_link"), "pending");
  assertEquals(orderPaymentStatusForMethod("momo_ussd"), "pending");
});

Deno.test("orderPaymentStatusForMethod throws on invalid method", () => {
  assertThrows(() => orderPaymentStatusForMethod("invalid"), Error);
});

// ─── Venue Supported Payment Methods ───

Deno.test(
  "normalizeVenueSupportedPaymentMethods parses array correctly",
  () => {
    const result = normalizeVenueSupportedPaymentMethods([
      "cash",
      "revolut_link",
    ]);
    assertEquals(result, ["cash", "revolut_link"]);
  },
);

Deno.test("normalizeVenueSupportedPaymentMethods deduplicates", () => {
  const result = normalizeVenueSupportedPaymentMethods([
    "cash",
    "cash",
    "revolut_link",
  ]);
  assertEquals(result, ["cash", "revolut_link"]);
});

Deno.test(
  "normalizeVenueSupportedPaymentMethods defaults to cash if empty",
  () => {
    assertEquals(normalizeVenueSupportedPaymentMethods([]), ["cash"]);
    assertEquals(normalizeVenueSupportedPaymentMethods(null), ["cash"]);
    assertEquals(normalizeVenueSupportedPaymentMethods(undefined), ["cash"]);
  },
);

Deno.test(
  "normalizeVenueSupportedPaymentMethods adds revolut if URL present",
  () => {
    const result = normalizeVenueSupportedPaymentMethods(
      [],
      "https://revolut.me/test",
    );
    assertEquals(result, ["cash", "revolut_link"]);
  },
);

Deno.test(
  "normalizeVenueSupportedPaymentMethods parses comma-separated string",
  () => {
    const result = normalizeVenueSupportedPaymentMethods("cash,revolut_link");
    assertEquals(result, ["cash", "revolut_link"]);
  },
);

// ─── Wave Table Number ───

Deno.test("normalizeWaveTableNumber accepts valid 1-4 digit values", () => {
  assertEquals(normalizeWaveTableNumber("1"), "1");
  assertEquals(normalizeWaveTableNumber("12"), "12");
  assertEquals(normalizeWaveTableNumber("123"), "123");
  assertEquals(normalizeWaveTableNumber("9999"), "9999");
});

Deno.test("normalizeWaveTableNumber strips leading zeros", () => {
  assertEquals(normalizeWaveTableNumber("007"), "7");
  assertEquals(normalizeWaveTableNumber("0012"), "12");
});

Deno.test("normalizeWaveTableNumber strips whitespace", () => {
  assertEquals(normalizeWaveTableNumber(" 42 "), "42");
  assertEquals(normalizeWaveTableNumber("1 2"), "12");
});

Deno.test("normalizeWaveTableNumber rejects invalid values", () => {
  assertThrows(() => normalizeWaveTableNumber(""), Error);
  assertThrows(() => normalizeWaveTableNumber("abc"), Error);
  assertThrows(() => normalizeWaveTableNumber("12345"), Error);
  assertThrows(() => normalizeWaveTableNumber("0"), Error);
  assertThrows(() => normalizeWaveTableNumber("-1"), Error);
});

// ─── AI Venue Profile Image ───

Deno.test("shouldGenerateAiVenueProfileImage returns true for no image", () => {
  assertEquals(shouldGenerateAiVenueProfileImage({ image_url: null }), true);
  assertEquals(shouldGenerateAiVenueProfileImage({}), true);
});

Deno.test(
  "shouldGenerateAiVenueProfileImage returns false for locked image",
  () => {
    assertEquals(
      shouldGenerateAiVenueProfileImage({
        image_locked: true,
        image_url: null,
      }),
      false,
    );
  },
);

Deno.test(
  "shouldGenerateAiVenueProfileImage returns false for manual image",
  () => {
    assertEquals(
      shouldGenerateAiVenueProfileImage({
        image_source: "manual",
        image_url: "https://example.com/img.jpg",
      }),
      false,
    );
  },
);

Deno.test(
  "shouldGenerateAiVenueProfileImage returns false for existing AI image",
  () => {
    assertEquals(
      shouldGenerateAiVenueProfileImage({
        image_source: "ai_gemini",
        image_url: "https://example.com/ai.jpg",
      }),
      false,
    );
  },
);

Deno.test(
  "shouldGenerateAiVenueProfileImage returns true for non-AI existing image",
  () => {
    assertEquals(
      shouldGenerateAiVenueProfileImage({
        image_source: "import",
        image_url: "https://example.com/old.jpg",
      }),
      true,
    );
  },
);

// ─── Rate Limit State Reset ───

Deno.test(
  "resetWaveRateLimitState and resetGoogleMapsSearchRateLimitState do not throw",
  () => {
    resetWaveRateLimitState();
    resetGoogleMapsSearchRateLimitState();
  },
);
