-- RLS policies for dinein_menu_items.
--
-- Public read for all users (menu browsing).
-- Write restricted to venue owners (via dinein-api edge function, but
-- belt-and-suspenders RLS ensures even direct access is safe).

begin;

-- Ensure RLS is enabled on the table.
alter table public.dinein_menu_items enable row level security;

-- 1) Public read: anyone can browse menus.
drop policy if exists "Anyone can read menu items" on public.dinein_menu_items;
create policy "Anyone can read menu items"
  on public.dinein_menu_items for select
  using (true);

-- 2) Venue owners can insert items for their own venue.
drop policy if exists "Venue owners can insert menu items" on public.dinein_menu_items;
create policy "Venue owners can insert menu items"
  on public.dinein_menu_items for insert
  with check (
    exists (
      select 1
      from public.dinein_venues
      where dinein_venues.id = venue_id
        and dinein_venues.owner_id = auth.uid()
    )
  );

-- 3) Venue owners can update their own menu items.
drop policy if exists "Venue owners can update menu items" on public.dinein_menu_items;
create policy "Venue owners can update menu items"
  on public.dinein_menu_items for update
  using (
    exists (
      select 1
      from public.dinein_venues
      where dinein_venues.id = venue_id
        and dinein_venues.owner_id = auth.uid()
    )
  );

-- 4) Venue owners can delete their own menu items.
drop policy if exists "Venue owners can delete menu items" on public.dinein_menu_items;
create policy "Venue owners can delete menu items"
  on public.dinein_menu_items for delete
  using (
    exists (
      select 1
      from public.dinein_venues
      where dinein_venues.id = venue_id
        and dinein_venues.owner_id = auth.uid()
    )
  );

-- 5) Admins can manage all menu items.
drop policy if exists "Admins can manage menu items" on public.dinein_menu_items;
create policy "Admins can manage menu items"
  on public.dinein_menu_items for all
  using (public.is_admin());

-- 6) Service role (edge functions) can manage all menu items.
-- The service_role key bypasses RLS by default, so no explicit policy needed.

commit;
