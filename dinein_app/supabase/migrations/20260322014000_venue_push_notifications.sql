-- DineIn: venue push notifications

CREATE TABLE IF NOT EXISTS public.dinein_venue_notification_settings (
  venue_id UUID PRIMARY KEY REFERENCES public.dinein_venues(id) ON DELETE CASCADE,
  order_push_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  whatsapp_updates_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.dinein_venue_notification_settings ENABLE ROW LEVEL SECURITY;

DROP TRIGGER IF EXISTS set_dinein_venue_notification_settings_updated_at
  ON public.dinein_venue_notification_settings;
CREATE TRIGGER set_dinein_venue_notification_settings_updated_at
BEFORE UPDATE ON public.dinein_venue_notification_settings
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE IF NOT EXISTS public.dinein_push_registrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  venue_id UUID NOT NULL REFERENCES public.dinein_venues(id) ON DELETE CASCADE,
  contact_phone TEXT,
  device_key TEXT NOT NULL,
  push_token TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
  provider TEXT NOT NULL DEFAULT 'fcm' CHECK (provider = 'fcm'),
  notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  app_version TEXT,
  locale TEXT,
  time_zone TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.dinein_push_registrations ENABLE ROW LEVEL SECURITY;

DROP TRIGGER IF EXISTS set_dinein_push_registrations_updated_at
  ON public.dinein_push_registrations;
CREATE TRIGGER set_dinein_push_registrations_updated_at
BEFORE UPDATE ON public.dinein_push_registrations
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE UNIQUE INDEX IF NOT EXISTS idx_dinein_push_registrations_venue_device
  ON public.dinein_push_registrations (venue_id, device_key);

CREATE UNIQUE INDEX IF NOT EXISTS idx_dinein_push_registrations_token
  ON public.dinein_push_registrations (push_token);

CREATE INDEX IF NOT EXISTS idx_dinein_push_registrations_venue_seen
  ON public.dinein_push_registrations (venue_id, last_seen_at DESC);
