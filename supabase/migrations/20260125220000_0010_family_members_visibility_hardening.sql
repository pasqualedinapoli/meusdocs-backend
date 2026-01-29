-- 0010 Family Members Visibility Hardening (V1: ajustar visibilidade de membros)

-- Ajustar policy de SELECT para family_members:
-- - Owner do family_group vê TODOS os membros do grupo
-- - Membro não-owner vê APENAS a própria linha (onde profile_id = auth.uid())
drop policy if exists "family_members_client_select" on public.family_members;
create policy "family_members_client_select"
on public.family_members for select
to authenticated
using (
  -- Owner vê todos os membros do grupo
  exists (
    select 1 from public.family_groups fg
    where fg.id = family_members.family_group_id
      and fg.owner_id = auth.uid()
  )
  or
  -- Membro não-owner vê apenas sua própria linha
  family_members.profile_id = auth.uid()
);

-- Nota: As policies de INSERT e DELETE permanecem inalteradas:
-- - INSERT: apenas owner pode adicionar membros (já implementado)
-- - DELETE: apenas owner pode remover membros (já implementado)
-- - A policy family_groups_client_select também permanece inalterada (membro ainda pode ver o grupo que participa)
