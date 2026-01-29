-- 0012 Add tasks.order_id Foreign Key (V1: corrigir FK faltante)

-- Adicionar Foreign Key de tasks.order_id para orders.id
-- Nota: Migration 0005 criou order_id sem FK, prometendo adicionar em 0006, mas não foi feito.
-- Esta migration corrige esse gap para garantir integridade referencial.
alter table public.tasks
add constraint fk_tasks_order_id
foreign key (order_id) references public.orders(id) on delete set null;

-- Índice para performance de JOINs (se não existir)
create index if not exists idx_tasks_order_id on public.tasks(order_id);
