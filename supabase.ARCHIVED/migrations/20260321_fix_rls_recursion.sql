-- Fix infinite recursion in RLS policies.
--
-- Root cause: the "Admins can read all profiles" policy on dinein_profiles
-- queries dinein_profiles itself to check the admin role, which triggers the
-- same policy evaluation again → infinite recursion.
--
-- Fix: create a SECURITY DEFINER function that bypasses RLS to check admin
-- status, then rewrite every admin-check policy to use it.

begin;

-- 1) Create a SECURITY DEFINER function to check admin role.
--    Runs as the function owner (postgres) and bypasses RLS.
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.dinein_profiles
    where id = auth.uid()
      and role = 'admin'
  );
$$;

-- 2) Drop the self-referencing policy on dinein_profiles.
drop policy if exists "Admins can read all profiles" on public.dinein_profiles;

-- Recreate it using the SECURITY DEFINER function.
create policy "Admins can read all profiles"
  on public.dinein_profiles for select
  using (is_admin());

-- 3) Fix admin policies on dinein_venues.
drop policy if exists "Admins can read all venues" on public.dinein_venues;
create policy "Admins can read all venues"
  on public.dinein_venues for select
  using (is_admin());

drop policy if exists "Admins can update all venues" on public.dinein_venues;
create policy "Admins can update all venues"
  on public.dinein_venues for update
  using (is_admin());

-- 4) Fix admin policy on dinein_orders.
drop policy if exists "Admins can read all orders" on public.dinein_orders;
create policy "Admins can read all orders"
  on public.dinein_orders for select
  using (is_admin());

-- 5) Fix admin policies on dinein_venue_claims.
drop policy if exists "Admins can read all claims" on public.dinein_venue_claims;
create policy "Admins can read all claims"
  on public.dinein_venue_claims for select
  using (is_admin());

drop policy if exists "Admins can update claims" on public.dinein_venue_claims;
create policy "Admins can update claims"
  on public.dinein_venue_claims for update
  using (is_admin());

commit;
