-- ============================================================================
-- 活动提醒排程 + 变更通知降噪(pgTAP)· 运行:npx supabase test db
-- 覆盖 migration 0025 + 0026(PRD v0.5.21 §5,任务 P2.14/P2.15),用例编号见
-- docs/design/notification-overhaul.md §12.1(T-DB-20…40)。
-- 事务内执行并回滚。
--
-- ⚠️ 展开口径必须与客户端 Dart(app/lib/features/events/occurrence_utils.dart)一致:
--    每周循环在**活动时区**做日历算术,跨 DST 保持当地墙钟不变;
--    occurrence_date = 该场次在活动时区的日期。T-DB-23 与 occurrence_tz_test.dart
--    使用同一组 DST 期望值,改展开规则必须两边同改同跑。
-- seed:admin=…0001,member(B)=…0003,user(A)=…0004
-- ============================================================================
begin;
create extension if not exists pgtap with schema extensions;
set search_path = extensions, public;

select plan(33);

create function er_login(uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

create function er_reset() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', null, true);
  perform set_config('role', 'postgres', true);
end $$;

-- 清出确定基线(seed 的两个活动及其提醒会干扰计数)
delete from public.events;
delete from public.notifications;

-- ---------------------------------------------------------------- 单次活动
-- T-DB-33 新建活动自动获得默认三档
insert into public.events (id, title, event_type_id, start_at, timezone, recurrence_rule)
values ('00000000-0000-4000-9200-000000000001', '单次活动',
        (select id from public.event_types order by sort_order limit 1),
        now() + interval '7 days', 'Asia/Shanghai', null);

select results_eq(
  $$ select offset_minutes from public.event_reminders
      where event_id = '00000000-0000-4000-9200-000000000001' order by offset_minutes desc $$,
  $$ values (1440), (30), (0) $$,
  'T-DB-33 新建活动默认三档 1440/30/0');

-- T-DB-20 单次活动 → 每档恰好 1 条,1440 档 = 开始时刻 - 1 天 - 60 秒
select is((select count(*) from public.notifications
            where type = 'event_reminder'
              and event_id = '00000000-0000-4000-9200-000000000001'),
  3::bigint, 'T-DB-20a 单次活动每档各 1 条提醒');

select is(
  (select scheduled_at from public.notifications
    where type = 'event_reminder'
      and event_id = '00000000-0000-4000-9200-000000000001'
      and payload->>'offset_minutes' = '1440'),
  (select start_at - interval '1 day' - interval '60 seconds'
     from public.events where id = '00000000-0000-4000-9200-000000000001'),
  'T-DB-20b 提前一天档 = 开始时刻 - 1 天 - 60 秒');

-- T-DB-34 cron 粒度补偿:0 档不是等于开始时刻,而是提前 60 秒
select is(
  (select scheduled_at from public.notifications
    where type = 'event_reminder'
      and event_id = '00000000-0000-4000-9200-000000000001'
      and payload->>'offset_minutes' = '0'),
  (select start_at - interval '60 seconds'
     from public.events where id = '00000000-0000-4000-9200-000000000001'),
  'T-DB-34 开始档提前 60 秒排程(补 push-dispatch-sweep 的 1 分钟粒度)');

-- T-DB-31 event_id 列被真实写入(改造前是死列,只塞在 payload 里)
select ok(
  (select bool_and(event_id is not null) from public.notifications
    where type = 'event_reminder'),
  'T-DB-31 notifications.event_id 被真实写入');

-- T-DB-22 幂等:重复展开不产生重复通知
select is(public.expand_event_reminders(14), 0, 'T-DB-22a 重复展开新增 0 条');
select is((select count(*) from public.notifications where type = 'event_reminder'),
  3::bigint, 'T-DB-22b 重复展开后总数不变(唯一索引生效)');

-- ---------------------------------------------------------------- 每周活动
delete from public.events;
delete from public.notifications;
-- 起点取 +2 天:若取 +1 天,首场的「提前一天」档落在过去而被跳过(见 T-DB-26)
insert into public.events (id, title, event_type_id, start_at, timezone, recurrence_rule)
values ('00000000-0000-4000-9200-000000000002', '每周活动',
        (select id from public.event_types order by sort_order limit 1),
        now() + interval '2 days', 'Asia/Shanghai', 'FREQ=WEEKLY');

-- T-DB-21 14 天窗口内 2 场(+2 天、+9 天;+16 天超出)× 3 档 = 6 条
select is((select count(*) from public.notifications
            where type = 'event_reminder'
              and event_id = '00000000-0000-4000-9200-000000000002'),
  6::bigint, 'T-DB-21a 每周活动 14 天窗口内 2 场 × 3 档');

select is((select count(distinct payload->>'occurrence_date') from public.notifications
            where type = 'event_reminder'),
  2::bigint, 'T-DB-21b occurrence_date 恰好 2 个不同日期');

-- occurrence_date 取**活动时区**日期(不是 UTC 日期,也不是设备时区日期)
select is(
  (select min(payload->>'occurrence_date') from public.notifications
    where type = 'event_reminder'),
  (select ((start_at at time zone 'Asia/Shanghai')::date)::text
     from public.events where id = '00000000-0000-4000-9200-000000000002'),
  'T-DB-21c occurrence_date = 活动时区日期');

-- T-DB-26 提醒时刻已过去的不补(明天开始的活动,「提前一天」档已错过 → 首场跳过)
delete from public.events;
delete from public.notifications;
insert into public.events (id, title, event_type_id, start_at, timezone, recurrence_rule)
values ('00000000-0000-4000-9200-000000000006', '明天开始',
        (select id from public.event_types order by sort_order limit 1),
        now() + interval '1 day', 'Asia/Shanghai', 'FREQ=WEEKLY');
select is((select count(*) from public.notifications
            where type = 'event_reminder' and payload->>'offset_minutes' = '1440'),
  1::bigint, 'T-DB-26a 首场的提前一天档已过期 → 只剩第二场那一条');
select is((select count(*) from public.notifications
            where type = 'event_reminder' and payload->>'offset_minutes' = '0'),
  2::bigint, 'T-DB-26b 开始档两场都在未来 → 两条都在');

-- ---------------------------------------------------------------- DST
-- T-DB-23 跨 2026-11-01 美国夏令时结束,活动当地墙钟保持 10:00 不变
--   (直接对 timestamptz 加 7 天会漂 1 小时 —— 那正是 P2.10 修过的坑)
delete from public.events;
delete from public.notifications;
insert into public.events (id, title, event_type_id, start_at, timezone, recurrence_rule)
values ('00000000-0000-4000-9200-000000000003', 'LA 每周',
        (select id from public.event_types order by sort_order limit 1),
        '2026-10-24 17:00:00+00', 'America/Los_Angeles', 'FREQ=WEEKLY');
select public.expand_event_reminders(120, '00000000-0000-4000-9200-000000000003');

select is(
  (select count(distinct ((payload->>'start_at')::timestamptz
                          at time zone 'America/Los_Angeles')::time)
     from public.notifications
    where type = 'event_reminder'
      and event_id = '00000000-0000-4000-9200-000000000003'),
  1::bigint, 'T-DB-23a 所有场次的活动当地墙钟完全一致(跨 DST 不漂移)');

select is(
  (select distinct ((payload->>'start_at')::timestamptz
                    at time zone 'America/Los_Angeles')::time
     from public.notifications
    where type = 'event_reminder'
      and event_id = '00000000-0000-4000-9200-000000000003'),
  '10:00'::time, 'T-DB-23b 当地墙钟恒为 10:00');

-- 且确实跨越了 DST 边界(UTC 偏移出现过两种)
select cmp_ok(
  (select count(distinct extract(hour from (payload->>'start_at')::timestamptz))
     from public.notifications
    where type = 'event_reminder'
      and event_id = '00000000-0000-4000-9200-000000000003'),
  '>=', 2::bigint, 'T-DB-23c 覆盖范围确实跨过夏令时切换(UTC 时刻出现两种)');

-- ---------------------------------------------------------------- override 联动
delete from public.events;
delete from public.notifications;
insert into public.events (id, title, event_type_id, start_at, timezone, recurrence_rule)
values ('00000000-0000-4000-9200-000000000004', '联动活动',
        (select id from public.event_types order by sort_order limit 1),
        now() + interval '3 days', 'Asia/Shanghai', null);

-- T-DB-24 取消单次 → 该场提醒全部消失
insert into public.event_overrides (event_id, occurrence_date, patch)
select '00000000-0000-4000-9200-000000000004',
       (start_at at time zone 'Asia/Shanghai')::date, '{"cancelled":true}'::jsonb
  from public.events where id = '00000000-0000-4000-9200-000000000004';
select is((select count(*) from public.notifications where type = 'event_reminder'),
  0::bigint, 'T-DB-24 取消单次 → 该场提醒消失');

-- T-DB-37 删 override(撤销取消)→ 提醒回来 + 「單次恢復」通知(缺陷 F 回归)
delete from public.notifications where type = 'event_changed';
delete from public.event_overrides;
select is((select count(*) from public.notifications where type = 'event_reminder'),
  3::bigint, 'T-DB-37a 撤销取消 → 提醒回来');
select is(
  (select payload->>'action' from public.notifications
    where type = 'event_changed' limit 1),
  'occurrence_restored', 'T-DB-37b 撤销取消产生「單次恢復」通知(缺陷 F 回归)');

-- T-DB-25 改期 → 提醒跟随新时刻,occurrence_date 仍是原定日
delete from public.notifications;
insert into public.event_overrides (event_id, occurrence_date, patch)
select '00000000-0000-4000-9200-000000000004',
       (start_at at time zone 'Asia/Shanghai')::date,
       jsonb_build_object('start_at', (start_at + interval '2 hours')::text)
  from public.events where id = '00000000-0000-4000-9200-000000000004';
select is(
  (select (payload->>'start_at')::timestamptz from public.notifications
    where type = 'event_reminder' and payload->>'offset_minutes' = '0'),
  (select start_at + interval '2 hours' from public.events
    where id = '00000000-0000-4000-9200-000000000004'),
  'T-DB-25a 改期 → 提醒跟随新时刻');
select is(
  (select payload->>'occurrence_date' from public.notifications
    where type = 'event_reminder' and payload->>'offset_minutes' = '0'),
  (select ((start_at at time zone 'Asia/Shanghai')::date)::text from public.events
    where id = '00000000-0000-4000-9200-000000000004'),
  'T-DB-25b 改期后 occurrence_date 仍是原定日(与 Dart dateKey 口径一致)');
delete from public.event_overrides;

-- T-DB-27 改活动开始时刻 → 旧未发提醒删除、按新时刻重建
delete from public.notifications;
update public.events set start_at = start_at + interval '1 day'
 where id = '00000000-0000-4000-9200-000000000004';
select is(
  (select scheduled_at from public.notifications
    where type = 'event_reminder' and payload->>'offset_minutes' = '0'),
  (select start_at - interval '60 seconds' from public.events
    where id = '00000000-0000-4000-9200-000000000004'),
  'T-DB-27 改活动时间 → 提醒按新时刻重建');

-- T-DB-29 停用/删除提醒点 → 对应未发通知消失
delete from public.event_reminders
 where event_id = '00000000-0000-4000-9200-000000000004' and offset_minutes = 30;
select is((select count(*) from public.notifications
            where type = 'event_reminder' and payload->>'offset_minutes' = '30'),
  0::bigint, 'T-DB-29a 删提醒点 → 该档未发通知消失');
update public.event_reminders set enabled = false
 where event_id = '00000000-0000-4000-9200-000000000004' and offset_minutes = 0;
select is((select count(*) from public.notifications
            where type = 'event_reminder' and payload->>'offset_minutes' = '0'),
  0::bigint, 'T-DB-29b 停用提醒点 → 该档未发通知消失');

-- T-DB-28 删活动 → 未发提醒随之消失
delete from public.events where id = '00000000-0000-4000-9200-000000000004';
select is((select count(*) from public.notifications where type = 'event_reminder'),
  0::bigint, 'T-DB-28 删活动 → 未发提醒清空');

-- ---------------------------------------------------------------- 降噪
delete from public.events;
delete from public.notifications;
insert into public.events (id, title, event_type_id, start_at, timezone)
values ('00000000-0000-4000-9200-000000000005', '降噪活动',
        (select id from public.event_types order by sort_order limit 1),
        now() + interval '5 days', 'Asia/Shanghai');

-- T-DB-36 created 立即发(scheduled_at 为空)
select ok(
  (select scheduled_at is null from public.notifications
    where type = 'event_changed' and payload->>'action' = 'created'),
  'T-DB-36 新增活动立即通知(不进防抖窗口)');

-- T-DB-35 连改 3 次只聚合成 1 条未发通知
update public.events set title = '改1' where id = '00000000-0000-4000-9200-000000000005';
update public.events set title = '改2' where id = '00000000-0000-4000-9200-000000000005';
update public.events set title = '改3' where id = '00000000-0000-4000-9200-000000000005';
select is((select count(*) from public.notifications
            where type = 'event_changed' and sent_at is null),
  1::bigint, 'T-DB-35a 连改 3 次只聚合成 1 条通知');
select is((select payload->>'title' from public.notifications
            where type = 'event_changed' and sent_at is null),
  '改3', 'T-DB-35b 聚合条保留最新标题');

-- T-DB-38/39 admin_save_event 的「本次不通知全体」
delete from public.notifications;
select er_login('00000000-0000-4000-8000-000000000003');
select throws_ok(
  $$ select public.admin_save_event('{"title":"x","event_type_id":"00000000-0000-4000-0000-000000000000","start_at":"2026-12-01T00:00:00Z"}'::jsonb) $$,
  '42501', null, 'T-DB-39 非管理员调 admin_save_event 抛 42501');

select er_login('00000000-0000-4000-8000-000000000001');
select public.admin_save_event(
  jsonb_build_object('title', '静默新建',
                     'event_type_id', (select id from public.event_types order by sort_order limit 1),
                     'start_at', (now() + interval '9 days')::text,
                     'timezone', 'Asia/Shanghai'),
  false);
select is((select count(*) from public.notifications where type = 'event_changed'),
  0::bigint, 'T-DB-38a p_notify=false → 不产生全员变更通知');

select public.admin_save_event(
  jsonb_build_object('title', '正常新建',
                     'event_type_id', (select id from public.event_types order by sort_order limit 1),
                     'start_at', (now() + interval '10 days')::text,
                     'timezone', 'Asia/Shanghai'),
  true);
select is((select count(*) from public.notifications where type = 'event_changed'),
  1::bigint, 'T-DB-38b p_notify=true → 正常产生变更通知');
select er_reset();

-- T-DB-30 event_reminders RLS:匿名可读、非管理员不可写
select ok(has_table_privilege('anon', 'public.event_reminders', 'select'),
  'T-DB-30a anon 可读 event_reminders(与 events 同口径)');
select er_login('00000000-0000-4000-8000-000000000004');
select throws_ok(
  $$ insert into public.event_reminders (event_id, offset_minutes)
     select id, 999 from public.events limit 1 $$,
  '42501', null, 'T-DB-30b 非管理员写 event_reminders 被 RLS 拒绝');
select er_reset();

-- T-DB-32 cron 已注册
select ok(exists(select 1 from cron.job where jobname = 'event-reminders-daily'),
  'T-DB-32 event-reminders-daily cron 已注册');

select * from finish();
rollback;
