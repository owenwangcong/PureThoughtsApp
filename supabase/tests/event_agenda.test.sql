-- ============================================================================
-- 活动时间表/资料 RLS(pgTAP)· 运行:npx supabase test db
-- 覆盖 PRD v0.5.12 §5:两表匿名可读、仅 App 管理员可写;event-files 桶公开。
-- 事务内执行并回滚,不留数据。
-- ============================================================================
begin;
create extension if not exists pgtap with schema extensions;
set search_path = extensions, public;

select plan(7);

-- 身份切换(整文件一个事务,set_config local 生效到结束)
create function ea_login(uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

create function ea_anon() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('role', 'anon', true);
end $$;

-- seed 中的测试身份
--   admin  = ...0001(is_app_admin)   member = ...0003(非管理员)

-- 1) Storage 桶存在且公开(postgres 视角)
select ok(
  exists(select 1 from storage.buckets where id = 'event-files' and public),
  'event-files 桶存在且公开');

-- 2) 匿名可读时间表(seed 了 3 行週六共修流程)
select ea_anon();
select is(
  (select count(*) from public.event_agenda_items
     where event_id = (select id from public.events where title = '週六共修')),
  3::bigint, '匿名可读週六共修时间表 3 行');

-- 3) 匿名可读相关资料(无数据也应能查、不报错)
select lives_ok(
  $$ select count(*) from public.event_attachments $$,
  '匿名可 select 相关资料');

-- 4) 非管理员写时间表被 RLS 拒(42501)
select ea_login('00000000-0000-4000-8000-000000000003');
select throws_ok($$
  insert into public.event_agenda_items (event_id, day_index, start_time, activity)
  values ((select id from public.events where title = '週六共修'), 1, '08:00', '偷改')
$$, '42501', null, '非管理员不能写时间表');

-- 5) 管理员可写时间表
select ea_login('00000000-0000-4000-8000-000000000001');
select lives_ok($$
  insert into public.event_agenda_items (event_id, day_index, start_time, end_time, activity)
  values ((select id from public.events where title = '週六共修'), 2, '06:00', '07:00', '早課')
$$, '管理员可写时间表');

-- 6) 非管理员写资料被拒
select ea_login('00000000-0000-4000-8000-000000000003');
select throws_ok($$
  insert into public.event_attachments (event_id, title, storage_path)
  values ((select id from public.events where title = '週六共修'), 'x', 'x/y.pdf')
$$, '42501', null, '非管理员不能写相关资料');

-- 7) 管理员可写资料
select ea_login('00000000-0000-4000-8000-000000000001');
select lives_ok($$
  insert into public.event_attachments (event_id, title, storage_path, content_type)
  values ((select id from public.events where title = '週六共修'),
          '地藏經 經本', 'e/abc.pdf', 'application/pdf')
$$, '管理员可写相关资料');

select * from finish();
rollback;
