-- Cleanup Legacy SMS Subsystem (M-Money Parsing)
-- Drops tables, views, and functions introduced during a retired legacy phase.
-- This does NOT remove MoMo USSD (which is a non-parsing UI-based handoff).

BEGIN;

-- Drop functions first (CASCADE will handle triggers/defaults if any, but we specify them explicitly)
DROP FUNCTION IF EXISTS public.ingest_sms CASCADE;
DROP FUNCTION IF EXISTS public.parse_momo_sms CASCADE;
DROP FUNCTION IF EXISTS public.compute_sms_hash CASCADE;
DROP FUNCTION IF EXISTS public.compute_txn_fingerprint CASCADE;
DROP FUNCTION IF EXISTS public.parse_sms_deterministic CASCADE;
DROP FUNCTION IF EXISTS public.parse_sms_batch CASCADE;
DROP FUNCTION IF EXISTS public.mark_sms_ignored CASCADE;
DROP FUNCTION IF EXISTS public.resolve_sms_error CASCADE;
DROP FUNCTION IF EXISTS public.retry_parse_sms CASCADE;
DROP FUNCTION IF EXISTS public.register_sms_source CASCADE;
DROP FUNCTION IF EXISTS public.deactivate_sms_source CASCADE;
DROP FUNCTION IF EXISTS public.generate_device_key CASCADE;
DROP FUNCTION IF EXISTS public._sync_device_status CASCADE;
DROP FUNCTION IF EXISTS public._touch_device_last_sms CASCADE;

-- Drop tables
DROP TABLE IF EXISTS public.sms_parse_attempts CASCADE;
DROP TABLE IF EXISTS public.sms_gateway_devices CASCADE;
DROP TABLE IF EXISTS public.sms_sources CASCADE;
DROP TABLE IF EXISTS public.momo_sms_raw CASCADE;
DROP TABLE IF EXISTS public.sms_messages CASCADE;
DROP TABLE IF EXISTS public.incoming_payments CASCADE;

COMMIT;
