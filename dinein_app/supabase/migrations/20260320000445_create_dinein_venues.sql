
-- DineIn: Venues
CREATE TABLE IF NOT EXISTS dinein_venues (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  category TEXT NOT NULL DEFAULT 'restaurant',
  description TEXT NOT NULL DEFAULT '',
  address TEXT NOT NULL DEFAULT '',
  phone TEXT,
  email TEXT,
  image_url TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'pending_claim', 'pending_activation')),
  rating NUMERIC(3,2) NOT NULL DEFAULT 0.00,
  rating_count INTEGER NOT NULL DEFAULT 0,
  country TEXT NOT NULL DEFAULT 'MT' CHECK (country IN ('MT', 'RW')),
  opening_hours JSONB,
  owner_id UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX idx_dinein_venues_slug ON dinein_venues(slug);
CREATE INDEX idx_dinein_venues_status ON dinein_venues(status);
CREATE INDEX idx_dinein_venues_country ON dinein_venues(country);
CREATE INDEX idx_dinein_venues_owner ON dinein_venues(owner_id);

-- RLS
ALTER TABLE dinein_venues ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read active venues"
  ON dinein_venues FOR SELECT
  USING (status = 'active');

CREATE POLICY "Venue owners can read own venue"
  ON dinein_venues FOR SELECT
  USING (owner_id = auth.uid());

CREATE POLICY "Venue owners can update own venue"
  ON dinein_venues FOR UPDATE
  USING (owner_id = auth.uid());

CREATE POLICY "Admins can read all venues"
  ON dinein_venues FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM dinein_profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Admins can update all venues"
  ON dinein_venues FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM dinein_profiles WHERE id = auth.uid() AND role = 'admin')
  );
;
