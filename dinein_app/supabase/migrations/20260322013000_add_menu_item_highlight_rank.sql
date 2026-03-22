ALTER TABLE dinein_menu_items
ADD COLUMN IF NOT EXISTS highlight_rank INTEGER;

ALTER TABLE dinein_menu_items
DROP CONSTRAINT IF EXISTS dinein_menu_items_highlight_rank_check;

ALTER TABLE dinein_menu_items
ADD CONSTRAINT dinein_menu_items_highlight_rank_check
CHECK (highlight_rank IS NULL OR highlight_rank BETWEEN 1 AND 3);

CREATE UNIQUE INDEX IF NOT EXISTS idx_dinein_menu_items_venue_highlight_rank
  ON dinein_menu_items (venue_id, highlight_rank)
  WHERE highlight_rank IS NOT NULL;
