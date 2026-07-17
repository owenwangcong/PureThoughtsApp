-- ============================================================================
-- 活动时间表与相关资料(PRD v0.5.12 §5,设计 docs/design/event-agenda.md):
-- 1. event_agenda_items —— 时间表行(支持跨天:day_index + 起讫时间 + 活动 + 可选自由网址)
-- 2. event_attachments  —— 相关资料(管理员上传的 PDF,存 Storage,表内只记元数据)
-- 3. Storage bucket event-files —— 公开可读、仅 App 管理员可写,承载 PDF(大陆可达)
-- 权限一律:anon/authenticated 可读、仅 public.is_app_admin() 可写(与 events 一致)。
-- ============================================================================

-- ---------------------------------------------------------------- 时间表行
create table public.event_agenda_items (
  id         uuid primary key default gen_random_uuid(),
  event_id   uuid not null references public.events(id) on delete cascade,
  day_index  int  not null default 1 check (day_index >= 1), -- 第几天(单日活动恒 1)
  start_time time not null,                 -- 起(现场墙钟时间,不带 tz)
  end_time   time,                          -- 讫(可空:开放式)
  activity   text not null,                 -- 做什么
  link_url   text,                          -- 自由网址(经文等,可空)
  link_label text,                          -- 链接显示文字(可空)
  sort_order int  not null default 0,       -- 同一天内排序
  created_at timestamptz not null default now(),
  check (end_time is null or end_time >= start_time)
);
create index idx_agenda_event on public.event_agenda_items (event_id);

alter table public.event_agenda_items enable row level security;
create policy agenda_select on public.event_agenda_items for select using (true);
create policy agenda_write  on public.event_agenda_items for all
  using (public.is_app_admin()) with check (public.is_app_admin());

grant select on public.event_agenda_items to anon, authenticated;
grant insert, update, delete on public.event_agenda_items to authenticated; -- 行级限管理员
grant all on public.event_agenda_items to service_role;

-- ---------------------------------------------------------------- 相关资料(PDF)
create table public.event_attachments (
  id           uuid primary key default gen_random_uuid(),
  event_id     uuid not null references public.events(id) on delete cascade,
  title        text not null,               -- 显示名(如「地藏經 經本」)
  storage_path text not null,               -- event-files 桶内 key,如 {event_id}/{uuid}.pdf
  size_bytes   bigint,
  content_type text,                         -- MVP 固定 application/pdf
  sort_order   int not null default 0,
  created_at   timestamptz not null default now()
);
create index idx_attach_event on public.event_attachments (event_id);

alter table public.event_attachments enable row level security;
create policy attach_select on public.event_attachments for select using (true);
create policy attach_write  on public.event_attachments for all
  using (public.is_app_admin()) with check (public.is_app_admin());

grant select on public.event_attachments to anon, authenticated;
grant insert, update, delete on public.event_attachments to authenticated;
grant all on public.event_attachments to service_role;

-- ---------------------------------------------------------------- Storage bucket
-- 公开可读(匿名可下,与「活动匿名可看」一致);20 MB 上限、仅 PDF(服务端强校验)。
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('event-files', 'event-files', true, 20971520, array['application/pdf'])
on conflict (id) do nothing;

-- storage.objects 策略:公开读 + 仅管理员写(insert/update/delete)
create policy "event_files_read" on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'event-files');

create policy "event_files_admin_insert" on storage.objects for insert
  to authenticated
  with check (bucket_id = 'event-files' and public.is_app_admin());

create policy "event_files_admin_update" on storage.objects for update
  to authenticated
  using (bucket_id = 'event-files' and public.is_app_admin())
  with check (bucket_id = 'event-files' and public.is_app_admin());

create policy "event_files_admin_delete" on storage.objects for delete
  to authenticated
  using (bucket_id = 'event-files' and public.is_app_admin());
