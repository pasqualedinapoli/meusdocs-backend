-- 0014 Family RLS Anti-Loop (V1: corrigir recursão infinita em family_groups e family_members)
--
-- Problema: Policies atuais causam loop recursivo:
--   - family_groups SELECT faz JOIN em family_members (dispara RLS)
--   - family_members SELECT faz JOIN em family_groups (dispara RLS)
--   - Loop infinito
--
-- Solução: Funções helper SECURITY DEFINER que fazem queries diretas (bypass RLS)
--          e policies que usam essas funções (sem JOINs recursivos)

-- ============================================================================
-- 1. FUNÇÕES HELPER (SECURITY DEFINER para bypass RLS)
-- ============================================================================

-- Helper: verifica se auth.uid() é owner do grupo (anti-loop)
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

-- Helper: verifica se auth.uid() é membro do grupo (anti-loop)
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

-- Helper: verifica se auth.uid() pode acessar o grupo (owner OU member)
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
-- 2. DROP DE TODAS AS POLICIES EXISTENTES (idempotente)
-- ============================================================================

-- Dropar policies de family_groups (idempotente)
do $$
begin
  drop policy if exists "family_groups_client_select" on public.family_groups;
  drop policy if exists "family_groups_client_insert" on public.family_groups;
  drop policy if exists "family_groups_client_update" on public.family_groups;
  drop policy if exists "family_groups_client_delete" on public.family_groups;
  drop policy if exists "family_groups_operator_select" on public.family_groups;
  drop policy if exists "family_groups_operator_insert" on public.family_groups;
  drop policy if exists "family_groups_operator_update" on public.family_groups;
  drop policy if exists "family_groups_operator_delete" on public.family_groups;
exception
  when others then null; -- Ignorar erros (policy pode não existir)
end $$;

-- Dropar policies de family_members (idempotente)
do $$
begin
  drop policy if exists "family_members_client_select" on public.family_members;
  drop policy if exists "family_members_client_insert" on public.family_members;
  drop policy if exists "family_members_client_update" on public.family_members;
  drop policy if exists "family_members_client_delete" on public.family_members;
  drop policy if exists "family_members_operator_select" on public.family_members;
  drop policy if exists "family_members_operator_insert" on public.family_members;
  drop policy if exists "family_members_operator_update" on public.family_members;
  drop policy if exists "family_members_operator_delete" on public.family_members;
exception
  when others then null; -- Ignorar erros (policy pode não existir)
end $$;

-- ============================================================================
-- 3. RECRIAR POLICIES ANTI-LOOP (usando funções helper)
-- ============================================================================

-- Garantir RLS habilitado (idempotente)
alter table public.family_groups enable row level security;
alter table public.family_members enable row level security;

-- ============================================================================
-- POLICIES: family_groups
-- ============================================================================

-- SELECT: Owner vê seus grupos OU member vê grupos que participa (anti-loop)
create policy "family_groups_client_select"
on public.family_groups for select
to authenticated
using (
  owner_id = auth.uid()  -- Owner direto (sem JOIN)
  or public.can_access_family_group(id)  -- Member via função helper (anti-loop)
);

-- INSERT: Apenas owner pode criar grupo (owner_id = auth.uid())
create policy "family_groups_client_insert"
on public.family_groups for insert
to authenticated
with check (owner_id = auth.uid());

-- UPDATE: Apenas owner pode atualizar seu grupo
create policy "family_groups_client_update"
on public.family_groups for update
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

-- DELETE: Apenas owner pode deletar seu grupo
create policy "family_groups_client_delete"
on public.family_groups for delete
to authenticated
using (owner_id = auth.uid());

-- OPERADOR: pode ler todos os grupos (usa is_operator() de 0013)
create policy "family_groups_operator_select"
on public.family_groups for select
to authenticated
using (public.is_operator());

-- ============================================================================
-- POLICIES: family_members
-- ============================================================================

-- SELECT: Owner vê TODOS os membros do grupo OU member vê APENAS sua linha (anti-loop)
create policy "family_members_client_select"
on public.family_members for select
to authenticated
using (
  public.is_family_group_owner(family_group_id)  -- Owner via função helper (anti-loop)
  or profile_id = auth.uid()  -- Member vê apenas sua linha (sem JOIN)
);

-- INSERT: Apenas owner pode adicionar membros (anti-loop)
create policy "family_members_client_insert"
on public.family_members for insert
to authenticated
with check (
  public.is_family_group_owner(family_group_id)  -- Owner via função helper (anti-loop)
);

-- DELETE: Apenas owner pode remover membros (anti-loop)
create policy "family_members_client_delete"
on public.family_members for delete
to authenticated
using (
  public.is_family_group_owner(family_group_id)  -- Owner via função helper (anti-loop)
);

-- OPERADOR: pode ler todos os membros (usa is_operator() de 0013)
create policy "family_members_operator_select"
on public.family_members for select
to authenticated
using (public.is_operator());

-- ============================================================================
-- 4. QUERIES DE VERIFICAÇÃO (comentadas - executar manualmente após migration)
-- ============================================================================

-- Verificar policies criadas:
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
-- FROM pg_policies
-- WHERE tablename IN ('family_groups', 'family_members')
-- ORDER BY tablename, policyname;

-- Verificar RLS habilitado:
-- SELECT relname, relrowsecurity
-- FROM pg_class
-- WHERE relname IN ('family_groups', 'family_members')
--   AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

-- Verificar funções helper:
-- SELECT proname, prosecdef, proconfig
-- FROM pg_proc
-- WHERE proname IN ('is_family_group_owner', 'is_family_group_member', 'can_access_family_group')
--   AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

-- Testar função helper (substituir <group_id> por UUID real):
-- SELECT public.is_family_group_owner('<group_id>'::uuid);
-- SELECT public.is_family_group_member('<group_id>'::uuid);
-- SELECT public.can_access_family_group('<group_id>'::uuid);
