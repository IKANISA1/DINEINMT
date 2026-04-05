-- Add missing columns directly from Edge Function payloads
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='dinein_venues' AND column_name='owner_contact_phone') THEN
    ALTER TABLE public.dinein_venues ADD COLUMN owner_contact_phone TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='dinein_venues' AND column_name='owner_whatsapp_number') THEN
    ALTER TABLE public.dinein_venues ADD COLUMN owner_whatsapp_number TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='dinein_venues' AND column_name='normalized_access_phone') THEN
    ALTER TABLE public.dinein_venues ADD COLUMN normalized_access_phone TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='dinein_venues' AND column_name='revolut_url') THEN
    ALTER TABLE public.dinein_venues ADD COLUMN revolut_url TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='dinein_venues' AND column_name='website_url') THEN
    ALTER TABLE public.dinein_venues ADD COLUMN website_url TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='dinein_venues' AND column_name='reservation_url') THEN
    ALTER TABLE public.dinein_venues ADD COLUMN reservation_url TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='dinein_venues' AND column_name='wifi_ssid') THEN
    ALTER TABLE public.dinein_venues ADD COLUMN wifi_ssid TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='dinein_venues' AND column_name='wifi_password') THEN
    ALTER TABLE public.dinein_venues ADD COLUMN wifi_password TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='dinein_venues' AND column_name='wifi_security') THEN
    ALTER TABLE public.dinein_venues ADD COLUMN wifi_security TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='dinein_venues' AND column_name='supported_payment_methods') THEN
    ALTER TABLE public.dinein_venues ADD COLUMN supported_payment_methods JSONB DEFAULT '["cash"]'::jsonb;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='dinein_venues' AND column_name='ordering_enabled') THEN
    ALTER TABLE public.dinein_venues ADD COLUMN ordering_enabled BOOLEAN DEFAULT true;
  END IF;
END $$;