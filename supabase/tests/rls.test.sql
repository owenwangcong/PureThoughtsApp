-- ============================================================================
-- RLS / 权限验证(pgTAP)· 运行:npx supabase test db
-- 覆盖 PRD §12.3 核心策略。**v0.6.0 去群化改写**(PLAN P9.1):
--   建群 / join code / 入群审核 / 转让 / 解散 / 退群 六组用例已随功能下线删除,
--   替换为「注册即入会」「建群已关闭」「join_group 已停用」「封禁用户不能报数」。
--   单一共修体后所有注册用户互为同修,故不再有「非成员」视角 —— 边界测试改由
--   匿名(anon)与封禁用户承担。去群化专属用例见 community.test.sql。
-- 全部在事务内执行并回滚,不留数据。
-- ============================================================================
begin;
create extension if not exists pgtap with schema extensions;
set search_path = extensions, public;

select plan(35);

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

-- 共修体 id(唯一 is_default 行;definer 以免受调用者 RLS 影响)
create function tests_gid() returns uuid
language sql stable security definer set search_path = public as $$
  select id from public.groups where is_default limit 1;
$$;

-- ---------------------------------------------------------------- 测试用户
-- A / B / C 三个普通注册用户(handle_new_user 触发器自动建 profiles 并自动入会)
insert into auth.users (instance_id, id, aud, role, email)
values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-00000000000a', 'authenticated', 'authenticated', 'alice@test.local'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-00000000000b', 'authenticated', 'authenticated', 'bob@test.local'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-00000000000c', 'authenticated', 'authenticated', 'carol@test.local');

select is(
  (select count(*)::int from public.profiles where id in
    ('00000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-00000000000b','00000000-0000-0000-0000-00000000000c')),
  3, 'handle_new_user 触发器:注册自动创建 profiles');

-- 去群化核心:注册即入会(PRD v0.6.0 §3.1)
select is(
  (select count(*)::int from public.group_members
   where group_id = tests_gid() and status = 'approved'
     and user_id in ('00000000-0000-0000-0000-00000000000a',
                     '00000000-0000-0000-0000-00000000000b',
                     '00000000-0000-0000-0000-00000000000c')),
  3, '注册即自动成为共修体 approved 成员(无需申请与审核)');

-- 建群与入群申请已关闭
select tests_login('00000000-0000-0000-0000-00000000000a');
select throws_ok($$
  insert into public.groups (name, owner_id)
  values ('新群', '00000000-0000-0000-0000-00000000000a')
$$, '42501', null, '建群已关闭:authenticated 无 groups insert 权限');

select throws_ok($$ select public.join_group('ANYCODE8', 'hi') $$,
  'P0001', 'joining is no longer required: every registered user is a member',
  'join_group 已停用');

-- 公告更新 → 共修体范围通知(管理员维护,此处以 postgres 身份模拟)
select tests_logout();
update public.groups set announcement = '本週六共修改為線上' where id = tests_gid();
select tests_login('00000000-0000-0000-0000-00000000000b');
select is(
  (select count(*)::int from public.notifications
   where scope = 'group' and type = 'announcement' and target_id = tests_gid()),
  1, '公告更新生成共修体范围通知,成员可见');

-- ---------------------------------------------------------------- 报数与可见性
select lives_ok($$
  insert into public.practice_logs (id, group_id, reporter_id, practice_type_id, quantity)
  values ('00000000-0000-0000-0000-0000000000e1',
          tests_gid(),
          '00000000-0000-0000-0000-00000000000b',
          (select id from public.practice_types where name_hans = '金刚经'),
          3)
$$, '注册用户可直接报数(无需审核)');

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
  values (tests_gid(),
          '00000000-0000-0000-0000-00000000000b',
          '陳阿姨',
          (select id from public.practice_types where name_hans = '大悲咒'),
          108)
$$, '可用自由名字代报');

select is(
  (select use_count from public.proxy_names
   where group_id = tests_gid() and name = '陳阿姨'),
  1, '自由名字自动记入代报名单');

-- 代报同修 A → A 收到通知
select lives_ok($$
  insert into public.practice_logs (group_id, reporter_id, subject_user_id, practice_type_id, quantity)
  values (tests_gid(),
          '00000000-0000-0000-0000-00000000000b',
          '00000000-0000-0000-0000-00000000000a',
          (select id from public.practice_types where name_hans = '念佛'),
          1000)
$$, '可代报同修');

select tests_logout();
select tests_login('00000000-0000-0000-0000-00000000000a');
select is(
  (select count(*)::int from public.notifications
   where scope = 'user' and target_id = '00000000-0000-0000-0000-00000000000a' and type = 'proxy_log'),
  1, '被代报的同修收到 App 内通知');

select is(
  (select count(*)::int from public.practice_logs
   where reporter_id = '00000000-0000-0000-0000-00000000000b'),
  3, '同修可见彼此的共修报数');

-- ---------------------------------------------------------------- 匿名(未登录)
select tests_logout();
select tests_anon();
select lives_ok($$ select count(*) from public.scriptures $$, '匿名可访问公开内容表');
select is((select count(*)::int from public.practice_types where group_id is null), 17, '匿名可读全局功课清单');
select throws_ok($$ select count(*) from public.practice_logs $$,
  '42501', null, '匿名无权访问报数表(未授 GRANT,硬拒绝)');
select throws_ok($$ select count(*) from public.notifications $$,
  '42501', null, '匿名无权访问通知表(未授 GRANT,硬拒绝)');
select lives_ok($$ select count(*) from public.live_streams $$,
  '匿名可读直播状态(公开内容,P3.1)');
select throws_ok($$
  insert into public.live_streams (platform, url) values ('youtube', 'x')
$$, '42501', null, '匿名不能写直播状态(仅服务端)');

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

-- C(同修,但既非报数人也非被代报人、更非管理员)不能删别人的记录
select tests_logout();
select tests_login('00000000-0000-0000-0000-00000000000c');
select throws_ok($$
  select public.delete_practice_log('00000000-0000-0000-0000-0000000000e1')
$$, 'P0001', 'not allowed to delete this record', '无关同修不能删除他人报数');

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

-- 共修统计随软删即时扣减(B 本轮新增 3 条、软删 1 条 → 净增 2)
select tests_logout();
select tests_login('00000000-0000-0000-0000-00000000000b');
-- seed 3 条 + 本轮 B 报 3 条 - 软删 1 条 = 5
select is(
  (select sum(entries)::int from public.daily_group_stats where group_id = tests_gid()),
  5, '软删后共修统计即时扣减');

-- 成员显示名视图(管理后台用;客户端已改走 search_members)
select ok(
  (select count(*)::int from public.group_member_display where group_id = tests_gid()) >= 3,
  '成员可经视图看到同修显示名');

-- 同修搜索 RPC(客户端代报选择器,PRD v0.6.0 §4.2)
select is(
  (select count(*)::int from public.search_members('ali')),
  1, 'search_members 按显示名片段搜到同修(代报选择器数据源)');

-- 个人字段保护
select throws_ok($$
  update public.profiles set is_app_admin = true
  where id = '00000000-0000-0000-0000-00000000000b'
$$, 'P0001', 'not allowed to change admin/ban fields', '用户不能自封管理员');

-- ---------------------------------------------------------------- 活动变更通知(v0.5.7)
-- v0.5.21 降噪(migration 0026):编辑类变更走 5 分钟防抖窗口,窗口内反复编辑只更新
-- 同一条未发通知;「刚新建又编辑」保持「新增」语义、只刷新标题,不再多发一条。
select tests_logout();
insert into public.events (title, event_type_id, start_at)
values ('測試活動通知',
        (select id from public.event_types where name_hans = '共修'),
        now() + interval '1 day');
select tests_login('00000000-0000-0000-0000-00000000000c');
select is(
  (select count(*)::int from public.notifications
   where type = 'event_changed' and payload->>'action' = 'created'
     and payload->>'title' = '測試活動通知'),
  1, '新增活动生成全员通知');

-- 新建后立即编辑 → 聚合进上面那条(不新增,action 仍为 created,标题刷新)
select tests_logout();
update public.events set title = '測試活動通知(改)' where title = '測試活動通知';
select tests_login('00000000-0000-0000-0000-00000000000c');
select is(
  (select count(*)::int from public.notifications
   where type = 'event_changed' and payload->>'title' like '測試活動通知%'),
  1, '新建后立即编辑被防抖聚合,不额外产生通知');

-- 上一条已投递后再改 → 才产生独立的「更新」通知
select tests_logout();
update public.notifications set sent_at = now() where type = 'event_changed';
update public.events set title = '測試活動通知(再改)' where title = '測試活動通知(改)';
select tests_login('00000000-0000-0000-0000-00000000000c');
select is(
  (select count(*)::int from public.notifications
   where type = 'event_changed' and payload->>'action' = 'updated'
     and payload->>'title' = '測試活動通知(再改)'),
  1, '修改活动生成全员通知');

-- ---------------------------------------------------------------- 封禁用户
select tests_logout();
update public.profiles set banned_at = now() where id = '00000000-0000-0000-0000-00000000000c';
select tests_login('00000000-0000-0000-0000-00000000000c');
select throws_ok($$
  insert into public.practice_logs (group_id, reporter_id, practice_type_id, quantity)
  values (tests_gid(), '00000000-0000-0000-0000-00000000000c',
          (select id from public.practice_types where name_hans = '金刚经'), 1)
$$, '42501', null, '封禁用户不能报数(is_active_user 拦截)');

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
  '删号后共修总量数据仍在(功德保留)');

select * from finish();
rollback;
