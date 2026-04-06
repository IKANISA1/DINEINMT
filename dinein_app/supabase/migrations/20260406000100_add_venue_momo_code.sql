-- Add venue-level MoMo code for Rwanda venues
-- NOTE: On RW Supabase, `dinein_venues` is a VIEW over `venues` table
--       which already has momo_code. On MT, `dinein_venues` is a BASE TABLE.
-- This migration targets MT only (RW already has the column via venues table).

-- MT: dinein_venues is a base table
ALTER TABLE public.dinein_venues
  ADD COLUMN IF NOT EXISTS momo_code TEXT;

COMMENT ON COLUMN public.dinein_venues.momo_code IS
  'Venue-level MoMo receive number/merchant code (Rwanda only). Used for guest payment handoff.';
