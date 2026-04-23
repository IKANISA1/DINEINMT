-- Align RW orders table with MT dinein_orders schema.
-- RW has `orders` base table with legacy columns exposed via `dinein_orders` view.
-- MT has `dinein_orders` as a base table with the standard schema.
--
-- This migration was applied to RW Supabase on 2026-04-06.
-- It is NOT needed for MT (already has the correct schema).

BEGIN;

-- 1. Drop the RW compatibility view only when the RW base table exists.
DO $$
BEGIN
  IF to_regclass('public.orders') IS NOT NULL
     AND EXISTS (
       SELECT 1
       FROM pg_class c
       JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE n.nspname = 'public'
         AND c.relname = 'dinein_orders'
         AND c.relkind = 'v'
     ) THEN
    EXECUTE 'DROP VIEW public.dinein_orders';
  END IF;
END;
$$;

-- 2. Convert enum columns to TEXT (legacy RW used order_status, payment_method, payment_status enums)
ALTER TABLE IF EXISTS public.orders ALTER COLUMN status TYPE TEXT USING status::TEXT;
ALTER TABLE IF EXISTS public.orders ALTER COLUMN payment_method TYPE TEXT USING payment_method::TEXT;
ALTER TABLE IF EXISTS public.orders ALTER COLUMN payment_status TYPE TEXT USING payment_status::TEXT;

-- 3. Add missing columns required by the edge function
ALTER TABLE IF EXISTS public.orders ADD COLUMN IF NOT EXISTS venue_name TEXT;
ALTER TABLE IF EXISTS public.orders ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE IF EXISTS public.orders ADD COLUMN IF NOT EXISTS user_name TEXT;
ALTER TABLE IF EXISTS public.orders ADD COLUMN IF NOT EXISTS items JSONB DEFAULT '[]'::jsonb;
ALTER TABLE IF EXISTS public.orders ADD COLUMN IF NOT EXISTS table_number TEXT;
ALTER TABLE IF EXISTS public.orders ADD COLUMN IF NOT EXISTS special_requests TEXT;
ALTER TABLE IF EXISTS public.orders ADD COLUMN IF NOT EXISTS guest_receipt_token TEXT;
ALTER TABLE IF EXISTS public.orders ADD COLUMN IF NOT EXISTS service_fee NUMERIC DEFAULT 0;

-- 4. Relax legacy NOT NULL constraints that clash with the edge function schema
ALTER TABLE IF EXISTS public.orders ALTER COLUMN client_auth_user_id DROP NOT NULL;
ALTER TABLE IF EXISTS public.orders ALTER COLUMN order_code DROP NOT NULL;
ALTER TABLE IF EXISTS public.orders ALTER COLUMN currency DROP NOT NULL;
ALTER TABLE IF EXISTS public.orders ALTER COLUMN currency_code DROP NOT NULL;
ALTER TABLE IF EXISTS public.orders ALTER COLUMN guest_session_id DROP NOT NULL;
ALTER TABLE IF EXISTS public.orders ALTER COLUMN subtotal_amount DROP NOT NULL;
ALTER TABLE IF EXISTS public.orders ALTER COLUMN tax_amount DROP NOT NULL;
ALTER TABLE IF EXISTS public.orders ALTER COLUMN tip_amount DROP NOT NULL;
ALTER TABLE IF EXISTS public.orders ALTER COLUMN total_amount DROP NOT NULL;
ALTER TABLE IF EXISTS public.orders ALTER COLUMN status_changed_at DROP NOT NULL;

-- 5. Fix defaults from enum casts to plain text
ALTER TABLE IF EXISTS public.orders ALTER COLUMN status SET DEFAULT 'placed';
ALTER TABLE IF EXISTS public.orders ALTER COLUMN payment_method SET DEFAULT 'cash';
ALTER TABLE IF EXISTS public.orders ALTER COLUMN payment_status SET DEFAULT 'pending';

-- 6. Recreate the RW compatibility view only when the RW base table exists.
DO $$
BEGIN
  IF to_regclass('public.orders') IS NOT NULL THEN
    EXECUTE $view$
      CREATE OR REPLACE VIEW public.dinein_orders AS
      SELECT
        id,
        venue_id,
        venue_name,
        user_id,
        user_name,
        items,
        total,
        subtotal,
        service_fee,
        status,
        payment_method,
        payment_status,
        table_number,
        special_requests,
        guest_receipt_token,
        order_number,
        created_at,
        updated_at
      FROM public.orders
    $view$;
  END IF;
END;
$$;

COMMIT;
