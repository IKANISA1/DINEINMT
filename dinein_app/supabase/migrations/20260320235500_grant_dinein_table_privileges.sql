begin;

grant usage on schema public to anon, authenticated, service_role;

grant all privileges on all tables in schema public to service_role;
grant all privileges on all sequences in schema public to service_role;
grant all privileges on all routines in schema public to service_role;

grant select, insert, update, delete on table public.dinein_profiles
  to authenticated;
grant select, insert, update, delete on table public.dinein_venues
  to anon, authenticated;
grant select, insert, update, delete on table public.dinein_menu_items
  to anon, authenticated;
grant select, insert, update, delete on table public.dinein_orders
  to anon, authenticated;
grant select, insert, update, delete on table public.dinein_venue_claims
  to anon, authenticated;

alter default privileges in schema public
  grant all on tables to service_role;

alter default privileges in schema public
  grant all on sequences to service_role;

alter default privileges in schema public
  grant all on routines to service_role;

commit;
