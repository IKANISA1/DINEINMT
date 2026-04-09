import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  canonicalPhoneDigits,
  normalizeWhatsAppPhone,
  phoneNumbersMatch,
} from "./phone.ts";

Deno.test("normalizeWhatsAppPhone canonicalizes Rwanda local and legacy stored formats", () => {
  assertEquals(
    normalizeWhatsAppPhone("0795588248", { defaultCountryCode: "250" }),
    "+250795588248",
  );
  assertEquals(
    normalizeWhatsAppPhone("795588248", { defaultCountryCode: "250" }),
    "+250795588248",
  );
  assertEquals(
    normalizeWhatsAppPhone("+2500795588248"),
    "+250795588248",
  );
});

Deno.test("normalizeWhatsAppPhone canonicalizes Malta local and legacy stored formats", () => {
  assertEquals(
    normalizeWhatsAppPhone("77186193", { defaultCountryCode: "356" }),
    "+35677186193",
  );
  assertEquals(
    normalizeWhatsAppPhone("+356077186193"),
    "+35677186193",
  );
});

Deno.test("canonicalPhoneDigits collapses equivalent phone representations", () => {
  assertEquals(
    canonicalPhoneDigits("+2500795588248"),
    canonicalPhoneDigits("+250795588248"),
  );
  assertEquals(
    canonicalPhoneDigits("077186193", { defaultCountryCode: "356" }),
    canonicalPhoneDigits("+35677186193"),
  );
});

Deno.test("phoneNumbersMatch compares canonicalized values", () => {
  assertEquals(
    phoneNumbersMatch("+2500795588248", "+250795588248"),
    true,
  );
  assertEquals(
    phoneNumbersMatch("077186193", "+35677186193", {
      defaultCountryCode: "356",
    }),
    true,
  );
  assertEquals(phoneNumbersMatch("+250795588248", "+35677186193"), false);
});

Deno.test("normalizeWhatsAppPhone rejects invalid values", () => {
  assertThrows(() => normalizeWhatsAppPhone(""));
  assertThrows(() => normalizeWhatsAppPhone("1234"));
});
