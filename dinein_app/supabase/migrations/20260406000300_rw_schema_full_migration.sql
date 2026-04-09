-- Full Schema Alignment for Rwanda
-- Replaces old ALIAS VIEWS with the fully renamed base tables to match Malta exactly.
-- Wrapped in DO blocks to ensure idempotency.

BEGIN;

-- 1. Profiles
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_views WHERE viewname = 'dinein_profiles' AND schemaname = 'public') THEN
    DROP VIEW public.dinein_profiles CASCADE;
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'profiles' AND schemaname = 'public') AND 
     NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'dinein_profiles' AND schemaname = 'public') THEN
    ALTER TABLE public.profiles RENAME TO dinein_profiles;
  END IF;
END $$;

-- 2. Venues
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_views WHERE viewname = 'dinein_venues' AND schemaname = 'public') THEN
    DROP VIEW public.dinein_venues CASCADE;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'venues' AND schemaname = 'public') AND 
     NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'dinein_venues' AND schemaname = 'public') THEN
    ALTER TABLE public.venues RENAME TO dinein_venues;
  END IF;
END $$;

-- 3. Orders 
-- (Note: 20260406000200 modified the view, so it still exists as a view)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_views WHERE viewname = 'dinein_orders' AND schemaname = 'public') THEN
    DROP VIEW public.dinein_orders CASCADE;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'orders' AND schemaname = 'public') AND 
     NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'dinein_orders' AND schemaname = 'public') THEN
    ALTER TABLE public.orders RENAME TO dinein_orders;
  END IF;
END $$;

-- 4. Menu Items
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_views WHERE viewname = 'dinein_menu_items' AND schemaname = 'public') THEN
    DROP VIEW public.dinein_menu_items CASCADE;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'menu_items' AND schemaname = 'public') AND 
     NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'dinein_menu_items' AND schemaname = 'public') THEN
    ALTER TABLE public.menu_items RENAME TO dinein_menu_items;
  END IF;
END $$;

COMMIT;
