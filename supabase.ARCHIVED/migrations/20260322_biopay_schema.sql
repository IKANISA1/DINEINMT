-- BioPay schema for Rwanda only
-- Requires pgvector extension for face-embedding similarity search.
-- All tables are RLS-enabled with NO direct client policies.
-- Access is exclusively via the biopay-api edge function using service role.

-- ─── pgvector ───────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS vector;

-- ─── USSD validation helper ────────────────────────────────
CREATE OR REPLACE FUNCTION public.validate_rw_ussd(raw text)
RETURNS text
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  normalized text;
BEGIN
  -- Strip spaces
  normalized := regexp_replace(raw, '\s', '', 'g');

  -- Rwanda MoMo USSD patterns:
  --   *182*8*1*AMOUNT#               (MTN MoMo pay)
  --   *182*1*RECIPIENT*AMOUNT#       (MTN MoMo transfer)
  --   *131*RECIPIENT*AMOUNT#         (Airtel Money)
  --   General USSD: *NNN*...*#
  IF normalized !~ '^\*\d{2,4}(\*[\d\w]+)*\*?#?$' THEN
    RAISE EXCEPTION 'Invalid Rwanda USSD pattern: %', normalized;
  END IF;

  -- Ensure it ends with #
  IF NOT normalized LIKE '%#' THEN
    normalized := normalized || '#';
  END IF;

  RETURN normalized;
END;
$$;

-- ─── biopay_profiles ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.biopay_profiles (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  biopay_id     text UNIQUE NOT NULL DEFAULT lpad(floor(random() * 1000000)::int::text, 6, '0'),
  display_name  text NOT NULL CHECK (length(display_name) BETWEEN 1 AND 100),
  ussd_string   text NOT NULL,
  ussd_normalized text NOT NULL,
  status        text NOT NULL DEFAULT 'active'
                  CHECK (status IN ('active','suspended','deleted')),
  consent_version text NOT NULL DEFAULT 'v1',
  consent_at    timestamptz NOT NULL DEFAULT now(),
  owner_token_version int NOT NULL DEFAULT 1,
  manage_code_hash text,  -- bcrypt hash of the one-time management code
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- Unique on normalized USSD to prevent duplicate registrations
CREATE UNIQUE INDEX IF NOT EXISTS idx_biopay_profiles_ussd_norm
  ON public.biopay_profiles (ussd_normalized)
  WHERE status = 'active';

ALTER TABLE public.biopay_profiles ENABLE ROW LEVEL SECURITY;
-- No client policies — service role only via edge function.

-- ─── biopay_face_embeddings ────────────────────────────────
CREATE TABLE IF NOT EXISTS public.biopay_face_embeddings (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id    uuid NOT NULL REFERENCES public.biopay_profiles(id) ON DELETE CASCADE,
  embedding     vector(128) NOT NULL,
  model_version text NOT NULL DEFAULT 'mobilefacenet_v2',
  quality_score real NOT NULL CHECK (quality_score BETWEEN 0 AND 1),
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_biopay_embeddings_profile
  ON public.biopay_face_embeddings (profile_id);

-- IVFFlat index for approximate nearest-neighbor search.
-- lists = 100 is a good starting point for <10K profiles.
-- Retune to lists = sqrt(N) when profile count grows.
CREATE INDEX IF NOT EXISTS idx_biopay_embeddings_vector
  ON public.biopay_face_embeddings
  USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);

ALTER TABLE public.biopay_face_embeddings ENABLE ROW LEVEL SECURITY;

-- ─── biopay_match_audit ────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.biopay_match_audit (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  matched_profile_id uuid REFERENCES public.biopay_profiles(id),
  similarity        real NOT NULL,
  result            text NOT NULL CHECK (result IN ('match','no_match','rate_limited','error')),
  client_install_id text,
  ip_hash           text,
  device_label      text,
  created_at        timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.biopay_match_audit ENABLE ROW LEVEL SECURITY;

-- ─── biopay_enrollment_audit ───────────────────────────────
CREATE TABLE IF NOT EXISTS public.biopay_enrollment_audit (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id        uuid REFERENCES public.biopay_profiles(id),
  event_type        text NOT NULL CHECK (event_type IN (
    'enrolled','re_enrolled','updated','deleted','consent_given'
  )),
  client_install_id text,
  ip_hash           text,
  details           jsonb DEFAULT '{}',
  created_at        timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.biopay_enrollment_audit ENABLE ROW LEVEL SECURITY;

-- ─── biopay_abuse_reports ──────────────────────────────────
CREATE TABLE IF NOT EXISTS public.biopay_abuse_reports (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id        uuid NOT NULL REFERENCES public.biopay_profiles(id),
  reason            text NOT NULL,
  notes             text,
  client_install_id text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  resolved_at       timestamptz
);

ALTER TABLE public.biopay_abuse_reports ENABLE ROW LEVEL SECURITY;

-- ─── RPCs ──────────────────────────────────────────────────

-- Match a face embedding against active profiles.
-- Returns top N matches above the threshold, ordered by similarity desc.
CREATE OR REPLACE FUNCTION public.match_biopay_embedding(
  query_embedding vector(128),
  threshold real,
  limit_count int DEFAULT 3
)
RETURNS TABLE (
  profile_id uuid,
  biopay_id text,
  display_name text,
  ussd_string text,
  similarity real
)
LANGUAGE sql STABLE
AS $$
  SELECT
    p.id AS profile_id,
    p.biopay_id,
    p.display_name,
    p.ussd_string,
    (1 - (e.embedding <=> query_embedding))::real AS similarity
  FROM public.biopay_face_embeddings e
  JOIN public.biopay_profiles p ON p.id = e.profile_id
  WHERE e.is_active = true
    AND p.status = 'active'
    AND (1 - (e.embedding <=> query_embedding)) >= threshold
  ORDER BY similarity DESC
  LIMIT limit_count;
$$;

-- Check for duplicate face before enrollment.
-- Returns any existing profile whose active embedding is too similar.
CREATE OR REPLACE FUNCTION public.find_duplicate_biopay_profile(
  query_embedding vector(128),
  threshold real
)
RETURNS TABLE (
  profile_id uuid,
  biopay_id text,
  display_name text,
  similarity real
)
LANGUAGE sql STABLE
AS $$
  SELECT
    p.id AS profile_id,
    p.biopay_id,
    p.display_name,
    (1 - (e.embedding <=> query_embedding))::real AS similarity
  FROM public.biopay_face_embeddings e
  JOIN public.biopay_profiles p ON p.id = e.profile_id
  WHERE e.is_active = true
    AND p.status = 'active'
    AND (1 - (e.embedding <=> query_embedding)) >= threshold
  ORDER BY similarity DESC
  LIMIT 1;
$$;

-- ─── updated_at trigger ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.biopay_update_timestamp()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_biopay_profiles_updated
  BEFORE UPDATE ON public.biopay_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.biopay_update_timestamp();
