-- 0001 RBAC + Profiles (V1: client + operator)

-- Extensions (se não existirem)
create extension if not exists pgcrypto;

-- Enum de roles do app (simples e evolutivo)
do $$
begin
  if not exists (select 1 from pg_type where typname = 'app_role') then
    create type app_role as enum ('client', 'operator');
  end if;
end$$;

-- Profiles (1:1 com auth.users)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role app_role not null default 'client',
  full_name text,
  email text,
  phone text,
  locale text default 'pt-br',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Updated_at trigger helper
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

-- RLS
alter table public.profiles enable row level security;

-- Policies:
-- 1) Usuário logado pode ver e editar o próprio profile
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
on public.profiles for select
to authenticated
using (id = auth.uid());

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

-- 2) Operador pode ler todos os profiles (somente leitura por enquanto)
-- Definimos operador via coluna role no próprio profile.
drop policy if exists "profiles_operator_read_all" on public.profiles;
create policy "profiles_operator_read_all"
on public.profiles for select
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role = 'operator'
  )
);

-- Seed opcional: nada aqui (admin/operator será promovido manualmente no painel)