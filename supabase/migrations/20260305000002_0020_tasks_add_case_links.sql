-- 0020_tasks_add_case_links.sql
-- Link seguro (aditivo) entre tasks e ops crm

alter table public.tasks
add column if not exists case_id uuid references public.cases(id) on delete set null;

alter table public.tasks
add column if not exists case_item_id uuid references public.case_items(id) on delete set null;

create index if not exists idx_tasks_case_id on public.tasks(case_id);
create index if not exists idx_tasks_case_item_id on public.tasks(case_item_id);