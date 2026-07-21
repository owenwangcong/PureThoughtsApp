-- ============================================================================
-- 推送触发链路(pgTAP)· 运行:npx supabase test db
-- 覆盖 migration 0014 + 0016:配置键(已迁 app_secrets)、密钥不可被客户端读、
-- invoke 函数(url 未配置时静默)、notifications 触发器、cron 兜底任务。
-- 事务内执行并回滚。
-- ============================================================================
begin;
create extension if not exists pgtap with schema extensions;
set search_path = extensions, public;

select plan(9);

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

select * from finish();
rollback;
