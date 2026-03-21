import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";
import {
  buildClaimAccessAuditUpdate,
  buildVenueAccessAuditUpdate,
} from "./index.ts";

Deno.test("buildClaimAccessAuditUpdate captures verification and token issuance", () => {
  const issuedAt = "2026-03-21T11:00:00.000Z";
  const verifiedAt = "2026-03-21T11:01:00.000Z";
  assertEquals(
    buildClaimAccessAuditUpdate({
      issuedAt,
      verifiedAt,
      normalizedPhone: "+35699123456",
      challengeId: "c4d6af9f-a2cf-4725-b366-c55f32a0f901",
      verificationMethod: "otp",
      verifiedBy: "+35699123456",
      verificationNote: "Verified via WhatsApp OTP.",
    }),
    {
      last_access_token_issued_at: issuedAt,
      whatsapp_verified_at: verifiedAt,
      last_verified_whatsapp_number: "+35699123456",
      last_otp_challenge_id: "c4d6af9f-a2cf-4725-b366-c55f32a0f901",
      access_verification_method: "otp",
      access_verified_by: "+35699123456",
      access_verification_note: "Verified via WhatsApp OTP.",
    },
  );
});

Deno.test("buildVenueAccessAuditUpdate links approved claim sessions back to the venue", () => {
  const issuedAt = "2026-03-21T11:00:00.000Z";
  const verifiedAt = "2026-03-21T11:01:00.000Z";
  assertEquals(
    buildVenueAccessAuditUpdate({
      id: "claim-123",
      venue_id: "venue-123",
      claimant_id: null,
      contact_phone: "+35699123456",
      whatsapp_number: "+35699888777",
      approved_at: "2026-03-21T10:50:00.000Z",
    }, {
      issuedAt,
      verifiedAt,
      verificationMethod: "otp",
      verifiedBy: "+35699123456",
      verificationNote: "Verified via WhatsApp OTP.",
    }),
    {
      approved_claim_id: "claim-123",
      approved_at: "2026-03-21T10:50:00.000Z",
      owner_contact_phone: "+35699123456",
      owner_whatsapp_number: "+35699888777",
      last_access_token_issued_at: issuedAt,
      access_verified_at: verifiedAt,
      access_verification_method: "otp",
      access_verified_by: "+35699123456",
      access_verification_note: "Verified via WhatsApp OTP.",
    },
  );
});
