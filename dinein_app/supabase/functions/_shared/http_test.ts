import { assertEquals, assertThrows } from "jsr:@std/assert@1";

import {
  assertAllowedAppOrigin,
  HttpError,
  resolveAllowedAppOrigin,
} from "./http.ts";

Deno.test("resolveAllowedAppOrigin allows production guest, venue, and admin hosts", () => {
  assertEquals(
    resolveAllowedAppOrigin("https://dineinmtg.ikanisa.com/discover"),
    "https://dineinmtg.ikanisa.com",
  );
  assertEquals(
    resolveAllowedAppOrigin("https://dineinmtv.ikanisa.com/venue/login"),
    "https://dineinmtv.ikanisa.com",
  );
  assertEquals(
    resolveAllowedAppOrigin("https://dineinrwa.ikanisa.com/admin/login"),
    "https://dineinrwa.ikanisa.com",
  );
});

Deno.test("resolveAllowedAppOrigin allows localhost development origins", () => {
  assertEquals(
    resolveAllowedAppOrigin("http://localhost:4173/discover"),
    "http://localhost:4173",
  );
  assertEquals(
    resolveAllowedAppOrigin("http://127.0.0.1:8080/venue/login"),
    "http://127.0.0.1:8080",
  );
});

Deno.test("resolveAllowedAppOrigin honors APP_ALLOWED_ORIGINS overrides", () => {
  const previous = Deno.env.get("APP_ALLOWED_ORIGINS");
  try {
    Deno.env.set(
      "APP_ALLOWED_ORIGINS",
      "https://preview.dinein.test, https://staging.dinein.test",
    );
    assertEquals(
      resolveAllowedAppOrigin("https://preview.dinein.test/discover"),
      "https://preview.dinein.test",
    );
    assertEquals(resolveAllowedAppOrigin("https://evil.example"), null);
  } finally {
    if (previous == null) {
      Deno.env.delete("APP_ALLOWED_ORIGINS");
    } else {
      Deno.env.set("APP_ALLOWED_ORIGINS", previous);
    }
  }
});

Deno.test("assertAllowedAppOrigin rejects unexpected browser origins", () => {
  assertThrows(
    () =>
      assertAllowedAppOrigin(
        new Request("https://example.functions.supabase.co", {
          headers: { origin: "https://evil.example" },
        }),
      ),
    HttpError,
    "Origin not allowed.",
  );
});
