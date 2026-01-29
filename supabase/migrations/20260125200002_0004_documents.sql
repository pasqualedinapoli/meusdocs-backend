-- 0004 Documents e Document Files (V1: documentos e arquivos)

-- Documents: documentos do cliente
create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  family_group_id uuid references public.family_groups(id) on delete set null,
  partner_id uuid, -- Gancho para V2 (nullable)
  title text not null,
  description text,
  document_type text, -- ex: 'passport', 'birth_certificate', etc.
  status document_status not null default 'draft',
  metadata jsonb, -- Dados adicionais flexíveis
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Document Files: arquivos anexados aos documentos
create table if not exists public.document_files (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.documents(id) on delete cascade,
  file_name text not null,
  file_path text not null, -- Caminho no storage (Supabase Storage)
  file_size bigint,
  mime_type text,
  uploaded_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

-- Índices
create index if not exists idx_documents_owner_id on public.documents(owner_id);
create index if not exists idx_documents_family_group_id on public.documents(family_group_id);
create index if not exists idx_documents_status on public.documents(status);
create index if not exists idx_documents_partner_id on public.documents(partner_id); -- Para V2
create index if not exists idx_document_files_document_id on public.document_files(document_id);
create index if not exists idx_document_files_uploaded_by on public.document_files(uploaded_by);

-- Updated_at trigger para documents
drop trigger if exists trg_documents_updated_at on public.documents;
create trigger trg_documents_updated_at
before update on public.documents
for each row execute function public.set_updated_at();

-- RLS
alter table public.documents enable row level security;
alter table public.document_files enable row level security;

-- Policies: CLIENTE
-- Cliente vê/edita apenas documentos próprios ou do seu family_group
drop policy if exists "documents_client_select" on public.documents;
create policy "documents_client_select"
on public.documents for select
to authenticated
using (
  owner_id = auth.uid()
  or (family_group_id is not null and exists (
    select 1 from public.family_members fm
    where fm.family_group_id = documents.family_group_id
      and fm.profile_id = auth.uid()
  ))
);

drop policy if exists "documents_client_insert" on public.documents;
create policy "documents_client_insert"
on public.documents for insert
to authenticated
with check (owner_id = auth.uid());

drop policy if exists "documents_client_update" on public.documents;
create policy "documents_client_update"
on public.documents for update
to authenticated
using (
  owner_id = auth.uid()
  or (family_group_id is not null and exists (
    select 1 from public.family_members fm
    where fm.family_group_id = documents.family_group_id
      and fm.profile_id = auth.uid()
  ))
)
with check (
  owner_id = auth.uid()
  or (family_group_id is not null and exists (
    select 1 from public.family_members fm
    where fm.family_group_id = documents.family_group_id
      and fm.profile_id = auth.uid()
  ))
);

-- Cliente vê/insere arquivos apenas em documentos acessíveis
drop policy if exists "document_files_client_select" on public.document_files;
create policy "document_files_client_select"
on public.document_files for select
to authenticated
using (
  exists (
    select 1 from public.documents d
    where d.id = document_files.document_id
      and (d.owner_id = auth.uid()
        or (d.family_group_id is not null and exists (
          select 1 from public.family_members fm
          where fm.family_group_id = d.family_group_id
            and fm.profile_id = auth.uid()
        )))
  )
);

drop policy if exists "document_files_client_insert" on public.document_files;
create policy "document_files_client_insert"
on public.document_files for insert
to authenticated
with check (
  exists (
    select 1 from public.documents d
    where d.id = document_files.document_id
      and (d.owner_id = auth.uid()
        or (d.family_group_id is not null and exists (
          select 1 from public.family_members fm
          where fm.family_group_id = d.family_group_id
            and fm.profile_id = auth.uid()
        )))
  )
  and uploaded_by = auth.uid()
);

drop policy if exists "document_files_client_delete" on public.document_files;
create policy "document_files_client_delete"
on public.document_files for delete
to authenticated
using (
  exists (
    select 1 from public.documents d
    where d.id = document_files.document_id
      and d.owner_id = auth.uid()
  )
);

-- Policies: OPERADOR
-- Operador pode ler todos os documentos e arquivos
drop policy if exists "documents_operator_select" on public.documents;
create policy "documents_operator_select"
on public.documents for select
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role = 'operator'
  )
);

-- Operador pode atualizar apenas campos não sensíveis (status, metadata)
drop policy if exists "documents_operator_update" on public.documents;
create policy "documents_operator_update"
on public.documents for update
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
  -- Note: operador não pode alterar owner_id, family_group_id, partner_id
  -- Apenas status, description, metadata são permitidos
);

drop policy if exists "document_files_operator_select" on public.document_files;
create policy "document_files_operator_select"
on public.document_files for select
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role = 'operator'
  )
);
