-- Repair claim contact schema, recursive admin policies, and venue status drift.

CREATE OR REPLACE FUNCTION public.is_admin_user(user_id UUID DEFAULT NULL)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.dinein_profiles profile
    WHERE profile.id = COALESCE(user_id, auth.uid())
      AND profile.role = 'admin'
  );
$$;

REVOKE ALL ON FUNCTION public.is_admin_user(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin_user(UUID)
  TO anon, authenticated, service_role;

ALTER TABLE public.dinein_venue_claims
  ADD COLUMN IF NOT EXISTS contact_phone TEXT,
  ADD COLUMN IF NOT EXISTS whatsapp_number TEXT;

ALTER TABLE public.dinein_venue_claims
  ALTER COLUMN email DROP NOT NULL;

UPDATE public.dinein_venue_claims
SET
  contact_phone = COALESCE(contact_phone, email),
  whatsapp_number = COALESCE(whatsapp_number, email)
WHERE email IS NOT NULL
  AND POSITION('@' IN email) = 0;

CREATE INDEX IF NOT EXISTS idx_dinein_claims_contact_phone
  ON public.dinein_venue_claims (contact_phone);

CREATE INDEX IF NOT EXISTS idx_dinein_claims_whatsapp_number
  ON public.dinein_venue_claims (whatsapp_number);

DROP POLICY IF EXISTS "Authenticated users can submit claims"
  ON public.dinein_venue_claims;
DROP POLICY IF EXISTS "Anyone can submit claims"
  ON public.dinein_venue_claims;
CREATE POLICY "Anyone can submit claims"
  ON public.dinein_venue_claims FOR INSERT
  WITH CHECK (
    status = 'pending'
    AND reviewed_at IS NULL
    AND reviewed_by IS NULL
    AND COALESCE(
      NULLIF(BTRIM(contact_phone), ''),
      NULLIF(BTRIM(whatsapp_number), ''),
      NULLIF(BTRIM(email), '')
    ) IS NOT NULL
  );

DROP POLICY IF EXISTS "Admins can read all profiles"
  ON public.dinein_profiles;
CREATE POLICY "Admins can read all profiles"
  ON public.dinein_profiles FOR SELECT
  USING (public.is_admin_user());

DROP POLICY IF EXISTS "Admins can update all profiles"
  ON public.dinein_profiles;
CREATE POLICY "Admins can update all profiles"
  ON public.dinein_profiles FOR UPDATE
  USING (public.is_admin_user())
  WITH CHECK (public.is_admin_user());

DROP POLICY IF EXISTS "Admins can read all venues"
  ON public.dinein_venues;
CREATE POLICY "Admins can read all venues"
  ON public.dinein_venues FOR SELECT
  USING (public.is_admin_user());

DROP POLICY IF EXISTS "Admins can update all venues"
  ON public.dinein_venues;
CREATE POLICY "Admins can update all venues"
  ON public.dinein_venues FOR UPDATE
  USING (public.is_admin_user())
  WITH CHECK (public.is_admin_user());

DROP POLICY IF EXISTS "Admins can read all claims"
  ON public.dinein_venue_claims;
CREATE POLICY "Admins can read all claims"
  ON public.dinein_venue_claims FOR SELECT
  USING (public.is_admin_user());

DROP POLICY IF EXISTS "Admins can update claims"
  ON public.dinein_venue_claims;
CREATE POLICY "Admins can update claims"
  ON public.dinein_venue_claims FOR UPDATE
  USING (public.is_admin_user())
  WITH CHECK (public.is_admin_user());

DROP POLICY IF EXISTS "Admins can read all orders"
  ON public.dinein_orders;
CREATE POLICY "Admins can read all orders"
  ON public.dinein_orders FOR SELECT
  USING (public.is_admin_user());

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
        'deleted'::TEXT,
        'pending_claim'::TEXT,
        'pending_activation'::TEXT
      ]
    )
  );
