-- 0007 Conversations e Messages (V1: conversas e mensagens)

-- Conversations: conversas entre cliente e operador
create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  partner_id uuid, -- Gancho para V2 (nullable)
  subject text,
  status text default 'open', -- 'open', 'closed', 'archived'
  last_message_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Messages: mensagens dentro de uma conversa
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  content text not null,
  is_internal boolean not null default false, -- Mensagem interna (não visível ao cliente)
  metadata jsonb,
  created_at timestamptz not null default now()
);

-- Índices
create index if not exists idx_conversations_owner_id on public.conversations(owner_id);
create index if not exists idx_conversations_status on public.conversations(status);
create index if not exists idx_conversations_partner_id on public.conversations(partner_id); -- Para V2
create index if not exists idx_messages_conversation_id on public.messages(conversation_id);
create index if not exists idx_messages_sender_id on public.messages(sender_id);
create index if not exists idx_messages_created_at on public.messages(created_at);

-- Updated_at trigger para conversations
drop trigger if exists trg_conversations_updated_at on public.conversations;
create trigger trg_conversations_updated_at
before update on public.conversations
for each row execute function public.set_updated_at();

-- Função para atualizar last_message_at automaticamente
create or replace function public.update_conversation_last_message()
returns trigger as $$
begin
  update public.conversations
  set last_message_at = new.created_at
  where id = new.conversation_id;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_messages_update_conversation on public.messages;
create trigger trg_messages_update_conversation
after insert on public.messages
for each row execute function public.update_conversation_last_message();

-- RLS
alter table public.conversations enable row level security;
alter table public.messages enable row level security;

-- Policies: CLIENTE
-- Cliente vê/edita apenas suas próprias conversas
drop policy if exists "conversations_client_select" on public.conversations;
create policy "conversations_client_select"
on public.conversations for select
to authenticated
using (owner_id = auth.uid());

drop policy if exists "conversations_client_insert" on public.conversations;
create policy "conversations_client_insert"
on public.conversations for insert
to authenticated
with check (owner_id = auth.uid());

drop policy if exists "conversations_client_update" on public.conversations;
create policy "conversations_client_update"
on public.conversations for update
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

-- Cliente vê apenas mensagens não-internas das suas conversas
drop policy if exists "messages_client_select" on public.messages;
create policy "messages_client_select"
on public.messages for select
to authenticated
using (
  exists (
    select 1 from public.conversations c
    where c.id = messages.conversation_id
      and c.owner_id = auth.uid()
  )
  and not is_internal
);

drop policy if exists "messages_client_insert" on public.messages;
create policy "messages_client_insert"
on public.messages for insert
to authenticated
with check (
  exists (
    select 1 from public.conversations c
    where c.id = messages.conversation_id
      and c.owner_id = auth.uid()
  )
  and sender_id = auth.uid()
  and not is_internal
);

-- Policies: OPERADOR
-- Operador pode ler todas as conversas
drop policy if exists "conversations_operator_select" on public.conversations;
create policy "conversations_operator_select"
on public.conversations for select
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role = 'operator'
  )
);

-- Operador pode atualizar status da conversa
drop policy if exists "conversations_operator_update" on public.conversations;
create policy "conversations_operator_update"
on public.conversations for update
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
  -- Note: operador não pode alterar owner_id, partner_id
  -- Apenas status, subject são permitidos
);

-- Operador pode ler todas as mensagens (incluindo internas)
drop policy if exists "messages_operator_select" on public.messages;
create policy "messages_operator_select"
on public.messages for select
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role = 'operator'
  )
);

-- Operador pode inserir mensagens (incluindo internas)
drop policy if exists "messages_operator_insert" on public.messages;
create policy "messages_operator_insert"
on public.messages for insert
to authenticated
with check (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role = 'operator'
  )
  and sender_id = auth.uid()
);
