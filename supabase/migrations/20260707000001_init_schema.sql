-- ============================================================================
-- 善护念 PureThoughts · Schema v1  (PRD v0.5.1 §12.2 数据模型 / §12.3 RLS)
-- 设计要点:
--   * join_code 独立成 group_join_codes 表(owner 专属 RLS),入群走 join_group() RPC,防遍历
--   * practice_logs 软删除(deleted_at);统计一律按 local_date;unit 落库时从功课项快照
--   * 代报:subject_user_id(群成员,触发通知)/ subject_name(自由名字,自动记入 proxy_names)
--   * 账号删除:profiles 级联删,practice_logs 的 reporter/subject ON DELETE SET NULL(匿名化,群总量不变)
--   * 单位枚举:volume=部 recitation=遍 count=次 minute=分钟(客户端做简繁显示)
-- ============================================================================

-- ---------------------------------------------------------------- 枚举类型
create type public.member_status     as enum ('pending','approved','rejected','removed','left');
create type public.member_role       as enum ('owner','member');
create type public.practice_unit     as enum ('volume','recitation','count','minute');
create type public.vow_status        as enum ('active','completed','expired','abandoned');
create type public.notification_scope as enum ('user','group','all');
create type public.push_platform     as enum ('apns','fcm');
create type public.media_kind        as enum ('audio','video');
create type public.media_source      as enum ('youtube','https');
create type public.report_target     as enum ('user','group','log');
create type public.report_status     as enum ('open','resolved');
create type public.event_type        as enum ('group_practice','meditation','dharma_talk','dharma_assembly','other');

-- ---------------------------------------------------------------- 表
create table public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  locale       text not null default 'zh_Hant' check (locale in ('zh_Hant','zh_Hans')),
  font_scale   numeric(3,2) not null default 1.0 check (font_scale between 0.8 and 3.0),
  timezone     text not null default 'UTC',
  region       text not null default 'other' check (region in ('cn','other')),
  is_app_admin boolean not null default false,
  banned_at    timestamptz,
  created_at   timestamptz not null default now()
);

create table public.groups (
  id           uuid primary key default gen_random_uuid(),
  name         text not null check (char_length(name) between 1 and 100),
  description  text,
  announcement text,
  owner_id     uuid not null references public.profiles(id),
  deleted_at   timestamptz,
  created_at   timestamptz not null default now()
);

-- join_code 单独存放:仅群主/管理员可见(RLS),入群走 join_group() RPC
create table public.group_join_codes (
  group_id   uuid primary key references public.groups(id) on delete cascade,
  code       text not null unique,
  updated_at timestamptz not null default now()
);

create table public.group_members (
  group_id      uuid not null references public.groups(id) on delete cascade,
  user_id       uuid not null references public.profiles(id) on delete cascade,
  status        public.member_status not null default 'pending',
  role          public.member_role not null default 'member',
  apply_message text,
  approved_at   timestamptz,
  created_at    timestamptz not null default now(),
  primary key (group_id, user_id)
);
create index idx_group_members_user on public.group_members (user_id);
create index idx_group_members_group_status on public.group_members (group_id, status);

create table public.practice_types (
  id         uuid primary key default gen_random_uuid(),
  group_id   uuid references public.groups(id) on delete cascade,  -- null = 全局主清单
  name_hant  text not null,
  name_hans  text not null,
  unit       public.practice_unit not null,
  is_custom  boolean not null default false,
  active     boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  check (is_custom = (group_id is not null))
);
create index idx_practice_types_group on public.practice_types (group_id);

create table public.practice_logs (
  id               uuid primary key default gen_random_uuid(),
  group_id         uuid not null references public.groups(id) on delete cascade,
  reporter_id      uuid references public.profiles(id) on delete set null,        -- 删号匿名化
  subject_user_id  uuid references public.profiles(id) on delete set null,        -- 代报给群成员
  subject_name     text check (subject_name is null or char_length(subject_name) between 1 and 50), -- 代报自由名字
  practice_type_id uuid not null references public.practice_types(id),
  quantity         numeric(14,2) not null check (quantity > 0),
  unit             public.practice_unit not null,
  note             text,
  local_date       date not null,                                                 -- 统计口径:报数人本地自然日
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  deleted_at       timestamptz,
  check (not (subject_user_id is not null and subject_name is not null))
);
create index idx_logs_group_date  on public.practice_logs (group_id, local_date) where deleted_at is null;
create index idx_logs_subject     on public.practice_logs (subject_user_id, practice_type_id, local_date) where deleted_at is null;
create index idx_logs_reporter    on public.practice_logs (reporter_id, local_date);
create index idx_logs_type        on public.practice_logs (practice_type_id);

-- 代报自由名字的群共享名单(报数时触发器自动 upsert)
create table public.proxy_names (
  id           uuid primary key default gen_random_uuid(),
  group_id     uuid not null references public.groups(id) on delete cascade,
  name         text not null check (char_length(name) between 1 and 50),
  created_by   uuid references public.profiles(id) on delete set null,
  use_count    int not null default 1,
  last_used_at timestamptz not null default now(),
  unique (group_id, name)
);

create table public.vows (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.profiles(id) on delete cascade,
  group_id         uuid references public.groups(id) on delete cascade,  -- null = 跨全部群
  practice_type_id uuid not null references public.practice_types(id),
  target_qty       numeric(14,2) not null check (target_qty > 0),
  start_date       date not null,
  end_date         date not null,
  status           public.vow_status not null default 'active',
  created_at       timestamptz not null default now(),
  check (end_date >= start_date)
);
create index idx_vows_user on public.vows (user_id);

create table public.events (
  id               uuid primary key default gen_random_uuid(),
  title            text not null,
  type             public.event_type not null default 'other',
  start_at         timestamptz not null,
  duration_minutes int check (duration_minutes > 0),
  recurrence_rule  text,   -- RRULE(RFC 5545);null = 单次活动
  webex_url        text,
  youtube_url      text,
  content          text,
  created_by       uuid references public.profiles(id) on delete set null,
  created_at       timestamptz not null default now()
);

create table public.event_overrides (
  event_id        uuid not null references public.events(id) on delete cascade,
  occurrence_date date not null,
  patch           jsonb not null default '{}',   -- 改期/改内容/取消:{cancelled, start_at, title, content, ...}
  primary key (event_id, occurrence_date)
);

create table public.media_items (
  id         uuid primary key default gen_random_uuid(),
  title_hant text not null,
  title_hans text not null,
  kind       public.media_kind not null,
  source     public.media_source not null,
  url        text not null,
  size_bytes bigint,
  category   text,
  sort_order int not null default 0,
  active     boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.scriptures (
  id         uuid primary key default gen_random_uuid(),
  title      text not null,
  web_url    text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create table public.push_tokens (
  token      text primary key,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  platform   public.push_platform not null,
  fcm_failed boolean not null default false,   -- 邮件兜底标记
  updated_at timestamptz not null default now()
);
create index idx_push_tokens_user on public.push_tokens (user_id);

create table public.notifications (
  id           uuid primary key default gen_random_uuid(),
  scope        public.notification_scope not null,
  target_id    uuid,                        -- user id / group id;scope=all 时为 null
  title        text not null default '',
  body         text,
  type         text not null default 'general',   -- general / proxy_log / event_reminder / announcement ...
  payload      jsonb not null default '{}',       -- 客户端按 type 渲染本地化文案所需数据
  event_id     uuid references public.events(id) on delete set null,
  channels     text[] not null default '{inapp}', -- inapp / push / email
  scheduled_at timestamptz,
  sent_at      timestamptz,
  created_at   timestamptz not null default now(),
  check ((scope = 'all') = (target_id is null))
);
create index idx_notifications_target on public.notifications (scope, target_id, created_at desc);

create table public.notification_reads (
  notification_id uuid not null references public.notifications(id) on delete cascade,
  user_id         uuid not null references public.profiles(id) on delete cascade,
  read_at         timestamptz not null default now(),
  primary key (notification_id, user_id)
);

create table public.reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_type public.report_target not null,
  target_id   uuid not null,
  reason      text not null,
  status      public.report_status not null default 'open',
  handled_by  uuid references public.profiles(id),
  created_at  timestamptz not null default now()
);

create table public.user_blocks (
  user_id         uuid not null references public.profiles(id) on delete cascade,
  blocked_user_id uuid not null references public.profiles(id) on delete cascade,
  created_at      timestamptz not null default now(),
  primary key (user_id, blocked_user_id),
  check (user_id <> blocked_user_id)
);

-- ---------------------------------------------------------------- RLS 辅助函数(security definer,避免策略递归)
create or replace function public.is_app_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select p.is_app_admin from profiles p where p.id = auth.uid()), false);
$$;

create or replace function public.is_active_user() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles p where p.id = auth.uid() and p.banned_at is null);
$$;

create or replace function public.is_group_member(gid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from group_members gm
                 where gm.group_id = gid and gm.user_id = auth.uid() and gm.status = 'approved');
$$;

create or replace function public.is_group_owner(gid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from groups g
                 where g.id = gid and g.owner_id = auth.uid() and g.deleted_at is null);
$$;

-- 与群存在任意状态的关系(pending 申请者可看到群名)
create or replace function public.has_group_relation(gid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from group_members gm
                 where gm.group_id = gid and gm.user_id = auth.uid());
$$;

-- ---------------------------------------------------------------- 触发器
-- 注册即建 profile
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name',
                           split_part(coalesce(new.email,''),'@',1)));
  return new;
end $$;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 防止用户自改 is_app_admin / banned_at
create or replace function public.protect_profile_columns() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not public.is_app_admin() then
    if new.is_app_admin is distinct from old.is_app_admin
       or new.banned_at is distinct from old.banned_at then
      raise exception 'not allowed to change admin/ban fields';
    end if;
  end if;
  return new;
end $$;
create trigger trg_protect_profile_columns
  before update on public.profiles
  for each row execute function public.protect_profile_columns();

-- 建群:自动加群主成员 + 生成 join code
create or replace function public.gen_join_code() returns text
language plpgsql volatile set search_path = public as $$
declare
  chars constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; -- 去掉易混淆的 0/O/1/I/L
  v_code text;
begin
  loop
    v_code := '';
    for i in 1..8 loop
      v_code := v_code || substr(chars, 1 + floor(random() * length(chars))::int, 1);
    end loop;
    exit when not exists (select 1 from group_join_codes c where c.code = v_code);
  end loop;
  return v_code;
end $$;

create or replace function public.handle_new_group() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.group_members (group_id, user_id, status, role, approved_at)
  values (new.id, new.owner_id, 'approved', 'owner', now());
  insert into public.group_join_codes (group_id, code)
  values (new.id, public.gen_join_code());
  return new;
end $$;
create trigger trg_handle_new_group
  after insert on public.groups
  for each row execute function public.handle_new_group();

-- 成员表守卫:role 只能经 transfer RPC 改;群主不得直接退出(需先转让)
create or replace function public.guard_group_members() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return new; end if;  -- 服务端/内部操作放行
  if new.role is distinct from old.role then
    raise exception 'role can only change via ownership transfer';
  end if;
  if old.user_id = (select owner_id from groups where id = old.group_id)
     and new.status <> 'approved' then
    raise exception 'owner must transfer ownership before leaving';
  end if;
  return new;
end $$;
create trigger trg_guard_group_members
  before update on public.group_members
  for each row execute function public.guard_group_members();

-- 报数落库前:校验功课项/代报对象,快照 unit,补 local_date
create or replace function public.before_insert_practice_log() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  pt record;
  tz text;
begin
  select * into pt from practice_types where id = new.practice_type_id;
  if not found or not pt.active then
    raise exception 'invalid or inactive practice type';
  end if;
  if pt.group_id is not null and pt.group_id <> new.group_id then
    raise exception 'practice type not available in this group';
  end if;
  new.unit := pt.unit;
  if new.local_date is null then
    select p.timezone into tz from profiles p where p.id = new.reporter_id;
    new.local_date := (now() at time zone coalesce(tz, 'UTC'))::date;
  end if;
  if new.subject_user_id is not null and new.subject_user_id <> new.reporter_id then
    if not exists (select 1 from group_members gm
                   where gm.group_id = new.group_id
                     and gm.user_id = new.subject_user_id
                     and gm.status = 'approved') then
      raise exception 'subject must be an approved group member';
    end if;
  end if;
  return new;
end $$;
create trigger trg_before_insert_practice_log
  before insert on public.practice_logs
  for each row execute function public.before_insert_practice_log();

-- 报数更新守卫:客户端直连仅报数人可改 quantity/note;
-- 软删一律走 delete_practice_log() RPC —— 因为 PG 会用 SELECT 策略校验 UPDATE 后的新行,
-- 直接置 deleted_at 会让行对自己"消失"而报 RLS 违规(实测确认)
create or replace function public.guard_practice_log_update() returns trigger
language plpgsql set search_path = public as $$
begin
  -- 仅约束客户端直连(authenticated);RPC(definer)/服务端/FK 匿名化不受限
  if current_user <> 'authenticated' then
    new.updated_at := now();
    return new;
  end if;
  if old.deleted_at is not null then
    raise exception 'record already deleted';
  end if;
  if new.deleted_at is distinct from old.deleted_at then
    raise exception 'use delete_practice_log() to delete';
  end if;
  -- 不得改动归属与口径字段
  if (new.group_id, new.reporter_id, new.subject_user_id, new.subject_name,
      new.practice_type_id, new.unit, new.local_date)
     is distinct from
     (old.group_id, old.reporter_id, old.subject_user_id, old.subject_name,
      old.practice_type_id, old.unit, old.local_date) then
    raise exception 'only quantity and note may change';
  end if;
  new.updated_at := now();
  return new;
end $$;
create trigger trg_guard_practice_log_update
  before update on public.practice_logs
  for each row execute function public.guard_practice_log_update();

-- 报数落库后:自由名字记入 proxy_names;代报群成员生成通知
create or replace function public.after_insert_practice_log() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.subject_name is not null then
    insert into public.proxy_names (group_id, name, created_by)
    values (new.group_id, new.subject_name, new.reporter_id)
    on conflict (group_id, name)
    do update set use_count = proxy_names.use_count + 1, last_used_at = now();
  end if;
  if new.subject_user_id is not null and new.subject_user_id <> new.reporter_id then
    insert into public.notifications (scope, target_id, type, payload, channels)
    values ('user', new.subject_user_id, 'proxy_log',
            jsonb_build_object('log_id', new.id, 'group_id', new.group_id,
                               'reporter_id', new.reporter_id,
                               'practice_type_id', new.practice_type_id,
                               'quantity', new.quantity),
            '{inapp}');
  end if;
  return new;
end $$;
create trigger trg_after_insert_practice_log
  after insert on public.practice_logs
  for each row execute function public.after_insert_practice_log();

-- push_tokens.updated_at
create or replace function public.set_updated_at() returns trigger
language plpgsql set search_path = public as $$
begin
  new.updated_at := now();
  return new;
end $$;
create trigger trg_push_tokens_updated
  before update on public.push_tokens
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------- RPC
-- 入群申请(附说明);join_code 不可直读,防遍历由本函数统一入口
create or replace function public.join_group(p_code text, p_message text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_uid    uuid := auth.uid();
  v_gid    uuid;
  v_status public.member_status;
begin
  if v_uid is null then raise exception 'authentication required'; end if;
  if not public.is_active_user() then raise exception 'account banned or missing'; end if;

  select c.group_id into v_gid
  from group_join_codes c
  join groups g on g.id = c.group_id
  where c.code = upper(trim(p_code)) and g.deleted_at is null;
  if v_gid is null then raise exception 'invalid join code'; end if;

  select gm.status into v_status from group_members gm
  where gm.group_id = v_gid and gm.user_id = v_uid;

  if v_status = 'approved' then
    raise exception 'already a member';
  elsif v_status = 'pending' then
    update group_members set apply_message = p_message
    where group_id = v_gid and user_id = v_uid;
  elsif v_status is null then
    insert into group_members (group_id, user_id, status, apply_message)
    values (v_gid, v_uid, 'pending', p_message);
  else  -- rejected / removed / left → 重新申请
    update group_members
    set status = 'pending', apply_message = p_message, approved_at = null
    where group_id = v_gid and user_id = v_uid;
  end if;
  return v_gid;
end $$;

-- 群主查看本群 join code
create or replace function public.get_group_join_code(p_group_id uuid) returns text
language plpgsql stable security definer set search_path = public as $$
begin
  if not (public.is_group_owner(p_group_id) or public.is_app_admin()) then
    raise exception 'only group owner can view join code';
  end if;
  return (select code from group_join_codes where group_id = p_group_id);
end $$;

-- 重置 join code(旧码失效)
create or replace function public.reset_group_join_code(p_group_id uuid) returns text
language plpgsql security definer set search_path = public as $$
declare v_code text;
begin
  if not (public.is_group_owner(p_group_id) or public.is_app_admin()) then
    raise exception 'only group owner can reset join code';
  end if;
  v_code := public.gen_join_code();
  update group_join_codes set code = v_code, updated_at = now() where group_id = p_group_id;
  return v_code;
end $$;

-- 群主转让(新群主须为 approved 成员)
create or replace function public.transfer_group_ownership(p_group_id uuid, p_new_owner uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not (public.is_group_owner(p_group_id) or public.is_app_admin()) then
    raise exception 'only group owner can transfer ownership';
  end if;
  if not exists (select 1 from group_members
                 where group_id = p_group_id and user_id = p_new_owner and status = 'approved') then
    raise exception 'new owner must be an approved member';
  end if;
  update groups set owner_id = p_new_owner where id = p_group_id;
  update group_members set role = 'member' where group_id = p_group_id and role = 'owner';
  update group_members set role = 'owner'  where group_id = p_group_id and user_id = p_new_owner;
end $$;

-- 删除报数(软删)。权限:报数人 / 被代报人 / 群主 / 管理员(PRD §4.2)
-- 用 definer RPC 而非直接 UPDATE:置 deleted_at 后行对本人 SELECT 策略不可见,
-- 直接 UPDATE 会被 PG 判为 RLS 违规;RPC 内部自行鉴权后以 owner 身份更新
create or replace function public.delete_practice_log(p_log_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_log record;
begin
  if v_uid is null then raise exception 'authentication required'; end if;
  select * into v_log from practice_logs where id = p_log_id and deleted_at is null;
  if not found then raise exception 'record not found'; end if;
  -- 注意 NULL 三值逻辑:subject_user_id 可为 NULL,必须用 IS NOT TRUE 而非 NOT(...)
  if (v_log.reporter_id = v_uid
      or v_log.subject_user_id = v_uid
      or public.is_group_owner(v_log.group_id)
      or public.is_app_admin()) is not true then
    raise exception 'not allowed to delete this record';
  end if;
  update practice_logs set deleted_at = now(), updated_at = now() where id = p_log_id;
end $$;

-- 发愿进度(跨群或指定群;含被代报;不含自由名字;退群后仍可算自己的历史)
create or replace function public.vow_progress(p_vow_id uuid) returns numeric
language sql stable security definer set search_path = public as $$
  select coalesce(sum(l.quantity), 0)
  from vows v
  join practice_logs l
    on l.practice_type_id = v.practice_type_id
   and l.deleted_at is null
   and l.subject_name is null
   and coalesce(l.subject_user_id, l.reporter_id) = v.user_id
   and l.local_date between v.start_date and v.end_date
   and (v.group_id is null or l.group_id = v.group_id)
  where v.id = p_vow_id and v.user_id = auth.uid();
$$;

-- ---------------------------------------------------------------- 视图
-- 群成员显示名(供代报选择器/成员列表;只收敛 display_name,守卫为本群成员)
create view public.group_member_display as
select gm.group_id, gm.user_id, p.display_name, gm.role
from public.group_members gm
join public.profiles p on p.id = gm.user_id
where gm.status = 'approved'
  and public.is_group_member(gm.group_id);

-- 个人按日统计(仅本人;自报+被代报;不含自由名字)
create view public.daily_user_stats with (security_invoker = on) as
select l.group_id,
       coalesce(l.subject_user_id, l.reporter_id) as user_id,
       l.practice_type_id, l.unit, l.local_date,
       sum(l.quantity) as total
from public.practice_logs l
where l.deleted_at is null
  and l.subject_name is null
  and coalesce(l.subject_user_id, l.reporter_id) = auth.uid()
group by 1, 2, 3, 4, 5;

-- 群按日统计(含自由名字代报;仅群成员可见,靠底层 RLS)
create view public.daily_group_stats with (security_invoker = on) as
select l.group_id, l.practice_type_id, l.unit, l.local_date,
       sum(l.quantity) as total, count(*) as entries
from public.practice_logs l
where l.deleted_at is null
group by 1, 2, 3, 4;

-- ---------------------------------------------------------------- RLS
alter table public.profiles           enable row level security;
alter table public.groups             enable row level security;
alter table public.group_join_codes   enable row level security;
alter table public.group_members      enable row level security;
alter table public.practice_types     enable row level security;
alter table public.practice_logs      enable row level security;
alter table public.proxy_names        enable row level security;
alter table public.vows               enable row level security;
alter table public.events             enable row level security;
alter table public.event_overrides    enable row level security;
alter table public.media_items        enable row level security;
alter table public.scriptures         enable row level security;
alter table public.push_tokens        enable row level security;
alter table public.notifications      enable row level security;
alter table public.notification_reads enable row level security;
alter table public.reports            enable row level security;
alter table public.user_blocks        enable row level security;

-- profiles:本人读写自己;管理员全读写(display_name 供他人经 group_member_display 视图)
create policy profiles_select on public.profiles for select
  using (id = auth.uid() or public.is_app_admin());
create policy profiles_update on public.profiles for update
  using (id = auth.uid() or public.is_app_admin())
  with check (id = auth.uid() or public.is_app_admin());

-- groups:群主/有任意关系者可读(pending 申请者可见群名);建群者=群主;群主可改(owner_id 只能经 RPC 转让)
-- owner_id 直查是必要的:建群 INSERT..RETURNING 时 AFTER 触发器尚未写入成员行
create policy groups_select on public.groups for select
  using (public.is_app_admin()
         or (deleted_at is null
             and (owner_id = auth.uid() or public.has_group_relation(id))));
create policy groups_insert on public.groups for insert
  with check (owner_id = auth.uid() and public.is_active_user());
create policy groups_update on public.groups for update
  using (public.is_app_admin() or (owner_id = auth.uid() and deleted_at is null))
  with check (public.is_app_admin() or owner_id = auth.uid());

-- group_join_codes:仅管理员直读(群主经 get_group_join_code RPC);不给写策略
create policy join_codes_admin on public.group_join_codes for select
  using (public.is_app_admin());

-- group_members:本人行 + 群主 + 管理员可读;群主可审核,成员可退群(status→left)
create policy members_select on public.group_members for select
  using (user_id = auth.uid() or public.is_group_owner(group_id) or public.is_app_admin());
create policy members_update_owner on public.group_members for update
  using (public.is_group_owner(group_id) or public.is_app_admin())
  with check (public.is_group_owner(group_id) or public.is_app_admin());
create policy members_update_self_leave on public.group_members for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid() and status = 'left');

-- practice_types:全局所有人可读;群项本群成员可读、成员可加、群主可管;全局仅管理员写
create policy ptypes_select on public.practice_types for select
  using (group_id is null or public.is_group_member(group_id) or public.is_app_admin());
create policy ptypes_insert on public.practice_types for insert
  with check (
    public.is_app_admin()
    or (group_id is not null and is_custom and public.is_group_member(group_id) and public.is_active_user())
  );
create policy ptypes_update on public.practice_types for update
  using (public.is_app_admin() or (group_id is not null and public.is_group_owner(group_id)))
  with check (public.is_app_admin() or (group_id is not null and public.is_group_owner(group_id)));

-- practice_logs:本群成员可读;本人报数;修改/软删经触发器细化(退群后本人仍可见自己的记录,PRD §3.2)
create policy logs_select on public.practice_logs for select
  using (
    public.is_app_admin()
    or (deleted_at is null
        and (public.is_group_member(group_id)
             or reporter_id = auth.uid()
             or subject_user_id = auth.uid()))
  );
create policy logs_insert on public.practice_logs for insert
  with check (reporter_id = auth.uid() and public.is_group_member(group_id)
              and public.is_active_user() and deleted_at is null);
-- 直连更新仅报数人(改 quantity/note,细节由触发器守卫);删除走 delete_practice_log() RPC
create policy logs_update on public.practice_logs for update
  using (deleted_at is null and reporter_id = auth.uid())
  with check (reporter_id = auth.uid());

-- proxy_names:本群成员可读;写入经触发器;删除限添加者/群主/管理员
create policy proxy_select on public.proxy_names for select
  using (public.is_group_member(group_id) or public.is_app_admin());
create policy proxy_delete on public.proxy_names for delete
  using (created_by = auth.uid() or public.is_group_owner(group_id) or public.is_app_admin());

-- vows:仅本人
create policy vows_all on public.vows for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 公开内容:匿名可读,仅管理员写
create policy events_select on public.events for select using (true);
create policy events_write  on public.events for all
  using (public.is_app_admin()) with check (public.is_app_admin());
create policy overrides_select on public.event_overrides for select using (true);
create policy overrides_write  on public.event_overrides for all
  using (public.is_app_admin()) with check (public.is_app_admin());
create policy media_select on public.media_items for select using (true);
create policy media_write  on public.media_items for all
  using (public.is_app_admin()) with check (public.is_app_admin());
create policy scriptures_select on public.scriptures for select using (true);
create policy scriptures_write  on public.scriptures for all
  using (public.is_app_admin()) with check (public.is_app_admin());

-- push_tokens:仅本人
create policy push_tokens_all on public.push_tokens for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- notifications:登录用户按 scope 命中可读;写仅服务端(service_role 绕过 RLS / definer 触发器)
create policy notifications_select on public.notifications for select
  using (
    auth.uid() is not null
    and (scope = 'all'
         or (scope = 'user'  and target_id = auth.uid())
         or (scope = 'group' and public.is_group_member(target_id)))
  );

-- notification_reads:仅本人
create policy notification_reads_all on public.notification_reads for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- reports:举报人可提交/看自己的;管理员全权
create policy reports_insert on public.reports for insert
  with check (reporter_id = auth.uid() and public.is_active_user());
create policy reports_select on public.reports for select
  using (reporter_id = auth.uid() or public.is_app_admin());
create policy reports_update on public.reports for update
  using (public.is_app_admin()) with check (public.is_app_admin());

-- user_blocks:仅本人
create policy user_blocks_all on public.user_blocks for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------------------------------------------------------------- 表级授权
-- Supabase 模型:GRANT 给角色 + RLS 收窄到行;此处按最小权限逐表授
grant usage on schema public to anon, authenticated, service_role;
grant all on all tables in schema public to service_role;

-- 公开内容:匿名/登录均只读(写走 service_role 或管理员 RLS)
grant select on public.events, public.event_overrides,
                public.media_items, public.scriptures, public.practice_types
  to anon, authenticated;

-- 管理员(也是 authenticated 角色)维护公开内容与主清单,行级由 is_app_admin() 把关
grant insert, update, delete on public.events, public.event_overrides,
                                public.media_items, public.scriptures
  to authenticated;
grant insert, update on public.practice_types to authenticated;

grant select, update           on public.profiles           to authenticated;
grant select, insert, update   on public.groups             to authenticated;   -- 解散=软删,无 delete
grant select                   on public.group_join_codes   to authenticated;   -- RLS 限管理员;群主走 RPC
grant select, update           on public.group_members      to authenticated;   -- insert 仅经 join_group RPC
grant select, insert, update   on public.practice_logs      to authenticated;   -- 删除=软删
grant select, delete           on public.proxy_names        to authenticated;   -- 写入经触发器
grant select, insert, update, delete on public.vows         to authenticated;
grant select, insert, update, delete on public.push_tokens  to authenticated;
grant select                   on public.notifications      to authenticated;   -- 写仅服务端
grant select, insert, update, delete on public.notification_reads to authenticated;
grant select, insert, update   on public.reports            to authenticated;   -- update 行级限管理员
grant select, insert, delete   on public.user_blocks        to authenticated;

-- 视图
grant select on public.group_member_display, public.daily_user_stats, public.daily_group_stats
  to authenticated;
