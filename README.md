# MEUS DOCS — Backend Supabase

Este repo é a **fonte da verdade** do banco (Supabase) do MEUS DOCS. O site (meusdocs-site) consome o mesmo projeto Supabase e não deve receber novas migrations; migrations e documentação de contrato ficam aqui.

## Estrutura

- `supabase/migrations/` — Migrations SQL (ordem por timestamp no nome).
- `supabase/migrations_archive/` — Migrations arquivadas (ex.: não aplicadas em produção).
- `docs/` — Documentação de banco: contrato, RLS, segurança, setup, testes.

## Como aplicar migrations

Requisito: [Supabase CLI](https://supabase.com/docs/guides/cli) instalado e linkado ao projeto.

```bash
# Linkar ao projeto (uma vez)
supabase link --project-ref <SEU_PROJECT_REF>

# Aplicar todas as migrations pendentes
supabase db push

# Ou, em ambiente local (Supabase local)
supabase start
supabase db reset   # aplica migrations do zero
```

Para criar uma nova migration:

```bash
supabase migration new nome_da_mudanca
# Editar o arquivo em supabase/migrations/
supabase db push
```

## Como rodar testes RLS

Os testes de RLS estão documentados no site (meusdocs-site); o schema e as policies vêm deste repo. Para rodar a partir do **site** (recomendado, pois usa o mesmo código e env):

```bash
# No repo meusdocs-site, com .env.local configurado (SUPABASE_* e usuários de teste)
npm run test:rls
# ou
node scripts/test-family-rls.mjs
```

Se este repo tiver uma cópia do script ou um wrapper, use-o da mesma forma, garantindo que `SUPABASE_URL`, `SUPABASE_ANON_KEY` e `SUPABASE_SERVICE_ROLE_KEY` (e usuários de teste, se necessário) estejam configurados.

## Documentação

- `docs/DB_CONTRACT.md` — Contrato das tabelas e policies.
- `docs/TESTING_RLS.md` — Como testar RLS.
- `docs/MIGRATION_REVIEW_V1.md` — Revisão das migrations V1.
- `docs/SECURITY.md` — Segurança e RLS.
- `docs/SUPABASE_SETUP.md` — Setup do Supabase.
- `docs/SUPABASE_INTEGRATION_SUMMARY.md` — Resumo da integração.
