import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";
import {
  configuredAdminWhatsAppNumberForCountry,
  selectAdminProfileForPhone,
} from "./index.ts";

Deno.test("configuredAdminWhatsAppNumberForCountry returns the current country number", () => {
  assertEquals(
    configuredAdminWhatsAppNumberForCountry("356"),
    "+35699711145",
  );
  assertEquals(
    configuredAdminWhatsAppNumberForCountry("250"),
    "+25075588248",
  );
});

Deno.test("selectAdminProfileForPhone falls back to the configured country admin number", () => {
  const profile = selectAdminProfileForPhone(
    [{
      id: "admin-1",
      display_name: "Main Admin",
      email: "admin@example.com",
      role: "admin",
      whatsapp_number: "+35699742524",
    }],
    "+35699711145",
    "356",
  );

  assertEquals(profile?.id, "admin-1");
});

Deno.test("selectAdminProfileForPhone matches canonicalized Rwanda numbers", () => {
  const profile = selectAdminProfileForPhone(
    [{
      id: "admin-rw",
      display_name: "RW Admin",
      role: "admin",
      whatsapp_number: "+250075588248",
    }],
    "+25075588248",
    "250",
  );

  assertEquals(profile?.id, "admin-rw");
});

Deno.test("selectAdminProfileForPhone still falls back when the stored profile has no phone", () => {
  const profile = selectAdminProfileForPhone(
    [{
      id: "admin-2",
      display_name: "Fallback Admin",
      role: "admin",
      whatsapp_number: null,
    }],
    "+25075588248",
    "250",
  );

  assertEquals(profile?.id, "admin-2");
});

Deno.test("selectAdminProfileForPhone synthesizes an admin profile when storage is missing", () => {
  const profile = selectAdminProfileForPhone(
    [],
    "+25075588248",
    "250",
  );

  assertEquals(profile?.id, "00000000-0000-0000-0000-000000000250");
  assertEquals(profile?.role, "admin");
});

Deno.test("selectAdminProfileForPhone still finds configured admin numbers across country defaults", () => {
  const profile = selectAdminProfileForPhone(
    [],
    "+35699711145",
    "250",
  );

  assertEquals(profile?.id, "00000000-0000-0000-0000-000000000356");
});
