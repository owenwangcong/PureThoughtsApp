-- ============================================================================
-- 推送触发链路(pgTAP)· 运行:npx supabase test db
-- 覆盖 migration 0014:配置键、invoke 函数(url 未配置时静默)、
-- notifications 触发器、cron 兜底任务。事务内执行并回滚。
-- ============================================================================
begin;
create extension if not exists pgtap with schema extensions;
set search_path = extensions, public;

select plan(5);

-- 1) 配置键已种(默认空 = 本地不外呼)
select is(
  (select count(*) from public.app_settings
    where key in ('push_dispatch_url', 'push_dispatch_key')),
  2::bigint, 'push_dispatch_url / push_dispatch_key 配置键存在');

-- 2) url 未配置时 invoke 静默无害
select lives_ok($$ select public.invoke_push_dispatch() $$,
  'url 未配置时 invoke_push_dispatch 静默跳过');

-- 3) notifications 触发器已挂
select ok(
  exists(select 1 from pg_trigger
    where tgname = 'trg_push_dispatch'
      and tgrelid = 'public.notifications'::regclass),
  'notifications 上有 trg_push_dispatch 触发器');

-- 4) cron 兜底任务已注册
select ok(
  exists(select 1 from cron.job where jobname = 'push-dispatch-sweep'),
  'pg_cron 每分钟兜底任务存在');

-- 5) 插通知不因触发器报错(url 空 → 不外呼)
select lives_ok($$
  insert into public.notifications (scope, type, payload, channels)
  values ('all', 'general', '{}'::jsonb, '{inapp}')
$$, '插入通知触发器无害通过');

select * from finish();
rollback;
