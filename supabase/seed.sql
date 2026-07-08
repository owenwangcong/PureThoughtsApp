-- 本地开发种子数据(仅 `supabase db reset` 时在本地执行,不进生产)
-- 全局功课主清单示例(生产环境由 App 管理员维护)
-- 功课项必须具体到经/咒/忏名(PRD v0.5.2 §4.1),經咒懺是分类
insert into public.practice_types (name_hant, name_hans, category, unit, is_custom, sort_order) values
  -- 經(部)
  ('金剛經',   '金刚经',   'sutra', 'volume', false, 10),
  ('地藏經',   '地藏经',   'sutra', 'volume', false, 11),
  ('藥師經',   '药师经',   'sutra', 'volume', false, 12),
  ('阿彌陀經', '阿弥陀经', 'sutra', 'volume', false, 13),
  ('無量壽經', '无量寿经', 'sutra', 'volume', false, 14),
  ('心經',     '心经',     'sutra', 'volume', false, 15),
  -- 咒(遍)
  ('大悲咒',   '大悲咒',   'mantra', 'recitation', false, 20),
  ('楞嚴咒',   '楞严咒',   'mantra', 'recitation', false, 21),
  ('十小咒',   '十小咒',   'mantra', 'recitation', false, 22),
  ('往生咒',   '往生咒',   'mantra', 'recitation', false, 23),
  ('準提咒',   '准提咒',   'mantra', 'recitation', false, 24),
  -- 懺(遍)
  ('地藏懺',           '地藏忏',           'repentance', 'recitation', false, 30),
  ('八十八佛大懺悔文', '八十八佛大忏悔文', 'repentance', 'recitation', false, 31),
  ('梁皇寶懺',         '梁皇宝忏',         'repentance', 'recitation', false, 32),
  -- 念佛(次)
  ('念佛',     '念佛',     'buddha_name', 'count', false, 40),
  ('觀音聖號', '观音圣号', 'buddha_name', 'count', false, 41),
  -- 靜坐(分鐘)
  ('靜坐',     '静坐',     'meditation', 'minute', false, 50);

-- ============================================================================
-- 本地测试账号(密码均为 test1234)
--   admin@test.local   App 管理员
--   owner@test.local   测试共修群 群主
--   member@test.local  测试共修群 已审核成员
--   user@test.local    普通用户(未入群)
-- 测试群:測試共修群,群 ID(join code)固定为 TESTGRP2
-- ============================================================================
insert into auth.users
  (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
   raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
   confirmation_token, recovery_token, email_change, email_change_token_new)
values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-8000-000000000001',
   'authenticated', 'authenticated', 'admin@test.local',
   crypt('test1234', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"display_name":"管理員"}',
   now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-8000-000000000002',
   'authenticated', 'authenticated', 'owner@test.local',
   crypt('test1234', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"display_name":"張群主"}',
   now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-8000-000000000003',
   'authenticated', 'authenticated', 'member@test.local',
   crypt('test1234', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"display_name":"李師兄"}',
   now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-8000-000000000004',
   'authenticated', 'authenticated', 'user@test.local',
   crypt('test1234', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"display_name":"王居士"}',
   now(), now(), '', '', '', '');

insert into auth.identities
  (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
select gen_random_uuid(), u.id, u.id::text,
       jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
       'email', now(), now(), now()
from auth.users u where u.email like '%@test.local';

-- 管理员标记(profiles 由 handle_new_user 触发器自动创建)
update public.profiles set is_app_admin = true
 where id = '00000000-0000-4000-8000-000000000001';

-- 测试群(触发器自动加群主成员并生成 join code,改为固定值便于测试)
insert into public.groups (id, name, description, owner_id) values
  ('00000000-0000-4000-8000-0000000000d0', '測試共修群', '本地開發測試用群組',
   '00000000-0000-4000-8000-000000000002');
update public.group_join_codes set code = 'TESTGRP2'
 where group_id = '00000000-0000-4000-8000-0000000000d0';

insert into public.group_members (group_id, user_id, status, apply_message, approved_at) values
  ('00000000-0000-4000-8000-0000000000d0', '00000000-0000-4000-8000-000000000003',
   'approved', '弟子請求加入', now());

-- 示例活动:周六共修(每周)+ 周三打坐(每周)
insert into public.events (title, type, start_at, duration_minutes, recurrence_rule, youtube_url, content, created_by) values
  ('週六共修', 'group_practice', '2026-07-11 11:30:00+00', 120, 'FREQ=WEEKLY',
   'https://youtube.com/@example', '共同誦經迴向', '00000000-0000-4000-8000-000000000001'),
  ('週三打坐', 'meditation', '2026-07-08 12:00:00+00', 60, 'FREQ=WEEKLY',
   null, '線上靜坐共修', '00000000-0000-4000-8000-000000000001');

-- 示例报数(local_date/unit 由触发器补全;含自由名字代报 → proxy_names 自动生成)
insert into public.practice_logs (group_id, reporter_id, practice_type_id, quantity) values
  ('00000000-0000-4000-8000-0000000000d0', '00000000-0000-4000-8000-000000000003',
   (select id from public.practice_types where name_hans = '金刚经' and group_id is null), 2),
  ('00000000-0000-4000-8000-0000000000d0', '00000000-0000-4000-8000-000000000002',
   (select id from public.practice_types where name_hans = '静坐' and group_id is null), 30);
insert into public.practice_logs (group_id, reporter_id, subject_name, practice_type_id, quantity) values
  ('00000000-0000-4000-8000-0000000000d0', '00000000-0000-4000-8000-000000000003', '王阿姨',
   (select id from public.practice_types where name_hans = '大悲咒' and group_id is null), 108);
