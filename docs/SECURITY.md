# Security - MEUS DOCS V1

## Visão Geral

Este documento descreve as práticas de segurança para integração do Supabase com Next.js App Router.

---

## 🔑 Variáveis de Ambiente

### Públicas (Client-Side Safe)

Estas variáveis são expostas no client-side e são **seguras** porque o Supabase usa RLS (Row Level Security) para proteger os dados.

```env
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
```

**Por que são seguras?**
- `NEXT_PUBLIC_SUPABASE_URL`: Apenas a URL do projeto (pública)
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`: RLS garante que apenas dados permitidos sejam acessíveis
- Mesmo que alguém veja essas chaves, não consegue acessar dados não autorizados

### Privadas (Server-Side Only)

```env
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

**⚠️ CRÍTICO:**
- **NUNCA** expor no client-side
- **NUNCA** commitar no git
- Usar apenas em server-side com extrema cautela
- Bypassa RLS completamente - acesso total ao banco

---

## 🔐 Sessão e Autenticação

### Como Funciona

1. **Login/Auth**: Supabase gerencia sessão via cookies HTTP-only
2. **Cookies**: Armazenados automaticamente pelo `@supabase/ssr`
3. **RLS**: Políticas no banco garantem acesso apenas aos dados permitidos
4. **Middleware**: Pode verificar autenticação sem fazer queries ao banco

### Fluxo de Autenticação

```
1. Usuário faz login → Supabase cria sessão
2. Cookie HTTP-only é setado automaticamente
3. Próximas requisições incluem cookie
4. Supabase valida cookie e identifica usuário
5. RLS aplica policies baseado em auth.uid()
```

### Verificação de Sessão

```tsx
// Server Component / Server Action
const supabase = await createServerSupabaseClient();
const { data: { user } } = await supabase.auth.getUser();

if (!user) {
  // Usuário não autenticado
}
```

---

## 🛡️ Row Level Security (RLS)

### O que é RLS?

RLS é uma camada de segurança no PostgreSQL que filtra linhas baseado em policies. Mesmo que alguém tenha a `ANON_KEY`, só acessa dados permitidos.

### Policies Implementadas

**CLIENTE:**
- Acesso apenas a registros com `owner_id = auth.uid()`
- Acesso a `family_groups` onde é owner ou membro
- Sem acesso a `jobs`, `idempotency_keys`, `event_log`

**OPERADOR:**
- SELECT global (pode ler todos os registros)
- UPDATE apenas campos não sensíveis (enforcement via triggers)
- DELETE não permitido (sem policies de DELETE)

### Verificação de Acesso

```tsx
// Exemplo: Verificar acesso antes de operação
import { canAccessResource } from '@/lib/rbac';

const hasAccess = canAccessResource(
  profile.role,
  user.id,
  document.owner_id
);

if (!hasAccess) {
  throw new Error('Access denied');
}
```

---

## 🚫 O que NUNCA fazer

### ❌ Expor Service Role Key

```tsx
// ❌ ERRADO - NUNCA fazer isso
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY // ⚠️ NUNCA no client!
);
```

### ❌ Usar Service Role sem Necessidade

```tsx
// ❌ ERRADO - Usar service role quando anon key + RLS é suficiente
const supabase = createServiceRoleSupabaseClient();
const { data } = await supabase.from('documents').select('*');
```

### ❌ Confiar Apenas em Client-Side

```tsx
// ❌ ERRADO - Verificação apenas no client
'use client';
if (user.role === 'operator') {
  // Operação sensível
}
```

**Solução:** Sempre verificar no server-side também.

### ❌ Hardcode de Secrets

```tsx
// ❌ ERRADO
const key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
```

**Solução:** Sempre usar variáveis de ambiente.

---

## ✅ Boas Práticas

### 1. Usar Clientes Corretos

```tsx
// ✅ Client Component
'use client';
const supabase = createBrowserSupabaseClient();

// ✅ Server Component / Server Action
const supabase = await createServerSupabaseClient();

// ✅ Middleware
const supabase = createMiddlewareSupabaseClient();
```

### 2. Verificar Autenticação

```tsx
// ✅ Sempre verificar antes de operações sensíveis
const { data: { user } } = await supabase.auth.getUser();
if (!user) {
  throw new Error('Not authenticated');
}
```

### 3. Usar RBAC Helpers

```tsx
// ✅ Usar helpers do lib/rbac
import { assertProfileOperator } from '@/lib/rbac';

export async function adminFunction(profile: Profile | null) {
  assertProfileOperator(profile);
  // Código seguro...
}
```

### 4. Validar Inputs

```tsx
// ✅ Validar inputs antes de inserir no banco
if (!name || name.length < 3) {
  throw new Error('Invalid name');
}
```

### 5. Tratar Erros

```tsx
// ✅ Tratar erros adequadamente
try {
  const { data, error } = await supabase.from('documents').insert(...);
  if (error) {
    // Log error, retornar mensagem genérica ao usuário
    console.error('Database error:', error);
    throw new Error('Failed to create document');
  }
} catch (error) {
  // Não expor detalhes internos
}
```

---

## 🔍 Auditoria

### Event Log

Todas as operações sensíveis devem ser logadas:

```tsx
// Usar função helper do banco
await supabase.rpc('log_event', {
  p_event_type: 'create',
  p_resource_type: 'document',
  p_resource_id: documentId,
  p_user_id: user.id,
});
```

### Acesso ao Event Log

- **CLIENTE:** Sem acesso
- **OPERADOR:** Pode ler todos os eventos

---

## 📝 Checklist de Segurança

Antes de fazer deploy:

- [ ] Todas as variáveis de ambiente estão configuradas
- [ ] `SUPABASE_SERVICE_ROLE_KEY` não está exposta no client
- [ ] RLS está habilitado em todas as tabelas sensíveis
- [ ] Policies estão testadas e funcionando
- [ ] Verificações de autenticação estão em todos os endpoints
- [ ] RBAC helpers estão sendo usados
- [ ] Erros não expõem informações sensíveis
- [ ] Inputs estão sendo validados
- [ ] Event log está sendo usado para auditoria

---

## 🧪 Testes de Segurança

### Testar RLS

```bash
# Como cliente
curl -H "Authorization: Bearer $ANON_KEY" \
  https://your-project.supabase.co/rest/v1/documents

# Deve retornar apenas documentos do usuário autenticado
```

### Testar Service Role (Apenas em ambiente isolado!)

```bash
# ⚠️ CUIDADO: Isso bypassa RLS
curl -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  https://your-project.supabase.co/rest/v1/documents

# Retorna TODOS os documentos (por isso é perigoso)
```

---

## 📚 Referências

- [Supabase Security Best Practices](https://supabase.com/docs/guides/auth/row-level-security)
- [Next.js Environment Variables](https://nextjs.org/docs/app/building-your-application/configuring/environment-variables)
- [Supabase SSR Guide](https://supabase.com/docs/guides/auth/server-side/creating-a-client)

---

## 🆘 Em Caso de Vazamento

1. **Rotacionar chaves imediatamente** no dashboard do Supabase
2. **Revisar logs** para identificar acessos não autorizados
3. **Notificar usuários** se dados sensíveis foram expostos
4. **Atualizar variáveis de ambiente** em todos os ambientes
5. **Revisar código** para identificar a causa do vazamento