-- DineIn: allow venue push registrations from the web PWA.

ALTER TABLE public.dinein_push_registrations
  DROP CONSTRAINT IF EXISTS dinein_push_registrations_platform_check;

ALTER TABLE public.dinein_push_registrations
  ADD CONSTRAINT dinein_push_registrations_platform_check
  CHECK (platform IN ('android', 'ios', 'web'));
