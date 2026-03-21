-- Backfill: activate venues that have approved claims but were left in a
-- non-active state due to the bug where approve_claim didn't activate the venue.
UPDATE dinein_venues v
SET status = 'active'
FROM dinein_venue_claims c
WHERE c.venue_id = v.id
  AND c.status = 'approved'
  AND v.status IN ('pending_activation', 'pending_claim')
  AND v.owner_id IS NOT NULL;
