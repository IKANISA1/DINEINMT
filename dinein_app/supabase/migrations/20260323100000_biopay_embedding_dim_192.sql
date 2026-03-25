-- Expand BioPay embedding dimension from 128 → 192 to match
-- the MobileFaceNet float32 model output.
--
-- Steps:
-- 1) Drop IVFFlat index (cannot alter column type with index in place)
-- 2) Alter column from vector(128) to vector(192)
-- 3) Recreate IVFFlat index on the wider dimension

begin;

-- 1) Drop the index
drop index if exists public.idx_biopay_face_embeddings_embedding_cosine;

-- 2) Alter column
alter table public.biopay_face_embeddings
  alter column embedding type vector(192);

-- 3) Recreate index
create index idx_biopay_face_embeddings_embedding_cosine
  on public.biopay_face_embeddings
  using ivfflat (embedding vector_cosine_ops)
  with (lists = 64);

commit;
