
-- DineIn: Orders
CREATE TABLE IF NOT EXISTS dinein_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  venue_id UUID NOT NULL REFERENCES dinein_venues(id),
  venue_name TEXT NOT NULL,
  user_id UUID REFERENCES auth.users(id),
  user_name TEXT,
  items JSONB NOT NULL DEFAULT '[]',
  total NUMERIC(10,2) NOT NULL,
  status TEXT NOT NULL DEFAULT 'placed' CHECK (status IN ('placed', 'received', 'served', 'cancelled')),
  payment_method TEXT NOT NULL DEFAULT 'cash' CHECK (payment_method IN ('cash', 'momo_ussd', 'revolut_link')),
  table_number TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX idx_dinein_orders_venue ON dinein_orders(venue_id);
CREATE INDEX idx_dinein_orders_user ON dinein_orders(user_id);
CREATE INDEX idx_dinein_orders_status ON dinein_orders(status);
CREATE INDEX idx_dinein_orders_created ON dinein_orders(created_at DESC);

-- RLS
ALTER TABLE dinein_orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Customers can insert orders"
  ON dinein_orders FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Customers can read own orders"
  ON dinein_orders FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Venue owners can read venue orders"
  ON dinein_orders FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM dinein_venues WHERE id = venue_id AND owner_id = auth.uid())
  );

CREATE POLICY "Venue owners can update venue order status"
  ON dinein_orders FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM dinein_venues WHERE id = venue_id AND owner_id = auth.uid())
  );

CREATE POLICY "Admins can read all orders"
  ON dinein_orders FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM dinein_profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Enable realtime for order status tracking
ALTER PUBLICATION supabase_realtime ADD TABLE dinein_orders;
;
