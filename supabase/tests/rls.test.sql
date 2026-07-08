-- ============================================================================
-- RLS / 权限验证(pgTAP)· 运行:npx supabase test db
-- 覆盖 PRD §12.3 核心策略:报数仅本群可见、join_code 不可直读、
-- 非报数人只能软删、自由名字自动记忆、代报通知、个人字段保护等。
-- 全部在事务内执行并回滚,不留数据。
-- ============================================================================
begin;
create extension if not exists pgtap with schema extensions;
set search_path = extensions, public;

select plan(45);

-- ---------------------------------------------------------------- 测试辅助
-- 身份切换(整个文件是一个事务,set_config local 生效到结束)
create function tests_login(uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

create function tests_logout() returns void language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', '', true);
end $$;

create function tests_anon() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('role', 'anon', true);
end $$;

-- 测试专用:绕过 RLS 取 join code(definer=postgres;随事务回滚,不进生产)
create function tests_code(gid uuid) returns text
language sql security definer set search_path = public as $$
  select code from group_join_codes where group_id = gid;
$$;

-- ---------------------------------------------------------------- 测试用户
-- A=群主 B=成员 C=外人(handle_new_user 触发器自动建 profiles)
insert into auth.users (instance_id, id, aud, role, email)
values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-00000000000a', 'authenticated', 'authenticated', 'alice@test.local'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-00000000000b', 'authenticated', 'authenticated', 'bob@test.local'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-00000000000c', 'authenticated', 'authenticated', 'carol@test.local');

select is(
  (select count(*)::int from public.profiles where id in
    ('00000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-00000000000b','00000000-0000-0000-0000-00000000000c')),
  3, 'handle_new_user 触发器:注册自动创建 profiles');

-- ---------------------------------------------------------------- 建群 / 入群
select tests_login('00000000-0000-0000-0000-00000000000a');

select lives_ok($$
  insert into public.groups (id, name, owner_id)
  values ('00000000-0000-0000-0000-0000000000d1', '測試共修群', '00000000-0000-0000-0000-00000000000a')
$$, '注册用户可建群');

select is(
  (select count(*)::int from public.group_members
   where group_id = '00000000-0000-0000-0000-0000000000d1' and role = 'owner' and status = 'approved'),
  1, '建群自动成为群主(approved/owner)');

select ok(
  length(public.get_group_join_code('00000000-0000-0000-0000-0000000000d1')) = 8,
  '群主经 RPC 可取得 8 位 join code');

-- B 申请入群
select tests_logout();
select tests_login('00000000-0000-0000-0000-00000000000b');

select is(
  (select count(*)::int from public.group_join_codes),
  0, '非管理员不可直读 group_join_codes(RLS)');

select lives_ok($$
  select public.join_group(tests_code('00000000-0000-0000-0000-0000000000d1'), '請通過我')
$$, 'B 可用 join code 申请入群');

-- C 用错误 code 申请失败
select tests_logout();
select tests_login('00000000-0000-0000-0000-00000000000c');
select throws_ok($$ select public.join_group('WRONGCOD', 'hi') $$,
  'P0001', 'invalid join code', '错误 join code 申请被拒');

-- 群主审核通过 B
select tests_logout();
select tests_login('00000000-0000-0000-0000-00000000000a');
update public.group_members set status = 'approved', approved_at = now()
 where group_id = '00000000-0000-0000-0000-0000000000d1'
   and user_id  = '00000000-0000-0000-0000-00000000000b';
select is(
  (select count(*)::int from public.group_members
   where group_id = '00000000-0000-0000-0000-0000000000d1' and status = 'approved'),
  2, '群主可审核通过入群申请');

-- 公告更新 → 群成员收到 App 内通知(P2.3);非成员不可见
update public.groups set announcement = '本週六共修改為線上'
 where id = '00000000-0000-0000-0000-0000000000d1';
select tests_logout();
select tests_login('00000000-0000-0000-0000-00000000000b');
select is(
  (select count(*)::int from public.notifications
   where scope = 'group' and type = 'announcement'
     and target_id = '00000000-0000-0000-0000-0000000000d1'),
  1, '公告更新生成群范围通知,成员可见');
select tests_logout();
select tests_login('00000000-0000-0000-0000-00000000000c');
select is(
  (select count(*)::int from public.notifications where type = 'announcement'),
  0, '非成员看不到群公告通知');
select tests_logout();
select tests_login('00000000-0000-0000-0000-00000000000a');

-- ---------------------------------------------------------------- 报数与可见性
select tests_logout();
select tests_login('00000000-0000-0000-0000-00000000000b');

select lives_ok($$
  insert into public.practice_logs (id, group_id, reporter_id, practice_type_id, quantity)
  values ('00000000-0000-0000-0000-0000000000e1',
          '00000000-0000-0000-0000-0000000000d1',
          '00000000-0000-0000-0000-00000000000b',
          (select id from public.practice_types where name_hans = '金刚经'),
          3)
$$, '成员可自报功课');

select is(
  (select unit::text from public.practice_logs where id = '00000000-0000-0000-0000-0000000000e1'),
  'volume', 'unit 从功课项快照');

select ok(
  (select local_date is not null from public.practice_logs
   where id = '00000000-0000-0000-0000-0000000000e1'),
  'local_date 自动填充');

-- 代报:自由名字 → proxy_names 自动记忆
select lives_ok($$
  insert into public.practice_logs (group_id, reporter_id, subject_name, practice_type_id, quantity)
  values ('00000000-0000-0000-0000-0000000000d1',
          '00000000-0000-0000-0000-00000000000b',
          '王阿姨',
          (select id from public.practice_types where name_hans = '大悲咒'),
          108)
$$, '可用自由名字代报');

select is(
  (select use_count from public.proxy_names
   where group_id = '00000000-0000-0000-0000-0000000000d1' and name = '王阿姨'),
  1, '自由名字自动记入本群代报名单');

-- 代报群成员 A → A 收到通知
select lives_ok($$
  insert into public.practice_logs (group_id, reporter_id, subject_user_id, practice_type_id, quantity)
  values ('00000000-0000-0000-0000-0000000000d1',
          '00000000-0000-0000-0000-00000000000b',
          '00000000-0000-0000-0000-00000000000a',
          (select id from public.practice_types where name_hans = '念佛'),
          1000)
$$, '可代报群成员');

select tests_logout();
select tests_login('00000000-0000-0000-0000-00000000000a');
select is(
  (select count(*)::int from public.notifications
   where scope = 'user' and target_id = '00000000-0000-0000-0000-00000000000a' and type = 'proxy_log'),
  1, '被代报的群成员收到 App 内通知');

select is(
  (select count(*)::int from public.practice_logs
   where group_id = '00000000-0000-0000-0000-0000000000d1'),
  3, '群成员可见本群全部报数');

-- 外人 C 什么都看不到、不能报
select tests_logout();
select tests_login('00000000-0000-0000-0000-00000000000c');
select is((select count(*)::int from public.practice_logs), 0, '非成员看不到任何报数(RLS)');
select is((select count(*)::int from public.groups), 0, '非成员看不到群');
select throws_ok($$
  insert into public.practice_logs (group_id, reporter_id, practice_type_id, quantity)
  values ('00000000-0000-0000-0000-0000000000d1',
          '00000000-0000-0000-0000-00000000000c',
          (select id from public.practice_types where name_hans = '金刚经'), 1)
$$, '42501', null, '非成员不能报数');

-- 匿名(未登录)
select tests_logout();
select tests_anon();
select lives_ok($$ select count(*) from public.scriptures $$, '匿名可访问公开内容表');
select is((select count(*)::int from public.practice_types where group_id is null), 17, '匿名可读全局功课清单');
select throws_ok($$ select count(*) from public.practice_logs $$,
  '42501', null, '匿名无权访问报数表(未授 GRANT,硬拒绝)');
select throws_ok($$ select count(*) from public.notifications $$,
  '42501', null, '匿名无权访问通知表(未授 GRANT,硬拒绝)');

-- ---------------------------------------------------------------- 修改/删除权限
-- B(报数人)可改自己的数量/备注;直接置 deleted_at 被拒(须走 RPC)
select tests_logout();
select tests_login('00000000-0000-0000-0000-00000000000b');
select lives_ok($$
  update public.practice_logs set quantity = 5, note = '補記'
  where id = '00000000-0000-0000-0000-0000000000e1'
$$, '报数人可修改自己记录的数量与备注');
select throws_ok($$
  update public.practice_logs set deleted_at = now()
  where id = '00000000-0000-0000-0000-0000000000e1'
$$, 'P0001', 'use delete_practice_log() to delete', '直接置 deleted_at 被拒,删除须走 RPC');

-- C(外人)不能删除任何记录
select tests_logout();
select tests_login('00000000-0000-0000-0000-00000000000c');
select throws_ok($$
  select public.delete_practice_log('00000000-0000-0000-0000-0000000000e1')
$$, 'P0001', 'not allowed to delete this record', '非成员不能删除报数');

-- A(非报数人,是被代报人):改数量不生效(RLS 0 行命中),但可经 RPC 删自己名下记录
select tests_logout();
select tests_login('00000000-0000-0000-0000-00000000000a');
update public.practice_logs set quantity = 9999
 where subject_user_id = '00000000-0000-0000-0000-00000000000a';
select is(
  (select quantity from public.practice_logs
   where subject_user_id = '00000000-0000-0000-0000-00000000000a'),
  1000::numeric, '非报数人的修改不生效(RLS 0 行命中)');

select lives_ok($$
  select public.delete_practice_log(
    (select id from public.practice_logs
     where subject_user_id = '00000000-0000-0000-0000-00000000000a'))
$$, '被代报人可经 RPC 删除自己名下的记录');

-- 群统计随软删即时扣减(B 视角:剩 2 条记录进统计)
select tests_logout();
select tests_login('00000000-0000-0000-0000-00000000000b');
select is(
  (select sum(entries)::int from public.daily_group_stats
   where group_id = '00000000-0000-0000-0000-0000000000d1'),
  2, '软删后群统计即时扣减');

-- 成员显示名视图(代报选择器用)
select is(
  (select count(*)::int from public.group_member_display
   where group_id = '00000000-0000-0000-0000-0000000000d1'),
  2, '成员可经视图看到本群成员显示名');

-- 个人字段保护
select throws_ok($$
  update public.profiles set is_app_admin = true
  where id = '00000000-0000-0000-0000-00000000000b'
$$, 'P0001', 'not allowed to change admin/ban fields', '用户不能自封管理员');

-- ---------------------------------------------------------------- 群生命周期(P1.4)
-- 群主 A 不能直接退群(须先转让)
select tests_logout();
select tests_login('00000000-0000-0000-0000-00000000000a');
select throws_ok($$
  update public.group_members set status = 'left'
  where group_id = '00000000-0000-0000-0000-0000000000d1'
    and user_id  = '00000000-0000-0000-0000-00000000000a'
$$, 'P0001', 'owner must transfer ownership before leaving', '群主不能直接退群');

-- 转让给 B(approved 成员)
select lives_ok($$
  select public.transfer_group_ownership(
    '00000000-0000-0000-0000-0000000000d1',
    '00000000-0000-0000-0000-00000000000b')
$$, '群主可转让给 approved 成员');

select tests_logout();
select tests_login('00000000-0000-0000-0000-00000000000b');
select is(
  (select owner_id from public.groups where id = '00000000-0000-0000-0000-0000000000d1'),
  '00000000-0000-0000-0000-00000000000b'::uuid, '转让后 owner_id 更新');
select is(
  (select role::text from public.group_members
   where group_id = '00000000-0000-0000-0000-0000000000d1'
     and user_id  = '00000000-0000-0000-0000-00000000000b'),
  'owner', '转让后新群主 role=owner');

-- 新群主 B 重置 join code(旧码失效,返回 8 位新码)
select ok(
  length(public.reset_group_join_code('00000000-0000-0000-0000-0000000000d1')) = 8,
  '群主可重置 join code(8 位新码)');

-- A(已转为普通成员)可退群
select tests_logout();
select tests_login('00000000-0000-0000-0000-00000000000a');
select lives_ok($$
  update public.group_members set status = 'left'
  where group_id = '00000000-0000-0000-0000-0000000000d1'
    and user_id  = '00000000-0000-0000-0000-00000000000a'
$$, '普通成员可退群');
select is(
  (select status::text from public.group_members
   where group_id = '00000000-0000-0000-0000-0000000000d1'
     and user_id  = '00000000-0000-0000-0000-00000000000a'),
  'left', '退群后状态为 left');

-- 新群主 B 解散群(经 RPC,软删),之后对成员不可见
select tests_logout();
select tests_login('00000000-0000-0000-0000-00000000000b');
select lives_ok($$
  select public.dissolve_group('00000000-0000-0000-0000-0000000000d1')
$$, '群主可解散群');
select is(
  (select count(*)::int from public.groups
   where id = '00000000-0000-0000-0000-0000000000d1'),
  0, '解散后群对成员不可见(软删)');

-- ---------------------------------------------------------------- 账号删除匿名化(P1.9)
-- 模拟删号(delete-account Edge Function 最终执行 auth.users 删除)
select tests_logout();
delete from auth.users where id = '00000000-0000-0000-0000-00000000000b';

select is(
  (select count(*)::int from public.profiles
   where id = '00000000-0000-0000-0000-00000000000b'),
  0, '删号后 profile 级联删除');

select is(
  (select count(*)::int from public.practice_logs
   where reporter_id is null),
  3, '删号后其报数 reporter 置空(匿名化),记录保留(含软删行)');

select ok(
  (select sum(quantity) from public.practice_logs where deleted_at is null) is not null,
  '删号后群总量数据仍在(功德保留)');

select * from finish();
rollback;
