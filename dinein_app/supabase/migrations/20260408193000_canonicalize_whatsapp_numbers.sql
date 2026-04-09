BEGIN;

CREATE OR REPLACE FUNCTION public.normalize_whatsapp_e164(
  raw text,
  default_country_code text DEFAULT NULL
)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  trimmed text := btrim(coalesce(raw, ''));
  digits text := regexp_replace(trimmed, '[^0-9]', '', 'g');
  resolved_default text := regexp_replace(
    coalesce(default_country_code, ''),
    '[^0-9]',
    '',
    'g'
  );
  candidate text := NULL;
BEGIN
  IF trimmed = '' OR digits = '' THEN
    RETURN NULL;
  END IF;

  IF left(trimmed, 1) = '+' THEN
    candidate := digits;
  ELSIF left(trimmed, 2) = '00' THEN
    candidate := substr(digits, 3);
  ELSIF resolved_default = '250' AND digits ~ '^0?[0-9]{9}$' THEN
    candidate := '250' || regexp_replace(digits, '^0', '');
  ELSIF resolved_default = '356' AND digits ~ '^0?[0-9]{8}$' THEN
    candidate := '356' || regexp_replace(digits, '^0', '');
  ELSIF length(digits) BETWEEN 10 AND 15 THEN
    candidate := digits;
  ELSE
    RETURN NULL;
  END IF;

  IF candidate ~ '^2500[0-9]{9}$' THEN
    candidate := '250' || substr(candidate, 5);
  ELSIF candidate ~ '^3560[0-9]{8}$' THEN
    candidate := '356' || substr(candidate, 5);
  END IF;

  IF length(candidate) < 8 OR length(candidate) > 15 THEN
    RETURN NULL;
  END IF;

  RETURN '+' || candidate;
END;
$$;

DO $$
DECLARE
  access_phone_conflicts text;
BEGIN
  SELECT string_agg(
    format('%s => %s', normalized_phone, venue_ids),
    '; ' ORDER BY normalized_phone
  )
  INTO access_phone_conflicts
  FROM (
    SELECT
      public.normalize_whatsapp_e164(
        phone,
        CASE WHEN country = 'RW' THEN '250' ELSE '356' END
      ) AS normalized_phone,
      string_agg(id::text, ', ' ORDER BY id::text) AS venue_ids
    FROM public.dinein_venues
    WHERE status <> 'deleted'
      AND NULLIF(BTRIM(phone), '') IS NOT NULL
    GROUP BY 1
    HAVING public.normalize_whatsapp_e164(
      phone,
      CASE WHEN country = 'RW' THEN '250' ELSE '356' END
    ) IS NOT NULL
      AND count(*) > 1
  ) conflicts;

  IF access_phone_conflicts IS NOT NULL THEN
    RAISE NOTICE
      'Skipping canonical venue phone writes for colliding access numbers: %',
      access_phone_conflicts;
  END IF;
END $$;

DO $$
DECLARE
  venue_conflicts text;
BEGIN
  SELECT string_agg(
    format('%s => %s', normalized_phone, venue_ids),
    '; ' ORDER BY normalized_phone
  )
  INTO venue_conflicts
  FROM (
    SELECT
      public.normalize_whatsapp_e164(
        owner_whatsapp_number,
        CASE WHEN country = 'RW' THEN '250' ELSE '356' END
      ) AS normalized_phone,
      string_agg(id::text, ', ' ORDER BY id::text) AS venue_ids
    FROM public.dinein_venues
    WHERE status <> 'deleted'
      AND NULLIF(BTRIM(owner_whatsapp_number), '') IS NOT NULL
    GROUP BY 1
    HAVING public.normalize_whatsapp_e164(
      owner_whatsapp_number,
      CASE WHEN country = 'RW' THEN '250' ELSE '356' END
    ) IS NOT NULL
      AND count(*) > 1
  ) conflicts;

  IF venue_conflicts IS NOT NULL THEN
    RAISE EXCEPTION
      'Canonical venue WhatsApp numbers collide after normalization.'
      USING DETAIL = venue_conflicts;
  END IF;
END $$;

DO $$
DECLARE
  admin_conflicts text;
BEGIN
  SELECT string_agg(
    format('%s => %s', normalized_phone, profile_ids),
    '; ' ORDER BY normalized_phone
  )
  INTO admin_conflicts
  FROM (
    SELECT
      public.normalize_whatsapp_e164(
        whatsapp_number,
        CASE
          WHEN regexp_replace(coalesce(whatsapp_number, ''), '[^0-9]', '', 'g')
            ~ '^0?[0-9]{8}$' THEN '356'
          WHEN regexp_replace(coalesce(whatsapp_number, ''), '[^0-9]', '', 'g')
            ~ '^0?[0-9]{9}$' THEN '250'
          ELSE NULL
        END
      ) AS normalized_phone,
      string_agg(id::text, ', ' ORDER BY id::text) AS profile_ids
    FROM public.dinein_profiles
    WHERE role = 'admin'
      AND NULLIF(BTRIM(whatsapp_number), '') IS NOT NULL
    GROUP BY 1
    HAVING public.normalize_whatsapp_e164(
      whatsapp_number,
      CASE
        WHEN regexp_replace(coalesce(whatsapp_number, ''), '[^0-9]', '', 'g')
          ~ '^0?[0-9]{8}$' THEN '356'
        WHEN regexp_replace(coalesce(whatsapp_number, ''), '[^0-9]', '', 'g')
          ~ '^0?[0-9]{9}$' THEN '250'
        ELSE NULL
      END
    ) IS NOT NULL
      AND count(*) > 1
  ) conflicts;

  IF admin_conflicts IS NOT NULL THEN
    RAISE EXCEPTION
      'Canonical admin WhatsApp numbers collide after normalization.'
      USING DETAIL = admin_conflicts;
  END IF;
END $$;

UPDATE public.dinein_venues
SET phone = normalized.normalized_phone
FROM (
  SELECT
    id,
    normalized_phone
  FROM (
    SELECT
      id,
      public.normalize_whatsapp_e164(
        phone,
        CASE WHEN country = 'RW' THEN '250' ELSE '356' END
      ) AS normalized_phone,
      count(*) OVER (
        PARTITION BY public.normalize_whatsapp_e164(
          phone,
          CASE WHEN country = 'RW' THEN '250' ELSE '356' END
        )
      ) AS normalized_phone_count
    FROM public.dinein_venues
    WHERE status <> 'deleted'
  ) candidates
  WHERE normalized_phone IS NOT NULL
    AND normalized_phone_count = 1
) normalized
WHERE public.dinein_venues.id = normalized.id
  AND normalized.normalized_phone IS NOT NULL
  AND public.dinein_venues.phone IS DISTINCT FROM normalized.normalized_phone;

UPDATE public.dinein_venues
SET owner_whatsapp_number = normalized.normalized_phone
FROM (
  SELECT
    id,
    public.normalize_whatsapp_e164(
      owner_whatsapp_number,
      CASE WHEN country = 'RW' THEN '250' ELSE '356' END
    ) AS normalized_phone
  FROM public.dinein_venues
) normalized
WHERE public.dinein_venues.id = normalized.id
  AND normalized.normalized_phone IS NOT NULL
  AND public.dinein_venues.owner_whatsapp_number IS DISTINCT FROM normalized.normalized_phone;

UPDATE public.dinein_profiles
SET whatsapp_number = normalized.normalized_phone
FROM (
  SELECT
    id,
    public.normalize_whatsapp_e164(
      whatsapp_number,
      CASE
        WHEN regexp_replace(coalesce(whatsapp_number, ''), '[^0-9]', '', 'g')
          ~ '^0?[0-9]{8}$' THEN '356'
        WHEN regexp_replace(coalesce(whatsapp_number, ''), '[^0-9]', '', 'g')
          ~ '^0?[0-9]{9}$' THEN '250'
        ELSE NULL
      END
    ) AS normalized_phone
  FROM public.dinein_profiles
) normalized
WHERE public.dinein_profiles.id = normalized.id
  AND normalized.normalized_phone IS NOT NULL
  AND public.dinein_profiles.whatsapp_number IS DISTINCT FROM normalized.normalized_phone;

DROP INDEX IF EXISTS public.uq_dinein_profiles_admin_whatsapp_number;
CREATE UNIQUE INDEX IF NOT EXISTS uq_dinein_profiles_admin_whatsapp_number
  ON public.dinein_profiles (
    public.normalize_whatsapp_e164(
      whatsapp_number,
      CASE
        WHEN regexp_replace(coalesce(whatsapp_number, ''), '[^0-9]', '', 'g')
          ~ '^0?[0-9]{8}$' THEN '356'
        WHEN regexp_replace(coalesce(whatsapp_number, ''), '[^0-9]', '', 'g')
          ~ '^0?[0-9]{9}$' THEN '250'
        ELSE NULL
      END
    )
  )
  WHERE role = 'admin'
    AND whatsapp_number IS NOT NULL
    AND NULLIF(BTRIM(whatsapp_number), '') IS NOT NULL;

DROP INDEX IF EXISTS public.uq_dinein_venues_owner_whatsapp_number_active;
CREATE UNIQUE INDEX IF NOT EXISTS uq_dinein_venues_owner_whatsapp_number_active
  ON public.dinein_venues (
    public.normalize_whatsapp_e164(
      owner_whatsapp_number,
      CASE WHEN country = 'RW' THEN '250' ELSE '356' END
    )
  )
  WHERE owner_whatsapp_number IS NOT NULL
    AND NULLIF(BTRIM(owner_whatsapp_number), '') IS NOT NULL
    AND status <> 'deleted';

COMMENT ON FUNCTION public.normalize_whatsapp_e164(text, text) IS
  'Canonicalizes Malta and Rwanda WhatsApp numbers to E.164, stripping legacy trunk zeros after the country code.';

COMMIT;
