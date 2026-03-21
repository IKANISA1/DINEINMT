CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.venue_whatsapp_otp_challenges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id UUID NOT NULL DEFAULT gen_random_uuid(),
  whatsapp_number TEXT NOT NULL,
  normalized_whatsapp_number TEXT GENERATED ALWAYS AS (
    regexp_replace(whatsapp_number, '[^0-9]', '', 'g')
  ) STORED,
  app_scope TEXT NOT NULL DEFAULT 'venue'
    CHECK (app_scope IN ('venue', 'admin', 'guest')),
  otp_hash TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  consumed_at TIMESTAMPTZ,
  attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  max_attempts INTEGER NOT NULL DEFAULT 5 CHECK (max_attempts > 0),
  delivery_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (delivery_status IN ('pending', 'sent', 'failed')),
  delivery_method TEXT NOT NULL DEFAULT 'template'
    CHECK (delivery_method IN ('template', 'text', 'mock')),
  wa_message_id TEXT,
  failure_reason TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (challenge_id)
);

CREATE INDEX IF NOT EXISTS idx_venue_whatsapp_otp_number_scope_created
  ON public.venue_whatsapp_otp_challenges (
    normalized_whatsapp_number,
    app_scope,
    created_at DESC
  );

CREATE INDEX IF NOT EXISTS idx_venue_whatsapp_otp_active
  ON public.venue_whatsapp_otp_challenges (
    normalized_whatsapp_number,
    app_scope,
    expires_at
  )
  WHERE consumed_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_venue_whatsapp_otp_message_id
  ON public.venue_whatsapp_otp_challenges (wa_message_id)
  WHERE wa_message_id IS NOT NULL;

COMMENT ON TABLE public.venue_whatsapp_otp_challenges IS
  'Ephemeral WhatsApp OTP challenges for DineIn venue access.';

CREATE OR REPLACE FUNCTION public.set_venue_whatsapp_otp_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_venue_whatsapp_otp_updated_at
  ON public.venue_whatsapp_otp_challenges;

CREATE TRIGGER trg_venue_whatsapp_otp_updated_at
  BEFORE UPDATE ON public.venue_whatsapp_otp_challenges
  FOR EACH ROW
  EXECUTE FUNCTION public.set_venue_whatsapp_otp_updated_at();

CREATE OR REPLACE FUNCTION public.cleanup_venue_whatsapp_otp_challenges()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  deleted_count INTEGER := 0;
BEGIN
  DELETE FROM public.venue_whatsapp_otp_challenges
  WHERE created_at < now() - interval '7 days';

  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$;

ALTER TABLE public.venue_whatsapp_otp_challenges ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.venue_whatsapp_otp_challenges FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.venue_whatsapp_otp_challenges
  TO service_role;

GRANT EXECUTE ON FUNCTION public.cleanup_venue_whatsapp_otp_challenges()
  TO service_role;
