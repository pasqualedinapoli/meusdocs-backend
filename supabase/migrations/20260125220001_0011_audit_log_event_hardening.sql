-- 0011 Audit Log Event Hardening (V1: endurecer função log_event contra forjamento)

-- Reatribuir função log_event com proteções de segurança:
-- 1. SET search_path = public (SQL function security best practice)
-- 2. Proteger contra forjamento de user_id: se auth.uid() IS NOT NULL, usar auth.uid(); senão usar p_user_id
create or replace function public.log_event(
  p_event_type event_type,
  p_resource_type text,
  p_resource_id uuid default null,
  p_user_id uuid default null,
  p_metadata jsonb default null,
  p_ip_address inet default null,
  p_user_agent text default null
)
returns uuid as $$
declare
  v_event_id uuid;
  v_user_id uuid;
begin
  -- Definir search_path explicitamente (security best practice)
  -- Usa pg_catalog, public para garantir acesso a funções do PostgreSQL
  set local search_path = pg_catalog, public;
  
  -- Proteger contra forjamento de user_id:
  -- Se auth.uid() estiver disponível (usuário autenticado), usar auth.uid()
  -- Caso contrário (service role ou contexto sem auth), aceitar p_user_id
  if auth.uid() is not null then
    v_user_id := auth.uid();
  else
    v_user_id := p_user_id;
  end if;
  
  insert into public.event_log (
    event_type,
    resource_type,
    resource_id,
    user_id,
    metadata,
    ip_address,
    user_agent
  ) values (
    p_event_type,
    p_resource_type,
    p_resource_id,
    v_user_id,
    p_metadata,
    p_ip_address,
    p_user_agent
  )
  returning id into v_event_id;
  
  return v_event_id;
end;
$$ language plpgsql security definer;
