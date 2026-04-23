-- Remove the deprecated legacy identity subsystem from the active DineIn schema.
-- Historical legacy identity migrations remain in git for reproducibility only.

begin;

drop trigger if exists set_legacy_identity_abuse_reports_updated_at
  on public.legacy_identity_abuse_reports;
drop trigger if exists set_legacy_identity_profiles_updated_at
  on public.legacy_identity_profiles;

drop table if exists public.legacy_identity_rate_limit_buckets;
drop table if exists public.legacy_identity_abuse_reports cascade;
drop table if exists public.legacy_identity_enrollment_audit cascade;
drop table if exists public.legacy_identity_match_audit cascade;
drop table if exists public.legacy_identity_face_embeddings cascade;
drop table if exists public.legacy_identity_profiles cascade;

do $$
begin
  if to_regtype('vector') is not null then
    execute
      'drop function if exists public.match_legacy_identity_embedding(vector, integer)';
    execute
      'drop function if exists public.find_duplicate_legacy_identity_profile(vector, double precision)';
  end if;
end $$;

drop function if exists public.generate_legacy_identity_id();
drop function if exists public.legacy_identity_set_updated_at();

commit;
