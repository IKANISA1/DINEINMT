ALTER TABLE public.dinein_venues
  ADD COLUMN IF NOT EXISTS website_url TEXT,
  ADD COLUMN IF NOT EXISTS reservation_url TEXT,
  ADD COLUMN IF NOT EXISTS social_links JSONB,
  ADD COLUMN IF NOT EXISTS reviews JSONB,
  ADD COLUMN IF NOT EXISTS google_place_id TEXT,
  ADD COLUMN IF NOT EXISTS google_place_resource_name TEXT,
  ADD COLUMN IF NOT EXISTS google_maps_uri TEXT,
  ADD COLUMN IF NOT EXISTS google_maps_links JSONB,
  ADD COLUMN IF NOT EXISTS google_primary_type TEXT,
  ADD COLUMN IF NOT EXISTS google_types TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS google_business_status TEXT,
  ADD COLUMN IF NOT EXISTS google_location JSONB,
  ADD COLUMN IF NOT EXISTS google_opening_hours JSONB,
  ADD COLUMN IF NOT EXISTS google_price_level TEXT,
  ADD COLUMN IF NOT EXISTS google_review_summary TEXT,
  ADD COLUMN IF NOT EXISTS google_review_summary_disclosure TEXT,
  ADD COLUMN IF NOT EXISTS google_review_summary_uri TEXT,
  ADD COLUMN IF NOT EXISTS google_place_summary TEXT,
  ADD COLUMN IF NOT EXISTS google_place_summary_disclosure TEXT,
  ADD COLUMN IF NOT EXISTS google_photos JSONB,
  ADD COLUMN IF NOT EXISTS google_attributions JSONB,
  ADD COLUMN IF NOT EXISTS search_summary TEXT,
  ADD COLUMN IF NOT EXISTS search_sources JSONB,
  ADD COLUMN IF NOT EXISTS search_queries JSONB,
  ADD COLUMN IF NOT EXISTS enrichment_status TEXT NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS enrichment_error TEXT,
  ADD COLUMN IF NOT EXISTS enrichment_attempts INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS enrichment_locked BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS last_enriched_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS enrichment_confidence NUMERIC(4,3),
  ADD COLUMN IF NOT EXISTS category_source TEXT;

ALTER TABLE public.dinein_venues
  DROP CONSTRAINT IF EXISTS dinein_venues_enrichment_status_check;

ALTER TABLE public.dinein_venues
  ADD CONSTRAINT dinein_venues_enrichment_status_check
  CHECK (enrichment_status IN ('pending', 'enriching', 'ready', 'failed'));

ALTER TABLE public.dinein_venues
  DROP CONSTRAINT IF EXISTS dinein_venues_category_source_check;

ALTER TABLE public.dinein_venues
  ADD CONSTRAINT dinein_venues_category_source_check
  CHECK (
    category_source IS NULL OR
    category_source IN ('manual', 'google_places', 'google_search', 'ai_gemini')
  );

CREATE INDEX IF NOT EXISTS idx_dinein_venues_google_place_id
  ON public.dinein_venues (google_place_id)
  WHERE google_place_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_dinein_venues_enrichment_status
  ON public.dinein_venues (enrichment_status, enrichment_locked, last_enriched_at);
