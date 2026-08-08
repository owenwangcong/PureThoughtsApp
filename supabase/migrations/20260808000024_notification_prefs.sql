-- ============================================================================
-- 免打扰时段 + 分类订阅上云(PRD v0.5.21 §5.2/§5,设计 notification-overhaul.md §5,任务 P2.13)
-- 修 PLAN §7(2026-08-07)登记的缺陷 C/D:
--   C. 免打扰从未实现(服务端从不读 profiles.timezone),而 almanac-daily 在 UTC+8 次日
--      00:05 生成并被秒级推送 → 推送一上生产,大陆用户凌晨 00:05 被叫醒。
--   D. 设置页「佛教節日提醒 / 十齋日提醒」只在客户端过滤列表,服务端照推,用户关了仍收推送。
--
-- 顺延实现(设计 §5.4):命中免打扰的用户不即时推送,由 push-dispatch 克隆一条
--   scope='user' + channels='{push}' + scheduled_at=本地时段结束 的通知,走完全相同的
--   投递路径。channels 因此正式生效(原通知 {inapp,push} 进通知中心 + 即时推;克隆
--   {push} 只推不进列表),这也是 P2.2 邮件兜底的前置。
--
-- ⚠️ 建表教训(migration 0016/0019/0022 三次踩坑):自托管生产库对新建表存在 default
--    privileges,会把 anon/authenticated 全权塞进来;仅靠 RLS 是「空结果」而非「权限拒绝」。
--    必须显式 revoke all 后再按需 grant。
-- ============================================================================

-- ---------------------------------------------------------------- channels 生效前的兼容
-- ⚠️ 回归风险:改造前所有写入点(proxy_log / announcement / event_changed / almanac /
--    admin_publish / qa_*)一律显式写 '{inapp}',而 push-dispatch 从不读该列。一旦
--    push_audience 开始按 channels 判断,这些通知会全部停止推送。
-- 处置:①默认值改 '{inapp,push}',新数据语义清晰;②存量未发行一并补 push;
--      ③push_audience 采用宽松判据(含 push **或** 含 inapp 都推),这样那 6 个仍写死
--        '{inapp}' 的既有函数无需逐个重定义也不会掉推送。真正「只推不进站内」的
--        免打扰克隆用 '{push}'(不含 inapp),客户端据 inapp 决定是否显示 —— 两个方向
--        都能表达,且零回归。
alter table public.notifications alter column channels set default '{inapp,push}';

update public.notifications
   set channels = '{inapp,push}'
 where sent_at is null and channels = '{inapp}';

-- ---------------------------------------------------------------- 偏好表
create table if not exists public.notification_prefs (
  user_id          uuid primary key references public.profiles(id) on delete cascade,
  quiet_enabled    boolean not null default true,
  quiet_start      time    not null default '22:00',
  quiet_end        time    not null default '07:00',
  muted_types      text[]  not null default '{}',
  push_unavailable boolean not null default false,
  updated_at       timestamptz not null default now()
);

comment on table public.notification_prefs is
  '每用户一行的通知偏好(跨设备同步);无行时按默认值处理(免打扰开、22:00-07:00、不静音任何类型)';
comment on column public.notification_prefs.muted_types is
  '静音的通知类型;支持裸 type(event_reminder/event_changed/qa_reply...)与带 kind 形式(almanac:festival / almanac:zhai)。语义 = 不推送 + 通知中心不显示 + 不计红点';
comment on column public.notification_prefs.push_unavailable is
  'FCM 注册失败(典型为无 Google 服务的大陆 Android)→ 需邮件兜底。取代 push_tokens.fcm_failed:大陆机拿不到 token,根本没有 token 行可标记,那个字段生产恒为 false';

alter table public.notification_prefs enable row level security;

drop policy if exists notification_prefs_all on public.notification_prefs;
create policy notification_prefs_all on public.notification_prefs for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists notification_prefs_admin_read on public.notification_prefs;
create policy notification_prefs_admin_read on public.notification_prefs for select
  using (public.is_app_admin());

revoke all on public.notification_prefs from public, anon, authenticated;
grant select, insert, update, delete on public.notification_prefs to authenticated;
grant all on public.notification_prefs to service_role;

drop trigger if exists trg_notification_prefs_updated on public.notification_prefs;
create trigger trg_notification_prefs_updated before update
  on public.notification_prefs for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------- 免打扰计算
-- 纯计算版(供 push_audience 内联调用,零额外查询):给定用户时区与免打扰配置,
-- 返回「此刻处于免打扰、应顺延到的时刻」;null = 不在免打扰时段。
-- 时区串非法时(客户端上报了垃圾值)降级为 null,不让整批投递崩溃。
create or replace function public.quiet_until_for(
  p_tz text, p_enabled boolean, p_start time, p_end time
) returns timestamptz
language plpgsql stable set search_path = public as $$
declare
  v_tz text := coalesce(nullif(trim(p_tz), ''), 'UTC');
  v_qs time := coalesce(p_start, '22:00');
  v_qe time := coalesce(p_end,   '07:00');
  v_lt time;
  v_ld date;
begin
  if not coalesce(p_enabled, true) then return null; end if;

  v_lt := (now() at time zone v_tz)::time;
  v_ld := (now() at time zone v_tz)::date;

  if v_qs > v_qe then
    -- 跨午夜窗口(默认 22:00–07:00)
    if v_lt >= v_qs then                        -- 当晚 22:00 之后 → 顺延到次日终点
      return (v_ld + 1 + v_qe) at time zone v_tz;
    elsif v_lt < v_qe then                      -- 凌晨 07:00 之前 → 顺延到当日终点
      return (v_ld + v_qe) at time zone v_tz;
    end if;
  elsif v_qs < v_qe then
    -- 同日窗口(如 01:00–06:00);qs = qe 视为零长度窗口,不免打扰
    if v_lt >= v_qs and v_lt < v_qe then
      return (v_ld + v_qe) at time zone v_tz;
    end if;
  end if;

  return null;
exception when others then
  -- 非法时区名等 → 不免打扰(宁可推出去,也不要让整批通知卡住)
  return null;
end $$;

-- 便捷版(测试 / 调试 / 后台单点查询用)
create or replace function public.quiet_until(p_user uuid)
returns timestamptz
language sql stable security definer set search_path = public as $$
  select public.quiet_until_for(p.timezone,
                                coalesce(np.quiet_enabled, true),
                                coalesce(np.quiet_start, '22:00'::time),
                                coalesce(np.quiet_end,   '07:00'::time))
    from public.profiles p
    left join public.notification_prefs np on np.user_id = p.id
   where p.id = p_user;
$$;

-- PRD §5.2:「活动开始前的实时通知(如共修连接)不受免打扰限制」
-- 判据 = event_reminder 且提前量 ≤60 分钟(即三档默认里的 30 与 0 放行,提前一天的预告遵守)
create or replace function public.reminder_bypasses_quiet(p_type text, p_payload jsonb)
returns boolean
language sql immutable as $$
  select p_type = 'event_reminder'
     and coalesce((p_payload->>'offset_minutes')::int, 99999) <= 60;
$$;

-- ---------------------------------------------------------------- 受众解析
-- push-dispatch 一次 RPC 取齐:token / 平台 / 语言 / 免打扰顺延时刻。
-- 内含四道过滤:channels 含 push · 分类订阅 muted_types · 用户封禁 · scope 命中。
create or replace function public.push_audience(p_notification_id uuid)
returns table (
  token       text,
  platform    public.push_platform,
  locale      text,
  quiet_until timestamptz,
  user_id     uuid
)
language plpgsql security definer set search_path = public as $$
declare n public.notifications%rowtype;
begin
  select * into n from public.notifications where id = p_notification_id;
  if not found then return; end if;
  -- channels 生效(宽松判据,见文件头「兼容」小节):显式 push 或历史 inapp 都投递;
  -- 只有既不含 push 也不含 inapp 的(纯 email 等)才跳过。
  if not ('push' = any(n.channels) or 'inapp' = any(n.channels)) then return; end if;

  return query
  select pt.token,
         pt.platform,
         p.locale,
         case when public.reminder_bypasses_quiet(n.type, n.payload) then null
              else public.quiet_until_for(p.timezone,
                                          coalesce(np.quiet_enabled, true),
                                          coalesce(np.quiet_start, '22:00'::time),
                                          coalesce(np.quiet_end,   '07:00'::time))
         end,
         p.id
    from public.push_tokens pt
    join public.profiles p on p.id = pt.user_id
    left join public.notification_prefs np on np.user_id = p.id
   where p.banned_at is null
     -- 分类订阅:裸 type 与带 kind 形式(almanac:festival / almanac:zhai)都要匹配
     and not (n.type = any(coalesce(np.muted_types, '{}')))
     and not (
       n.payload ? 'kind'
       and (n.type || ':' || (n.payload->>'kind')) = any(coalesce(np.muted_types, '{}'))
     )
     and (
       n.scope = 'all'
       or (n.scope = 'user'  and p.id = n.target_id)
       or (n.scope = 'group' and exists (
             select 1 from public.group_members gm
              where gm.group_id = n.target_id
                and gm.user_id  = p.id
                and gm.status   = 'approved'))
     );
end $$;

-- 同 0023:push-dispatch 经 PostgREST 以 service_role 调用,需在 revoke 后显式 grant
revoke execute on function public.push_audience(uuid) from public, anon, authenticated;
grant  execute on function public.push_audience(uuid) to service_role;

revoke execute on function public.quiet_until(uuid) from public, anon, authenticated;
grant  execute on function public.quiet_until(uuid) to service_role;
