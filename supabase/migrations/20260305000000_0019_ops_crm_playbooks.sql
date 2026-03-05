-- 0019_ops_crm_playbooks.sql
-- P1: playbooks por serviço (templates) + document_requests + packets

do $$ begin
  create type doc_request_status as enum ('required','uploaded','approved','rejected');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type packet_status as enum ('draft','waiting_customer_approval','approved','sent','failed');
exception when duplicate_object then null;
end $$;

create table if not exists public.task_templates (
  id uuid primary key default gen_random_uuid(),
  service_slug text not null,
  title text not null,
  description text,
  sort_order integer not null default 100,
  default_priority text not null default 'normal' check (default_priority in ('low','normal','high','urgent')),
  default_due_days integer, -- ex.: 2 => due_at = now()+2d
  metadata jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_task_templates_service_slug on public.task_templates(service_slug);

create table if not exists public.document_request_templates (
  id uuid primary key default gen_random_uuid(),
  service_slug text not null,
  doc_type text not null, -- ex: "selfie_doc", "certidao_nascimento", etc.
  title text not null,
  instructions text,
  sort_order integer not null default 100,
  required boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists idx_docreq_templates_service_slug on public.document_request_templates(service_slug);

create table if not exists public.document_requests (
  id uuid primary key default gen_random_uuid(),
  case_item_id uuid not null references public.case_items(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,

  doc_type text not null,
  title text not null,
  instructions text,

  status doc_request_status not null default 'required',
  document_id uuid references public.documents(id) on delete set null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_docreq_case_item_id on public.document_requests(case_item_id);
create index if not exists idx_docreq_owner_id on public.document_requests(owner_id);
create index if not exists idx_docreq_status on public.document_requests(status);

drop trigger if exists trg_document_requests_updated_at on public.document_requests;
create trigger trg_document_requests_updated_at
before update on public.document_requests
for each row execute function public.set_updated_at();

create table if not exists public.document_packets (
  id uuid primary key default gen_random_uuid(),
  case_item_id uuid not null references public.case_items(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,

  packet_type text not null, -- ex: "tse_submission", "cartorio_jk_procuracao", "cpf_email"
  status packet_status not null default 'draft',

  -- PDF gerado como um "document" do sistema (reusa documents + storage)
  generated_document_id uuid references public.documents(id) on delete set null,

  -- payload pronto para envio
  to_email text,
  subject text,
  body text,

  metadata jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_packets_case_item_id on public.document_packets(case_item_id);
create index if not exists idx_packets_owner_id on public.document_packets(owner_id);
create index if not exists idx_packets_status on public.document_packets(status);

drop trigger if exists trg_document_packets_updated_at on public.document_packets;
create trigger trg_document_packets_updated_at
before update on public.document_packets
for each row execute function public.set_updated_at();

-- RLS
alter table public.task_templates enable row level security;
alter table public.document_request_templates enable row level security;
alter table public.document_requests enable row level security;
alter table public.document_packets enable row level security;

-- templates: somente operador (leitura/gestão)
drop policy if exists task_templates_operator_select on public.task_templates;
create policy task_templates_operator_select on public.task_templates
for select to authenticated
using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'operator'::app_role)
);

drop policy if exists task_templates_operator_write on public.task_templates;
create policy task_templates_operator_write on public.task_templates
for all to authenticated
using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'operator'::app_role)
)
with check (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'operator'::app_role)
);

drop policy if exists docreq_templates_operator_select on public.document_request_templates;
create policy docreq_templates_operator_select on public.document_request_templates
for select to authenticated
using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'operator'::app_role)
);

drop policy if exists docreq_templates_operator_write on public.document_request_templates;
create policy docreq_templates_operator_write on public.document_request_templates
for all to authenticated
using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'operator'::app_role)
)
with check (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'operator'::app_role)
);

-- document_requests: cliente vê os seus / operador vê tudo
drop policy if exists document_requests_client_select on public.document_requests;
create policy document_requests_client_select on public.document_requests
for select to authenticated
using (owner_id = auth.uid());

drop policy if exists document_requests_client_update on public.document_requests;
create policy document_requests_client_update on public.document_requests
for update to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

drop policy if exists document_requests_operator_select on public.document_requests;
create policy document_requests_operator_select on public.document_requests
for select to authenticated
using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'operator'::app_role)
);

drop policy if exists document_requests_operator_update on public.document_requests;
create policy document_requests_operator_update on public.document_requests
for update to authenticated
using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'operator'::app_role)
)
with check (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'operator'::app_role)
);

-- document_packets: cliente vê os seus / operador vê tudo
drop policy if exists document_packets_client_select on public.document_packets;
create policy document_packets_client_select on public.document_packets
for select to authenticated
using (owner_id = auth.uid());

drop policy if exists document_packets_operator_select on public.document_packets;
create policy document_packets_operator_select on public.document_packets
for select to authenticated
using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'operator'::app_role)
);

drop policy if exists document_packets_operator_update on public.document_packets;
create policy document_packets_operator_update on public.document_packets
for update to authenticated
using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'operator'::app_role)
)
with check (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'operator'::app_role)
);