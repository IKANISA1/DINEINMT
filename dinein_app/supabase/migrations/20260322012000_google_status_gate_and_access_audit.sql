ALTER TABLE public.dinein_venue_claims
  ADD COLUMN IF NOT EXISTS access_verification_method TEXT,
  ADD COLUMN IF NOT EXISTS access_verified_by TEXT,
  ADD COLUMN IF NOT EXISTS access_verification_note TEXT;

ALTER TABLE public.dinein_venues
  ADD COLUMN IF NOT EXISTS access_verification_method TEXT,
  ADD COLUMN IF NOT EXISTS access_verified_by TEXT,
  ADD COLUMN IF NOT EXISTS access_verification_note TEXT,
  ADD COLUMN IF NOT EXISTS google_closed_override_enabled BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN public.dinein_venue_claims.access_verification_method IS
  'How venue access was verified: otp or admin_override.';
COMMENT ON COLUMN public.dinein_venue_claims.access_verified_by IS
  'Actor that verified venue access: normalized WhatsApp phone, admin id, or service_role.';
COMMENT ON COLUMN public.dinein_venue_claims.access_verification_note IS
  'Operational note explaining the venue access verification event.';

COMMENT ON COLUMN public.dinein_venues.access_verification_method IS
  'Most recent method used to verify access for the linked approved claim.';
COMMENT ON COLUMN public.dinein_venues.access_verified_by IS
  'Most recent actor that verified venue access for this venue.';
COMMENT ON COLUMN public.dinein_venues.access_verification_note IS
  'Most recent operational note explaining venue access verification.';
COMMENT ON COLUMN public.dinein_venues.google_closed_override_enabled IS
  'Explicit admin override allowing ordering readiness even when Google marks the venue CLOSED_PERMANENTLY.';

ALTER TABLE public.dinein_venue_claims
  DROP CONSTRAINT IF EXISTS dinein_venue_claims_access_verification_method_check;

ALTER TABLE public.dinein_venue_claims
  ADD CONSTRAINT dinein_venue_claims_access_verification_method_check
  CHECK (
    access_verification_method IS NULL
    OR access_verification_method IN ('otp', 'admin_override')
  );

ALTER TABLE public.dinein_venues
  DROP CONSTRAINT IF EXISTS dinein_venues_access_verification_method_check;

ALTER TABLE public.dinein_venues
  ADD CONSTRAINT dinein_venues_access_verification_method_check
  CHECK (
    access_verification_method IS NULL
    OR access_verification_method IN ('otp', 'admin_override')
  );

UPDATE public.dinein_venue_claims
SET
  access_verification_method = COALESCE(access_verification_method, 'otp'),
  access_verified_by = COALESCE(
    NULLIF(BTRIM(access_verified_by), ''),
    NULLIF(BTRIM(last_verified_whatsapp_number), ''),
    NULLIF(BTRIM(whatsapp_number), ''),
    NULLIF(BTRIM(contact_phone), '')
  ),
  access_verification_note = COALESCE(
    access_verification_note,
    'Verified via WhatsApp OTP.'
  )
WHERE whatsapp_verified_at IS NOT NULL;

UPDATE public.dinein_venues AS venue
SET
  access_verification_method = COALESCE(
    venue.access_verification_method,
    claim.access_verification_method
  ),
  access_verified_by = COALESCE(
    NULLIF(BTRIM(venue.access_verified_by), ''),
    NULLIF(BTRIM(claim.access_verified_by), '')
  ),
  access_verification_note = COALESCE(
    venue.access_verification_note,
    claim.access_verification_note
  )
FROM public.dinein_venue_claims AS claim
WHERE venue.approved_claim_id = claim.id
  AND venue.access_verified_at IS NOT NULL;

CREATE OR REPLACE FUNCTION public.dinein_venue_ordering_readiness_reasons(
  venue public.dinein_venues
)
RETURNS TEXT[]
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  reasons TEXT[] := ARRAY[]::TEXT[];
  effective_phone TEXT := COALESCE(
    NULLIF(BTRIM(COALESCE(venue.phone, '')), ''),
    NULLIF(BTRIM(COALESCE(venue.owner_contact_phone, '')), ''),
    NULLIF(BTRIM(COALESCE(venue.owner_whatsapp_number, '')), '')
  );
  normalized_google_status TEXT := UPPER(
    NULLIF(BTRIM(COALESCE(venue.google_business_status, '')), '')
  );
  has_cash BOOLEAN := 'cash' = ANY(COALESCE(venue.supported_payment_methods, ARRAY[]::TEXT[]));
  has_revolut BOOLEAN := 'revolut_link' = ANY(COALESCE(venue.supported_payment_methods, ARRAY[]::TEXT[]));
  has_momo BOOLEAN := 'momo_ussd' = ANY(COALESCE(venue.supported_payment_methods, ARRAY[]::TEXT[]));
  has_revolut_config BOOLEAN := has_revolut
    AND NULLIF(BTRIM(COALESCE(venue.revolut_url, '')), '') IS NOT NULL;
  has_viable_payment_method BOOLEAN := has_cash OR has_revolut_config;
BEGIN
  IF venue.status IS DISTINCT FROM 'active' THEN
    reasons := array_append(reasons, 'venue_not_active');
  END IF;

  IF normalized_google_status = 'CLOSED_PERMANENTLY'
     AND COALESCE(venue.google_closed_override_enabled, FALSE) = FALSE THEN
    reasons := array_append(reasons, 'google_business_closed_permanently');
  END IF;

  IF venue.approved_claim_id IS NULL THEN
    reasons := array_append(reasons, 'approved_claim_required');
  END IF;

  IF venue.approved_at IS NULL THEN
    reasons := array_append(reasons, 'approved_at_required');
  END IF;

  IF venue.access_verified_at IS NULL THEN
    reasons := array_append(reasons, 'access_verification_required');
  END IF;

  IF NULLIF(BTRIM(COALESCE(venue.name, '')), '') IS NULL THEN
    reasons := array_append(reasons, 'venue_name_required');
  END IF;

  IF NULLIF(BTRIM(COALESCE(venue.address, '')), '') IS NULL THEN
    reasons := array_append(reasons, 'venue_address_required');
  END IF;

  IF effective_phone IS NULL THEN
    reasons := array_append(reasons, 'venue_phone_required');
  END IF;

  IF NULLIF(BTRIM(COALESCE(venue.image_url, '')), '') IS NULL THEN
    reasons := array_append(reasons, 'venue_image_required');
  END IF;

  IF NULLIF(
    BTRIM(
      COALESCE(
        NULLIF(BTRIM(COALESCE(venue.owner_contact_phone, '')), ''),
        NULLIF(BTRIM(COALESCE(venue.owner_whatsapp_number, '')), ''),
        ''
      )
    ),
    ''
  ) IS NULL THEN
    reasons := array_append(reasons, 'owner_contact_required');
  END IF;

  IF COALESCE(array_length(venue.supported_payment_methods, 1), 0) = 0 THEN
    reasons := array_append(reasons, 'payment_method_required');
  END IF;

  IF NOT has_viable_payment_method THEN
    IF has_revolut AND NOT has_revolut_config THEN
      reasons := array_append(reasons, 'revolut_url_required');
    END IF;

    IF has_momo THEN
      reasons := array_append(reasons, 'momo_configuration_required');
    END IF;

    IF COALESCE(array_length(reasons, 1), 0) = 0 THEN
      reasons := array_append(reasons, 'payment_method_required');
    END IF;
  END IF;

  RETURN reasons;
END;
$$;

UPDATE public.dinein_venues AS venue
SET ordering_enabled = FALSE
WHERE COALESCE(
  array_length(public.dinein_venue_ordering_readiness_reasons(venue), 1),
  0
) > 0;
