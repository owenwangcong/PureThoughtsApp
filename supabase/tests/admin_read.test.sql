-- ============================================================================
-- 管理后台读支持(pgTAP)· 覆盖 migration 0017
-- ============================================================================
begin;
create extension if not exists pgtap with schema extensions;
set search_path = extensions, public;

select plan(4);

select ok(
  exists(select 1 from pg_policies
    where schemaname = 'public' and tablename = 'push_tokens'
      and policyname = 'push_tokens_admin_read'),
  'push_tokens 有管理员只读策略');

select ok(
  exists(select 1 from pg_policies
    where schemaname = 'public' and tablename = 'notifications'
      and policyname = 'notifications_admin_read'),
  'notifications 有管理员只读策略');

select has_function('public', 'admin_list_logins', array['uuid[]'],
  'admin_list_logins(uuid[]) 存在');

-- anon 不可执行 admin_list_logins(EXECUTE 权限已回收)
select ok(
  not has_function_privilege('anon', 'public.admin_list_logins(uuid[])', 'execute'),
  'anon 无 admin_list_logins 执行权限');

select * from finish();
rollback;
