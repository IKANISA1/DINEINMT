import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";
import { buildVenueAccessAuditUpdate } from "./index.ts";

Deno.test("buildVenueAccessAuditUpdate preserves venue access data and verification audit", () => {
  const issuedAt = "2026-03-21T11:00:00.000Z";
  const verifiedAt = "2026-03-21T11:01:00.000Z";
  assertEquals(
    buildVenueAccessAuditUpdate({
      id: "venue-123",
      phone: "+35699123456",
      owner_contact_phone: "+35699222333",
      owner_whatsapp_number: "+35699888777",
      approved_at: "2026-03-21T10:50:00.000Z",
    }, {
      issuedAt,
      verifiedAt,
      normalizedPhone: "+35699123456",
      verificationMethod: "otp",
      verifiedBy: "+35699123456",
      verificationNote: "Verified via WhatsApp OTP.",
    }),
    {
      normalized_access_phone: "+35699123456",
      phone: "+35699123456",
      approved_at: "2026-03-21T10:50:00.000Z",
      owner_contact_phone: "+35699222333",
      owner_whatsapp_number: "+35699888777",
      last_access_token_issued_at: issuedAt,
      access_verified_at: verifiedAt,
      access_verification_method: "otp",
      access_verified_by: "+35699123456",
      access_verification_note: "Verified via WhatsApp OTP.",
    },
  );
});
