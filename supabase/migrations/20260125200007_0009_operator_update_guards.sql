-- 0009 Operator update guards (V1: bloquear UPDATE em colunas sensíveis)

-- Helper: retorna true se o usuário atual é operador (usa auth.uid(), sem gambiarras)
create or replace function public.is_operator()
returns boolean as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role = 'operator'
  );
$$ language sql stable security invoker;

-- Documents: operador não pode alterar owner_id, family_group_id, partner_id
create or replace function public.guard_documents_operator_update()
returns trigger as $$
begin
  if not public.is_operator() then
    return new;
  end if;
  if (old.owner_id is distinct from new.owner_id)
     or (old.family_group_id is distinct from new.family_group_id)
     or (old.partner_id is distinct from new.partner_id) then
    raise exception 'operator cannot change owner_id, family_group_id or partner_id on documents'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$ language plpgsql security invoker;

drop trigger if exists trg_guard_documents_operator_update on public.documents;
create trigger trg_guard_documents_operator_update
before update on public.documents
for each row execute function public.guard_documents_operator_update();

-- Orders: operador não pode alterar owner_id, partner_id, total_amount_cents
create or replace function public.guard_orders_operator_update()
returns trigger as $$
begin
  if not public.is_operator() then
    return new;
  end if;
  if (old.owner_id is distinct from new.owner_id)
     or (old.partner_id is distinct from new.partner_id)
     or (old.total_amount_cents is distinct from new.total_amount_cents) then
    raise exception 'operator cannot change owner_id, partner_id or total_amount_cents on orders'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$ language plpgsql security invoker;

drop trigger if exists trg_guard_orders_operator_update on public.orders;
create trigger trg_guard_orders_operator_update
before update on public.orders
for each row execute function public.guard_orders_operator_update();

-- Conversations: operador não pode alterar owner_id, partner_id
create or replace function public.guard_conversations_operator_update()
returns trigger as $$
begin
  if not public.is_operator() then
    return new;
  end if;
  if (old.owner_id is distinct from new.owner_id)
     or (old.partner_id is distinct from new.partner_id) then
    raise exception 'operator cannot change owner_id or partner_id on conversations'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$ language plpgsql security invoker;

drop trigger if exists trg_guard_conversations_operator_update on public.conversations;
create trigger trg_guard_conversations_operator_update
before update on public.conversations
for each row execute function public.guard_conversations_operator_update();
