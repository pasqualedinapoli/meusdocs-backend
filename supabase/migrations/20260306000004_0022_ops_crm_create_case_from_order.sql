-- 0022_ops_crm_create_case_from_order.sql
-- Função idempotente para criar/atualizar case e gerar itens + tasks + doc requests

create or replace function public.ops_create_case_from_order(p_order_id uuid)
returns uuid
language plpgsql
security definer
as $$
declare
  v_owner_id uuid;
  v_case_id uuid;
  v_has_tse boolean := false;
begin
  -- pega owner do order
  select owner_id into v_owner_id
  from public.orders
  where id = p_order_id;

  if v_owner_id is null then
    raise exception 'order not found: %', p_order_id;
  end if;

  -- upsert case por order_id
  insert into public.cases (order_id, owner_id, status, priority, campaign_tag, metadata)
  values (p_order_id, v_owner_id, 'new', 'normal', null, jsonb_build_object('source','ops_create_case_from_order'))
  on conflict (order_id)
  do update set
    owner_id = excluded.owner_id,
    updated_at = now()
  returning id into v_case_id;

  -- cria/atualiza case_items a partir de order_items
  insert into public.case_items (case_id, order_item_id, service_slug, service_title, quantity, status, priority, metadata)
  select
    v_case_id,
    oi.id,
    oi.service_slug,
    oi.service_title,
    oi.quantity,
    'new'::case_item_status,
    'normal',
    coalesce(oi.metadata, '{}'::jsonb)
  from public.order_items oi
  where oi.order_id = p_order_id
  on conflict (order_item_id)
  do update set
    case_id = excluded.case_id,
    service_slug = excluded.service_slug,
    service_title = excluded.service_title,
    quantity = excluded.quantity,
    updated_at = now();

  -- detectar se tem TSE para aplicar campaign tag
  select exists (
    select 1 from public.order_items oi
    where oi.order_id = p_order_id
      and oi.service_slug = 'regularizacao-transferencia-titulo-eleitoral'
  ) into v_has_tse;

  if v_has_tse then
    update public.cases
      set campaign_tag = 'tse_2026'
    where id = v_case_id;
  end if;

  -- gerar document_requests a partir dos templates (somente se não existirem)
  insert into public.document_requests (case_item_id, owner_id, doc_type, title, instructions, status)
  select
    ci.id,
    v_owner_id,
    drt.doc_type,
    drt.title,
    drt.instructions,
    'required'::doc_request_status
  from public.case_items ci
  join public.document_request_templates drt
    on drt.service_slug = ci.service_slug
  left join public.document_requests dr
    on dr.case_item_id = ci.id and dr.doc_type = drt.doc_type
  where ci.case_id = v_case_id
    and dr.id is null;

  -- gerar tasks a partir dos templates (criamos tasks vinculadas a case/case_item/order)
  insert into public.tasks (owner_id, assigned_to, order_id, title, description, status, priority, due_date, metadata, case_id, case_item_id)
  select
    v_owner_id,
    null::uuid,
    p_order_id,
    tt.title,
    tt.description,
    'todo'::task_status,
    tt.default_priority::task_priority,
    case
      when tt.default_due_days is null then null
      else now() + make_interval(days => tt.default_due_days)
    end,
    coalesce(tt.metadata, '{}'::jsonb),
    v_case_id,
    ci.id
  from public.case_items ci
  join public.task_templates tt
    on tt.service_slug = ci.service_slug
  left join public.tasks t
    on t.case_item_id = ci.id and t.title = tt.title
  where ci.case_id = v_case_id
    and t.id is null;

  return v_case_id;
end $$;

-- Permitir chamada pelos operadores (e futuramente webhook server-side)
grant execute on function public.ops_create_case_from_order(uuid) to authenticated;