ALTER TABLE public.dinein_venues
  ADD COLUMN IF NOT EXISTS ordering_enabled BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN public.dinein_venues.ordering_enabled IS
  'Whether guests can place orders for this venue. Public visibility remains controlled separately.';

UPDATE public.dinein_venues AS venue
SET ordering_enabled = TRUE
WHERE venue.owner_id IS NOT NULL
   OR EXISTS (
        SELECT 1
        FROM public.dinein_venue_claims AS claim
        WHERE claim.venue_id = venue.id
          AND claim.status = 'approved'
      );

CREATE INDEX IF NOT EXISTS idx_dinein_venues_ordering_enabled
  ON public.dinein_venues (ordering_enabled, status);
