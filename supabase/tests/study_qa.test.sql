-- ============================================================================
-- 学修问答 RLS / 触发器 / RPC(pgTAP)· 运行:npx supabase test db
-- 覆盖 migration 0018 与设计文档 docs/design/study-qa.md §8.1(T-DB-01…15)。
-- 事务内执行并回滚;注意 now() 在事务内恒定,「时间前进」类断言用预置旧时间戳。
-- 破坏性用例(删 profiles 行)放在文件最后。
-- seed:admin=…0001,owner=…0002(测试中临时提为第二管理员),member(B)=…0003,user(A)=…0004
-- ============================================================================
begin;
create extension if not exists pgtap with schema extensions;
set search_path = extensions, public;

select plan(36);

-- ---------------------------------------------------------------- 身份切换
create function sq_login(uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

create function sq_reset() returns void language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', '', true);
end $$;

create function sq_anon() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('role', 'anon', true);
end $$;

-- 跨语句传递 id / 计数 / 时间戳(授 public 以便切换角色后仍可写)
create temp table sq_ids (k text primary key, v uuid);
create temp table sq_nums (k text primary key, n bigint);
create temp table sq_ts  (k text primary key, v timestamptz);
grant all on sq_ids, sq_nums, sq_ts to public;

-- ---------------------------------------------------------------- T-DB-01 隔离
select sq_login('00000000-0000-4000-8000-000000000004');  -- A
insert into sq_ids select 't1', public.create_qa_thread('打坐時妄念很多,如何安住?');

select ok(
  (select count(*) from qa_threads) = 1 and (select count(*) from qa_messages) = 1,
  'T-DB-01a A 可见自己的线程与消息');

select sq_login('00000000-0000-4000-8000-000000000003');  -- B
select ok(
  (select count(*) from qa_threads) = 0 and (select count(*) from qa_messages) = 0,
  'T-DB-01b B 完全看不到 A 的提问(0 行)');

select sq_login('00000000-0000-4000-8000-000000000001');  -- 管理员
select ok(
  (select count(*) from qa_threads) = 1 and (select count(*) from qa_messages) = 1,
  'T-DB-01c 管理员可见全部');

-- ---------------------------------------------------------------- T-DB-02 anon
select sq_anon();
select throws_ok($$ select * from public.qa_threads $$,  '42501', null,
  'T-DB-02a anon 读线程被拒');
select throws_ok($$ select * from public.qa_messages $$, '42501', null,
  'T-DB-02b anon 读消息被拒');
select throws_ok($$ insert into public.qa_threads (user_id)
  values ('00000000-0000-4000-8000-000000000004') $$, '42501', null,
  'T-DB-02c anon 建线程被拒');
select throws_ok($$ insert into public.qa_messages (thread_id, sender_id, sender_role, body)
  select v, '00000000-0000-4000-8000-000000000004', 'user', '匿名' from sq_ids where k = 't1' $$,
  '42501', null, 'T-DB-02d anon 发消息被拒');

-- ---------------------------------------------------------------- T-DB-03 B 蹭线程
select sq_login('00000000-0000-4000-8000-000000000003');
select throws_ok($$ insert into public.qa_messages (thread_id, sender_id, sender_role, body)
  select v, '00000000-0000-4000-8000-000000000003', 'user', '蹭問' from sq_ids where k = 't1' $$,
  '42501', null, 'T-DB-03 B 向 A 的线程发消息被拒');

-- ---------------------------------------------------------------- T-DB-04 追问与回复
select sq_login('00000000-0000-4000-8000-000000000004');
select lives_ok($$ insert into public.qa_messages (thread_id, sender_id, sender_role, body)
  select v, '00000000-0000-4000-8000-000000000004', 'user', '補充:每晚打坐一小時' from sq_ids where k = 't1' $$,
  'T-DB-04a A 可追问自己的线程');

select sq_login('00000000-0000-4000-8000-000000000001');
select lives_ok($$ insert into public.qa_messages (thread_id, sender_id, sender_role, body)
  select v, '00000000-0000-4000-8000-000000000001', 'admin', '妄念來去不隨,安住呼吸即可' from sq_ids where k = 't1' $$,
  'T-DB-04b 管理员可回复任意线程');

-- ---------------------------------------------------------------- T-DB-05 越权身份
select sq_login('00000000-0000-4000-8000-000000000003');
select throws_ok($$ insert into public.qa_messages (thread_id, sender_id, sender_role, body)
  select v, '00000000-0000-4000-8000-000000000003', 'admin', '假管理員' from sq_ids where k = 't1' $$,
  '42501', null, 'T-DB-05a 非管理员冒充 admin 角色被拒');

select sq_login('00000000-0000-4000-8000-000000000004');
select throws_ok($$ insert into public.qa_messages (thread_id, sender_id, sender_role, body)
  select v, '00000000-0000-4000-8000-000000000003', 'user', '偽造發送者' from sq_ids where k = 't1' $$,
  '42501', null, 'T-DB-05b 伪造 sender_id 被拒');

-- ---------------------------------------------------------------- T-DB-06 封禁
select sq_reset();
update profiles set banned_at = now() where id = '00000000-0000-4000-8000-000000000004';

select sq_login('00000000-0000-4000-8000-000000000004');
select throws_ok($$ select public.create_qa_thread('封禁期間提問') $$, '42501', null,
  'T-DB-06a 封禁用户不能建线程');
select throws_ok($$ insert into public.qa_messages (thread_id, sender_id, sender_role, body)
  select v, '00000000-0000-4000-8000-000000000004', 'user', '封禁追問' from sq_ids where k = 't1' $$,
  '42501', null, 'T-DB-06b 封禁用户不能发消息');

select sq_reset();
update profiles set banned_at = null where id = '00000000-0000-4000-8000-000000000004';
select sq_login('00000000-0000-4000-8000-000000000004');
select lives_ok($$ insert into public.qa_messages (thread_id, sender_id, sender_role, body)
  select v, '00000000-0000-4000-8000-000000000004', 'user', '解封後追問' from sq_ids where k = 't1' $$,
  'T-DB-06c 解封后恢复');
-- 此时 t1 待回覆(A 追问在后)

-- ---------------------------------------------------------------- T-DB-08 长度约束(在触及上限前测,否则先撞 CAP)
select throws_ok($$ select public.create_qa_thread('   ') $$, '23514', null,
  'T-DB-08a 空白正文被拒');
select throws_ok($$ select public.create_qa_thread(repeat('佛', 2001)) $$, '23514', null,
  'T-DB-08b 超 2000 字被拒');

-- ---------------------------------------------------------------- T-DB-15 RPC 原子性
select ok((select count(*) from qa_threads) = 1,
  'T-DB-15a 建线程失败不留空线程');
insert into sq_ids select 'atomic', public.create_qa_thread('原子測試問題');
select ok(
  exists(select 1 from qa_threads t where t.id = (select v from sq_ids where k = 'atomic'))
  and (select count(*) from qa_messages
        where thread_id = (select v from sq_ids where k = 'atomic')) = 1,
  'T-DB-15b 成功时线程与首消息同在且返回 id 正确');

-- ---------------------------------------------------------------- T-DB-07 待回覆上限
-- 当前 A 待回覆:t1 + atomic = 2;再建 1 个到 3,第 4 个应被拒
insert into sq_ids select 't2', public.create_qa_thread('第二問:誦經迴向');
select throws_ok($$ select public.create_qa_thread('第三問') $$, 'P0001', 'QA_PENDING_LIMIT',
  'T-DB-07a 已有 3 个待回覆,再建被拒');

select sq_login('00000000-0000-4000-8000-000000000001');
insert into public.qa_messages (thread_id, sender_id, sender_role, body)
  select v, '00000000-0000-4000-8000-000000000001', 'admin', '迴向如法' from sq_ids where k = 't2';

select sq_login('00000000-0000-4000-8000-000000000004');
select lives_ok($$ insert into sq_ids select 't3', public.create_qa_thread('第三問:持咒計數') $$,
  'T-DB-07b 管理员回复一个后可再建');
-- 待回覆:t1 / atomic / t3;已回覆:t2

-- ---------------------------------------------------------------- T-DB-11 回复通知
select sq_login('00000000-0000-4000-8000-000000000001');
insert into public.qa_messages (thread_id, sender_id, sender_role, body)
  select v, '00000000-0000-4000-8000-000000000001', 'admin', '標記正文XYZ' from sq_ids where k = 'atomic';

select sq_reset();
select ok(
  (select count(*) from notifications
    where type = 'qa_reply'
      and scope = 'user'
      and target_id = '00000000-0000-4000-8000-000000000004'
      and payload->>'thread_id' = (select v::text from sq_ids where k = 'atomic')
      and channels @> '{inapp,push}') = 1,
  'T-DB-11a 管理员回复产生恰 1 条 qa_reply(target/payload/channels 正确)');
select ok(
  (select coalesce(title, '') = '' and coalesce(body, '') = ''
     from notifications
    where type = 'qa_reply'
      and payload->>'thread_id' = (select v::text from sq_ids where k = 'atomic')),
  'T-DB-11b 通知 title/body 不含消息正文');

-- ---------------------------------------------------------------- T-DB-12 提问通知(多管理员/封禁排除/不自通知)
update profiles set is_app_admin = true
 where id = '00000000-0000-4000-8000-000000000002';  -- owner 临时提为第二管理员

insert into sq_nums select 'q0', count(*) from notifications where type = 'qa_question';
select sq_login('00000000-0000-4000-8000-000000000004');
insert into public.qa_messages (thread_id, sender_id, sender_role, body)
  select v, '00000000-0000-4000-8000-000000000004', 'user', '多管理員通知測試' from sq_ids where k = 't1';

select sq_reset();
select ok(
  (select count(*) from notifications where type = 'qa_question')
    - (select n from sq_nums where k = 'q0') = 2
  and exists(select 1 from notifications
       where type = 'qa_question'
         and target_id = '00000000-0000-4000-8000-000000000002'
         and payload->>'thread_id' = (select v::text from sq_ids where k = 't1')),
  'T-DB-12a 用户消息通知每个管理员各 1 条(共 2 管理员)');

update profiles set banned_at = now()
 where id = '00000000-0000-4000-8000-000000000002';
insert into sq_nums select 'q1', count(*) from notifications where type = 'qa_question';
select sq_login('00000000-0000-4000-8000-000000000004');
insert into public.qa_messages (thread_id, sender_id, sender_role, body)
  select v, '00000000-0000-4000-8000-000000000004', 'user', '封禁管理員排除測試' from sq_ids where k = 't1';
select sq_reset();
select ok(
  (select count(*) from notifications where type = 'qa_question')
    - (select n from sq_nums where k = 'q1') = 1,
  'T-DB-12b 被封禁的管理员不收提问通知');
update profiles set banned_at = null
 where id = '00000000-0000-4000-8000-000000000002';

-- 管理员自己的线程自己回复 → 也产生 qa_reply,target=本人(P8.6/0020:不再抑制自通知)
select sq_login('00000000-0000-4000-8000-000000000001');
insert into sq_ids select 'at', public.create_qa_thread('管理員自問');
select sq_reset();
insert into sq_nums select 'r0', count(*) from notifications where type = 'qa_reply';
select sq_login('00000000-0000-4000-8000-000000000001');
insert into public.qa_messages (thread_id, sender_id, sender_role, body)
  select v, '00000000-0000-4000-8000-000000000001', 'admin', '自答' from sq_ids where k = 'at';
select sq_reset();
select ok(
  (select count(*) from notifications
    where type = 'qa_reply'
      and target_id = '00000000-0000-4000-8000-000000000001'
      and payload->>'thread_id' = (select v::text from sq_ids where k = 'at'))
    = 1
  and (select count(*) from notifications where type = 'qa_reply')
    - (select n from sq_nums where k = 'r0') = 1,
  'T-DB-12c 管理员自答自己的线程也产生 qa_reply(target=本人,0020 定案)');

-- ---------------------------------------------------------------- T-DB-13 冗余列
select sq_login('00000000-0000-4000-8000-000000000004');
insert into sq_ids select 'trunc', public.create_qa_thread(repeat('心', 150));
select sq_reset();
select ok(
  (select first_message_preview = repeat('心', 100)
      and last_message_preview  = repeat('心', 100)
      and last_sender_role = 'user'
     from qa_threads where id = (select v from sq_ids where k = 'trunc')),
  'T-DB-13a 首条消息写两个 preview 且截断 100 字');

select sq_login('00000000-0000-4000-8000-000000000001');
insert into public.qa_messages (thread_id, sender_id, sender_role, body)
  select v, '00000000-0000-4000-8000-000000000001', 'admin', '回覆預覽測試' from sq_ids where k = 'trunc';
select sq_reset();
select ok(
  (select last_sender_role = 'admin'
      and last_message_preview = '回覆預覽測試'
      and first_message_preview = repeat('心', 100)
      and last_message_at = (select max(created_at) from qa_messages
                              where thread_id = qa_threads.id)
     from qa_threads where id = (select v from sq_ids where k = 'trunc')),
  'T-DB-13b 回复后 last_* 更新、first 保持');

-- ---------------------------------------------------------------- T-DB-14 update 封锁与已读 RPC
select sq_login('00000000-0000-4000-8000-000000000004');
select throws_ok($$ update public.qa_threads set last_sender_role = 'user' $$,
  '42501', null, 'T-DB-14a 客户端直接 update 线程被拒(表级无 update 授权)');
select sq_reset();

-- now() 事务内恒定:预置 1 小时前的已读位点来验证「时间前进」
update qa_threads set user_last_read_at = now() - interval '1 hour'
 where id = (select v from sq_ids where k = 'trunc');
insert into sq_ts select 'r0', user_last_read_at from qa_threads
 where id = (select v from sq_ids where k = 'trunc');

select sq_login('00000000-0000-4000-8000-000000000003');  -- B 调 A 的线程
select public.mark_qa_thread_read((select v from sq_ids where k = 'trunc'));
select sq_reset();
select ok(
  (select user_last_read_at from qa_threads
    where id = (select v from sq_ids where k = 'trunc'))
    = (select v from sq_ts where k = 'r0'),
  'T-DB-14b 非 owner 调 mark_qa_thread_read 无效果');

select sq_login('00000000-0000-4000-8000-000000000004');
select public.mark_qa_thread_read((select v from sq_ids where k = 'trunc'));
select sq_reset();
select ok(
  (select user_last_read_at from qa_threads
    where id = (select v from sq_ids where k = 'trunc'))
    > (select v from sq_ts where k = 'r0'),
  'T-DB-14c owner 调 mark_qa_thread_read 更新已读位点');

-- ---------------------------------------------------------------- T-DB-09 删除
-- 现有线程:A 的 t1/t2/t3/atomic/trunc + 管理员的 at = 6
select sq_login('00000000-0000-4000-8000-000000000003');
delete from qa_threads;                                  -- B 全删 → RLS 过滤,0 行受影响
select sq_reset();
select ok((select count(*) from qa_threads) = 6,
  'T-DB-09a B 删他人线程无效');

select sq_login('00000000-0000-4000-8000-000000000004');
delete from qa_threads where id = (select v from sq_ids where k = 't3');
select sq_reset();
select ok(
  not exists(select 1 from qa_threads  where id = (select v from sq_ids where k = 't3'))
  and not exists(select 1 from qa_messages where thread_id = (select v from sq_ids where k = 't3')),
  'T-DB-09b A 删自己的线程成功且消息级联清空');

select sq_login('00000000-0000-4000-8000-000000000001');
delete from qa_threads where id = (select v from sq_ids where k = 't2');
select sq_reset();
select ok(
  not exists(select 1 from qa_threads where id = (select v from sq_ids where k = 't2')),
  'T-DB-09c 管理员可删任意线程');

-- ---------------------------------------------------------------- T-DB-10 账号删除级联(破坏性,最后)
-- 第二管理员(0002)回复 A 的 t1 后删其 profiles 行:消息保留、sender_id 置空
select sq_login('00000000-0000-4000-8000-000000000002');
insert into public.qa_messages (thread_id, sender_id, sender_role, body)
  select v, '00000000-0000-4000-8000-000000000002', 'admin', '第二管理員回覆' from sq_ids where k = 't1';
select sq_reset();
delete from profiles where id = '00000000-0000-4000-8000-000000000002';
select ok(
  exists(select 1 from qa_messages
    where thread_id = (select v from sq_ids where k = 't1')
      and body = '第二管理員回覆'
      and sender_role = 'admin'
      and sender_id is null),
  'T-DB-10a 管理员删号后其回复保留且 sender_id 置空');

-- 删 A 的 profiles 行:其全部线程与消息级联消失
delete from profiles where id = '00000000-0000-4000-8000-000000000004';
select ok(
  not exists(select 1 from qa_threads
    where user_id = '00000000-0000-4000-8000-000000000004')
  and not exists(select 1 from qa_messages
    where thread_id = (select v from sq_ids where k = 't1')),
  'T-DB-10b 提问人删号后线程与消息全部级联清空');

select * from finish();
rollback;
