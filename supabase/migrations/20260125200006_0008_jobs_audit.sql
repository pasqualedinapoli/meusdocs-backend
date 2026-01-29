-- 0008 Jobs, Idempotency Keys e Event Log (V1: jobs e auditoria)

-- Jobs: jobs de background/processamento assíncrono
create table if not exists public.jobs (
  id uuid primary key default gen_random_uuid(),
  job_type text not null, -- ex: 'send_email', 'process_document', etc.
  status job_status not null default 'pending',
  payload jsonb, -- Dados do job
  result jsonb, -- Resultado do job (se completado)
  error_message text,
  retry_count integer not null default 0,
  max_retries integer not null default 3,
  scheduled_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Idempotency Keys: chaves para garantir idempotência de operações
create table if not exists public.idempotency_keys (
  id uuid primary key default gen_random_uuid(),
  key text not null unique, -- Chave idempotente (ex: hash da requisição)
  resource_type text, -- Tipo de recurso afetado (ex: 'order', 'document')
  resource_id uuid, -- ID do recurso criado/atualizado
  response_data jsonb, -- Resposta da operação (para retornar em caso de duplicação)
  expires_at timestamptz not null, -- Expiração da chave (ex: 24h)
  created_at timestamptz not null default now()
);

-- Event Log: log de auditoria de eventos
create table if not exists public.event_log (
  id uuid primary key default gen_random_uuid(),
  event_type event_type not null,
  resource_type text not null, -- Tipo de recurso (ex: 'document', 'order', 'profile')
  resource_id uuid, -- ID do recurso afetado
  user_id uuid references public.profiles(id) on delete set null,
  metadata jsonb, -- Dados adicionais do evento
  ip_address inet,
  user_agent text,
  created_at timestamptz not null default now()
);

-- Índices
create index if not exists idx_jobs_status on public.jobs(status);
create index if not exists idx_jobs_job_type on public.jobs(job_type);
create index if not exists idx_jobs_scheduled_at on public.jobs(scheduled_at);
create index if not exists idx_idempotency_keys_key on public.idempotency_keys(key);
create index if not exists idx_idempotency_keys_expires_at on public.idempotency_keys(expires_at);
create index if not exists idx_event_log_event_type on public.event_log(event_type);
create index if not exists idx_event_log_resource_type on public.event_log(resource_type);
create index if not exists idx_event_log_resource_id on public.event_log(resource_id);
create index if not exists idx_event_log_user_id on public.event_log(user_id);
create index if not exists idx_event_log_created_at on public.event_log(created_at);

-- Updated_at trigger para jobs
drop trigger if exists trg_jobs_updated_at on public.jobs;
create trigger trg_jobs_updated_at
before update on public.jobs
for each row execute function public.set_updated_at();

-- Função helper para inserir eventos no log de auditoria
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
begin
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
    coalesce(p_user_id, auth.uid()),
    p_metadata,
    p_ip_address,
    p_user_agent
  )
  returning id into v_event_id;
  
  return v_event_id;
end;
$$ language plpgsql security definer;

-- RLS
alter table public.jobs enable row level security;
alter table public.idempotency_keys enable row level security;
alter table public.event_log enable row level security;

-- Policies: CLIENTE
-- Cliente não tem acesso direto a jobs, idempotency_keys e event_log
-- (esses são gerenciados pelo sistema/operador)

-- Policies: OPERADOR
-- Operador pode ler todos os jobs
drop policy if exists "jobs_operator_select" on public.jobs;
create policy "jobs_operator_select"
on public.jobs for select
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role = 'operator'
  )
);

-- Operador pode inserir/atualizar jobs
drop policy if exists "jobs_operator_insert" on public.jobs;
create policy "jobs_operator_insert"
on public.jobs for insert
to authenticated
with check (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role = 'operator'
  )
);

drop policy if exists "jobs_operator_update" on public.jobs;
create policy "jobs_operator_update"
on public.jobs for update
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role = 'operator'
  )
)
with check (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role = 'operator'
  )
);

-- Operador pode ler idempotency_keys (para debug)
drop policy if exists "idempotency_keys_operator_select" on public.idempotency_keys;
create policy "idempotency_keys_operator_select"
on public.idempotency_keys for select
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role = 'operator'
  )
);

-- Operador pode ler event_log
drop policy if exists "event_log_operator_select" on public.event_log;
create policy "event_log_operator_select"
on public.event_log for select
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role = 'operator'
  )
);

-- Service role pode inserir em event_log (via função helper)
-- Nota: service_role bypassa RLS, então não precisa policy específica
-- A função log_event usa security definer para permitir inserção
