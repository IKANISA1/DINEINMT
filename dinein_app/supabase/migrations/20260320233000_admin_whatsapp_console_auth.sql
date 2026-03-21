-- Admin console WhatsApp OTP lookup support.
ALTER TABLE public.dinein_profiles
ADD COLUMN IF NOT EXISTS whatsapp_number TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS uq_dinein_profiles_admin_whatsapp_number
ON public.dinein_profiles (
  (regexp_replace(whatsapp_number, '[^0-9]', '', 'g'))
)
WHERE role = 'admin' AND whatsapp_number IS NOT NULL;

COMMENT ON COLUMN public.dinein_profiles.whatsapp_number IS
  'Canonical WhatsApp number used for venue/admin OTP login and operational contact.';
