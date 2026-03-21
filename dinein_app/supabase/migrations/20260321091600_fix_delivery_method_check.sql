-- Fix: add 'test_override' to delivery_method CHECK constraint.
-- The whatsapp-otp edge function writes 'test_override' for closed testing,
-- but the original migration only allowed (template, text, mock).

ALTER TABLE public.venue_whatsapp_otp_challenges
  DROP CONSTRAINT IF EXISTS venue_whatsapp_otp_challenges_delivery_method_check;

ALTER TABLE public.venue_whatsapp_otp_challenges
  ADD CONSTRAINT venue_whatsapp_otp_challenges_delivery_method_check
  CHECK (delivery_method IN ('pending', 'sent', 'failed', 'template', 'text', 'mock', 'test_override'));
