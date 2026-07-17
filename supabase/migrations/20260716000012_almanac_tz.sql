-- ============================================================================
-- 佛教日曆 + 活动显式时区(PRD v0.5.15 §5/§5.2,设计 docs/design/buddhist-calendar.md)
-- 1. almanac_days  —— 佛历特殊日(节日/十斋日),数据由 tools/almanac 生成器产出
--                     (见 20260716000013_almanac_data.sql);anon 可读,无人可写。
-- 2. app_settings  —— 全局键值配置(首个键 default_event_timezone);anon 可读,仅管理员写。
-- 3. events.timezone —— 活动举办地 IANA 时区(循环展开与「活動當地時間」标注用)。
-- 4. generate_almanac_notifications() + pg_cron:每日 16:05 UTC(= UTC+8 次日 00:05)
--    生成当日节日/十斋日 + 次日重大节日预告的全员通知(幂等,重跑不重复)。
-- ============================================================================

-- ---------------------------------------------------------------- 佛历特殊日
create table public.almanac_days (
  solar_date    date primary key,
  lunar_month   smallint not null check (lunar_month between 1 and 12),
  lunar_day     smallint not null check (lunar_day between 1 and 30),
  is_leap_month boolean  not null default false,
  festival_ids  text[]   not null default '{}',
  names_hant    text[]   not null default '{}',  -- 节日全名(繁),与 festival_ids 同序
  names_hans    text[]   not null default '{}',
  is_zhai_ten   boolean  not null default false, -- 十斋日
  has_major     boolean  not null default false  -- 含重大节日(★,提前一天预告)
);

alter table public.almanac_days enable row level security;
create policy almanac_select on public.almanac_days for select using (true);
-- 不建写策略、不授写权:数据仅来自 migration / service_role
grant select on public.almanac_days to anon, authenticated;
grant all on public.almanac_days to service_role;

-- ---------------------------------------------------------------- 全局配置
create table public.app_settings (
  key        text primary key,
  value      text not null,
  updated_at timestamptz not null default now()
);

alter table public.app_settings enable row level security;
create policy app_settings_select on public.app_settings for select using (true);
create policy app_settings_write  on public.app_settings for all
  using (public.is_app_admin()) with check (public.is_app_admin());

grant select on public.app_settings to anon, authenticated;
grant insert, update, delete on public.app_settings to authenticated; -- 行级限管理员
grant all on public.app_settings to service_role;

insert into public.app_settings (key, value)
values ('default_event_timezone', 'Asia/Shanghai')
on conflict (key) do nothing;

-- ---------------------------------------------------------------- 活动时区
alter table public.events
  add column timezone text not null default 'Asia/Shanghai';

-- 活动变更通知的「无实质变化跳过」比较元组补上 timezone(改时区=改实际时刻,应通知)
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
        new.webex_url, new.youtube_url, new.content, new.event_type_id, new.timezone)
       is not distinct from
       (old.title, old.start_at, old.duration_minutes, old.recurrence_rule,
        old.webex_url, old.youtube_url, old.content, old.event_type_id, old.timezone) then
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

-- ---------------------------------------------------------------- 佛历通知
-- 幂等键:type='almanac' + payload.kind + payload.date;客户端按 payload 渲染简繁文案。
create or replace function public.generate_almanac_notifications() returns void
language plpgsql security definer set search_path = public as $$
declare
  v_today    date := (now() at time zone 'Asia/Shanghai')::date; -- 农历日按 UTC+8 定义
  v_tomorrow date;
  r          public.almanac_days%rowtype;
begin
  v_tomorrow := v_today + 1;

  select * into r from public.almanac_days where solar_date = v_today;
  if found then
    if coalesce(array_length(r.festival_ids, 1), 0) > 0 then
      insert into public.notifications (scope, type, payload, channels)
      select 'all', 'almanac',
             jsonb_build_object('kind', 'festival', 'date', v_today,
               'names_hant', to_jsonb(r.names_hant), 'names_hans', to_jsonb(r.names_hans),
               'lunar_month', r.lunar_month, 'lunar_day', r.lunar_day,
               'is_leap_month', r.is_leap_month),
             '{inapp}'
      where not exists (select 1 from public.notifications
        where type = 'almanac' and payload->>'kind' = 'festival'
          and payload->>'date' = v_today::text);
    end if;
    if r.is_zhai_ten then
      insert into public.notifications (scope, type, payload, channels)
      select 'all', 'almanac',
             jsonb_build_object('kind', 'zhai', 'date', v_today,
               'lunar_month', r.lunar_month, 'lunar_day', r.lunar_day,
               'is_leap_month', r.is_leap_month),
             '{inapp}'
      where not exists (select 1 from public.notifications
        where type = 'almanac' and payload->>'kind' = 'zhai'
          and payload->>'date' = v_today::text);
    end if;
  end if;

  -- 次日重大节日预告(★)
  select * into r from public.almanac_days
   where solar_date = v_tomorrow and has_major;
  if found then
    insert into public.notifications (scope, type, payload, channels)
    select 'all', 'almanac',
           jsonb_build_object('kind', 'festival_eve', 'date', v_tomorrow,
             'names_hant', to_jsonb(r.names_hant), 'names_hans', to_jsonb(r.names_hans),
             'lunar_month', r.lunar_month, 'lunar_day', r.lunar_day,
             'is_leap_month', r.is_leap_month),
           '{inapp}'
    where not exists (select 1 from public.notifications
      where type = 'almanac' and payload->>'kind' = 'festival_eve'
        and payload->>'date' = v_tomorrow::text);
  end if;
end $$;

revoke execute on function public.generate_almanac_notifications() from public, anon, authenticated;

-- ---------------------------------------------------------------- pg_cron 排程
-- 本地栈与官方自托管镜像均已预载 pg_cron;个别环境不可用时仅告警跳过(生产部署时须补排程)。
do $$
begin
  create extension if not exists pg_cron;
exception when others then
  raise warning 'pg_cron 不可用,佛历通知排程跳过(生产须启用): %', sqlerrm;
end $$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'almanac-daily') then
      perform cron.unschedule('almanac-daily');
    end if;
    perform cron.schedule('almanac-daily', '5 16 * * *',
      $job$select public.generate_almanac_notifications()$job$);
  end if;
end $$;
