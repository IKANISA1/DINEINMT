begin;

grant select on public.dinein_orders to authenticated;

drop policy if exists "Scoped venue realtime can read venue orders"
  on public.dinein_orders;
create policy "Scoped venue realtime can read venue orders"
  on public.dinein_orders for select
  using (
    coalesce(auth.jwt() ->> 'aud', '') = 'dinein-venue-realtime'
    and coalesce(auth.jwt() ->> 'venue_id', '') <> ''
    and venue_id::text = auth.jwt() ->> 'venue_id'
  );

drop policy if exists "Scoped order realtime can read single order"
  on public.dinein_orders;
create policy "Scoped order realtime can read single order"
  on public.dinein_orders for select
  using (
    coalesce(auth.jwt() ->> 'aud', '') = 'dinein-order-realtime'
    and coalesce(auth.jwt() ->> 'order_id', '') <> ''
    and id::text = auth.jwt() ->> 'order_id'
  );

commit;
