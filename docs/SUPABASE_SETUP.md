# Supabase Setup - MEUS DOCS V1

## 📦 Instalação

### 1. Instalar Dependências

```bash
npm install @supabase/supabase-js @supabase/ssr
```

### 2. Configurar Variáveis de Ambiente

Crie um arquivo `.env.local` na raiz do projeto:

```env
# Públicas (seguras para client-side)
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key-here

# Privada (NUNCA expor no client!)
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here
```

**Onde encontrar as chaves:**
1. Acesse o [Dashboard do Supabase](https://app.supabase.com)
2. Selecione seu projeto
3. Vá em **Settings** → **API**
4. Copie:
   - **Project URL** → `NEXT_PUBLIC_SUPABASE_URL`
   - **anon public** key → `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - **service_role** key → `SUPABASE_SERVICE_ROLE_KEY` (⚠️ manter secreto!)

---

## 🧪 Testes

### Teste 1: Verificar Cliente Browser

```tsx
// app/test-browser/page.tsx
'use client';

import { createBrowserSupabaseClient } from '@/lib/db';
import { useEffect, useState } from 'react';

export default function TestBrowserPage() {
  const [user, setUser] = useState<any>(null);

  useEffect(() => {
    const supabase = createBrowserSupabaseClient();
    supabase.auth.getUser().then(({ data }) => {
      setUser(data.user);
    });
  }, []);

  return (
    <div>
      <h1>Test Browser Client</h1>
      <pre>{JSON.stringify(user, null, 2)}</pre>
    </div>
  );
}
```

**Acesse:** `http://localhost:3000/test-browser`

### Teste 2: Verificar Cliente Server

```tsx
// app/test-server/page.tsx
import { createServerSupabaseClient } from '@/lib/db';

export default async function TestServerPage() {
  const supabase = await createServerSupabaseClient();
  const { data: { user } } = await supabase.auth.getUser();

  return (
    <div>
      <h1>Test Server Client</h1>
      <pre>{JSON.stringify(user, null, 2)}</pre>
    </div>
  );
}
```

**Acesse:** `http://localhost:3000/test-server`

### Teste 3: Criar Family Group (API Route)

```tsx
// app/api/test/family-group/route.ts
import { createFamilyGroup } from '@/lib/db/examples';
import { NextResponse } from 'next/server';

export async function POST(req: Request) {
  try {
    const { name, description } = await req.json();
    const result = await createFamilyGroup(name, description);

    if (result.error) {
      return NextResponse.json(
        { error: result.error.message },
        { status: 400 }
      );
    }

    return NextResponse.json({ data: result.data });
  } catch (error) {
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
```

**Teste com curl:**

```bash
# Primeiro, faça login para obter sessão
# Depois:
curl -X POST http://localhost:3000/api/test/family-group \
  -H "Content-Type: application/json" \
  -d '{"name": "Minha Família", "description": "Grupo familiar"}'
```

### Teste 4: Listar Orders (API Route)

```tsx
// app/api/test/orders/route.ts
import { listUserOrders } from '@/lib/db/examples';
import { NextResponse } from 'next/server';

export async function GET(req: Request) {
  try {
    const { searchParams } = new URL(req.url);
    const status = searchParams.get('status');

    const result = await listUserOrders(status || undefined);

    if (result.error) {
      return NextResponse.json(
        { error: result.error.message },
        { status: 400 }
      );
    }

    return NextResponse.json({ data: result.data });
  } catch (error) {
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
```

**Teste com curl:**

```bash
curl http://localhost:3000/api/test/orders
curl http://localhost:3000/api/test/orders?status=pending
```

### Teste 5: RBAC Helpers

```tsx
// app/api/test/rbac/route.ts
import { createServerSupabaseClient } from '@/lib/db';
import { isOperator, assertProfileOperator } from '@/lib/rbac';
import { NextResponse } from 'next/server';

export async function GET() {
  try {
    const supabase = await createServerSupabaseClient();
    const { data: { user } } = await supabase.auth.getUser();

    if (!user) {
      return NextResponse.json({ error: 'Not authenticated' }, { status: 401 });
    }

    const { data: profile } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single();

    if (!profile) {
      return NextResponse.json({ error: 'Profile not found' }, { status: 404 });
    }

    // Teste 1: isOperator
    const isOp = isOperator(profile.role);

    // Teste 2: assertOperator (pode lançar erro)
    try {
      assertProfileOperator(profile);
      return NextResponse.json({
        isOperator: isOp,
        role: profile.role,
        message: 'User is operator',
      });
    } catch (error) {
      return NextResponse.json({
        isOperator: isOp,
        role: profile.role,
        message: 'User is not operator',
      });
    }
  } catch (error) {
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
```

**Teste com curl:**

```bash
curl http://localhost:3000/api/test/rbac
```

---

## 🔍 Verificação de Segurança

### 1. Verificar que Service Role não está exposta

```bash
# Build do projeto
npm run build

# Verificar se SERVICE_ROLE_KEY aparece no bundle
grep -r "SERVICE_ROLE_KEY" .next/ || echo "✅ Service Role Key não encontrada no bundle"
```

### 2. Verificar RLS

```bash
# Usar Supabase CLI para testar policies
supabase db test
```

### 3. Verificar Variáveis de Ambiente

```tsx
// app/api/test/env/route.ts
import { NextResponse } from 'next/server';

export async function GET() {
  return NextResponse.json({
    hasPublicUrl: !!process.env.NEXT_PUBLIC_SUPABASE_URL,
    hasAnonKey: !!process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
    hasServiceRole: !!process.env.SUPABASE_SERVICE_ROLE_KEY,
    // ⚠️ NUNCA retornar valores reais!
  });
}
```

---

## 📝 Checklist de Setup

- [ ] Dependências instaladas (`@supabase/supabase-js`, `@supabase/ssr`)
- [ ] Variáveis de ambiente configuradas (`.env.local`)
- [ ] `NEXT_PUBLIC_SUPABASE_URL` configurado
- [ ] `NEXT_PUBLIC_SUPABASE_ANON_KEY` configurado
- [ ] `SUPABASE_SERVICE_ROLE_KEY` configurado (e não exposto)
- [ ] Testes básicos funcionando
- [ ] RLS habilitado no banco
- [ ] Policies testadas

---

## 🚀 Próximos Passos

1. **Implementar autenticação** (login/signup)
2. **Criar middleware** para proteger rotas
3. **Implementar Server Actions** para operações CRUD
4. **Adicionar validação** com Zod ou similar
5. **Configurar event logging** para auditoria

---

## 🆘 Troubleshooting

### Erro: "Missing NEXT_PUBLIC_SUPABASE_URL"

**Solução:** Verifique se o arquivo `.env.local` existe e tem as variáveis corretas.

### Erro: "User not authenticated"

**Solução:** Certifique-se de que o usuário está logado. Use `supabase.auth.getUser()` para verificar.

### Erro: "Access denied"

**Solução:** Verifique se as policies RLS estão corretas e se o usuário tem permissão para acessar o recurso.

### Erro: "Profile not found"

**Solução:** Certifique-se de que o profile foi criado após o registro do usuário (trigger ou migration).

---

## 📚 Referências

- [Supabase Next.js Guide](https://supabase.com/docs/guides/getting-started/quickstarts/nextjs)
- [Supabase SSR](https://supabase.com/docs/guides/auth/server-side/creating-a-client)
- [Row Level Security](https://supabase.com/docs/guides/auth/row-level-security)