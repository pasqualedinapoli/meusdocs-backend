-- 0013 Fix recursion in profiles RLS (operator check)

-- 1) is_operator() deve rodar como SECURITY DEFINER para não depender de RLS
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

-- opcional (recomendado): garantir que authenticated pode executar
grant execute on function public.is_operator() to authenticated;

-- 2) Recriar policy de operador em profiles SEM consultar profiles diretamente
drop policy if exists "profiles_operator_read_all" on public.profiles;
create policy "profiles_operator_read_all"
on public.profiles for select
to authenticated
using (public.is_operator());