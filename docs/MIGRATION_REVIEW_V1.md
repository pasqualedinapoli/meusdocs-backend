# Revisão de Migrations V1 - MEUS DOCS

**Data:** 2025-01-25  
**Agente:** Migration Builder (Agente 2)  
**Branch:** backend-v1-supabase

---

## 1. Lista de Migrations Locais (em ordem)

| # | Timestamp | Nome | Status Local | Status Remoto* |
|---|-----------|------|--------------|----------------|
| 0 | 20260125175302 | remote_schema.sql | ✅ Existe (vazio) | ❓ Verificar |
| 1 | 20260125182409 | 0001_rbac_and_profiles.sql | ✅ Existe | ❓ Verificar |
| 2 | 20260125200000 | 0002_enums.sql | ✅ Existe | ❓ Verificar |
| 3 | 20260125200001 | 0003_family_groups.sql | ✅ Existe | ❓ Verificar |
| 4 | 20260125200002 | 0004_documents.sql | ✅ Existe | ❓ Verificar |
| 5 | 20260125200003 | 0005_reminders_tasks.sql | ✅ Existe | ❓ Verificar |
| 6 | 20260125200004 | 0006_orders.sql | ✅ Existe | ❓ Verificar |
| 7 | 20260125200005 | 0007_conversations.sql | ✅ Existe | ❓ Verificar |
| 8 | 20260125200006 | 0008_jobs_audit.sql | ✅ Existe | ❓ Verificar |
| 9 | 20260125200007 | 0009_operator_update_guards.sql | ✅ Existe | ❓ Verificar |
| 10 | 20260125220000 | 0010_family_members_visibility_hardening.sql | ✅ Existe | ❓ Verificar |
| 11 | 20260125220001 | 0011_audit_log_event_hardening.sql | ✅ Existe | ❓ Verificar |
| 12 | 20260125220002 | 0012_add_tasks_order_id_fk.sql | ✅ Existe | ❓ Verificar |

\* **Nota:** Execute `supabase migration list` para verificar status remoto e colar aqui.

---

## 2. Verificação de Dependências

### ✅ Checklist de Dependências

#### 0001_rbac_and_profiles.sql
- ✅ Cria `app_role` enum
- ✅ Cria `profiles` table
- ✅ Cria função `set_updated_at()`
- ✅ Cria policies RLS para profiles
- **Dependências:** Nenhuma (base)

#### 0002_enums.sql
- ✅ Cria `document_status` enum
- ✅ Cria `order_status` enum
- ✅ Cria `task_status` enum
- ✅ Cria `task_priority` enum
- ✅ Cria `job_status` enum
- ✅ Cria `event_type` enum
- **Dependências:** Nenhuma

#### 0003_family_groups.sql
- ✅ Cria `family_groups` table (FK: `profiles.id`)
- ✅ Cria `family_members` table (FK: `family_groups.id`, `profiles.id`)
- ✅ Usa função `set_updated_at()` de 0001
- ✅ Cria policies RLS
- **Dependências:** ✅ 0001 (profiles)

#### 0004_documents.sql
- ✅ Cria `documents` table (FK: `profiles.id`, `family_groups.id`)
- ✅ Cria `document_files` table (FK: `documents.id`, `profiles.id`)
- ✅ Usa enum `document_status` de 0002
- ✅ Usa função `set_updated_at()` de 0001
- ✅ Cria policies RLS
- **Dependências:** ✅ 0001 (profiles), ✅ 0002 (document_status), ✅ 0003 (family_groups)

#### 0005_reminders_tasks.sql
- ✅ Cria `reminders` table (FK: `profiles.id`, `documents.id`)
- ✅ Cria `tasks` table (FK: `profiles.id`, `documents.id`)
- ⚠️ `tasks.order_id` criado SEM FK (será corrigido em 0012)
- ✅ Usa enums `task_status`, `task_priority` de 0002
- ✅ Usa função `set_updated_at()` de 0001
- ✅ Cria policies RLS
- **Dependências:** ✅ 0001 (profiles), ✅ 0002 (task_status, task_priority), ✅ 0004 (documents)

#### 0006_orders.sql
- ✅ Cria `orders` table (FK: `profiles.id`)
- ✅ Cria `order_items` table (FK: `orders.id`)
- ✅ Usa enum `order_status` de 0002
- ✅ Usa função `set_updated_at()` de 0001
- ✅ Cria policies RLS
- **Dependências:** ✅ 0001 (profiles), ✅ 0002 (order_status)

#### 0007_conversations.sql
- ✅ Cria `conversations` table (FK: `profiles.id`)
- ✅ Cria `messages` table (FK: `conversations.id`, `profiles.id`)
- ✅ Cria função `update_conversation_last_message()`
- ✅ Usa função `set_updated_at()` de 0001
- ✅ Cria policies RLS
- **Dependências:** ✅ 0001 (profiles)

#### 0008_jobs_audit.sql
- ✅ Cria `jobs` table
- ✅ Cria `idempotency_keys` table
- ✅ Cria `event_log` table (FK: `profiles.id`)
- ✅ Usa enum `job_status`, `event_type` de 0002
- ✅ Cria função `log_event()` (SECURITY DEFINER)
- ✅ Usa função `set_updated_at()` de 0001
- ✅ Cria policies RLS
- **Dependências:** ✅ 0001 (profiles), ✅ 0002 (job_status, event_type)

#### 0009_operator_update_guards.sql
- ✅ Cria função `is_operator()` (usa `profiles`)
- ✅ Cria função `guard_documents_operator_update()` (usa `documents`)
- ✅ Cria função `guard_orders_operator_update()` (usa `orders`)
- ✅ Cria função `guard_conversations_operator_update()` (usa `conversations`)
- ✅ Cria triggers nas tabelas acima
- **Dependências:** ✅ 0001 (profiles), ✅ 0004 (documents), ✅ 0006 (orders), ✅ 0007 (conversations)

#### 0010_family_members_visibility_hardening.sql
- ✅ Ajusta policy `family_members_client_select`
- ✅ Mantém policies de INSERT/DELETE inalteradas
- **Dependências:** ✅ 0003 (family_members, family_groups)

#### 0011_audit_log_event_hardening.sql
- ✅ Reatribui função `log_event()` com:
  - `SET search_path = pg_catalog, public`
  - Proteção contra forjamento de `user_id`
- **Dependências:** ✅ 0008 (event_log, event_type)

#### 0012_add_tasks_order_id_fk.sql
- ✅ Adiciona FK `tasks.order_id` → `orders.id`
- ✅ Adiciona índice `idx_tasks_order_id`
- **Dependências:** ✅ 0005 (tasks), ✅ 0006 (orders)

---

## 3. Verificação de 0009_operator_update_guards.sql

### ✅ Checklist 0009

- ✅ Função `is_operator()` referencia `profiles` (existe em 0001)
- ✅ Trigger `guard_documents_operator_update` referencia:
  - ✅ `documents.owner_id` (existe em 0004)
  - ✅ `documents.family_group_id` (existe em 0004)
  - ✅ `documents.partner_id` (existe em 0004)
- ✅ Trigger `guard_orders_operator_update` referencia:
  - ✅ `orders.owner_id` (existe em 0006)
  - ✅ `orders.partner_id` (existe em 0006)
  - ✅ `orders.total_amount_cents` (existe em 0006)
- ✅ Trigger `guard_conversations_operator_update` referencia:
  - ✅ `conversations.owner_id` (existe em 0007)
  - ✅ `conversations.partner_id` (existe em 0007)

**Status:** ✅ **OK** - Todas as referências são válidas.

---

## 4. Verificação de Compatibilidade 0010 e 0011

### ✅ Checklist 0010

- ✅ Policy `family_members_client_select` existe em 0003 (será substituída)
- ✅ Referencia `family_groups` (existe em 0003)
- ✅ Referencia `family_members` (existe em 0003)
- ✅ Usa `auth.uid()` (padrão do sistema)
- ✅ Mantém policies de INSERT/DELETE inalteradas

**Status:** ✅ **OK** - Compatível com estado atual.

### ✅ Checklist 0011

- ✅ Função `log_event()` existe em 0008 (será substituída)
- ✅ Assinatura mantida (mesmos parâmetros)
- ✅ Referencia `event_log` (existe em 0008)
- ✅ Referencia `event_type` enum (existe em 0002)
- ✅ Usa `auth.uid()` (padrão do sistema)
- ✅ Mantém `SECURITY DEFINER`

**Status:** ✅ **OK** - Compatível com estado atual.

---

## 5. Análise de Gaps e Problemas

### ⚠️ Problemas Identificados

#### 1. Migration 0012 corrige gap intencional
- **Problema:** `tasks.order_id` foi criado em 0005 sem FK
- **Solução:** Migration 0012 adiciona FK corretamente
- **Status:** ✅ **OK** - Gap foi identificado e corrigido

#### 2. Migration remote_schema.sql está vazia
- **Problema:** Arquivo existe mas está vazio
- **Impacto:** Nenhum (arquivo vazio é ignorado)
- **Ação:** Manter como está ou remover se não for necessário

### ✅ Sem Duplicações
- Nenhuma migration duplicada encontrada
- Todas as policies usam `DROP POLICY IF EXISTS` antes de `CREATE POLICY`
- Todas as funções usam `CREATE OR REPLACE FUNCTION`
- Todos os triggers usam `DROP TRIGGER IF EXISTS` antes de `CREATE TRIGGER`

### ✅ Sem Gaps Críticos
- Todas as dependências estão satisfeitas
- Todas as tabelas têm RLS habilitado
- Todas as tabelas têm policies apropriadas
- FK faltante em 0005 foi corrigida em 0012

---

## 6. Plano de Aplicação em Lotes

### 📦 Lote 1: Base + Enums + Family (0001-0003)

**Migrations:**
- `20260125182409_0001_rbac_and_profiles.sql`
- `20260125200000_0002_enums.sql`
- `20260125200001_0003_family_groups.sql`

**Comando:**
```bash
supabase migration up --include-all
# Ou aplicar manualmente:
supabase db push
```

**Validação:**
```sql
-- Verificar se profiles existe
SELECT COUNT(*) FROM public.profiles;

-- Verificar se enums existem
SELECT typname FROM pg_type WHERE typname IN ('app_role', 'document_status', 'order_status', 'task_status', 'task_priority', 'job_status', 'event_type');

-- Verificar se family_groups existe
SELECT COUNT(*) FROM public.family_groups;
```

---

### 📦 Lote 2: Documents + Tasks + Orders (0004-0006)

**Migrations:**
- `20260125200002_0004_documents.sql`
- `20260125200003_0005_reminders_tasks.sql`
- `20260125200004_0006_orders.sql`

**Comando:**
```bash
supabase migration up --include-all
# Ou aplicar manualmente:
supabase db push
```

**Validação:**
```sql
-- Verificar se documents existe
SELECT COUNT(*) FROM public.documents;

-- Verificar se tasks existe (sem FK order_id ainda)
SELECT COUNT(*) FROM public.tasks;

-- Verificar se orders existe
SELECT COUNT(*) FROM public.orders;
```

---

### 📦 Lote 3: Conversations + Jobs/Audit (0007-0008)

**Migrations:**
- `20260125200005_0007_conversations.sql`
- `20260125200006_0008_jobs_audit.sql`

**Comando:**
```bash
supabase migration up --include-all
# Ou aplicar manualmente:
supabase db push
```

**Validação:**
```sql
-- Verificar se conversations existe
SELECT COUNT(*) FROM public.conversations;

-- Verificar se jobs, event_log existem
SELECT COUNT(*) FROM public.jobs;
SELECT COUNT(*) FROM public.event_log;

-- Testar função log_event
SELECT public.log_event('create', 'test', NULL, NULL, NULL, NULL, NULL);
```

---

### 📦 Lote 4: Hardening + Correções (0009-0012)

**Migrations:**
- `20260125200007_0009_operator_update_guards.sql`
- `20260125220000_0010_family_members_visibility_hardening.sql`
- `20260125220001_0011_audit_log_event_hardening.sql`
- `20260125220002_0012_add_tasks_order_id_fk.sql`

**Comando:**
```bash
supabase migration up --include-all
# Ou aplicar manualmente:
supabase db push
```

**Validação:**
```sql
-- Verificar se triggers existem
SELECT trigger_name FROM information_schema.triggers 
WHERE trigger_name LIKE 'trg_guard%';

-- Verificar se FK tasks.order_id existe
SELECT constraint_name FROM information_schema.table_constraints 
WHERE table_name = 'tasks' AND constraint_type = 'FOREIGN KEY' 
AND constraint_name = 'fk_tasks_order_id';

-- Testar função log_event (deve usar auth.uid() se autenticado)
SELECT public.log_event('create', 'test', NULL, NULL, NULL, NULL, NULL);
```

---

## 7. Sugestões de Ajustes (Opcional)

### ✅ Nenhum Ajuste Necessário

Todas as migrations estão:
- ✅ Em ordem correta
- ✅ Sem dependências quebradas
- ✅ Sem duplicações
- ✅ Sem gaps críticos
- ✅ Compatíveis entre si

**Recomendação:** Aplicar migrations em lotes conforme plano acima.

---

## 8. Comandos CLI para Verificação

### Verificar status das migrations no remoto:
```bash
supabase migration list
```

### Aplicar todas as migrations:
```bash
supabase db push
```

### Aplicar migrations até um ponto específico:
```bash
supabase migration up --target <timestamp>
```

### Verificar diferenças entre local e remoto:
```bash
supabase db diff
```

---

## 9. Resumo Executivo

| Item | Status | Observações |
|------|--------|-------------|
| **Ordem das migrations** | ✅ OK | Todas em ordem cronológica |
| **Dependências** | ✅ OK | Todas satisfeitas |
| **0009 (guards)** | ✅ OK | Todas as referências válidas |
| **0010 (hardening)** | ✅ OK | Compatível com estado atual |
| **0011 (hardening)** | ✅ OK | Compatível com estado atual |
| **0012 (FK fix)** | ✅ OK | Corrige gap intencional |
| **Duplicações** | ✅ OK | Nenhuma encontrada |
| **Gaps críticos** | ✅ OK | Nenhum encontrado |

**Conclusão:** ✅ **Todas as migrations estão prontas para aplicação em produção.**

---

## 10. Próximos Passos

1. ✅ Executar `supabase migration list` para verificar status remoto
2. ✅ Aplicar migrations em lotes conforme plano (se não aplicadas)
3. ✅ Validar cada lote após aplicação
4. ✅ Executar testes de segurança (ver `docs/DB_TESTING_V1.sql`)

---

**Fim do Relatório**
