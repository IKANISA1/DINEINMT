-- F2: Add checkout data columns to dinein_orders
-- Server computes total as sum of item prices; no service fee.

ALTER TABLE dinein_orders
  ADD COLUMN IF NOT EXISTS special_requests TEXT,
  ADD COLUMN IF NOT EXISTS guest_receipt_token TEXT;

-- Create index for receipt token lookup
CREATE INDEX IF NOT EXISTS idx_dinein_orders_receipt_token
  ON dinein_orders(guest_receipt_token)
  WHERE guest_receipt_token IS NOT NULL;
