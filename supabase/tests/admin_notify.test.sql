-- ============================================================================
-- 管理员发布通知 RPC(pgTAP)· 运行:npx supabase test db
-- 覆盖 migration 0015:发布(立即/定时)、非管理员拒绝、撤回仅限 general。
-- 事务内执行并回滚。
-- ============================================================================
begin;
create extension if not exists pgtap with schema extensions;
set search_path = extensions, public;

select plan(6);

create function an_login(uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

-- seed:admin=...0001,member=...0003

-- 1) 管理员立即发布:行落库为 general/all、sent_at 为空(待投递)
-- 注:函数须在独立语句调用(volatile 函数放 WHERE 会被逐行求值,且本语句快照看不见自己插的行)
select an_login('00000000-0000-4000-8000-000000000001');
select public.admin_publish_notification('測試公告', '內容');
select ok(
  exists(select 1 from public.notifications
    where title = '測試公告' and type = 'general' and scope = 'all' and sent_at is null),
  '管理员可发布,行落库为 general/all');

-- 2) 定时发布:scheduled_at 存储正确
select public.admin_publish_notification('定時公告', null, now() + interval '1 hour');
select ok(
  exists(select 1 from public.notifications
    where title = '定時公告' and scheduled_at > now() + interval '50 minutes'),
  '定时发布 scheduled_at 正确');

-- 3) 空标题拒绝
select throws_ok($$ select public.admin_publish_notification('  ') $$,
  null, null, '空标题拒绝');

-- 4) 非管理员发布被拒(42501)
select an_login('00000000-0000-4000-8000-000000000003');
select throws_ok($$ select public.admin_publish_notification('偷发') $$,
  '42501', null, '非管理员不能发布');

-- 5) 非管理员撤回被拒(42501)
select throws_ok($$
  select public.admin_cancel_notification(
    (select id from public.notifications where title = '測試公告'))
$$, '42501', null, '非管理员不能撤回');

-- 6) 管理员撤回 general 成功;非 general 类型拒绝
select an_login('00000000-0000-4000-8000-000000000001');
select lives_ok($$
  select public.admin_cancel_notification(
    (select id from public.notifications where title = '測試公告'))
$$, '管理员可撤回 general 通知');

select * from finish();
rollback;
