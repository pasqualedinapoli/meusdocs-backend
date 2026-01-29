-- 0002 Enums (V1: status e tipos de domínio)

-- Status de documentos
do $$
begin
  if not exists (select 1 from pg_type where typname = 'document_status') then
    create type document_status as enum (
      'draft',
      'pending',
      'in_progress',
      'completed',
      'cancelled',
      'rejected'
    );
  end if;
end$$;

-- Status de pedidos
do $$
begin
  if not exists (select 1 from pg_type where typname = 'order_status') then
    create type order_status as enum (
      'pending',
      'paid',
      'processing',
      'completed',
      'cancelled',
      'refunded'
    );
  end if;
end$$;

-- Status de tarefas
do $$
begin
  if not exists (select 1 from pg_type where typname = 'task_status') then
    create type task_status as enum (
      'todo',
      'in_progress',
      'blocked',
      'completed',
      'cancelled'
    );
  end if;
end$$;

-- Prioridade de tarefas
do $$
begin
  if not exists (select 1 from pg_type where typname = 'task_priority') then
    create type task_priority as enum (
      'low',
      'normal',
      'high',
      'urgent'
    );
  end if;
end$$;

-- Status de jobs (background)
do $$
begin
  if not exists (select 1 from pg_type where typname = 'job_status') then
    create type job_status as enum (
      'pending',
      'running',
      'completed',
      'failed',
      'cancelled'
    );
  end if;
end$$;

-- Tipo de evento para auditoria
do $$
begin
  if not exists (select 1 from pg_type where typname = 'event_type') then
    create type event_type as enum (
      'create',
      'update',
      'delete',
      'status_change',
      'file_upload',
      'file_delete',
      'access',
      'policy_violation'
    );
  end if;
end$$;
