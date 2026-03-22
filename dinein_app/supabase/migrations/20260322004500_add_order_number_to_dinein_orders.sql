alter table public.dinein_orders
  add column if not exists order_number text;

create or replace function public.generate_dinein_order_number()
returns text
language plpgsql
set search_path = public
as $$
declare
  candidate text;
begin
  loop
    candidate := (10000000 + floor(random() * 90000000)::integer)::text;
    exit when not exists (
      select 1
      from public.dinein_orders
      where order_number = candidate
    );
  end loop;

  return candidate;
end;
$$;

do $$
declare
  order_row record;
begin
  for order_row in
    select id
    from public.dinein_orders
    where order_number is null
  loop
    update public.dinein_orders
    set order_number = public.generate_dinein_order_number()
    where id = order_row.id;
  end loop;
end;
$$;

alter table public.dinein_orders
  alter column order_number set default public.generate_dinein_order_number();

alter table public.dinein_orders
  alter column order_number set not null;

alter table public.dinein_orders
  drop constraint if exists dinein_orders_order_number_format_check;

alter table public.dinein_orders
  add constraint dinein_orders_order_number_format_check
  check (order_number ~ '^[0-9]{8}$');

create unique index if not exists idx_dinein_orders_order_number
  on public.dinein_orders(order_number);
