-- ============================================================================
-- 佛历 + 时区 RLS 与通知幂等(pgTAP)· 运行:npx supabase test db
-- 覆盖 PRD v0.5.15:almanac_days/app_settings 读写口径、events.timezone 默认值、
-- generate_almanac_notifications() 幂等(重跑不产生重复通知)。
-- 事务内执行并回滚,不留数据。
-- ============================================================================
begin;
create extension if not exists pgtap with schema extensions;
set search_path = extensions, public;

select plan(10);

-- 身份切换(同 event_agenda.test.sql 约定)
create function al_login(uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

create function al_anon() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('role', 'anon', true);
end $$;

create function al_postgres() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('role', 'postgres', true);
end $$;

-- 1) 数据 migration 已灌入(50 年特殊日约 6500 行)
select ok((select count(*) from public.almanac_days) > 6000,
  'almanac_days 已灌入 50 年数据');

-- 2) 锚点:2026-05-24 佛诞(四月初八)
select ok(
  exists(select 1 from public.almanac_days
    where solar_date = '2026-05-24' and 'sakyamuni_birth' = any(festival_ids)
      and lunar_month = 4 and lunar_day = 8),
  '2026-05-24 为释迦牟尼佛圣诞(四月初八)');

-- 3) 匿名可读 almanac_days
select al_anon();
select ok((select count(*) from public.almanac_days where solar_date < '2027-01-01') > 100,
  '匿名可读佛历特殊日');

-- 4) 匿名可读 app_settings 默认时区
select is(
  (select value from public.app_settings where key = 'default_event_timezone'),
  'Asia/Shanghai', '匿名可读默认活动时区');

-- 5) 非管理员改 app_settings 不生效(UPDATE 被 RLS USING 过滤为 0 行,静默)
select al_login('00000000-0000-4000-8000-000000000003');
update public.app_settings set value = 'Asia/Tokyo' where key = 'default_event_timezone';
select is(
  (select value from public.app_settings where key = 'default_event_timezone'),
  'Asia/Shanghai', '非管理员改全局配置不生效');

-- 6) authenticated 写 almanac_days 被拒(42501,无写策略)
select throws_ok($$
  insert into public.almanac_days (solar_date, lunar_month, lunar_day) values ('2099-01-01', 1, 1)
$$, '42501', null, '登录用户不能写佛历表');

-- 7) 管理员可改 app_settings
select al_login('00000000-0000-4000-8000-000000000001');
select lives_ok($$
  update public.app_settings set value = 'America/Los_Angeles', updated_at = now()
   where key = 'default_event_timezone'
$$, '管理员可改默认活动时区');

-- 8) 存量活动 timezone 默认 Asia/Shanghai
select al_postgres();
select is(
  (select timezone from public.events where title = '週六共修'),
  'Asia/Shanghai', '存量活动 timezone 默认 Asia/Shanghai');

-- 9)+10) 通知幂等:注入「今天(UTC+8)」节日+斋日、「明天」重大节日,函数跑两次只产 3 条
delete from public.notifications where type = 'almanac';
insert into public.almanac_days
  (solar_date, lunar_month, lunar_day, is_leap_month, festival_ids, names_hant, names_hans, is_zhai_ten, has_major)
values
  ((now() at time zone 'Asia/Shanghai')::date,     4, 8, false, '{test_fest}', '{測試節}', '{测试节}', true,  false),
  ((now() at time zone 'Asia/Shanghai')::date + 1, 4, 9, false, '{test_major}', '{測試大節}', '{测试大节}', false, true)
on conflict (solar_date) do update set
  lunar_month = excluded.lunar_month, lunar_day = excluded.lunar_day,
  is_leap_month = excluded.is_leap_month, festival_ids = excluded.festival_ids,
  names_hant = excluded.names_hant, names_hans = excluded.names_hans,
  is_zhai_ten = excluded.is_zhai_ten, has_major = excluded.has_major;

select public.generate_almanac_notifications();
select public.generate_almanac_notifications();

select is((select count(*) from public.notifications where type = 'almanac'),
  3::bigint, '跑两次仅产生 3 条佛历通知(幂等)');
select is(
  (select count(distinct payload->>'kind') from public.notifications where type = 'almanac'),
  3::bigint, '三条分别为 festival / zhai / festival_eve');

select * from finish();
rollback;
