ALTER TABLE public.dinein_venues
  DROP CONSTRAINT IF EXISTS dinein_venues_status_check;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'dinein_venues'
      AND column_name = 'status'
      AND udt_name = 'venue_status'
  ) THEN
    ALTER TABLE public.dinein_venues
      ALTER COLUMN status DROP DEFAULT;

    ALTER TABLE public.dinein_venues
      ALTER COLUMN status TYPE TEXT
      USING status::TEXT;
  END IF;
END;
$$;

UPDATE public.dinein_venues
SET status = 'pending_activation'
WHERE status IN ('pending_claim', 'pending');

ALTER TABLE public.dinein_venues
  ADD CONSTRAINT dinein_venues_status_check
  CHECK (
    status = ANY (
      ARRAY[
        'active'::TEXT,
        'inactive'::TEXT,
        'maintenance'::TEXT,
        'suspended'::TEXT,
        'deleted'::TEXT,
        'pending_activation'::TEXT
      ]
    )
  );

UPDATE public.dinein_venues AS venue
SET
  phone = COALESCE(
    NULLIF(BTRIM(venue.phone), ''),
    NULLIF(BTRIM(claim.whatsapp_number), ''),
    NULLIF(BTRIM(claim.contact_phone), '')
  ),
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
  approved_at = COALESCE(
    venue.approved_at,
    claim.approved_at,
    claim.reviewed_at,
    claim.created_at
  ),
  access_verified_at = COALESCE(
    venue.access_verified_at,
    claim.whatsapp_verified_at
  ),
  last_access_token_issued_at = COALESCE(
    venue.last_access_token_issued_at,
    claim.last_access_token_issued_at
  ),
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
WHERE venue.approved_claim_id = claim.id;

UPDATE public.dinein_venues
SET phone = COALESCE(
  NULLIF(BTRIM(phone), ''),
  NULLIF(BTRIM(owner_whatsapp_number), ''),
  NULLIF(BTRIM(owner_contact_phone), '')
)
WHERE NULLIF(BTRIM(COALESCE(phone, '')), '') IS NULL
  AND COALESCE(
    NULLIF(BTRIM(owner_whatsapp_number), ''),
    NULLIF(BTRIM(owner_contact_phone), '')
  ) IS NOT NULL;

UPDATE public.dinein_venues
SET approved_at = COALESCE(approved_at, access_verified_at, updated_at, created_at)
WHERE status = 'active'
  AND approved_at IS NULL;

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
    NULLIF(BTRIM(COALESCE(venue.owner_whatsapp_number, '')), ''),
    NULLIF(BTRIM(COALESCE(venue.owner_contact_phone, '')), '')
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

COMMENT ON FUNCTION public.dinein_venue_ordering_readiness_reasons(public.dinein_venues) IS
  'Returns machine-readable readiness failures for venue guest ordering.';

UPDATE public.dinein_venues AS venue
SET ordering_enabled = FALSE
WHERE COALESCE(
  array_length(public.dinein_venue_ordering_readiness_reasons(venue), 1),
  0
) > 0;

DROP INDEX IF EXISTS public.uq_dinein_venues_approved_claim_id;

ALTER TABLE public.dinein_venues
  DROP COLUMN IF EXISTS approved_claim_id;

DROP TABLE IF EXISTS public.dinein_venue_claims;
