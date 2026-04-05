-- Computes per-item order popularity for a given venue.
-- Returns menu_item_id → total_quantity_ordered for served orders in the last 90 days.
-- Callable by anyone (anon/authenticated) since it only returns aggregate counts,
-- not sensitive order details.

CREATE OR REPLACE FUNCTION public.get_venue_item_popularity(p_venue_id UUID)
RETURNS TABLE (menu_item_id TEXT, total_ordered BIGINT)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT
    (item->>'menu_item_id')::TEXT AS menu_item_id,
    SUM((item->>'quantity')::BIGINT) AS total_ordered
  FROM
    dinein_orders,
    jsonb_array_elements(items) AS item
  WHERE
    venue_id = p_venue_id
    AND status = 'served'
    AND created_at > now() - interval '7 days'
  GROUP BY item->>'menu_item_id'
  HAVING SUM((item->>'quantity')::BIGINT) > 0
  ORDER BY total_ordered DESC;
$$;

-- Allow anon and authenticated users to call this function.
GRANT EXECUTE ON FUNCTION public.get_venue_item_popularity(UUID) TO anon, authenticated;
