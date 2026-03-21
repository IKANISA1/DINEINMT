
-- DineIn: Menu items
CREATE TABLE IF NOT EXISTS dinein_menu_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  venue_id UUID NOT NULL REFERENCES dinein_venues(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  price NUMERIC(10,2) NOT NULL,
  category TEXT NOT NULL DEFAULT 'Uncategorized',
  image_url TEXT,
  is_available BOOLEAN NOT NULL DEFAULT true,
  tags TEXT[] NOT NULL DEFAULT '{}',
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX idx_dinein_menu_items_venue ON dinein_menu_items(venue_id);
CREATE INDEX idx_dinein_menu_items_category ON dinein_menu_items(category);

-- RLS
ALTER TABLE dinein_menu_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read menu items"
  ON dinein_menu_items FOR SELECT
  USING (true);

CREATE POLICY "Venue owners can insert own menu items"
  ON dinein_menu_items FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM dinein_venues WHERE id = venue_id AND owner_id = auth.uid())
  );

CREATE POLICY "Venue owners can update own menu items"
  ON dinein_menu_items FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM dinein_venues WHERE id = venue_id AND owner_id = auth.uid())
  );

CREATE POLICY "Venue owners can delete own menu items"
  ON dinein_menu_items FOR DELETE
  USING (
    EXISTS (SELECT 1 FROM dinein_venues WHERE id = venue_id AND owner_id = auth.uid())
  );
;
