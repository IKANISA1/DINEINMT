-- Durable rate limiting for DineIn API actions (waves, Google Maps search).
-- Replaces in-memory Map-based buckets that reset on cold starts.
-- Pattern mirrors biopay_rate_limit_buckets.

CREATE TABLE IF NOT EXISTS public.dinein_rate_limit_buckets (
    subject_key text NOT NULL,
    action text NOT NULL,
    request_timestamps bigint[] DEFAULT '{}'::bigint[],
    updated_at timestamptz DEFAULT now(),
    PRIMARY KEY (subject_key, action)
);

-- Service-role only — no direct client access
ALTER TABLE public.dinein_rate_limit_buckets ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.dinein_rate_limit_buckets FROM anon, authenticated;
GRANT ALL ON public.dinein_rate_limit_buckets TO service_role;

-- Cleanup index for stale buckets
CREATE INDEX IF NOT EXISTS idx_dinein_rate_limit_updated_at
  ON public.dinein_rate_limit_buckets (updated_at);

COMMENT ON TABLE public.dinein_rate_limit_buckets IS
  'Durable bucket storage for DineIn rate limiting (waves, search). Service-role only.';
