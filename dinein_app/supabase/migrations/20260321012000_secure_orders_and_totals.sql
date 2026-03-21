begin;

alter table public.dinein_orders
  add column if not exists subtotal numeric(10,2),
  add column if not exists service_fee numeric(10,2) not null default 0,
  add column if not exists special_requests text;

update public.dinein_orders
set
  subtotal = coalesce(subtotal, total),
  service_fee = coalesce(service_fee, 0)
where subtotal is null
   or service_fee is null;

alter table public.dinein_orders
  alter column subtotal set not null,
  alter column service_fee set not null;

revoke insert, update, delete on table public.dinein_orders
  from anon, authenticated;

drop policy if exists "Anyone can insert orders" on public.dinein_orders;
drop policy if exists "Customers can insert orders" on public.dinein_orders;

commit;
