-- DineIn: Bell Requests
CREATE TABLE IF NOT EXISTS bell_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  venue_id UUID NOT NULL REFERENCES dinein_venues(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id),
  table_number TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'resolved')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at TIMESTAMPTZ
);

-- Indexes
CREATE INDEX idx_bell_requests_venue ON bell_requests(venue_id);
CREATE INDEX idx_bell_requests_status ON bell_requests(status);
CREATE INDEX idx_bell_requests_created ON bell_requests(created_at DESC);

-- RLS
ALTER TABLE bell_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can insert bell requests"
  ON bell_requests FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Venue owners can read venue bell requests"
  ON bell_requests FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM dinein_venues WHERE id = venue_id AND owner_id = auth.uid())
  );

CREATE POLICY "Venue owners can update venue bell requests"
  ON bell_requests FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM dinein_venues WHERE id = venue_id AND owner_id = auth.uid())
  );

CREATE POLICY "Admins can read all bell requests"
  ON bell_requests FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM dinein_profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Enable realtime for bell requests
ALTER PUBLICATION supabase_realtime ADD TABLE bell_requests;
