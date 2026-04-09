-- Repair recursive admin policies and normalize venue statuses.

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
        'deleted'::TEXT
      ]
    )
  );
