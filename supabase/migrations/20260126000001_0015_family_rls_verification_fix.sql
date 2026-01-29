-- 0015 Family RLS Verification & Fix (V1: garantir estado correto após 0014)
--
-- Esta migration:
-- 1) Garante que is_operator() está correto (SECURITY DEFINER)
-- 2) Remove qualquer policy antiga que possa ter sobrado
-- 3) Recria policies se necessário (idempotente)

-- ============================================================================
-- 1. GARANTIR is_operator() CORRETO (SECURITY DEFINER)
-- ============================================================================

-- Garantir que is_operator() está como SECURITY DEFINER (corrige se 0009 rodou depois de 0013)
create or replace function public.is_operator()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role = 'operator'
  );
$$;

-- Garantir permissão de execução
grant execute on function public.is_operator() to authenticated;

-- ============================================================================
-- 2. REMOVER POLICIES ANTIGAS (mais seguro que DO $$ ... EXCEPTION ... END $$)
-- ============================================================================

-- Remover TODAS as policies antigas de family_groups (idempotente)
drop policy if exists "family_groups_client_select" on public.family_groups;
drop policy if exists "family_groups_client_insert" on public.family_groups;
drop policy if exists "family_groups_client_update" on public.family_groups;
drop policy if exists "family_groups_client_delete" on public.family_groups;
drop policy if exists "family_groups_operator_select" on public.family_groups;
drop policy if exists "family_groups_operator_insert" on public.family_groups;
drop policy if exists "family_groups_operator_update" on public.family_groups;
drop policy if exists "family_groups_operator_delete" on public.family_groups;

-- Remover TODAS as policies antigas de family_members (idempotente)
drop policy if exists "family_members_client_select" on public.family_members;
drop policy if exists "family_members_client_insert" on public.family_members;
drop policy if exists "family_members_client_update" on public.family_members;
drop policy if exists "family_members_client_delete" on public.family_members;
drop policy if exists "family_members_operator_select" on public.family_members;
drop policy if exists "family_members_operator_insert" on public.family_members;
drop policy if exists "family_members_operator_update" on public.family_members;
drop policy if exists "family_members_operator_delete" on public.family_members;

-- ============================================================================
-- 3. GARANTIR FUNÇÕES HELPER EXISTEM (criadas em 0014)
-- ============================================================================

-- Se as funções helper não existirem (0014 não rodou), criar versões básicas
-- (Isso não deve acontecer, mas garante idempotência)

create or replace function public.is_family_group_owner(p_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.family_groups
    where id = p_group_id
      and owner_id = auth.uid()
  );
$$;

create or replace function public.is_family_group_member(p_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.family_members
    where family_group_id = p_group_id
      and profile_id = auth.uid()
  );
$$;

create or replace function public.can_access_family_group(p_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_family_group_owner(p_group_id)
      or public.is_family_group_member(p_group_id);
$$;

-- Garantir permissões de execução
grant execute on function public.is_family_group_owner(uuid) to authenticated;
grant execute on function public.is_family_group_member(uuid) to authenticated;
grant execute on function public.can_access_family_group(uuid) to authenticated;

-- ============================================================================
-- 4. RECRIAR POLICIES CORRETAS (idempotente - só cria se não existir)
-- ============================================================================

-- Garantir RLS habilitado
alter table public.family_groups enable row level security;
alter table public.family_members enable row level security;

-- POLICIES: family_groups
-- (DROP já foi feito acima, agora recriar)
create policy "family_groups_client_select"
on public.family_groups for select
to authenticated
using (
  owner_id = auth.uid()
  or public.can_access_family_group(id)
);

create policy "family_groups_client_insert"
on public.family_groups for insert
to authenticated
with check (owner_id = auth.uid());

create policy "family_groups_client_update"
on public.family_groups for update
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

create policy "family_groups_client_delete"
on public.family_groups for delete
to authenticated
using (owner_id = auth.uid());

create policy "family_groups_operator_select"
on public.family_groups for select
to authenticated
using (public.is_operator());

-- POLICIES: family_members
-- (DROP já foi feito acima, agora recriar)
create policy "family_members_client_select"
on public.family_members for select
to authenticated
using (
  public.is_family_group_owner(family_group_id)
  or profile_id = auth.uid()
);

create policy "family_members_client_insert"
on public.family_members for insert
to authenticated
with check (
  public.is_family_group_owner(family_group_id)
);

create policy "family_members_client_delete"
on public.family_members for delete
to authenticated
using (
  public.is_family_group_owner(family_group_id)
);

create policy "family_members_operator_select"
on public.family_members for select
to authenticated
using (public.is_operator());

-- ============================================================================
-- 5. VERIFICAÇÃO FINAL (comentada - executar manualmente após migration)
-- ============================================================================

-- Verificar policies criadas:
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
-- FROM pg_policies
-- WHERE tablename IN ('family_groups', 'family_members')
-- ORDER BY tablename, policyname;

-- Verificar funções helper:
-- SELECT proname, prosecdef, proconfig
-- FROM pg_proc
-- WHERE proname IN ('is_family_group_owner', 'is_family_group_member', 'can_access_family_group', 'is_operator')
--   AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
