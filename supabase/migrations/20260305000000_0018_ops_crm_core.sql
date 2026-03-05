-- 0018_ops_crm_core.sql
-- Núcleo do Ops CRM / ServiceOps (P0): cases + case_items + campaign tag

-- 1) Enums
do $$ begin
  create type case_status as enum (
    'new',
    'waiting_customer_docs',
    'ready_to_execute',
    'sent_to_vendor',
    'waiting_vendor',
    'in_progress',
    'qa_review',
    'delivered',
    'closed',
    'blocked'
  );
exception when duplicate_object then null;
end $$;

do $$ begin
  create type case_item_status as enum (
    'new',
    'waiting_customer_docs',
    'ready_to_execute',
    'sent_to_vendor',
    'waiting_vendor',
    'in_progress',
    'qa_review',
    'delivered',
    'closed',
    'blocked'
  );
exception when duplicate_object then null;
end $$;

-- 2) Tabelas
create table if not exists public.cases (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,

  status case_status not null default 'new',
  priority text not null default 'normal' check (priority in ('low','normal','high','urgent')),

  -- Campanhas / filtros operacionais (ex.: 'tse_2026')
  campaign_tag text,

  -- Operação
  assigned_to uuid references public.profiles(id) on delete set null,
  due_at timestamptz,

  summary text,
  metadata jsonb,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_cases_owner_id on public.cases(owner_id);
create index if not exists idx_cases_status on public.cases(status);
create index if not exists idx_cases_campaign_tag on public.cases(campaign_tag);
create index if not exists idx_cases_assigned_to on public.cases(assigned_to);
create index if not exists idx_cases_due_at on public.cases(due_at);

create table if not exists public.case_items (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.cases(id) on delete cascade,

  -- 1 case_item por order_item (idempotência e rastreio)
  order_item_id uuid not null unique references public.order_items(id) on delete cascade,

  service_slug text not null,
  service_title text,
  quantity integer not null default 1,

  status case_item_status not null default 'new',
  priority text not null default 'normal' check (priority in ('low','normal','high','urgent')),
  due_at timestamptz,

  -- fornecedor / operador (opcional no P0)
  vendor_id uuid,
  assigned_to uuid references public.profiles(id) on delete set null,

  metadata jsonb,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_case_items_case_id on public.case_items(case_id);
create index if not exists idx_case_items_status on public.case_items(status);
create index if not exists idx_case_items_service_slug on public.case_items(service_slug);
create index if not exists idx_case_items_assigned_to on public.case_items(assigned_to);
create index if not exists idx_case_items_due_at on public.case_items(due_at);

-- 3) Trigger updated_at (reusa sua função set_updated_at())
drop trigger if exists trg_cases_updated_at on public.cases;
create trigger trg_cases_updated_at
before update on public.cases
for each row execute function public.set_updated_at();

drop trigger if exists trg_case_items_updated_at on public.case_items;
create trigger trg_case_items_updated_at
before update on public.case_items
for each row execute function public.set_updated_at();

-- 4) RLS
alter table public.cases enable row level security;
alter table public.case_items enable row level security;

-- cases: client select/update apenas do próprio owner_id
drop policy if exists cases_client_select on public.cases;
create policy cases_client_select on public.cases
for select to authenticated
using (owner_id = auth.uid());

drop policy if exists cases_client_update on public.cases;
create policy cases_client_update on public.cases
for update to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

-- cases: operator select/update
drop policy if exists cases_operator_select on public.cases;
create policy cases_operator_select on public.cases
for select to authenticated
using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'operator'::app_role)
);

drop policy if exists cases_operator_update on public.cases;
create policy cases_operator_update on public.cases
for update to authenticated
using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'operator'::app_role)
)
with check (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'operator'::app_role)
);

-- case_items: client select via order->owner
drop policy if exists case_items_client_select on public.case_items;
create policy case_items_client_select on public.case_items
for select to authenticated
using (
  exists (
    select 1
    from public.cases c
    where c.id = case_items.case_id and c.owner_id = auth.uid()
  )
);

-- case_items: operator select/update
drop policy if exists case_items_operator_select on public.case_items;
create policy case_items_operator_select on public.case_items
for select to authenticated
using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'operator'::app_role)
);

drop policy if exists case_items_operator_update on public.case_items;
create policy case_items_operator_update on public.case_items
for update to authenticated
using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'operator'::app_role)
)
with check (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'operator'::app_role)
);