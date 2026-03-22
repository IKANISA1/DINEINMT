ALTER TABLE public.dinein_venue_claims
  ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS whatsapp_verified_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS last_access_token_issued_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS last_verified_whatsapp_number TEXT,
  ADD COLUMN IF NOT EXISTS last_otp_challenge_id UUID;

COMMENT ON COLUMN public.dinein_venue_claims.approved_at IS
  'Durable approval timestamp for the claim, separate from ad-hoc review metadata.';
COMMENT ON COLUMN public.dinein_venue_claims.whatsapp_verified_at IS
  'Latest time the approved claim completed WhatsApp OTP verification.';
COMMENT ON COLUMN public.dinein_venue_claims.last_access_token_issued_at IS
  'Latest time a venue access token/session was issued for this claim.';
COMMENT ON COLUMN public.dinein_venue_claims.last_verified_whatsapp_number IS
  'Normalized WhatsApp number that most recently verified this approved claim.';
COMMENT ON COLUMN public.dinein_venue_claims.last_otp_challenge_id IS
  'Most recent WhatsApp OTP challenge used to verify this approved claim.';

ALTER TABLE public.dinein_venues
  ADD COLUMN IF NOT EXISTS approved_claim_id UUID REFERENCES public.dinein_venue_claims(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS owner_contact_phone TEXT,
  ADD COLUMN IF NOT EXISTS owner_whatsapp_number TEXT,
  ADD COLUMN IF NOT EXISTS access_verified_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS last_access_token_issued_at TIMESTAMPTZ;

COMMENT ON COLUMN public.dinein_venues.approved_claim_id IS
  'Approved claim currently linked to venue access, including OTP-based venue sessions.';
COMMENT ON COLUMN public.dinein_venues.approved_at IS
  'Time the current approved claim was approved for this venue.';
COMMENT ON COLUMN public.dinein_venues.owner_contact_phone IS
  'Primary claim contact phone used for venue access when no auth user owner exists.';
COMMENT ON COLUMN public.dinein_venues.owner_whatsapp_number IS
  'Primary WhatsApp number used for venue access when no auth user owner exists.';
COMMENT ON COLUMN public.dinein_venues.access_verified_at IS
  'Latest time venue access was verified through WhatsApp OTP for the linked approved claim.';
COMMENT ON COLUMN public.dinein_venues.last_access_token_issued_at IS
  'Latest time a venue access token/session was issued for the linked approved claim.';

UPDATE public.dinein_venue_claims
SET approved_at = COALESCE(approved_at, reviewed_at, created_at)
WHERE status = 'approved'
  AND approved_at IS NULL;

WITH latest_approved_claim AS (
  SELECT DISTINCT ON (claim.venue_id)
    claim.id,
    claim.venue_id,
    claim.claimant_id,
    claim.contact_phone,
    claim.whatsapp_number,
    COALESCE(claim.approved_at, claim.reviewed_at, claim.created_at) AS derived_approved_at
  FROM public.dinein_venue_claims AS claim
  WHERE claim.status = 'approved'
  ORDER BY
    claim.venue_id,
    COALESCE(claim.approved_at, claim.reviewed_at, claim.created_at) DESC,
    claim.created_at DESC,
    claim.id DESC
)
UPDATE public.dinein_venues AS venue
SET
  approved_claim_id = claim.id,
  approved_at = COALESCE(venue.approved_at, claim.derived_approved_at),
  owner_contact_phone = COALESCE(
    NULLIF(BTRIM(venue.owner_contact_phone), ''),
    NULLIF(BTRIM(claim.contact_phone), ''),
    NULLIF(BTRIM(claim.whatsapp_number), '')
  ),
  owner_whatsapp_number = COALESCE(
    NULLIF(BTRIM(venue.owner_whatsapp_number), ''),
    NULLIF(BTRIM(claim.whatsapp_number), ''),
    NULLIF(BTRIM(claim.contact_phone), '')
  ),
  owner_id = COALESCE(venue.owner_id, claim.claimant_id)
FROM latest_approved_claim AS claim
WHERE venue.id = claim.venue_id;

WITH latest_consumed_otp AS (
  SELECT DISTINCT ON (claim.id)
    claim.id AS claim_id,
    challenge.consumed_at,
    challenge.challenge_id,
    challenge.whatsapp_number
  FROM public.dinein_venue_claims AS claim
  JOIN public.venue_whatsapp_otp_challenges AS challenge
    ON challenge.app_scope = 'venue'
   AND challenge.consumed_at IS NOT NULL
   AND (
     regexp_replace(COALESCE(claim.contact_phone, ''), '[^0-9]', '', 'g') = challenge.normalized_whatsapp_number
     OR regexp_replace(COALESCE(claim.whatsapp_number, ''), '[^0-9]', '', 'g') = challenge.normalized_whatsapp_number
   )
  WHERE claim.status = 'approved'
  ORDER BY
    claim.id,
    challenge.consumed_at DESC,
    challenge.created_at DESC,
    challenge.id DESC
)
UPDATE public.dinein_venue_claims AS claim
SET
  whatsapp_verified_at = COALESCE(claim.whatsapp_verified_at, otp.consumed_at),
  last_access_token_issued_at = COALESCE(claim.last_access_token_issued_at, otp.consumed_at),
  last_verified_whatsapp_number = COALESCE(
    NULLIF(BTRIM(claim.last_verified_whatsapp_number), ''),
    NULLIF(BTRIM(otp.whatsapp_number), '')
  ),
  last_otp_challenge_id = COALESCE(claim.last_otp_challenge_id, otp.challenge_id)
FROM latest_consumed_otp AS otp
WHERE claim.id = otp.claim_id;

UPDATE public.dinein_venues AS venue
SET
  access_verified_at = COALESCE(venue.access_verified_at, claim.whatsapp_verified_at),
  last_access_token_issued_at = COALESCE(
    venue.last_access_token_issued_at,
    claim.last_access_token_issued_at
  )
FROM public.dinein_venue_claims AS claim
WHERE venue.approved_claim_id = claim.id
  AND claim.status = 'approved';

CREATE UNIQUE INDEX IF NOT EXISTS uq_dinein_venues_approved_claim_id
  ON public.dinein_venues (approved_claim_id)
  WHERE approved_claim_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_dinein_claims_whatsapp_verified_at
  ON public.dinein_venue_claims (whatsapp_verified_at DESC)
  WHERE whatsapp_verified_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_dinein_claims_last_access_token_issued_at
  ON public.dinein_venue_claims (last_access_token_issued_at DESC)
  WHERE last_access_token_issued_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_dinein_venues_access_verified_at
  ON public.dinein_venues (access_verified_at DESC)
  WHERE access_verified_at IS NOT NULL;
