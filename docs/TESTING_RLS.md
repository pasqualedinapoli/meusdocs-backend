# Testes de RLS (Row Level Security)

Este documento descreve os testes automatizados de RLS para validar comportamentos críticos e prevenir regressões.

## 📋 Checklist de Testes

O script `scripts/test-family-rls.mjs` valida:

### ✅ Family Groups & Members (Anti-Loop)
- [x] Cliente cria family_group (owner_id correto)
- [x] Cliente vê seu próprio grupo (owner direto)
- [x] Cliente isolado NÃO vê grupos de outros clientes
- [x] Cliente (owner) adiciona membros ao grupo
- [x] Cliente (membro) vê o grupo via `can_access_family_group` (anti-loop)
- [x] Cliente (owner) vê TODOS os membros do grupo
- [x] Cliente (membro) vê APENAS sua própria linha (anti-loop)
- [x] Cliente (membro) NÃO pode adicionar membros (apenas owner)

### ✅ Operador (SELECT Global)
- [x] Operador vê TODOS os grupos (SELECT global)
- [x] Operador vê TODOS os membros (SELECT global)

### ✅ Guards de Campos Sensíveis
- [x] Operador NÃO pode alterar `owner_id` de documentos (trigger guard)
- [x] Operador NÃO pode alterar `family_group_id` de documentos (trigger guard)
- [x] Operador NÃO pode alterar `partner_id` de documentos (trigger guard)
- [x] Operador PODE alterar campos não sensíveis (status, description, metadata)

### ✅ Funções Helper (Anti-Loop)
- [x] `is_family_group_owner()` existe e funciona (SECURITY DEFINER)
- [x] `is_family_group_member()` existe e funciona (SECURITY DEFINER)
- [x] `can_access_family_group()` existe e funciona (SECURITY DEFINER)

## 🚀 Como Executar

### Pré-requisitos

1. **Variáveis de ambiente** (`.env.local`):
   ```bash
   NEXT_PUBLIC_SUPABASE_URL=https://seu-projeto.supabase.co
   NEXT_PUBLIC_SUPABASE_ANON_KEY=sua-anon-key
   SUPABASE_SERVICE_ROLE_KEY=sua-service-role-key  # Obrigatória para criar usuários de teste
   ```

2. **Usuário operador** (opcional):
   ```bash
   TEST_OPERATOR_EMAIL=operator@example.com
   TEST_OPERATOR_PASSWORD=senha-do-operator
   # OU usar OP_EMAIL e OP_PASSWORD (fallback)
   ```

3. **Migrations aplicadas**:
   - Todas as migrations do Supabase devem estar aplicadas
   - Especialmente: `0014_family_rls_anti_loop.sql` e `0015_family_rls_verification_fix.sql`

### Execução Básica

```bash
# Via npm script (recomendado)
npm run test:rls

# Ou diretamente
node scripts/test-family-rls.mjs
```

### Execução com Limpeza

Para remover dados de teste após execução:

```bash
CLEANUP=true node scripts/test-family-rls.mjs
```

### Execução com Debug

Para ver stack traces completos em caso de falha:

```bash
DEBUG=true node scripts/test-family-rls.mjs
```

## 📊 Saída Esperada

### ✅ Sucesso

```
======================================================================
TESTES DE RLS: Family Groups & Members (Anti-Loop)
======================================================================

✅ PASS: Setup: criar/obter usuários de teste
✅ PASS: Setup: autenticar clientes e operador
✅ PASS: 1.1: Cliente1 cria family_group
✅ PASS: 1.2: Cliente1 vê seu próprio grupo (owner direto)
✅ PASS: 1.3: Cliente2 NÃO vê grupo do Cliente1 (isolamento)
✅ PASS: 2.1: Cliente1 adiciona Cliente2 como membro
✅ PASS: 2.2: Cliente2 (membro) vê o grupo via can_access_family_group (anti-loop)
✅ PASS: 2.3: Cliente1 (owner) vê TODOS os membros do grupo
✅ PASS: 2.4: Cliente2 (membro) vê APENAS sua própria linha (anti-loop)
✅ PASS: 2.5: Cliente2 NÃO pode adicionar membros (apenas owner)
✅ PASS: 3.1: Operador vê TODOS os grupos (SELECT global)
✅ PASS: 3.2: Operador vê TODOS os membros (SELECT global)
✅ PASS: 4.1: Setup: Cliente1 cria documento
✅ PASS: 4.2: Operador NÃO pode alterar owner_id de documento (guard)
✅ PASS: 4.3: Operador PODE alterar campos não sensíveis (status, description)
✅ PASS: 5.1: Função is_family_group_owner existe e funciona
✅ PASS: 5.2: Função is_family_group_member existe e funciona
✅ PASS: 5.3: Função can_access_family_group existe e funciona

======================================================================
RESUMO
======================================================================
Total: 18 testes
✅ Passou: 18
❌ Falhou: 0

🎯 Todos os testes passaram!
```

**Exit code:** `0`

### ❌ Falha

```
❌ FAIL: 1.3: Cliente2 NÃO vê grupo do Cliente1 (isolamento)
   Erro: Cliente2 conseguiu ver grupo do Cliente1 (violação de RLS)

======================================================================
RESUMO
======================================================================
Total: 18 testes
✅ Passou: 17
❌ Falhou: 1

Falhas:
  - 1.3: Cliente2 NÃO vê grupo do Cliente1 (isolamento): Cliente2 conseguiu ver grupo do Cliente1 (violação de RLS)
```

**Exit code:** `1`

### ⚠️ Erro Fatal

```
❌ Erro fatal durante execução dos testes:
Error: SERVICE_ROLE_KEY necessária para criar usuários de teste
```

**Exit code:** `99`

## 🔍 Interpretação de Resultados

### Exit Codes

- `0`: Todos os testes passaram ✅
- `1`: Um ou mais testes falharam ❌
- `99`: Erro fatal (setup/configuração) ⚠️

### Tipos de Falha

1. **Violação de RLS**: Cliente conseguiu acessar recurso de outro cliente
2. **Violação de Guard**: Operador conseguiu alterar campo sensível
3. **Recursão Infinita**: Erro "infinite recursion detected in policy"
4. **Função Helper**: Função SECURITY DEFINER não existe ou não funciona

## 🛠️ Troubleshooting

### Erro: "SERVICE_ROLE_KEY necessária"

**Causa:** Variável `SUPABASE_SERVICE_ROLE_KEY` não encontrada no `.env.local`

**Solução:**
1. Verificar se `.env.local` existe e contém a variável
2. Obter SERVICE_ROLE_KEY no dashboard do Supabase (Settings → API)

### Erro: "infinite recursion detected in policy"

**Causa:** Policies antigas ainda estão ativas (migration 0014 não foi aplicada)

**Solução:**
1. Verificar se migrations `0014` e `0015` foram aplicadas
2. Executar manualmente:
   ```bash
   supabase migration up
   ```

### Erro: "function does not exist"

**Causa:** Funções helper não foram criadas (migration 0014 não aplicada)

**Solução:**
1. Verificar se migration `0014_family_rls_anti_loop.sql` foi aplicada
2. Verificar funções manualmente:
   ```sql
   SELECT proname FROM pg_proc
   WHERE proname IN ('is_family_group_owner', 'is_family_group_member', 'can_access_family_group')
     AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
   ```

### Teste falha mas comportamento parece correto

**Causa:** Dados de teste antigos podem estar interferindo

**Solução:**
1. Executar com `CLEANUP=true` para limpar dados de teste
2. Ou limpar manualmente:
   ```sql
   DELETE FROM family_members WHERE family_group_id IN (
     SELECT id FROM family_groups WHERE name LIKE 'Família Teste%'
   );
   DELETE FROM family_groups WHERE name LIKE 'Família Teste%';
   ```

## 📝 Notas Importantes

1. **Idempotência**: Os testes são idempotentes (podem ser executados múltiplas vezes)
2. **Isolamento**: Cada execução cria usuários de teste únicos (timestamp no email)
3. **Limpeza**: Por padrão, dados de teste NÃO são removidos (permitir inspeção manual)
4. **Segurança**: Nunca executar em produção sem `CLEANUP=true` ou revisão cuidadosa

## 🔗 Referências

- [Migration 0014: Family RLS Anti-Loop](../supabase/migrations/20260126000000_0014_family_rls_anti_loop.sql)
- [Migration 0015: Family RLS Verification Fix](../supabase/migrations/20260126000001_0015_family_rls_verification_fix.sql)
- [Migration 0009: Operator Update Guards](../supabase/migrations/20260125200007_0009_operator_update_guards.sql)
- [DB Contract](./DB_CONTRACT.md)
