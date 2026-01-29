-- 0003 Family Groups e Members (V1: grupos familiares)

-- Family Groups: grupos familiares para compartilhar documentos
create table if not exists public.family_groups (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Family Members: membros de um grupo familiar
create table if not exists public.family_members (
  id uuid primary key default gen_random_uuid(),
  family_group_id uuid not null references public.family_groups(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  relationship text, -- ex: 'spouse', 'child', 'parent', etc.
  created_at timestamptz not null default now(),
  unique(family_group_id, profile_id)
);

-- Índices
create index if not exists idx_family_groups_owner_id on public.family_groups(owner_id);
create index if not exists idx_family_members_family_group_id on public.family_members(family_group_id);
create index if not exists idx_family_members_profile_id on public.family_members(profile_id);

-- Updated_at trigger para family_groups
drop trigger if exists trg_family_groups_updated_at on public.family_groups;
create trigger trg_family_groups_updated_at
before update on public.family_groups
for each row execute function public.set_updated_at();

-- RLS
alter table public.family_groups enable row level security;
alter table public.family_members enable row level security;

-- Policies: CLIENTE
-- Cliente vê/edita apenas seus próprios grupos
drop policy if exists "family_groups_client_select" on public.family_groups;
create policy "family_groups_client_select"
on public.family_groups for select
to authenticated
using (
  owner_id = auth.uid()
  or exists (
    select 1 from public.family_members fm
    where fm.family_group_id = family_groups.id
      and fm.profile_id = auth.uid()
  )
);

drop policy if exists "family_groups_client_insert" on public.family_groups;
create policy "family_groups_client_insert"
on public.family_groups for insert
to authenticated
with check (owner_id = auth.uid());

drop policy if exists "family_groups_client_update" on public.family_groups;
create policy "family_groups_client_update"
on public.family_groups for update
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

-- Cliente vê/edita apenas membros dos seus grupos
drop policy if exists "family_members_client_select" on public.family_members;
create policy "family_members_client_select"
on public.family_members for select
to authenticated
using (
  exists (
    select 1 from public.family_groups fg
    where fg.id = family_members.family_group_id
      and (fg.owner_id = auth.uid()
        or exists (
          select 1 from public.family_members fm
          where fm.family_group_id = fg.id
            and fm.profile_id = auth.uid()
        ))
  )
);

drop policy if exists "family_members_client_insert" on public.family_members;
create policy "family_members_client_insert"
on public.family_members for insert
to authenticated
with check (
  exists (
    select 1 from public.family_groups fg
    where fg.id = family_members.family_group_id
      and fg.owner_id = auth.uid()
  )
);

drop policy if exists "family_members_client_delete" on public.family_members;
create policy "family_members_client_delete"
on public.family_members for delete
to authenticated
using (
  exists (
    select 1 from public.family_groups fg
    where fg.id = family_members.family_group_id
      and fg.owner_id = auth.uid()
  )
);

-- Policies: OPERADOR
-- Operador pode ler todos os grupos e membros
drop policy if exists "family_groups_operator_select" on public.family_groups;
create policy "family_groups_operator_select"
on public.family_groups for select
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role = 'operator'
  )
);

drop policy if exists "family_members_operator_select" on public.family_members;
create policy "family_members_operator_select"
on public.family_members for select
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role = 'operator'
  )
);
