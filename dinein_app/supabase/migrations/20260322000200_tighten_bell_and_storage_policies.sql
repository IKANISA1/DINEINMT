-- Release hardening: tighten bell_requests and menu-uploads policies
-- Rollback: recreate original open policies

-- ═══ 1. Bell Requests INSERT: require venue is active ═══
DROP POLICY IF EXISTS "Anyone can insert bell requests" ON bell_requests;
CREATE POLICY "Insert bell requests for active venues"
  ON bell_requests FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM dinein_venues
      WHERE id = venue_id AND status = 'active'
    )
  );

-- ═══ 2. Menu-uploads storage: tighten SELECT to service-role only ═══
-- Service role bypasses RLS, so removing the too-broad SELECT policy
-- that granted read access to all authenticated users.
DROP POLICY IF EXISTS "Service role can read menu uploads" ON storage.objects;
-- No replacement needed: service_role always bypasses RLS.
