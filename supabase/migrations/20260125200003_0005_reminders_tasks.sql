-- 0005 Reminders e Tasks (V1: lembretes e tarefas)

-- Reminders: lembretes para o cliente
create table if not exists public.reminders (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  document_id uuid references public.documents(id) on delete cascade,
  title text not null,
  description text,
  due_date timestamptz,
  completed boolean not null default false,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Tasks: tarefas internas (operador)
create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.profiles(id) on delete set null, -- Cliente relacionado (opcional)
  assigned_to uuid references public.profiles(id) on delete set null, -- Operador responsável
  document_id uuid references public.documents(id) on delete cascade,
  order_id uuid, -- Será referenciado na migration 0006
  title text not null,
  description text,
  status task_status not null default 'todo',
  priority task_priority not null default 'normal',
  due_date timestamptz,
  completed_at timestamptz,
  metadata jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Índices
create index if not exists idx_reminders_owner_id on public.reminders(owner_id);
create index if not exists idx_reminders_document_id on public.reminders(document_id);
create index if not exists idx_reminders_due_date on public.reminders(due_date);
create index if not exists idx_tasks_owner_id on public.tasks(owner_id);
create index if not exists idx_tasks_assigned_to on public.tasks(assigned_to);
create index if not exists idx_tasks_document_id on public.tasks(document_id);
create index if not exists idx_tasks_status on public.tasks(status);
create index if not exists idx_tasks_priority on public.tasks(priority);

-- Updated_at triggers
drop trigger if exists trg_reminders_updated_at on public.reminders;
create trigger trg_reminders_updated_at
before update on public.reminders
for each row execute function public.set_updated_at();

drop trigger if exists trg_tasks_updated_at on public.tasks;
create trigger trg_tasks_updated_at
before update on public.tasks
for each row execute function public.set_updated_at();

-- RLS
alter table public.reminders enable row level security;
alter table public.tasks enable row level security;

-- Policies: CLIENTE
-- Cliente vê/edita apenas seus próprios lembretes
drop policy if exists "reminders_client_select" on public.reminders;
create policy "reminders_client_select"
on public.reminders for select
to authenticated
using (owner_id = auth.uid());

drop policy if exists "reminders_client_insert" on public.reminders;
create policy "reminders_client_insert"
on public.reminders for insert
to authenticated
with check (owner_id = auth.uid());

drop policy if exists "reminders_client_update" on public.reminders;
create policy "reminders_client_update"
on public.reminders for update
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

drop policy if exists "reminders_client_delete" on public.reminders;
create policy "reminders_client_delete"
on public.reminders for delete
to authenticated
using (owner_id = auth.uid());

-- Cliente vê apenas tarefas relacionadas a ele
drop policy if exists "tasks_client_select" on public.tasks;
create policy "tasks_client_select"
on public.tasks for select
to authenticated
using (owner_id = auth.uid());

-- Policies: OPERADOR
-- Operador pode ler todas as tarefas
drop policy if exists "tasks_operator_select" on public.tasks;
create policy "tasks_operator_select"
on public.tasks for select
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role = 'operator'
  )
);

-- Operador pode inserir/atualizar tarefas
drop policy if exists "tasks_operator_insert" on public.tasks;
create policy "tasks_operator_insert"
on public.tasks for insert
to authenticated
with check (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role = 'operator'
  )
);

drop policy if exists "tasks_operator_update" on public.tasks;
create policy "tasks_operator_update"
on public.tasks for update
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

-- Operador pode ler todos os lembretes (para contexto)
drop policy if exists "reminders_operator_select" on public.reminders;
create policy "reminders_operator_select"
on public.reminders for select
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role = 'operator'
  )
);
