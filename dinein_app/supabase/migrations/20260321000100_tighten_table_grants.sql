-- F5a: Tighten direct table grants.
-- Orders and claims must go through the Edge Function only.
-- Venues and menu items remain publicly readable.

begin;

-- Revoke anon writes on orders (must go through handlePlaceOrder)
REVOKE INSERT, UPDATE, DELETE ON public.dinein_orders FROM anon;

-- Revoke anon writes on claims (must go through claim handlers)
REVOKE INSERT, UPDATE, DELETE ON public.dinein_venue_claims FROM anon;

-- Revoke anon mutation on venues (reads stay public)
REVOKE INSERT, UPDATE, DELETE ON public.dinein_venues FROM anon;

-- Revoke anon mutation on menu items (reads stay public)
REVOKE INSERT, UPDATE, DELETE ON public.dinein_menu_items FROM anon;

-- Keep authenticated users with SELECT only on sensitive tables
-- (writes go through edge functions which use service_role)
REVOKE INSERT, UPDATE, DELETE ON public.dinein_orders FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.dinein_venue_claims FROM authenticated;
REVOKE UPDATE, DELETE ON public.dinein_venues FROM authenticated;
REVOKE UPDATE, DELETE ON public.dinein_menu_items FROM authenticated;

-- Fix the overly permissive order insertion RLS policy
DROP POLICY IF EXISTS "Anyone can insert orders" ON public.dinein_orders;

-- Orders are inserted by the edge function using service_role,
-- so no direct insert policy is needed.

commit;
