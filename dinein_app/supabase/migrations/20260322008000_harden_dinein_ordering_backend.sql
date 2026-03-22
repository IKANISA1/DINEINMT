alter table public.dinein_orders
  add column if not exists payment_status text;

update public.dinein_orders
set payment_status = case
  when payment_method = 'cash' then 'not_required'
  else 'pending'
end
where payment_status is null;

alter table public.dinein_orders
  alter column payment_status set not null;

alter table public.dinein_orders
  drop constraint if exists dinein_orders_payment_status_check;

alter table public.dinein_orders
  add constraint dinein_orders_payment_status_check
  check (payment_status in ('pending', 'confirmed', 'not_required', 'failed'));

create index if not exists idx_dinein_orders_payment_status
  on public.dinein_orders(payment_status);

create or replace function public.prepare_dinein_order_row()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    if nullif(btrim(coalesce(new.table_number, '')), '') is null then
      raise exception 'Table number is required for dine-in orders.'
        using errcode = '23514';
    end if;
  end if;

  if new.payment_status is null then
    new.payment_status := case
      when new.payment_method = 'cash' then 'not_required'
      else 'pending'
    end;
  end if;

  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_prepare_dinein_order_row
  on public.dinein_orders;

create trigger trg_prepare_dinein_order_row
before insert or update on public.dinein_orders
for each row
execute function public.prepare_dinein_order_row();
