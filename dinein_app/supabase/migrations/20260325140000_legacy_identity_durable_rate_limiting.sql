-- Create a durable table for legacy identity rate limiting.
CREATE TABLE IF NOT EXISTS public.legacy_identity_rate_limit_buckets (
    subject_key text PRIMARY KEY,
    request_timestamps bigint[] DEFAULT '{}'::bigint[],
    updated_at timestamptz DEFAULT now()
);

-- Deny all access to anon and authenticated users; only service_role can access
ALTER TABLE public.legacy_identity_rate_limit_buckets ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.legacy_identity_rate_limit_buckets FROM anon, authenticated;
GRANT ALL ON public.legacy_identity_rate_limit_buckets TO service_role;

-- Index for cleanup of stale buckets
CREATE INDEX IF NOT EXISTS idx_legacy_identity_rate_limit_updated_at ON public.legacy_identity_rate_limit_buckets (updated_at);

COMMENT ON TABLE public.legacy_identity_rate_limit_buckets IS 'Durable bucket storage for legacy identity match rate limiting.';
