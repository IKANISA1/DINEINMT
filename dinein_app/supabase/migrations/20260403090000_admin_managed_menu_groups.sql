ALTER TABLE public.dinein_menu_items
  ADD COLUMN IF NOT EXISTS admin_group_id UUID,
  ADD COLUMN IF NOT EXISTS admin_managed BOOLEAN NOT NULL DEFAULT FALSE;

UPDATE public.dinein_menu_items
SET admin_managed = TRUE
WHERE admin_group_id IS NOT NULL;

ALTER TABLE public.dinein_menu_items
  DROP CONSTRAINT IF EXISTS dinein_menu_items_admin_group_consistency_check;

ALTER TABLE public.dinein_menu_items
  ADD CONSTRAINT dinein_menu_items_admin_group_consistency_check
  CHECK (
    (admin_group_id IS NULL AND admin_managed = FALSE) OR
    (admin_group_id IS NOT NULL AND admin_managed = TRUE)
  );

CREATE INDEX IF NOT EXISTS idx_dinein_menu_items_admin_group
  ON public.dinein_menu_items (admin_group_id)
  WHERE admin_group_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_dinein_menu_items_admin_group_venue
  ON public.dinein_menu_items (venue_id, admin_group_id)
  WHERE admin_group_id IS NOT NULL;

COMMENT ON COLUMN public.dinein_menu_items.admin_group_id IS
  'Shared admin-managed menu group identifier used to sync generic menu fields across assigned venues.';

COMMENT ON COLUMN public.dinein_menu_items.admin_managed IS
  'True when the menu item is managed centrally by admin and linked to an admin_group_id.';
