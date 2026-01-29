-- 0006 Orders e Order Items (V1: pedidos e itens)

-- Orders: pedidos de serviços
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  partner_id uuid, -- Gancho para V2 (nullable)
  stripe_payment_intent_id text, -- ID do Stripe
  status order_status not null default 'pending',
  total_amount_cents bigint not null, -- Valor em centavos
  currency text default 'eur',
  metadata jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Order Items: itens de um pedido
create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  service_slug text not null, -- Slug do serviço (ex: 'cpf', 'passaporte-brasileiro')
  service_title text not null,
  quantity integer not null default 1,
  unit_price_cents bigint not null,
  total_price_cents bigint not null,
  metadata jsonb,
  created_at timestamptz not null default now()
);

-- Índices
create index if not exists idx_orders_owner_id on public.orders(owner_id);
create index if not exists idx_orders_status on public.orders(status);
create index if not exists idx_orders_stripe_payment_intent_id on public.orders(stripe_payment_intent_id);
create index if not exists idx_orders_partner_id on public.orders(partner_id); -- Para V2
create index if not exists idx_order_items_order_id on public.order_items(order_id);
create index if not exists idx_order_items_service_slug on public.order_items(service_slug);

-- Updated_at trigger para orders
drop trigger if exists trg_orders_updated_at on public.orders;
create trigger trg_orders_updated_at
before update on public.orders
for each row execute function public.set_updated_at();

-- RLS
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

-- Policies: CLIENTE
-- Cliente vê/edita apenas seus próprios pedidos
drop policy if exists "orders_client_select" on public.orders;
create policy "orders_client_select"
on public.orders for select
to authenticated
using (owner_id = auth.uid());

drop policy if exists "orders_client_insert" on public.orders;
create policy "orders_client_insert"
on public.orders for insert
to authenticated
with check (owner_id = auth.uid());

drop policy if exists "orders_client_update" on public.orders;
create policy "orders_client_update"
on public.orders for update
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

-- Cliente vê apenas itens dos seus pedidos
drop policy if exists "order_items_client_select" on public.order_items;
create policy "order_items_client_select"
on public.order_items for select
to authenticated
using (
  exists (
    select 1 from public.orders o
    where o.id = order_items.order_id
      and o.owner_id = auth.uid()
  )
);

drop policy if exists "order_items_client_insert" on public.order_items;
create policy "order_items_client_insert"
on public.order_items for insert
to authenticated
with check (
  exists (
    select 1 from public.orders o
    where o.id = order_items.order_id
      and o.owner_id = auth.uid()
  )
);

-- Policies: OPERADOR
-- Operador pode ler todos os pedidos e itens
drop policy if exists "orders_operator_select" on public.orders;
create policy "orders_operator_select"
on public.orders for select
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role = 'operator'
  )
);

-- Operador pode atualizar apenas campos não sensíveis (status, metadata)
drop policy if exists "orders_operator_update" on public.orders;
create policy "orders_operator_update"
on public.orders for update
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role = 'operator'
  )
)
with check (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role = 'operator'
  )
  -- Note: operador não pode alterar owner_id, partner_id, total_amount_cents
  -- Apenas status, metadata são permitidos
);

drop policy if exists "order_items_operator_select" on public.order_items;
create policy "order_items_operator_select"
on public.order_items for select
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role = 'operator'
  )
);
