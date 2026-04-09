ALTER TABLE public.dinein_venues
  ADD COLUMN IF NOT EXISTS supported_payment_methods TEXT[] NOT NULL
    DEFAULT ARRAY['cash']::TEXT[];

COMMENT ON COLUMN public.dinein_venues.supported_payment_methods IS
  'Guest payment methods enabled for the venue. Cash is the default baseline; Revolut requires revolut_url.';

UPDATE public.dinein_venues
SET supported_payment_methods = CASE
  WHEN COALESCE(array_length(supported_payment_methods, 1), 0) > 0
    THEN supported_payment_methods
  WHEN NULLIF(BTRIM(COALESCE(revolut_url, '')), '') IS NOT NULL
    THEN ARRAY['cash', 'revolut_link']::TEXT[]
  ELSE ARRAY['cash']::TEXT[]
END;

ALTER TABLE public.dinein_venues
  DROP CONSTRAINT IF EXISTS dinein_venues_supported_payment_methods_check;

ALTER TABLE public.dinein_venues
  ADD CONSTRAINT dinein_venues_supported_payment_methods_check
  CHECK (
    COALESCE(array_length(supported_payment_methods, 1), 0) > 0
    AND supported_payment_methods <@ ARRAY['cash', 'revolut_link', 'momo_ussd']::TEXT[]
  );

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

COMMENT ON FUNCTION public.dinein_venue_ordering_readiness_reasons(public.dinein_venues) IS
  'Returns machine-readable readiness failures for venue guest ordering.';

CREATE OR REPLACE FUNCTION public.enforce_dinein_venue_ordering_readiness()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  reasons TEXT[];
  attempted_enable BOOLEAN := COALESCE(NEW.ordering_enabled, FALSE);
BEGIN
  IF COALESCE(array_length(NEW.supported_payment_methods, 1), 0) = 0 THEN
    NEW.supported_payment_methods := ARRAY['cash']::TEXT[];
  END IF;

  reasons := public.dinein_venue_ordering_readiness_reasons(NEW);

  IF COALESCE(array_length(reasons, 1), 0) = 0 THEN
    RETURN NEW;
  END IF;

  IF attempted_enable
     AND (
       TG_OP = 'INSERT'
       OR COALESCE(OLD.ordering_enabled, FALSE) IS DISTINCT FROM TRUE
     ) THEN
    RAISE EXCEPTION 'Venue is not ready for guest ordering'
      USING
        ERRCODE = '23514',
        DETAIL = array_to_string(reasons, ',');
  END IF;

  NEW.ordering_enabled := FALSE;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_dinein_venue_ordering_readiness
  ON public.dinein_venues;

CREATE TRIGGER trg_enforce_dinein_venue_ordering_readiness
  BEFORE INSERT OR UPDATE ON public.dinein_venues
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_dinein_venue_ordering_readiness();

UPDATE public.dinein_venues AS venue
SET ordering_enabled = FALSE
WHERE COALESCE(
  array_length(public.dinein_venue_ordering_readiness_reasons(venue), 1),
  0
) > 0;

CREATE INDEX IF NOT EXISTS idx_dinein_venues_supported_payment_methods
  ON public.dinein_venues USING GIN (supported_payment_methods);
