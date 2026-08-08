-- ============================================================================
-- 活动提醒排程(PRD v0.5.21 §5/§12.4,设计 notification-overhaul.md §6,任务 P2.14)
-- 兑现 PRD §5 一直没实现的核心承诺:「周六共修预告(提前一天)、周六当天 Webex/YouTube
-- 连接、周三打坐提醒」——改造前全库无人写 type='event_reminder',活动类通知只有
-- 「管理员改了活动 → 全站广播」。
--
-- 默认三档(用户 2026-08-08 拍板,依据见设计 §2「Q1 决策依据」):
--   1440(提前一天) —— 让用户安排时间,且是**大陆 Android 用户唯一能看到的一档**
--                      (PRD §5.1:该群体收不到实时推送,只能靠"打开 App 即见";只有覆盖
--                      24 小时的预告才有机会被看到),也是邮件兜底的唯一有意义载体;
--   30(提前半小时) —— 临门一脚,补上预告到开始之间 24 小时的空档;
--   0(活动开始时) —— 点击直进 Webex/YouTube。
--
-- ⚠️ 展开口径必须与客户端 Dart(app/lib/features/events/occurrence_utils.dart)一致:
--    每周循环在**活动时区**做日历算术(先落到该时区墙钟,加 7 个日历日,再转回 UTC),
--    跨 DST 保持当地墙钟不变;occurrence_date = 该场次在活动时区的日期(全球一致)。
--    直接对 timestamptz 加 7 天会在 DST 切换后漂 1 小时——那正是 P2.10 修过的坑。
-- ============================================================================

-- ---------------------------------------------------------------- 提醒点表
create table if not exists public.event_reminders (
  id             uuid primary key default gen_random_uuid(),
  event_id       uuid not null references public.events(id) on delete cascade,
  offset_minutes int  not null check (offset_minutes >= 0 and offset_minutes <= 10080),
  enabled        boolean not null default true,
  created_at     timestamptz not null default now(),
  unique (event_id, offset_minutes)
);

comment on table public.event_reminders is
  '活动提醒点(每活动可多条);offset_minutes = 提前多少分钟,0 = 活动开始时。默认三档 1440/30/0';

create index if not exists idx_event_reminders_event on public.event_reminders (event_id);

alter table public.event_reminders enable row level security;

drop policy if exists event_reminders_select on public.event_reminders;
create policy event_reminders_select on public.event_reminders for select using (true);

drop policy if exists event_reminders_write on public.event_reminders;
create policy event_reminders_write on public.event_reminders for all
  using (public.is_app_admin()) with check (public.is_app_admin());

-- 同 0016/0019/0022 教训:生产库新表默认授权会覆盖最小授权,必须显式 revoke
revoke all on public.event_reminders from public, anon, authenticated;
grant select on public.event_reminders to anon, authenticated;
grant insert, update, delete on public.event_reminders to authenticated;
grant all on public.event_reminders to service_role;

-- ---------------------------------------------------------------- 幂等键
-- 改造前 notifications 表没有任何唯一约束(「连改 5 次发 5 条」正是此因);
-- 提醒由 cron 每日重跑生成,没有这个索引就会天天重复。
-- 它同时要求 notifications.event_id 被真实写入 —— 那个 on delete set null 的外键
-- 自建库以来从未生效过(所有 insert 都只把 id 塞在 payload 里)。
-- 限定 scope='all':免打扰顺延会克隆出 scope='user' 的同 event/场次/档位副本(设计 §5.4),
-- 不加这个条件,克隆插入会撞上本索引导致整批投递失败。
create unique index if not exists uq_notifications_event_reminder
  on public.notifications (event_id, (payload->>'occurrence_date'), (payload->>'offset_minutes'))
  where type = 'event_reminder' and scope = 'all';

-- ---------------------------------------------------------------- 展开函数
create or replace function public.expand_event_reminders(
  p_days int default 14, p_event_id uuid default null
) returns int
language plpgsql security definer set search_path = public as $$
declare
  e         record;
  r         record;
  v_wall    timestamp;      -- 首场在活动时区的墙钟(无时区)
  v_local   timestamp;      -- 第 i 场的墙钟
  v_utc     timestamptz;    -- 第 i 场的绝对时刻
  v_date    date;           -- occurrence_date(活动时区日期,override 键)
  v_patch   jsonb;
  v_start   timestamptz;    -- 应用改期后的实际开始时刻
  v_remind  timestamptz;
  v_horizon timestamptz := now() + make_interval(days => p_days);
  v_weekly  boolean;
  v_ins     int;
  i         int;
  i_guard   int;
  n         int := 0;
begin
  for e in select * from public.events
            where (p_event_id is null or id = p_event_id) loop

    -- 关键:先落到活动时区墙钟,加周后再转回,跨 DST 墙钟不变(与 Dart 的
    -- tz.TZDateTime(loc, y, m, d + 7*i, h, min) 等价)
    v_wall   := e.start_at at time zone e.timezone;
    v_weekly := coalesce(e.recurrence_rule, '') ilike '%FREQ=WEEKLY%';

    -- 快进到 now() 附近(留 2 周余量),避免从首场逐周遍历多年(同 Dart 的快进逻辑)
    if v_weekly then
      i := greatest(0, (extract(epoch from (now() - e.start_at)) / 604800)::int - 2);
    else
      i := 0;
    end if;
    i_guard := i + 400;   -- 保险丝:14 天窗口正常只需 2–3 次迭代

    loop
      v_local := v_wall + (case when v_weekly then i * interval '7 days'
                                else interval '0' end);
      v_utc   := v_local at time zone e.timezone;
      exit when v_utc > v_horizon;

      v_date := v_local::date;
      select patch into v_patch from public.event_overrides
       where event_id = e.id and occurrence_date = v_date;

      if coalesce(v_patch->>'cancelled', '') <> 'true' then
        v_start := coalesce((v_patch->>'start_at')::timestamptz, v_utc);

        for r in select * from public.event_reminders
                  where event_id = e.id and enabled loop
          -- cron 粒度补偿:push-dispatch-sweep 每分钟跑一次,若 scheduled_at 正好等于
          -- 目标时刻,最坏会在其后 59 秒才被扫到 →「活动开始了」迟到。统一提前 60 秒。
          v_remind := v_start
                    - make_interval(mins => r.offset_minutes)
                    - interval '60 seconds';

          if v_remind > now() then
            insert into public.notifications
              (scope, type, event_id, payload, channels, scheduled_at)
            values ('all', 'event_reminder', e.id,
              jsonb_build_object(
                'event_id',        e.id,
                'occurrence_date', v_date,
                'offset_minutes',  r.offset_minutes,
                'title',           e.title,
                'start_at',        v_start,
                'timezone',        e.timezone,
                'has_webex',       e.webex_url   is not null,
                'has_youtube',     e.youtube_url is not null),
              '{inapp,push}', v_remind)
            on conflict do nothing;      -- 命中 uq_notifications_event_reminder
            get diagnostics v_ins = row_count;
            n := n + v_ins;
          end if;
        end loop;
      end if;

      exit when not v_weekly;            -- 单次活动只展开一场
      i := i + 1;
      exit when i > i_guard;
    end loop;
  end loop;
  return n;
end $$;

revoke execute on function public.expand_event_reminders(int, uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------- 变更重排
-- 改造前的缺口:活动改期/取消后,已生成的提醒不会被撤销(整个链路只追加、不撤回)。
-- 这里在活动、单次覆盖、提醒点三处变更时,清掉该活动**未发**的提醒并按最新状态重排;
-- 已发出的(sent_at 非空)不动——推送出去的收不回,由后续变更通知说明。
create or replace function public.resync_event_reminders() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  -- ⚠️ 本函数挂在三张表上(events / event_overrides / event_reminders),NEW/OLD 的行类型
  --    随触发表变化。直接写 new.event_id 会在 events 上抛「record new has no field
  --    event_id」(42703,2026-08-08 本地 seed 实测),CASE 分支也救不了——表达式整体
  --    要能解析。转成 jsonb 后按名取值,与行类型完全解耦,DELETE 时 NEW 为 NULL 也安全。
  v_rec   jsonb := coalesce(to_jsonb(new), to_jsonb(old));
  v_event uuid;
begin
  if tg_table_name = 'events' then
    v_event := (v_rec->>'id')::uuid;
  else
    v_event := (v_rec->>'event_id')::uuid;
  end if;
  if v_event is null then return coalesce(new, old); end if;

  delete from public.notifications
   where type = 'event_reminder' and event_id = v_event and sent_at is null;

  -- 活动本身被删时不重排(events 已无该行,expand 会空转;显式跳过更清楚)
  if not (tg_table_name = 'events' and tg_op = 'DELETE') then
    perform public.expand_event_reminders(14, v_event);
  end if;

  return coalesce(new, old);
end $$;

drop trigger if exists trg_resync_reminders_events on public.events;
create trigger trg_resync_reminders_events
  after insert or update on public.events
  for each row execute function public.resync_event_reminders();

-- ⚠️ 删除必须用 BEFORE:notifications.event_id 是 on delete set null,AFTER DELETE 时
--    RI 已把该活动所有通知的 event_id 置空,`delete ... where event_id = v_event` 一条
--    也删不到 → 未发的提醒会残留,到点仍推送「活动即将开始」但活动早已不存在
--    (2026-08-08 pgTAP T-DB-28 实测暴露)。BEFORE DELETE 时行还在,清理才有效。
drop trigger if exists trg_resync_reminders_events_del on public.events;
create trigger trg_resync_reminders_events_del
  before delete on public.events
  for each row execute function public.resync_event_reminders();

drop trigger if exists trg_resync_reminders_overrides on public.event_overrides;
create trigger trg_resync_reminders_overrides
  after insert or update or delete on public.event_overrides
  for each row execute function public.resync_event_reminders();

drop trigger if exists trg_resync_reminders_points on public.event_reminders;
create trigger trg_resync_reminders_points
  after insert or update or delete on public.event_reminders
  for each row execute function public.resync_event_reminders();

-- ---------------------------------------------------------------- 新建活动默认三档
-- 放在 DB 侧而不是只靠客户端编辑器:经管理后台、seed 或直接 SQL 建的活动同样要有提醒。
-- 只在 INSERT 时补,管理员事后删掉某档不会被重新塞回。
-- 触发器名以 trg_default_ 开头,字母序先于 trg_notify_ / trg_resync_,让提醒点先就位。
create or replace function public.default_event_reminders() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.event_reminders (event_id, offset_minutes)
  values (new.id, 1440), (new.id, 30), (new.id, 0)
  on conflict do nothing;
  return new;
end $$;

drop trigger if exists trg_default_event_reminders on public.events;
create trigger trg_default_event_reminders
  after insert on public.events
  for each row execute function public.default_event_reminders();

-- ---------------------------------------------------------------- 存量补默认三档
insert into public.event_reminders (event_id, offset_minutes)
select e.id, o.m
  from public.events e
  cross join (values (1440), (30), (0)) as o(m)
on conflict do nothing;

-- ---------------------------------------------------------------- pg_cron
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'event-reminders-daily') then
      perform cron.unschedule('event-reminders-daily');
    end if;
    -- 15:00 UTC:避开 almanac-daily(16:05)与 notifications-retention(17:00)
    perform cron.schedule('event-reminders-daily', '0 15 * * *',
      $job$select public.expand_event_reminders(14)$job$);
  end if;
end $$;
