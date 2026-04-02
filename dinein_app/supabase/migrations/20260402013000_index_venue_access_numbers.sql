CREATE OR REPLACE FUNCTION public.dinein_normalize_access_phone(
  venue_country TEXT,
  venue_phone TEXT,
  venue_owner_contact_phone TEXT,
  venue_owner_whatsapp_number TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  candidate TEXT := COALESCE(
    NULLIF(BTRIM(venue_phone), ''),
    NULLIF(BTRIM(venue_owner_whatsapp_number), ''),
    NULLIF(BTRIM(venue_owner_contact_phone), '')
  );
  trimmed TEXT;
  digits TEXT;
  country_code TEXT := UPPER(COALESCE(venue_country, ''));
BEGIN
  IF candidate IS NULL THEN
    RETURN NULL;
  END IF;

  trimmed := BTRIM(candidate);
  digits := REGEXP_REPLACE(trimmed, '\D', '', 'g');

  IF digits = '' THEN
    RETURN NULL;
  END IF;

  IF LEFT(trimmed, 1) = '+' THEN
    IF LENGTH(digits) BETWEEN 8 AND 15 THEN
      RETURN '+' || digits;
    END IF;
    RETURN NULL;
  END IF;

  IF LEFT(trimmed, 2) = '00' THEN
    IF LENGTH(digits) - 2 BETWEEN 8 AND 15 THEN
      RETURN '+' || SUBSTRING(digits FROM 3);
    END IF;
    RETURN NULL;
  END IF;

  IF country_code = 'MT' AND LENGTH(digits) = 8 THEN
    RETURN '+356' || digits;
  END IF;

  IF country_code = 'RW' AND LENGTH(digits) = 10 AND LEFT(digits, 1) = '0' THEN
    RETURN '+250' || SUBSTRING(digits FROM 2);
  END IF;

  IF LENGTH(digits) BETWEEN 10 AND 15 THEN
    RETURN '+' || digits;
  END IF;

  RETURN NULL;
END;
$$;

ALTER TABLE public.dinein_venues
  ADD COLUMN IF NOT EXISTS normalized_access_phone TEXT,
  ADD COLUMN IF NOT EXISTS access_number_updated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS access_number_updated_by TEXT;

COMMENT ON COLUMN public.dinein_venues.normalized_access_phone IS
  'Canonical WhatsApp access number used for direct venue OTP lookup.';

COMMENT ON COLUMN public.dinein_venues.access_number_updated_at IS
  'When the venue access WhatsApp number was last assigned or cleared.';

COMMENT ON COLUMN public.dinein_venues.access_number_updated_by IS
  'Who last assigned or cleared the venue access WhatsApp number.';

UPDATE public.dinein_venues
SET
  normalized_access_phone = public.dinein_normalize_access_phone(
    country,
    phone,
    owner_contact_phone,
    owner_whatsapp_number
  ),
  access_number_updated_at = COALESCE(
    access_number_updated_at,
    last_access_token_issued_at,
    access_verified_at,
    updated_at,
    created_at
  ),
  access_number_updated_by = COALESCE(
    NULLIF(BTRIM(access_number_updated_by), ''),
    NULLIF(BTRIM(access_verified_by), '')
  );

WITH ranked AS (
  SELECT
    id,
    normalized_access_phone,
    ROW_NUMBER() OVER (
      PARTITION BY normalized_access_phone
      ORDER BY
        (access_verified_at IS NOT NULL) DESC,
        (status = 'active') DESC,
        updated_at DESC NULLS LAST,
        created_at DESC NULLS LAST,
        id DESC
    ) AS phone_rank
  FROM public.dinein_venues
  WHERE normalized_access_phone IS NOT NULL
)
UPDATE public.dinein_venues AS venue
SET
  normalized_access_phone = NULL,
  access_verified_at = NULL,
  access_verification_method = NULL,
  access_verified_by = NULL,
  last_access_token_issued_at = NULL,
  access_verification_note = COALESCE(
    venue.access_verification_note,
    'Cleared automatically because this WhatsApp number was duplicated across multiple venues. Assign a unique number in admin.'
  )
FROM ranked
WHERE venue.id = ranked.id
  AND ranked.phone_rank > 1;

CREATE OR REPLACE FUNCTION public.sync_dinein_venue_access_phone()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.normalized_access_phone := public.dinein_normalize_access_phone(
    NEW.country,
    NEW.phone,
    NEW.owner_contact_phone,
    NEW.owner_whatsapp_number
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_dinein_venue_access_phone
  ON public.dinein_venues;

CREATE TRIGGER trg_sync_dinein_venue_access_phone
BEFORE INSERT OR UPDATE OF country, phone, owner_contact_phone, owner_whatsapp_number
ON public.dinein_venues
FOR EACH ROW
EXECUTE FUNCTION public.sync_dinein_venue_access_phone();

CREATE UNIQUE INDEX IF NOT EXISTS uq_dinein_venues_normalized_access_phone_active
  ON public.dinein_venues (normalized_access_phone)
  WHERE normalized_access_phone IS NOT NULL
    AND status <> 'deleted';
