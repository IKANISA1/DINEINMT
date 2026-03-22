UPDATE public.dinein_venues
SET phone = COALESCE(
  NULLIF(BTRIM(phone), ''),
  NULLIF(BTRIM(owner_contact_phone), ''),
  NULLIF(BTRIM(owner_whatsapp_number), '')
)
WHERE approved_claim_id IS NOT NULL
  AND NULLIF(BTRIM(COALESCE(phone, '')), '') IS NULL
  AND COALESCE(
    NULLIF(BTRIM(owner_contact_phone), ''),
    NULLIF(BTRIM(owner_whatsapp_number), '')
  ) IS NOT NULL;

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
