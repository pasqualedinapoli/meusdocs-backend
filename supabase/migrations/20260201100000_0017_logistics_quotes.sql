-- 0017 Logistics Quotes: armazenar cotações de frete (requestId, origin/destination, status, carrier/service/price, raw truncado)
-- Idempotente. RLS: cliente vê só as próprias; operador vê todas.

create table if not exists public.logistics_quotes (
  id uuid primary key default gen_random_uuid(),
  request_id text not null,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  origin jsonb not null default '{}',
  destination jsonb not null default '{}',
  status text not null default 'pending',
  carrier text,
  service text,
  price_cents bigint,
  currency text default 'EUR',
  raw_response_truncated text,
  created_at timestamptz not null default now()
);

comment on column public.logistics_quotes.request_id is 'ID da requisição (ex: envia_1234567890_abc)';
comment on column public.logistics_quotes.origin is 'Resumo origem: country, state, city, postcode (sem dados sensíveis)';
comment on column public.logistics_quotes.destination is 'Resumo destino: country, state, city, postcode (sem dados sensíveis)';
comment on column public.logistics_quotes.status is 'ok | error | invalid_payload | invalid_state';
comment on column public.logistics_quotes.raw_response_truncated is 'Resposta bruta truncada (ex: 2000 chars) para debug';

create index if not exists idx_logistics_quotes_profile_id on public.logistics_quotes(profile_id);
create index if not exists idx_logistics_quotes_request_id on public.logistics_quotes(request_id);
create index if not exists idx_logistics_quotes_created_at on public.logistics_quotes(created_at desc);

alter table public.logistics_quotes enable row level security;

-- CLIENTE: ver apenas as próprias cotações
drop policy if exists "logistics_quotes_client_select" on public.logistics_quotes;
create policy "logistics_quotes_client_select"
  on public.logistics_quotes for select to authenticated
  using (profile_id = auth.uid());

-- CLIENTE: inserir apenas com profile_id = auth.uid()
drop policy if exists "logistics_quotes_client_insert" on public.logistics_quotes;
create policy "logistics_quotes_client_insert"
  on public.logistics_quotes for insert to authenticated
  with check (profile_id = auth.uid());

-- OPERADOR: ver todas (suporte/debug)
drop policy if exists "logistics_quotes_operator_select" on public.logistics_quotes;
create policy "logistics_quotes_operator_select"
  on public.logistics_quotes for select to authenticated
  using (public.is_operator());
