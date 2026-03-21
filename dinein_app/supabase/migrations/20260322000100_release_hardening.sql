ALTER TABLE public.dinein_venues
  ADD COLUMN IF NOT EXISTS revolut_url TEXT;

DROP POLICY IF EXISTS "Authenticated users can upload menu files" ON storage.objects;
DROP POLICY IF EXISTS "Service role can read menu uploads" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own uploads" ON storage.objects;

DROP POLICY IF EXISTS "Anyone can insert bell requests" ON public.bell_requests;
DROP POLICY IF EXISTS "Venue owners can read venue bell requests" ON public.bell_requests;
DROP POLICY IF EXISTS "Venue owners can update venue bell requests" ON public.bell_requests;
DROP POLICY IF EXISTS "Admins can read all bell requests" ON public.bell_requests;
