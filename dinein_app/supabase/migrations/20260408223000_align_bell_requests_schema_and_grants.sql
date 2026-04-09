BEGIN;

CREATE TABLE IF NOT EXISTS public.bell_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  venue_id UUID NOT NULL REFERENCES public.dinein_venues(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id),
  table_number TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at TIMESTAMPTZ
);

ALTER TABLE public.bell_requests
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS table_number TEXT,
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMPTZ;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'bell_requests'
      AND column_name = 'acknowledged_at'
  ) THEN
    EXECUTE $sql$
      UPDATE public.bell_requests
      SET resolved_at = COALESCE(resolved_at, acknowledged_at)
      WHERE resolved_at IS NULL
    $sql$;
  END IF;
END $$;

UPDATE public.bell_requests
SET status = CASE
  WHEN resolved_at IS NOT NULL THEN 'resolved'
  ELSE 'pending'
END
WHERE status IS NULL;

UPDATE public.bell_requests
SET table_number = COALESCE(table_number, 'legacy')
WHERE table_number IS NULL;

ALTER TABLE public.bell_requests
  ALTER COLUMN table_number SET NOT NULL,
  ALTER COLUMN status SET DEFAULT 'pending',
  ALTER COLUMN status SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'bell_requests_status_check'
      AND conrelid = 'public.bell_requests'::regclass
  ) THEN
    ALTER TABLE public.bell_requests
      ADD CONSTRAINT bell_requests_status_check
      CHECK (status IN ('pending', 'resolved'));
  END IF;
END $$;

ALTER TABLE public.bell_requests
  DROP COLUMN IF EXISTS table_id,
  DROP COLUMN IF EXISTS guest_session_id,
  DROP COLUMN IF EXISTS message,
  DROP COLUMN IF EXISTS acknowledged_at,
  DROP COLUMN IF EXISTS acknowledged_by;

CREATE INDEX IF NOT EXISTS idx_bell_requests_venue
  ON public.bell_requests(venue_id);
CREATE INDEX IF NOT EXISTS idx_bell_requests_status
  ON public.bell_requests(status);
CREATE INDEX IF NOT EXISTS idx_bell_requests_created
  ON public.bell_requests(created_at DESC);

ALTER TABLE public.bell_requests ENABLE ROW LEVEL SECURITY;

GRANT SELECT ON public.bell_requests TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.bell_requests TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.bell_requests TO service_role;

DROP POLICY IF EXISTS "Anyone can insert bell requests" ON public.bell_requests;
DROP POLICY IF EXISTS "Insert bell requests for active venues" ON public.bell_requests;
CREATE POLICY "Insert bell requests for active venues"
  ON public.bell_requests FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.dinein_venues
      WHERE id = venue_id
        AND status = 'active'
    )
  );

DROP POLICY IF EXISTS "Venue owners can read venue bell requests" ON public.bell_requests;
CREATE POLICY "Venue owners can read venue bell requests"
  ON public.bell_requests FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.dinein_venues
      WHERE id = venue_id
        AND owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Venue owners can update venue bell requests" ON public.bell_requests;
CREATE POLICY "Venue owners can update venue bell requests"
  ON public.bell_requests FOR UPDATE
  USING (
    EXISTS (
      SELECT 1
      FROM public.dinein_venues
      WHERE id = venue_id
        AND owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Admins can read all bell requests" ON public.bell_requests;
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'dinein_profiles'
  ) THEN
    EXECUTE $sql$
      CREATE POLICY "Admins can read all bell requests"
        ON public.bell_requests FOR SELECT
        USING (
          EXISTS (
            SELECT 1
            FROM public.dinein_profiles
            WHERE id = auth.uid()
              AND role = 'admin'
          )
        )
    $sql$;
  ELSIF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'profiles'
  ) THEN
    EXECUTE $sql$
      CREATE POLICY "Admins can read all bell requests"
        ON public.bell_requests FOR SELECT
        USING (
          EXISTS (
            SELECT 1
            FROM public.profiles
            WHERE id = auth.uid()
              AND role = 'admin'
          )
        )
    $sql$;
  END IF;
END $$;

DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.bell_requests;
  EXCEPTION
    WHEN duplicate_object THEN NULL;
    WHEN invalid_object_definition THEN NULL;
  END;
END $$;

COMMIT;
