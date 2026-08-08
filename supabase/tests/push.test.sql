-- ============================================================================
-- 推送触发链路 + 投递管道(pgTAP)· 运行:npx supabase test db
-- 覆盖 migration 0014 + 0016(配置键已迁 app_secrets、密钥不可被客户端读、
--   invoke 函数静默、notifications 触发器、cron 兜底任务)
-- 与 0023 + 0027(P2.12/P2.17:租约式抢占、失败重试、转换表触发器、retention)。
-- 设计与用例编号见 docs/design/notification-overhaul.md §12.1(T-DB-01…09 / 41…42)。
-- 事务内执行并回滚。⚠️ 事务内 now() 恒定,「租约过期」类断言靠手动改 claimed_at。
-- ============================================================================
begin;
create extension if not exists pgtap with schema extensions;
set search_path = extensions, public;

select plan(30);

-- 1) 配置键在 app_secrets(默认空 = 本地不外呼)
select is(
  (select count(*) from public.app_secrets
    where key in ('push_dispatch_url', 'push_dispatch_key')),
  2::bigint, 'push_dispatch_url / push_dispatch_key 在 app_secrets');

-- 2) app_settings 不再含这两个键(0016 安全修复)
select is(
  (select count(*) from public.app_settings
    where key in ('push_dispatch_url', 'push_dispatch_key')),
  0::bigint, 'app_settings 已不含投递密钥');

-- 3/4) 客户端角色无 SELECT 权限(密钥不可经 REST 读取)
select ok(not has_table_privilege('anon', 'public.app_secrets', 'select'),
  'anon 无 app_secrets SELECT 权限');
select ok(not has_table_privilege('authenticated', 'public.app_secrets', 'select'),
  'authenticated 无 app_secrets SELECT 权限');

-- 5) RLS 开启且零策略(双保险)
select ok(
  (select relrowsecurity from pg_class where oid = 'public.app_secrets'::regclass)
  and not exists (select 1 from pg_policies
                   where schemaname = 'public' and tablename = 'app_secrets'),
  'app_secrets RLS 开启且无任何策略');

-- 6) url 未配置时 invoke 静默无害
select lives_ok($$ select public.invoke_push_dispatch() $$,
  'url 未配置时 invoke_push_dispatch 静默跳过');

-- 7) notifications 触发器已挂
select ok(
  exists(select 1 from pg_trigger
    where tgname = 'trg_push_dispatch'
      and tgrelid = 'public.notifications'::regclass),
  'notifications 上有 trg_push_dispatch 触发器');

-- 8) cron 兜底任务已注册
select ok(
  exists(select 1 from cron.job where jobname = 'push-dispatch-sweep'),
  'pg_cron 每分钟兜底任务存在');

-- 9) 插通知不因触发器报错(url 空 → 不外呼)
select lives_ok($$
  insert into public.notifications (scope, type, payload, channels)
  values ('all', 'general', '{}'::jsonb, '{inapp}')
$$, '插入通知触发器无害通过');

-- ============================================================================
-- P2.12 投递管道(migration 0023)· T-DB-01…09
-- ============================================================================
delete from public.notifications;

-- T-DB-01 只抢已到点的行(未来排程的不动)
insert into public.notifications (id, scope, type, title, channels, scheduled_at) values
  ('00000000-0000-4000-9000-000000000001', 'all', 'general', '到点', '{inapp,push}', now() - interval '1 minute'),
  ('00000000-0000-4000-9000-000000000002', 'all', 'general', '未来', '{inapp,push}', now() + interval '1 hour');
select is((select count(*) from public.claim_notifications(50)), 1::bigint,
  'T-DB-01 claim 只抢已到点的行');

-- T-DB-02 **缺陷 A 回归**:3 天前创建、刚到点的定时通知必须能被抢到
-- (改造前取数条件要求 created_at > now()-24h,这类行永久发不出去)
delete from public.notifications;
insert into public.notifications (scope, type, title, channels, created_at, scheduled_at)
values ('all', 'general', '超24h定时', '{inapp,push}', now() - interval '3 days', now() - interval '1 minute');
select is((select count(*) from public.claim_notifications(50)), 1::bigint,
  'T-DB-02 缺陷A回归:3 天前创建、刚到点的定时通知能被抢到');

-- T-DB-03 到点超过 6 小时的不再抢(防宕机恢复后过期雪崩)
delete from public.notifications;
insert into public.notifications (scope, type, title, channels, created_at, scheduled_at)
values ('all', 'general', '过期太久', '{inapp,push}', now() - interval '3 days', now() - interval '7 hours');
select is((select count(*) from public.claim_notifications(50)), 0::bigint,
  'T-DB-03 到点超 6 小时不再投递');

-- T-DB-04 租约:抢占后不可重抢;租约过期后可重抢且 attempts 递增
delete from public.notifications;
insert into public.notifications (id, scope, type, title, channels)
values ('00000000-0000-4000-9000-000000000010', 'all', 'general', '租约', '{inapp,push}');
select is((select count(*) from public.claim_notifications(50)), 1::bigint,
  'T-DB-04a 首次抢占成功');
select is((select count(*) from public.claim_notifications(50)), 0::bigint,
  'T-DB-04b 租约未过期时不可重抢');
update public.notifications set claimed_at = now() - interval '3 minutes'
 where id = '00000000-0000-4000-9000-000000000010';
select is((select count(*) from public.claim_notifications(50)), 1::bigint,
  'T-DB-04c 租约过期后可重抢');
select is((select attempts from public.notifications
            where id = '00000000-0000-4000-9000-000000000010'), 2::smallint,
  'T-DB-04d attempts 随抢占递增');

-- T-DB-05 complete(ok>0) → sent_at 置位、租约清空、last_error 有摘要
select public.complete_notification('00000000-0000-4000-9000-000000000010', 3, 1, 0, null);
select ok(
  (select sent_at is not null and claimed_at is null and last_error like 'ok=3%'
     from public.notifications where id = '00000000-0000-4000-9000-000000000010'),
  'T-DB-05 投递成功 → sent_at 置位、租约释放、结果落库');

-- T-DB-06 全失败 → 释放租约不置 sent_at;attempts 用尽 → failed_at
delete from public.notifications;
insert into public.notifications (id, scope, type, title, channels, claimed_at, attempts)
values ('00000000-0000-4000-9000-000000000020', 'all', 'general', '失败', '{inapp,push}', now(), 1);
select public.complete_notification('00000000-0000-4000-9000-000000000020', 0, 0, 2, 'APNs 503');
select ok(
  (select sent_at is null and claimed_at is null and failed_at is null
          and last_error like '%APNs 503%'
     from public.notifications where id = '00000000-0000-4000-9000-000000000020'),
  'T-DB-06a 全失败 → 释放租约等重投,错误落库');
update public.notifications set attempts = 5
 where id = '00000000-0000-4000-9000-000000000020';
select public.complete_notification('00000000-0000-4000-9000-000000000020', 0, 0, 2, 'again');
select ok(
  (select failed_at is not null from public.notifications
    where id = '00000000-0000-4000-9000-000000000020'),
  'T-DB-06b 重试 5 次用尽 → 记终局失败');
select is((select count(*) from public.claim_notifications(50)), 0::bigint,
  'T-DB-06c 终局失败的行不再被抢');

-- T-DB-07 语句级触发器只在本批含已到点行时才外呼(转换表)
--   url 未配置时 invoke 静默,这里断言两种插入都不报错即可(外呼与否见函数日志)
delete from public.notifications;
select lives_ok($$
  insert into public.notifications (scope, type, title, channels, scheduled_at)
  values ('all', 'general', '未来排程', '{inapp,push}', now() + interval '2 days')
$$, 'T-DB-07 插入未来排程行不触发外呼且无害');

-- T-DB-08 客户端角色无权调用投递 RPC
select ok(not has_function_privilege('anon', 'public.claim_notifications(int)', 'execute'),
  'T-DB-08a anon 不可调 claim_notifications');
select ok(not has_function_privilege('authenticated',
            'public.complete_notification(uuid,int,int,int,text)', 'execute'),
  'T-DB-08b authenticated 不可调 complete_notification');
-- push-dispatch 经 PostgREST 以 service_role 调用,必须有权限(revoke from public 会连它一起收走)
select ok(has_function_privilege('service_role', 'public.claim_notifications(int)', 'execute'),
  'T-DB-08c service_role 可调 claim_notifications');

-- ============================================================================
-- P2.17 数据治理(migration 0027)· T-DB-41…42
-- ============================================================================
delete from public.notifications;
insert into public.notifications (id, scope, type, title, channels, created_at) values
  ('00000000-0000-4000-9000-000000000030', 'all', 'general', '很旧', '{inapp}', now() - interval '181 days'),
  ('00000000-0000-4000-9000-000000000031', 'all', 'general', '较新', '{inapp}', now() - interval '179 days');
insert into public.notification_reads (notification_id, user_id)
values ('00000000-0000-4000-9000-000000000030', '00000000-0000-4000-8000-000000000001');
select is(public.purge_old_notifications(180), 1, 'T-DB-41a 只清理 180 天前的通知');
select is((select count(*) from public.notification_reads
            where notification_id = '00000000-0000-4000-9000-000000000030'),
  0::bigint, 'T-DB-41b 已读记录随通知级联清除');
select ok(exists(select 1 from public.notifications
                  where id = '00000000-0000-4000-9000-000000000031'),
  'T-DB-41c 保留期内的通知不动');

select ok(exists(select 1 from cron.job where jobname = 'notifications-retention'),
  'T-DB-42a retention cron 已注册');
select ok(exists(select 1 from pg_indexes
                  where schemaname = 'public' and indexname = 'idx_notification_reads_user'),
  'T-DB-42b notification_reads(user_id) 索引存在');

-- 通知中心红点靠订阅 notifications 的 INSERT;不在 publication 里则订阅建得起来
-- 但永远收不到事件(功能静默失效)
select ok(exists(select 1 from pg_publication_tables
                  where pubname = 'supabase_realtime'
                    and schemaname = 'public' and tablename = 'notifications'),
  'T-DB-42c notifications 已加入 supabase_realtime publication');

select * from finish();
rollback;
