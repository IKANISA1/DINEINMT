UPDATE public.dinein_venues
SET status = 'inactive'
WHERE status IN ('pending_claim', 'pending_activation', 'pending');

ALTER TABLE public.dinein_venues
  DROP CONSTRAINT IF EXISTS dinein_venues_status_check;

ALTER TABLE public.dinein_venues
  ADD CONSTRAINT dinein_venues_status_check
  CHECK (
    status = ANY (
      ARRAY[
        'active'::TEXT,
        'inactive'::TEXT,
        'maintenance'::TEXT,
        'suspended'::TEXT,
        'deleted'::TEXT
      ]
    )
  );

DROP TRIGGER IF EXISTS trg_sync_dinein_venue_access_phone
  ON public.dinein_venues;

DROP FUNCTION IF EXISTS public.sync_dinein_venue_access_phone();
DROP FUNCTION IF EXISTS public.dinein_normalize_access_phone(TEXT, TEXT, TEXT, TEXT);

DROP INDEX IF EXISTS public.uq_dinein_venues_normalized_access_phone_active;
DROP INDEX IF EXISTS public.idx_dinein_venues_access_verified_at;
DROP INDEX IF EXISTS public.uq_dinein_venues_approved_claim_id;

ALTER TABLE public.dinein_venues
  DROP COLUMN IF EXISTS approved_claim_id,
  DROP COLUMN IF EXISTS approved_at,
  DROP COLUMN IF EXISTS owner_contact_phone,
  DROP COLUMN IF EXISTS access_verified_at,
  DROP COLUMN IF EXISTS last_access_token_issued_at,
  DROP COLUMN IF EXISTS access_verification_method,
  DROP COLUMN IF EXISTS access_verified_by,
  DROP COLUMN IF EXISTS access_verification_note,
  DROP COLUMN IF EXISTS normalized_access_phone,
  DROP COLUMN IF EXISTS access_number_updated_at,
  DROP COLUMN IF EXISTS access_number_updated_by,
  DROP COLUMN IF EXISTS google_closed_override_enabled;

DROP TABLE IF EXISTS public.dinein_venue_claims;

CREATE OR REPLACE FUNCTION public.dinein_venue_ordering_readiness_reasons(
  venue public.dinein_venues
)
RETURNS TEXT[]
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  reasons TEXT[] := ARRAY[]::TEXT[];
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

  IF NULLIF(BTRIM(COALESCE(venue.name, '')), '') IS NULL THEN
    reasons := array_append(reasons, 'venue_name_required');
  END IF;

  IF NULLIF(BTRIM(COALESCE(venue.address, '')), '') IS NULL THEN
    reasons := array_append(reasons, 'venue_address_required');
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

CREATE UNIQUE INDEX IF NOT EXISTS uq_dinein_venues_owner_whatsapp_number_active
  ON public.dinein_venues (owner_whatsapp_number)
  WHERE owner_whatsapp_number IS NOT NULL
    AND NULLIF(BTRIM(owner_whatsapp_number), '') IS NOT NULL
    AND status <> 'deleted';
