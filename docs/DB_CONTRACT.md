# DB_CONTRACT.md
# Contrato do Banco de Dados - MEUS DOCS V1

## Visão Geral

**Stack:** Next.js + Supabase (PostgreSQL)  
**Versão:** V1 (CLIENTE + OPERADOR)  
**RLS:** Habilitado em todas as tabelas sensíveis  
**Auditoria:** event_log com função helper `log_event()`

**Schema fonte da verdade:** repo `backend-v1-supabase` (migrations). Tipos TS e este contrato devem ser regenerados/sincronizados a partir do backend após `supabase db push` e `supabase gen types typescript --local`.

---

## Enums

### `app_role`
- `client` - Cliente
- `operator` - Operador

### `document_status`
- `draft` - Rascunho
- `pending` - Pendente
- `in_progress` - Em progresso
- `completed` - Concluído
- `cancelled` - Cancelado
- `rejected` - Rejeitado

### `order_status`
- `pending` - Pendente
- `paid` - Pago
- `processing` - Processando
- `completed` - Concluído
- `cancelled` - Cancelado
- `refunded` - Reembolsado

### `task_status`
- `todo` - A fazer
- `in_progress` - Em progresso
- `blocked` - Bloqueado
- `completed` - Concluído
- `cancelled` - Cancelado

### `task_priority`
- `low` - Baixa
- `normal` - Normal
- `high` - Alta
- `urgent` - Urgente

### `job_status`
- `pending` - Pendente
- `running` - Executando
- `completed` - Concluído
- `failed` - Falhou
- `cancelled` - Cancelado

### `event_type`
- `create` - Criação
- `update` - Atualização
- `delete` - Exclusão
- `status_change` - Mudança de status
- `file_upload` - Upload de arquivo
- `file_delete` - Exclusão de arquivo
- `access` - Acesso
- `policy_violation` - Violação de política

---

## Tabelas

### `addresses`
Endereços do cliente (principal + múltiplos).

**Colunas:**
- `id` (uuid, PK)
- `profile_id` (uuid, FK → profiles)
- `label` (text, nullable) - ex: 'Casa', 'Trabalho', 'Principal'
- `street` (text)
- `number` (text, nullable)
- `complement` (text, nullable)
- `city` (text)
- `state` (text, nullable)
- `postal_code` (text, nullable)
- `country` (text, default: 'IT')
- `is_default` (boolean, default: false)
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

**RLS:** ✅ Habilitado

**Policies:**
- **CLIENTE:** SELECT/INSERT/UPDATE/DELETE próprios endereços
- **OPERADOR:** SELECT todos os endereços

---

### `profiles`
Perfis de usuários (1:1 com `auth.users`).

**Colunas:**
- `id` (uuid, PK, FK → auth.users)
- `role` (app_role, default: 'client')
- `full_name` (text)
- `email` (text)
- `phone` (text)
- `locale` (text, default: 'pt-br')
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

**RLS:** ✅ Habilitado

**Policies:**
- **CLIENTE:** SELECT/UPDATE próprio perfil
- **OPERADOR:** SELECT todos os perfis

---

### `family_groups`
Grupos familiares para compartilhar documentos.

**Colunas:**
- `id` (uuid, PK)
- `owner_id` (uuid, FK → profiles)
- `name` (text)
- `description` (text)
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

**RLS:** ✅ Habilitado

**Policies:**
- **CLIENTE:** SELECT/INSERT/UPDATE próprios grupos ou grupos onde é membro
- **OPERADOR:** SELECT todos os grupos

---

### `family_members`
Membros de um grupo familiar.

**Colunas:**
- `id` (uuid, PK)
- `family_group_id` (uuid, FK → family_groups)
- `profile_id` (uuid, FK → profiles)
- `relationship` (text) - ex: 'spouse', 'child', 'parent'
- `created_at` (timestamptz)

**RLS:** ✅ Habilitado

**Policies:**
- **CLIENTE:** 
  - SELECT: Owner vê TODOS os membros do grupo; membro não-owner vê APENAS sua própria linha
  - INSERT/DELETE: Apenas owner pode adicionar/remover membros
- **OPERADOR:** SELECT todos os membros

---

### `documents`
Documentos do cliente.

**Colunas:**
- `id` (uuid, PK)
- `owner_id` (uuid, FK → profiles)
- `family_group_id` (uuid, FK → family_groups, nullable)
- `partner_id` (uuid, nullable) - **V2: gancho para partner**
- `title` (text)
- `description` (text)
- `document_type` (text) - ex: 'passport', 'birth_certificate'
- `status` (document_status, default: 'draft')
- `metadata` (jsonb)
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

**RLS:** ✅ Habilitado

**Policies:**
- **CLIENTE:** SELECT/INSERT/UPDATE próprios documentos ou documentos do seu family_group
- **OPERADOR:** SELECT todos; UPDATE apenas campos não sensíveis (status, description, metadata) - **não pode alterar owner_id, family_group_id, partner_id**

---

### `document_files`
Arquivos anexados aos documentos.

**Colunas:**
- `id` (uuid, PK)
- `document_id` (uuid, FK → documents)
- `file_name` (text)
- `file_path` (text) - Caminho no Supabase Storage
- `file_size` (bigint)
- `mime_type` (text)
- `uploaded_by` (uuid, FK → profiles, nullable)
- `created_at` (timestamptz)

**RLS:** ✅ Habilitado

**Policies:**
- **CLIENTE:** SELECT/INSERT/DELETE arquivos de documentos acessíveis
- **OPERADOR:** SELECT todos os arquivos

---

### `reminders`
Lembretes para o cliente.

**Colunas:**
- `id` (uuid, PK)
- `owner_id` (uuid, FK → profiles)
- `document_id` (uuid, FK → documents, nullable)
- `title` (text)
- `description` (text)
- `due_date` (timestamptz, nullable)
- `completed` (boolean, default: false)
- `completed_at` (timestamptz, nullable)
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

**RLS:** ✅ Habilitado

**Policies:**
- **CLIENTE:** SELECT/INSERT/UPDATE/DELETE próprios lembretes
- **OPERADOR:** SELECT todos os lembretes (somente leitura)

---

### `tasks`
Tarefas internas (operador).

**Colunas:**
- `id` (uuid, PK)
- `owner_id` (uuid, FK → profiles, nullable) - Cliente relacionado
- `assigned_to` (uuid, FK → profiles, nullable) - Operador responsável
- `document_id` (uuid, FK → documents, nullable)
- `order_id` (uuid, nullable) - Será referenciado quando orders existir
- `title` (text)
- `description` (text)
- `status` (task_status, default: 'todo')
- `priority` (task_priority, default: 'normal')
- `due_date` (timestamptz, nullable)
- `completed_at` (timestamptz, nullable)
- `metadata` (jsonb)
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

**RLS:** ✅ Habilitado

**Policies:**
- **CLIENTE:** SELECT apenas tarefas relacionadas a ele (owner_id)
- **OPERADOR:** SELECT/INSERT/UPDATE todas as tarefas

---

### `orders`
Pedidos de serviços.

**Colunas:**
- `id` (uuid, PK)
- `owner_id` (uuid, FK → profiles)
- `partner_id` (uuid, nullable) - **V2: gancho para partner**
- `stripe_payment_intent_id` (text, nullable)
- `status` (order_status, default: 'pending')
- `total_amount_cents` (bigint)
- `currency` (text, default: 'eur')
- `metadata` (jsonb)
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

**RLS:** ✅ Habilitado

**Policies:**
- **CLIENTE:** SELECT/INSERT/UPDATE próprios pedidos
- **OPERADOR:** SELECT todos; UPDATE apenas campos não sensíveis (status, metadata) - **não pode alterar owner_id, partner_id, total_amount_cents**

---

### `order_items`
Itens de um pedido.

**Colunas:**
- `id` (uuid, PK)
- `order_id` (uuid, FK → orders)
- `service_slug` (text) - Slug do serviço
- `service_title` (text)
- `quantity` (integer, default: 1)
- `unit_price_cents` (bigint)
- `total_price_cents` (bigint)
- `metadata` (jsonb)
- `created_at` (timestamptz)

**RLS:** ✅ Habilitado

**Policies:**
- **CLIENTE:** SELECT/INSERT itens dos próprios pedidos
- **OPERADOR:** SELECT todos os itens

---

### `conversations`
Conversas entre cliente e operador.

**Colunas:**
- `id` (uuid, PK)
- `owner_id` (uuid, FK → profiles)
- `partner_id` (uuid, nullable) - **V2: gancho para partner**
- `subject` (text, nullable)
- `status` (text, default: 'open') - 'open', 'closed', 'archived'
- `last_message_at` (timestamptz, nullable) - Atualizado automaticamente via trigger
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

**RLS:** ✅ Habilitado

**Policies:**
- **CLIENTE:** SELECT/INSERT/UPDATE próprias conversas
- **OPERADOR:** SELECT todas; UPDATE apenas status e subject - **não pode alterar owner_id, partner_id**

---

### `messages`
Mensagens dentro de uma conversa.

**Colunas:**
- `id` (uuid, PK)
- `conversation_id` (uuid, FK → conversations)
- `sender_id` (uuid, FK → profiles)
- `content` (text)
- `is_internal` (boolean, default: false) - Mensagem interna (não visível ao cliente)
- `metadata` (jsonb)
- `created_at` (timestamptz)

**RLS:** ✅ Habilitado

**Policies:**
- **CLIENTE:** SELECT/INSERT apenas mensagens não-internas das próprias conversas
- **OPERADOR:** SELECT/INSERT todas as mensagens (incluindo internas)

**Triggers:**
- Atualiza `conversations.last_message_at` automaticamente ao inserir mensagem

---

### `jobs`
Jobs de background/processamento assíncrono.

**Colunas:**
- `id` (uuid, PK)
- `job_type` (text) - ex: 'send_email', 'process_document'
- `status` (job_status, default: 'pending')
- `payload` (jsonb)
- `result` (jsonb)
- `error_message` (text, nullable)
- `retry_count` (integer, default: 0)
- `max_retries` (integer, default: 3)
- `scheduled_at` (timestamptz, nullable)
- `started_at` (timestamptz, nullable)
- `completed_at` (timestamptz, nullable)
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

**RLS:** ✅ Habilitado

**Policies:**
- **CLIENTE:** Sem acesso
- **OPERADOR:** SELECT/INSERT/UPDATE todos os jobs

---

### `idempotency_keys`
Chaves para garantir idempotência de operações.

**Colunas:**
- `id` (uuid, PK)
- `key` (text, unique) - Chave idempotente
- `resource_type` (text, nullable) - Tipo de recurso
- `resource_id` (uuid, nullable) - ID do recurso
- `response_data` (jsonb) - Resposta da operação
- `expires_at` (timestamptz)
- `created_at` (timestamptz)

**RLS:** ✅ Habilitado

**Policies:**
- **CLIENTE:** Sem acesso
- **OPERADOR:** SELECT (para debug)

---

### `event_log`
Log de auditoria de eventos.

**Colunas:**
- `id` (uuid, PK)
- `event_type` (event_type)
- `resource_type` (text) - Tipo de recurso
- `resource_id` (uuid, nullable) - ID do recurso
- `user_id` (uuid, FK → profiles, nullable)
- `metadata` (jsonb)
- `ip_address` (inet, nullable)
- `user_agent` (text, nullable)
- `created_at` (timestamptz)

**RLS:** ✅ Habilitado

**Policies:**
- **CLIENTE:** Sem acesso
- **OPERADOR:** SELECT todos os eventos

**Função Helper:**
```sql
log_event(
  p_event_type event_type,
  p_resource_type text,
  p_resource_id uuid default null,
  p_user_id uuid default null,
  p_metadata jsonb default null,
  p_ip_address inet default null,
  p_user_agent text default null
) returns uuid
```

---

## Regras de Acesso (RBAC)

### CLIENTE
- Acesso apenas a registros vinculados ao seu `user_id` (owner_id) ou `family_group_id` associado
- Pode criar/ler/atualizar próprios recursos
- DELETE restrito (apenas em recursos próprios, quando permitido)

### OPERADOR
- **SELECT:** Global (pode ler todos os registros)
- **UPDATE:** Permitido apenas em campos não sensíveis:
  - `documents`: status, description, metadata (não pode alterar owner_id, family_group_id, partner_id)
  - `orders`: status, metadata (não pode alterar owner_id, partner_id, total_amount_cents)
  - `conversations`: status, subject (não pode alterar owner_id, partner_id)
- **DELETE:** Não permitido (sem policies de DELETE para operador)
- **INSERT:** Permitido em tasks, jobs, messages (conforme policies específicas)

---

## Ganchos para V2 (Partner)

Campos `partner_id` nullable nas seguintes tabelas:
- `documents`
- `orders`
- `conversations`

**Nota:** No V1, essas colunas existem mas não têm policies ativas. As policies de partner serão implementadas no V2.

---

## Índices

Todos os índices necessários foram criados nas migrations:
- Foreign keys (owner_id, family_group_id, etc.)
- Status fields (para filtros comuns)
- Timestamps (created_at, due_date, etc.)
- Campos únicos (idempotency_keys.key)

---

## Funções e Triggers

### `set_updated_at()`
Função genérica para atualizar `updated_at` automaticamente.

**Aplicada em:**
- `profiles`
- `family_groups`
- `documents`
- `reminders`
- `tasks`
- `orders`
- `conversations`
- `jobs`

### `update_conversation_last_message()`
Atualiza `conversations.last_message_at` quando uma mensagem é inserida.

### `log_event()`
Função helper para inserir eventos no log de auditoria (security definer).

**Proteções de segurança:**
- `SET search_path = public` (SQL function security best practice)
- Proteção contra forjamento de `user_id`: se `auth.uid()` IS NOT NULL, usa `auth.uid()`; caso contrário (service role), aceita `p_user_id`

### `is_operator()`
Retorna `true` se o usuário atual é operador (`profiles.role = 'operator'`). Usa `auth.uid()`, security invoker.

### `guard_*_operator_update()` + triggers
Triggers **BEFORE UPDATE** em `documents`, `orders` e `conversations` que, quando o usuário é operador, bloqueiam alteração de colunas sensíveis (owner_id, family_group_id, partner_id, total_amount_cents). Garantem que o operador não faça UPDATE perigoso mesmo com RLS permitindo a linha.

---

## Migrations

1. `20260125182409_0001_rbac_and_profiles.sql` - RBAC + Profiles
2. `20260125200000_0002_enums.sql` - Enums
3. `20260125200001_0003_family_groups.sql` - Family Groups e Members
4. `20260125200002_0004_documents.sql` - Documents e Document Files
5. `20260125200003_0005_reminders_tasks.sql` - Reminders e Tasks
6. `20260125200004_0006_orders.sql` - Orders e Order Items
7. `20260125200005_0007_conversations.sql` - Conversations e Messages
8. `20260125200006_0008_jobs_audit.sql` - Jobs, Idempotency Keys e Event Log
9. `20260125200007_0009_operator_update_guards.sql` - Triggers que bloqueiam operador de alterar colunas sensíveis
10. `20260125220000_0010_family_members_visibility_hardening.sql` - Ajustar visibilidade de family_members (owner vê todos; membro vê apenas sua linha)
11. `20260125220001_0011_audit_log_event_hardening.sql` - Hardening da função log_event() (search_path + proteção contra forjamento de user_id)
12. `20260125220002_0012_add_tasks_order_id_fk.sql` - Adicionar FK tasks.order_id → orders.id (correção de gap)

---

## RLS: auth.uid() e Joins

- **auth.uid():** Todas as policies usam exclusivamente `auth.uid()` (e `profiles.role` para operador). Sem session vars, custom claims ou bypass.
- **Operador UPDATE:** O RLS `with check` não restringe colunas. Os triggers em `0009_operator_update_guards` garantem que o operador **não** altere:
  - `documents`: owner_id, family_group_id, partner_id
  - `orders`: owner_id, partner_id, total_amount_cents
  - `conversations`: owner_id, partner_id
- **Joins:** Em `document_files` e `order_items`, as policies usam `EXISTS` em `documents` / `orders` sujeito ao RLS. JOINs não vazam dados entre donos ou entre family_groups.

---

## Notas de Implementação

- Todas as tabelas sensíveis têm RLS habilitado
- Policies explícitas por role (CLIENTE/OPERADOR)
- Operador não pode fazer DELETE (sem policies de DELETE)
- Operador pode atualizar apenas campos não sensíveis: **enforcement** via triggers `guard_*_operator_update` (RLS não restringe colunas)
- Função `log_event()` pronta para auditoria (não precisa de triggers completos ainda)
- Ganchos para partner (V2) incluídos mas sem policies ativas

---

## Logística e Stripe (referência)

- **addresses:** usados para cotação de frete e envio; ver `docs/LOGISTICS_CONTRACT.md`.
- **orders.metadata (jsonb):** pode armazenar `logistics_quote_id`, `logistics_snapshot` ou referência à cotação ao persistir pedido no Supabase.
- **event_log:** para tracking de logística use `resource_type` (ex.: ordem/shipment) e `metadata.tracking_event` com um dos eventos mínimos: `purchase_completed`, `quote_selected`, `label_generated`, `pickup_scheduled`, `in_transit`, `delivered`. Ver `lib/logistics-contract.ts` → `TRACKING_EVENT`.
- **Stripe Checkout Session metadata:** limite 500 caracteres por valor. O checkout-cart grava `locale`, `items_count`, `slugs_preview`; opcionalmente `logistics_quote_id` e `logistics_snapshot` (JSON string) quando há frete dinâmico. Ver `docs/LOGISTICS_CONTRACT.md`.
