-- ============================================================================
-- 日历增强(PRD v0.5.7 §5):
-- 1. 事件类型改为动态表 event_types(管理员增删改,含图标),替换 event_type 枚举;
--    默认:靜坐 / 共修 / 講法 / 禪七 / 其它。
-- 2. 活动变更(新增/更新/删除/单次取消)自动生成全员通知。
-- ============================================================================

create table public.event_types (
  id         uuid primary key default gen_random_uuid(),
  name_hant  text not null,
  name_hans  text not null,
  icon       text not null default 'event',  -- 预置图标集的键,App 端映射
  sort_order int not null default 0,
  active     boolean not null default true
);

alter table public.event_types enable row level security;
create policy event_types_select on public.event_types for select using (true);
create policy event_types_write on public.event_types for all
  using (public.is_app_admin()) with check (public.is_app_admin());

grant select on public.event_types to anon, authenticated;
grant insert, update, delete on public.event_types to authenticated; -- 行级限管理员
grant all on public.event_types to service_role;

insert into public.event_types (name_hant, name_hans, icon, sort_order) values
  ('靜坐', '静坐', 'self_improvement', 10),
  ('共修', '共修', 'groups', 20),
  ('講法', '讲法', 'record_voice_over', 30),
  ('禪七', '禅七', 'temple_buddhist', 40),
  ('其它', '其它', 'event', 90);

-- events.type(枚举)→ events.event_type_id(FK);旧 dharma_assembly 归入「其它」
alter table public.events add column event_type_id uuid references public.event_types(id);
update public.events e set event_type_id = et.id
from public.event_types et
where et.name_hans = case e.type::text
  when 'meditation' then '静坐'
  when 'group_practice' then '共修'
  when 'dharma_talk' then '讲法'
  else '其它'
end;
alter table public.events alter column event_type_id set not null;
alter table public.events drop column type;
drop type public.event_type;

-- ---------------------------------------------------------------- 变更通知
create or replace function public.notify_event_change() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_action text;
  v_title  text;
begin
  if tg_op = 'INSERT' then
    v_action := 'created';  v_title := new.title;
  elsif tg_op = 'DELETE' then
    v_action := 'deleted';  v_title := old.title;
  else
    if (new.title, new.start_at, new.duration_minutes, new.recurrence_rule,
        new.webex_url, new.youtube_url, new.content, new.event_type_id)
       is not distinct from
       (old.title, old.start_at, old.duration_minutes, old.recurrence_rule,
        old.webex_url, old.youtube_url, old.content, old.event_type_id) then
      return new;
    end if;
    v_action := 'updated';  v_title := new.title;
  end if;
  insert into public.notifications (scope, type, payload, channels)
  values ('all', 'event_changed',
          jsonb_build_object('action', v_action, 'title', v_title,
                             'event_id', coalesce(new.id, old.id)),
          '{inapp}');
  return coalesce(new, old);
end $$;

create trigger trg_notify_event_change
  after insert or update or delete on public.events
  for each row execute function public.notify_event_change();

-- 单次修改(取消/改期)通知
create or replace function public.notify_override_change() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_title text;
begin
  select title into v_title from events where id = new.event_id;
  insert into public.notifications (scope, type, payload, channels)
  values ('all', 'event_changed',
          jsonb_build_object(
            'action', case when new.patch->>'cancelled' = 'true'
                           then 'occurrence_cancelled' else 'occurrence_changed' end,
            'title', v_title,
            'event_id', new.event_id,
            'date', new.occurrence_date),
          '{inapp}');
  return new;
end $$;

create trigger trg_notify_override_change
  after insert or update on public.event_overrides
  for each row execute function public.notify_override_change();
