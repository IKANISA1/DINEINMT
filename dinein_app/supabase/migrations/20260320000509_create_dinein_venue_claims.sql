
-- DineIn: Venue claims
CREATE TABLE IF NOT EXISTS dinein_venue_claims (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  venue_id UUID NOT NULL REFERENCES dinein_venues(id),
  claimant_id UUID REFERENCES auth.users(id),
  email TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  reviewed_at TIMESTAMPTZ,
  reviewed_by UUID REFERENCES auth.users(id)
);

-- Indexes
CREATE INDEX idx_dinein_claims_venue ON dinein_venue_claims(venue_id);
CREATE INDEX idx_dinein_claims_status ON dinein_venue_claims(status);

-- RLS
ALTER TABLE dinein_venue_claims ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can submit claims"
  ON dinein_venue_claims FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Users can read own claims"
  ON dinein_venue_claims FOR SELECT
  USING (claimant_id = auth.uid());

CREATE POLICY "Admins can read all claims"
  ON dinein_venue_claims FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM dinein_profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Admins can update claims"
  ON dinein_venue_claims FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM dinein_profiles WHERE id = auth.uid() AND role = 'admin')
  );
;
