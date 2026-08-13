-- ============================================================================
-- 通知偏好:免打扰时段 + 分类订阅(pgTAP)· 运行:npx supabase test db
-- 覆盖 migration 0024(PRD v0.5.21 §5/§5.2,任务 P2.13),用例编号见
-- docs/design/notification-overhaul.md §12.1(T-DB-10…19)。
-- 事务内执行并回滚。
--
-- ⚠️ 免打扰依赖 now(),而测试运行的钟点不可控。这里不断言「现在是否处于免打扰」,
--    而是用**互补窗口**构造:任意时刻必然落在 [a,b) 与其补集之一,断言「恰好命中一个」。
--    这样既与运行时刻无关,又真正验证了跨午夜/同日两种窗口的分支逻辑。
-- seed:admin=…0001,owner=…0002,member(B)=…0003,user(A)=…0004
-- (v0.6.0 去群化后测试群已取消,scope=group 的 target 为唯一共修体 groups.is_default)
-- ============================================================================
begin;
create extension if not exists pgtap with schema extensions;
set search_path = extensions, public;

select plan(19);

create function np_login(uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

create function np_reset() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', null, true);
  perform set_config('role', 'postgres', true);
end $$;

-- ---------------------------------------------------------------- RLS
-- T-DB-10 本人可读写自己的偏好;他人读不到
select np_login('00000000-0000-4000-8000-000000000004');
insert into public.notification_prefs (user_id, quiet_enabled, muted_types)
values ('00000000-0000-4000-8000-000000000004', false, '{event_changed}');
select is((select count(*) from public.notification_prefs), 1::bigint,
  'T-DB-10a A 可读写自己的通知偏好');

select np_login('00000000-0000-4000-8000-000000000003');
select is((select count(*) from public.notification_prefs), 0::bigint,
  'T-DB-10b B 读不到 A 的偏好');

select np_login('00000000-0000-4000-8000-000000000001');
select is((select count(*) from public.notification_prefs), 1::bigint,
  'T-DB-10c 管理员可读全部偏好');
select np_reset();

-- T-DB-11 anon 无任何权限(显式 revoke,不是「RLS 空结果」)
select ok(not has_table_privilege('anon', 'public.notification_prefs', 'select'),
  'T-DB-11a anon 无 notification_prefs SELECT 权限');
select ok(not has_table_privilege('anon', 'public.notification_prefs', 'insert'),
  'T-DB-11b anon 无 notification_prefs INSERT 权限');

-- ---------------------------------------------------------------- 免打扰计算
-- T-DB-12 同日窗口:[00:00,12:00) 与 [12:00,23:59:59) 互补,当前时刻恰好命中其一
select is(
  (case when public.quiet_until_for('UTC', true, '00:00', '12:00') is not null then 1 else 0 end)
+ (case when public.quiet_until_for('UTC', true, '12:00', '23:59:59') is not null then 1 else 0 end),
  1, 'T-DB-12 同日窗口:互补两窗口恰好命中一个');

-- T-DB-13 跨午夜窗口:[22:00,07:00) 与其补集 [07:00,22:00) 互补
select is(
  (case when public.quiet_until_for('UTC', true, '22:00', '07:00') is not null then 1 else 0 end)
+ (case when public.quiet_until_for('UTC', true, '07:00', '22:00') is not null then 1 else 0 end),
  1, 'T-DB-13a 跨午夜窗口与其补集恰好命中一个');

-- 顺延目标必须落在窗口结束时刻(几乎覆盖全天的窗口保证命中)
select is(
  (public.quiet_until_for('UTC', true, '00:00', '23:59:59') at time zone 'UTC')::time,
  '23:59:59'::time, 'T-DB-13b 顺延到窗口结束时刻');

-- 顺延时刻必须在未来(不能把通知排到过去 → 会立刻被投递,等于免打扰失效)
select ok(public.quiet_until_for('UTC', true, '00:00', '23:59:59') > now(),
  'T-DB-13c 顺延时刻在未来');

-- T-DB-14 关闭开关 / 非法时区 → 恒 null
select ok(public.quiet_until_for('UTC', false, '00:00', '23:59:59') is null,
  'T-DB-14a 关闭免打扰 → null');
select ok(public.quiet_until_for('Not/AZone', true, '00:00', '23:59:59') is null,
  'T-DB-14b 非法时区名安全降级为 null(不让整批投递崩溃)');

-- T-DB-19 「活动开始前的实时通知不受限」判据(PRD §5.2)
select ok(
  public.reminder_bypasses_quiet('event_reminder', '{"offset_minutes":0}'::jsonb)
  and public.reminder_bypasses_quiet('event_reminder', '{"offset_minutes":30}'::jsonb)
  and public.reminder_bypasses_quiet('event_reminder', '{"offset_minutes":60}'::jsonb)
  and not public.reminder_bypasses_quiet('event_reminder', '{"offset_minutes":1440}'::jsonb)
  and not public.reminder_bypasses_quiet('almanac', '{"kind":"zhai"}'::jsonb),
  'T-DB-19 ≤60 分钟的活动提醒绕过免打扰,提前一天的预告与其它类型遵守');

-- ---------------------------------------------------------------- 受众解析
delete from public.notification_prefs;
delete from public.notifications;
delete from public.push_tokens;   -- 受众计数断言要求已知基线(库里可能有手工/真机残留)
insert into public.push_tokens (token, user_id, platform) values
  ('tok-a', '00000000-0000-4000-8000-000000000004', 'apns'),
  ('tok-b', '00000000-0000-4000-8000-000000000003', 'fcm');

-- T-DB-15 channels 不含 push 也不含 inapp(纯 email)→ 不投递
insert into public.notifications (id, scope, type, title, channels)
values ('00000000-0000-4000-9100-000000000001', 'all', 'general', '仅邮件', '{email}');
select is((select count(*) from public.push_audience('00000000-0000-4000-9100-000000000001')),
  0::bigint, 'T-DB-15a channels 不含 push/inapp → 受众为空');

-- 历史遗留的 {inapp} 必须照推(6 个既有触发器仍写死该值,不能因 channels 生效而掉推送)
insert into public.notifications (id, scope, type, title, channels)
values ('00000000-0000-4000-9100-000000000002', 'all', 'general', '历史inapp', '{inapp}');
select is((select count(*) from public.push_audience('00000000-0000-4000-9100-000000000002')),
  2::bigint, 'T-DB-15b 历史 {inapp} 仍投递(宽松判据,零回归)');

-- T-DB-16 分类订阅:裸 type 与 type:kind 两种形式分别生效
insert into public.notification_prefs (user_id, muted_types)
values ('00000000-0000-4000-8000-000000000004', '{general}');
select is((select count(*) from public.push_audience('00000000-0000-4000-9100-000000000002')),
  1::bigint, 'T-DB-16a muted_types 含裸 type → 该用户被过滤');

insert into public.notifications (id, scope, type, title, payload, channels)
values ('00000000-0000-4000-9100-000000000003', 'all', 'almanac', '十斋日',
        '{"kind":"zhai"}'::jsonb, '{inapp,push}');
update public.notification_prefs set muted_types = '{almanac:zhai}'
 where user_id = '00000000-0000-4000-8000-000000000004';
select is((select count(*) from public.push_audience('00000000-0000-4000-9100-000000000003')),
  1::bigint, 'T-DB-16b muted_types 含 type:kind → 只静音该 kind');
-- 同 type 的另一 kind 不受影响
insert into public.notifications (id, scope, type, title, payload, channels)
values ('00000000-0000-4000-9100-000000000004', 'all', 'almanac', '节日',
        '{"kind":"festival"}'::jsonb, '{inapp,push}');
select is((select count(*) from public.push_audience('00000000-0000-4000-9100-000000000004')),
  2::bigint, 'T-DB-16c 同 type 的其它 kind 不受影响');

-- T-DB-17 封禁用户不投递
delete from public.notification_prefs;
update public.profiles set banned_at = now()
 where id = '00000000-0000-4000-8000-000000000004';
select is((select count(*) from public.push_audience('00000000-0000-4000-9100-000000000002')),
  1::bigint, 'T-DB-17 封禁用户被过滤');
update public.profiles set banned_at = null
 where id = '00000000-0000-4000-8000-000000000004';

-- T-DB-18 scope=group 只覆盖 approved 成员
-- v0.6.0 去群化后 target 恒为共修体、注册即 approved,故这里把 A 置为 left 来构造边界
select np_reset();
update public.group_members set status = 'left'
 where group_id = (select id from public.groups where is_default)
   and user_id = '00000000-0000-4000-8000-000000000004';
insert into public.notifications (id, scope, target_id, type, title, channels)
select '00000000-0000-4000-9100-000000000005', 'group', id, 'announcement', '共修公告', '{inapp,push}'
from public.groups where is_default;
select is((select count(*) from public.push_audience('00000000-0000-4000-9100-000000000005')),
  1::bigint, 'T-DB-18 scope=group 只覆盖 approved 成员(B 在会内,A 已 left)');

select * from finish();
rollback;
