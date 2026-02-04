-- 20260204233453_0017_orders_order_number.sql
-- Adds human-friendly immutable order_number like: MD-2026-000042

-- 1) Sequência para números incrementais
create sequence if not exists public.orders_order_no_seq;

-- 2) Coluna order_number (texto, único)
alter table public.orders
  add column if not exists order_number text;

-- 3) Função que gera MD-YYYY-000001 (ou MD-2026-000001)
create or replace function public.generate_order_number()
returns text
language plpgsql
as $$
declare
  y text := to_char(now(), 'YYYY');
  n bigint;
begin
  n := nextval('public.orders_order_no_seq');
  return 'MD-' || y || '-' || lpad(n::text, 6, '0');
end;
$$;

-- 4) Trigger: preenche order_number no INSERT
create or replace function public.orders_set_order_number()
returns trigger
language plpgsql
as $$
begin
  if new.order_number is null or new.order_number = '' then
    new.order_number := public.generate_order_number();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_orders_set_order_number on public.orders;
create trigger trg_orders_set_order_number
before insert on public.orders
for each row execute function public.orders_set_order_number();

-- 5) Backfill para pedidos já existentes
update public.orders
set order_number = public.generate_order_number()
where order_number is null or order_number = '';

-- 6) Constraint única
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'orders_order_number_unique'
  ) then
    alter table public.orders
      add constraint orders_order_number_unique unique (order_number);
  end if;
end$$;
