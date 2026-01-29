-- ARQUIVADO: Migration movida para repo backend-v1-supabase (fonte da verdade).
-- Ver: backend-v1-supabase/supabase/migrations/20260129100000_0016_addresses.sql
-- Este arquivo é apenas referência; não aplicar no meusdocs-site.

-- 0016 Addresses: endereços do cliente (principal + múltiplos)

create table if not exists public.addresses (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  label text, -- ex: 'Casa', 'Trabalho', 'Principal'
  street text not null,
  number text,
  complement text,
  city text not null,
  state text,
  postal_code text,
  country text not null default 'IT',
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_addresses_profile_id on public.addresses(profile_id);
create index if not exists idx_addresses_is_default on public.addresses(profile_id, is_default) where is_default = true;

drop trigger if exists trg_addresses_updated_at on public.addresses;
create trigger trg_addresses_updated_at
before update on public.addresses
for each row execute function public.set_updated_at();

alter table public.addresses enable row level security;

drop policy if exists "addresses_client_select" on public.addresses;
create policy "addresses_client_select"
on public.addresses for select to authenticated
using (profile_id = auth.uid());

drop policy if exists "addresses_client_insert" on public.addresses;
create policy "addresses_client_insert"
on public.addresses for insert to authenticated
with check (profile_id = auth.uid());

drop policy if exists "addresses_client_update" on public.addresses;
create policy "addresses_client_update"
on public.addresses for update to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

drop policy if exists "addresses_client_delete" on public.addresses;
create policy "addresses_client_delete"
on public.addresses for delete to authenticated
using (profile_id = auth.uid());

drop policy if exists "addresses_operator_select" on public.addresses;
create policy "addresses_operator_select"
on public.addresses for select to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'operator'
  )
);
