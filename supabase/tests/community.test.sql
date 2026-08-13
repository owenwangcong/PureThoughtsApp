-- ============================================================================
-- 去群化(单一共修体)· pgTAP · PLAN P9.1 · 设计 design/single-community.md §4.3
-- T-DB-01…15:共修体唯一性、注册即入会、建群/入群关闭、自定义功课项归属、
--             同修搜索窄口、迁移后归口一致。
-- 全部在事务内执行并回滚,不留数据。
-- ============================================================================
begin;
create extension if not exists pgtap with schema extensions;
set search_path = extensions, public;

-- 15 个用例编号,其中 T-DB-07/08/14 各拆两条断言 → 17 项
select plan(17);

-- ---------------------------------------------------------------- 辅助
create function tc_login(uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

create function tc_logout() returns void language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', '', true);
end $$;

create function tc_anon() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('role', 'anon', true);
end $$;

create function tc_gid() returns uuid
language sql stable security definer set search_path = public as $$
  select id from public.groups where is_default limit 1;
$$;

-- 测试用户:P=创建自定义功课的人 · Q=另一位同修 · R=会被封禁/拉黑的人
insert into auth.users (instance_id, id, aud, role, email)
values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000000f1', 'authenticated', 'authenticated', 'ping@test.local'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000000f2', 'authenticated', 'authenticated', 'qing@test.local'),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000000f3', 'authenticated', 'authenticated', 'rong@test.local');

-- ---------------------------------------------------------------- 共修体
select is(
  (select count(*)::int from public.groups where is_default and deleted_at is null),
  1, 'T-DB-01 全库有且仅有一行有效的共修体');

select is(
  (select count(*)::int from public.group_members
   where group_id = tc_gid() and user_id = '00000000-0000-0000-0000-0000000000f1'
     and status = 'approved'),
  1, 'T-DB-02 新注册用户自动成为共修体 approved 成员');

-- 共修体缺失时注册仍须成功(handle_new_user 在 auth 链路上,不得抛错)
select tc_logout();
update public.groups set is_default = false where is_default;
select lives_ok($$
  insert into auth.users (instance_id, id, aud, role, email)
  values ('00000000-0000-0000-0000-000000000000',
          '00000000-0000-0000-0000-0000000000f9', 'authenticated', 'authenticated', 'solo@test.local')
$$, 'T-DB-03 共修体不存在时注册不抛错(静默跳过入会)');
update public.groups set is_default = true
 where id = (select id from public.groups where deleted_at is null order by created_at limit 1);

-- ---------------------------------------------------------------- 建群 / 入群已关闭
select tc_login('00000000-0000-0000-0000-0000000000f1');
select throws_ok($$
  insert into public.groups (name, owner_id)
  values ('偷偷建群', '00000000-0000-0000-0000-0000000000f1')
$$, '42501', null, 'T-DB-04 authenticated 直接 insert groups 被拒');

select throws_ok($$ select public.join_group('WHATEVER', null) $$,
  'P0001', 'joining is no longer required: every registered user is a member',
  'T-DB-05 join_group 已停用');

select lives_ok($$
  insert into public.practice_logs (group_id, reporter_id, practice_type_id, quantity)
  values (tc_gid(), '00000000-0000-0000-0000-0000000000f1',
          (select id from public.practice_types where name_hans = '心经' and group_id is null), 1)
$$, 'T-DB-06 任一注册用户可直接报数(零门槛)');

-- ---------------------------------------------------------------- 同修搜索
-- P 拉黑 R;R 之后被封禁
insert into public.user_blocks (user_id, blocked_user_id)
values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000f3');

select is(
  (select count(*)::int from public.search_members('qing')),
  1, 'T-DB-07a search_members 能搜到同修');

select ok(
  not exists (select 1 from public.search_members('ping'))
  and not exists (select 1 from public.search_members('rong')),
  'T-DB-07b search_members 排除自己与已拉黑的人');

select is(
  (select count(*)::int from public.search_members('')),
  0, 'T-DB-08a 空关键词返回空集(不做全表导出)');

select tc_logout();
select tc_anon();
select throws_ok($$ select count(*) from public.search_members('qing') $$,
  '42501', null, 'T-DB-08b 匿名不可调用 search_members(未授 execute,硬拒绝)');

-- ---------------------------------------------------------------- 迁移归口
select tc_logout();
select is(
  (select count(*)::int from public.practice_logs where group_id <> tc_gid()),
  0, 'T-DB-09 无任何报数指向非共修体');

select is(
  (select count(*)::int from public.proxy_names p
   where p.group_id <> tc_gid()
      or exists (select 1 from public.proxy_names q
                 where q.group_id = p.group_id and q.name = p.name and q.id <> p.id)),
  0, 'T-DB-10 代报名单已归口共修体且无重名');

select is(
  (select count(*)::int from public.vows where group_id is not null),
  0, 'T-DB-11 发愿范围一律为跨全部(group_id 恒 null)');

-- ---------------------------------------------------------------- 自定义功课项(Q8)
select tc_login('00000000-0000-0000-0000-0000000000f1');
insert into public.practice_types (group_id, name_hant, name_hans, category, unit, is_custom, sort_order)
values (tc_gid(), '大方廣佛華嚴經', '大方广佛华严经', 'sutra', 'volume', true, 900);

select is(
  (select created_by from public.practice_types where name_hans = '大方广佛华严经'),
  '00000000-0000-0000-0000-0000000000f1'::uuid,
  'T-DB-13 新建自定义功课项自动落 created_by = 当前用户');

-- 「可选」过滤:Q 拿不到 P 的自定义项;但按 id 仍可读到名称(渲染他人记录所必需)
select tc_logout();
select tc_login('00000000-0000-0000-0000-0000000000f2');
select ok(
  not exists (
    select 1 from public.practice_types
    where name_hans = '大方广佛华严经'
      and (group_id is null or created_by = auth.uid()))
  and exists (select 1 from public.practice_types where name_hans = '大方广佛华严经'),
  'T-DB-14a 他人的自定义项不进我的可选清单,但名称可读');

select throws_ok($$
  insert into public.practice_logs (group_id, reporter_id, practice_type_id, quantity)
  values (tc_gid(), '00000000-0000-0000-0000-0000000000f2',
          (select id from public.practice_types where name_hans = '大方广佛华严经'), 1)
$$, 'P0001', 'custom practice type belongs to another user',
  'T-DB-14b 不得用他人的自定义功课项报数');

-- 存量回填:seed 的全局主清单项不是自定义项,created_by 应为空
select tc_logout();
select is(
  (select count(*)::int from public.practice_types
   where group_id is null and created_by is not null),
  0, 'T-DB-15 全局主清单项不带 created_by(仅自定义项归属到人)');

select * from finish();
rollback;
