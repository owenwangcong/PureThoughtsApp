-- ============================================================================
-- 去群化(单一共修体)· PLAN P9.1 · PRD v0.6.0 §3 · 设计 design/single-community.md
--
-- 产品层面取消「群」概念:全 App 只有一个共修体(App 内叫「共修報數」),
-- 注册即入、无群 ID、无申请、无审核。数据层保留 group_id 单例(设计 Q1),
-- 以保「将来真要按地区/期别分组」的可逆性。
--
-- 本 migration 是**首个改写存量业务数据**的 migration:
--   * practice_logs.group_id 会被改指共修体 —— 旧值留档在 _pre_community_log_groups
--   * 其余群软删、其成员置 left
-- 生产执行前必须先手工全量快照(PLAN §7 2026-08-11 条目)。
--
-- 回滚要点(无 down migration):
--   * 软删的群:update groups set deleted_at = null where id in (...)
--   * group_id:update practice_logs l set group_id = b.old_group_id
--               from _pre_community_log_groups b where b.log_id = l.id
--   * is_default / created_by / search_members 均为新增物,drop 即可
-- ============================================================================

-- ---------------------------------------------------------------- ① 新增结构
-- 共修体标记:全库最多一行
alter table public.groups add column is_default boolean not null default false;
create unique index uq_groups_default on public.groups (is_default) where is_default;

-- 自定义功课项归属到人(设计 Q8:仅创建者可**选用**;名称仍对所有人可读,
-- 否则别人在共修报数记录里看到的会是一条无名记录)
alter table public.practice_types
  add column created_by uuid references public.profiles(id) on delete set null;
create index idx_ptypes_created_by on public.practice_types (created_by) where is_custom;

-- 旧 group_id 留档(本 migration 唯一不可逆动作的兜底;90 天后可由后续 migration 清理)
create table public._pre_community_log_groups (
  log_id       uuid primary key,
  old_group_id uuid not null,
  moved_at     timestamptz not null default now()
);
alter table public._pre_community_log_groups enable row level security;   -- 零策略 = 客户端不可达
revoke all on public._pre_community_log_groups from public, anon, authenticated;

-- ---------------------------------------------------------------- ② 触发器容错
-- 共修体那一行 owner_id 为 NULL(无群主),原触发器会插 group_members(user_id=null) 崩;
-- 且共修体不需要 join code。
create or replace function public.handle_new_group() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.owner_id is not null then
    insert into public.group_members (group_id, user_id, status, role, approved_at)
    values (new.id, new.owner_id, 'approved', 'owner', now());
  end if;
  if not new.is_default then
    insert into public.group_join_codes (group_id, code)
    values (new.id, public.gen_join_code());
  end if;
  return new;
end $$;

-- 新增自定义功课项时自动落创建者(客户端不必传,也不该由它决定)
create or replace function public.set_practice_type_creator() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.is_custom and new.created_by is null then
    new.created_by := auth.uid();
  end if;
  return new;
end $$;
create trigger trg_set_practice_type_creator
  before insert on public.practice_types
  for each row execute function public.set_practice_type_creator();

-- ---------------------------------------------------------------- ③④⑤ 确定共修体 + 合并 + 全员入会
do $$
declare
  v_gid  uuid;
  v_name constant text := '共修報數';
begin
  -- ③ 已有共修体则复用(幂等);否则把「approved 成员最多的未解散群」升格;都没有就新建
  select id into v_gid from public.groups where is_default limit 1;

  if v_gid is null then
    select g.id into v_gid
    from public.groups g
    left join public.group_members m
      on m.group_id = g.id and m.status = 'approved'
    where g.deleted_at is null
    group by g.id, g.created_at
    order by count(m.user_id) desc, g.created_at asc
    limit 1;

    if v_gid is null then
      insert into public.groups (name, description, owner_id, is_default)
      values (v_name, '善護念每日功課報數', null, true)
      returning id into v_gid;
    else
      update public.groups
         set is_default = true, owner_id = null, name = v_name, deleted_at = null
       where id = v_gid;
      -- 群主角色取消(设计 Q9),全部降为普通成员
      update public.group_members set role = 'member'
       where group_id = v_gid and role = 'owner';
    end if;
  end if;

  -- 共修体没有群 ID
  delete from public.group_join_codes where group_id = v_gid;

  -- ④ 其余群并入共修体 -------------------------------------------------
  -- 报数:先留档旧 group_id,再改指
  insert into public._pre_community_log_groups (log_id, old_group_id)
  select id, group_id from public.practice_logs where group_id <> v_gid
  on conflict (log_id) do nothing;

  update public.practice_logs set group_id = v_gid where group_id <> v_gid;

  -- 代报名单:撞 (group_id, name) 唯一键的合并 use_count / last_used_at
  with moved as (
    delete from public.proxy_names where group_id <> v_gid
    returning name, created_by, use_count, last_used_at
  ), agg as (
    select name,
           (array_agg(created_by order by last_used_at desc))[1] as creator,
           sum(use_count)::int as cnt,
           max(last_used_at) as last_used
    from moved group by name
  )
  insert into public.proxy_names (group_id, name, created_by, use_count, last_used_at)
  select v_gid, name, creator, cnt, last_used from agg
  on conflict (group_id, name) do update
    set use_count    = proxy_names.use_count + excluded.use_count,
        last_used_at = greatest(proxy_names.last_used_at, excluded.last_used_at);

  -- 自定义功课项:改挂共修体(不做自动去重——同名合并需要人工判断,交管理后台治理)
  update public.practice_types
     set group_id = v_gid
   where group_id is not null and group_id <> v_gid;

  -- 回填创建者:取首条引用该项的报数的报数人;取不到则留 null(无人可选,自然退役)
  update public.practice_types t
     set created_by = sub.uid
  from (select distinct on (l.practice_type_id)
               l.practice_type_id, l.reporter_id as uid
        from public.practice_logs l
        where l.reporter_id is not null
        order by l.practice_type_id, l.created_at) sub
  where t.id = sub.practice_type_id and t.is_custom and t.created_by is null;

  -- 发愿:范围选择器取消,一律跨全部(语义等价)
  update public.vows set group_id = null where group_id is not null;

  -- 其余群软删,其成员关系置 left
  update public.group_members set status = 'left', role = 'member'
   where group_id <> v_gid and status <> 'left';
  update public.groups set deleted_at = now()
   where id <> v_gid and deleted_at is null;

  -- ⑤ 全员入会(存量) ---------------------------------------------------
  insert into public.group_members (group_id, user_id, status, role, approved_at)
  select v_gid, p.id, 'approved', 'member', now()
  from public.profiles p
  on conflict (group_id, user_id) do update
    set status      = 'approved',
        approved_at = coalesce(group_members.approved_at, now());
end $$;

-- 新注册用户自动入会。⚠️ 本函数在 auth 注册链路上,任何异常都会让注册整体失败,
-- 故共修体缺失时必须静默跳过而不是抛错。
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name',
                           split_part(coalesce(new.email,''),'@',1)));

  insert into public.group_members (group_id, user_id, status, role, approved_at)
  select g.id, new.id, 'approved', 'member', now()
  from public.groups g
  where g.is_default and g.deleted_at is null
  on conflict (group_id, user_id) do nothing;

  return new;
end $$;

-- ---------------------------------------------------------------- ⑥ 关闭建群与入群申请
drop policy if exists groups_insert on public.groups;
revoke insert on public.groups from authenticated;

-- 保留函数体给旧版 App 一个可读的错误(客户端已无入口)
create or replace function public.join_group(p_code text, p_message text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
begin
  raise exception 'joining is no longer required: every registered user is a member';
end $$;

-- ---------------------------------------------------------------- ⑦ 同修搜索(替代全量成员视图)
-- definer 但内部自校验 auth.uid():anon 调用返回空集而非全表;
-- 必须给关键词、结果上限 50;排除自己 / 已封禁 / 已被我拉黑的人。
create or replace function public.search_members(p_q text, p_limit int default 20)
returns table (user_id uuid, display_name text)
language sql stable security definer set search_path = public as $$
  select p.id, p.display_name
  from public.profiles p
  where auth.uid() is not null
    and p.id <> auth.uid()
    and p.banned_at is null
    and length(btrim(coalesce(p_q, ''))) >= 1
    and p.display_name ilike '%' || btrim(p_q) || '%'
    and not exists (select 1 from public.user_blocks b
                    where b.user_id = auth.uid() and b.blocked_user_id = p.id)
  order by p.display_name
  limit least(greatest(coalesce(p_limit, 20), 1), 50);
$$;
revoke all on function public.search_members(text, int) from public, anon;
grant execute on function public.search_members(text, int) to authenticated;

-- ---------------------------------------------------------------- ⑧ 自定义功课项的权限收口
-- 「可读」维持宽松(渲染他人记录的功课名所必需);「可选」由客户端 / 服务端查询过滤:
--   group_id is null or created_by = auth.uid()
-- 这里只锁住两件事:创建者不可伪造、他人的自定义项不可被拿来报数。
drop policy if exists ptypes_insert on public.practice_types;
create policy ptypes_insert on public.practice_types for insert
  with check (
    public.is_app_admin()
    or (group_id is not null and is_custom
        and public.is_group_member(group_id) and public.is_active_user()
        and (created_by is null or created_by = auth.uid()))
  );

-- 群主角色取消:自定义项的停用/启用限创建者本人与管理员
drop policy if exists ptypes_update on public.practice_types;
create policy ptypes_update on public.practice_types for update
  using (public.is_app_admin() or (is_custom and created_by = auth.uid()))
  with check (public.is_app_admin() or (is_custom and created_by = auth.uid()));

-- 报数落库校验:不得用他人的自定义功课项报数(把「仅自己可选」变成真规则,而不只是 UI 过滤)
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
  if pt.is_custom and pt.created_by is not null
     and pt.created_by <> new.reporter_id and not public.is_app_admin() then
    raise exception 'custom practice type belongs to another user';
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
