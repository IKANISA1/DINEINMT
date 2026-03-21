-- Backfill venues left in a non-live state after claim approval.
WITH latest_approved_claim AS (
  SELECT DISTINCT ON (venue_id)
    venue_id,
    claimant_id
  FROM public.dinein_venue_claims
  WHERE status = 'approved'
  ORDER BY venue_id, COALESCE(reviewed_at, created_at) DESC
)
UPDATE public.dinein_venues AS venue
SET
  status = 'active',
  owner_id = COALESCE(claim.claimant_id, venue.owner_id)
FROM latest_approved_claim AS claim
WHERE venue.id = claim.venue_id
  AND venue.status IN ('pending_claim', 'pending_activation');
