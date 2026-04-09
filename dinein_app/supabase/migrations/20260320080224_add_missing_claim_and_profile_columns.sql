-- Add email column to dinein_profiles
ALTER TABLE dinein_profiles ADD COLUMN IF NOT EXISTS email text;

-- Fix guest order insertion: allow anonymous orders
DROP POLICY IF EXISTS "Customers can insert orders" ON dinein_orders;
CREATE POLICY "Anyone can insert orders" ON dinein_orders FOR INSERT WITH CHECK (true);;
