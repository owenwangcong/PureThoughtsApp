-- ============================================================================
-- 变更通知降噪(PRD v0.5.21 §5,设计 notification-overhaul.md §7,任务 P2.15)
-- 活动提醒(P2.14)上线后通知量翻倍,必须同期把「管理员一改活动、全站被轰炸」压下去。
-- 四件事:
--   1. 防抖聚合:notifications 表原本没有任何唯一约束,连改 5 次标题就是全站每人 5 条。
--      改为 updated 类走 5 分钟窗口,窗口内反复编辑只更新同一条(created/deleted 仍立即发;
--      「新建后马上又编辑」保持「新增」语义,只刷新标题、不推迟)。
--   2. 补「單次恢復」通知:原 trg_notify_override_change 只挂 after insert or update,
--      管理员删掉 override(= 撤销取消/改期)时没有任何通知,用户不知道活动又办了。
--   3. event_id 真实写入 + channels 显式声明(此前只塞在 payload 里,列一直是死列)。
--   4. admin_save_event RPC:让管理员能选「本次不通知全体」。触发器感知不到 UI 意图,
--      经 definer RPC 设事务级会话变量传递(客户端无法伪造该变量)。
-- 通知栏折叠(apns-collapse-id / FCM collapse_key)在 push-dispatch 侧实现。
-- ============================================================================

-- ---------------------------------------------------------------- 活动变更
create or replace function public.notify_event_change() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_action         text;
  v_title          text;
  v_event          uuid;
  v_pending        uuid;
  v_pending_action text;
begin
  if tg_op = 'INSERT' then
    v_action := 'created';  v_title := new.title;
  elsif tg_op = 'DELETE' then
    v_action := 'deleted';  v_title := old.title;
  else
    if (new.title, new.start_at, new.duration_minutes, new.recurrence_rule,
        new.webex_url, new.youtube_url, new.content, new.event_type_id, new.timezone)
       is not distinct from
       (old.title, old.start_at, old.duration_minutes, old.recurrence_rule,
        old.webex_url, old.youtube_url, old.content, old.event_type_id, old.timezone)
    then
      return new;                                    -- 无实质变化,不通知
    end if;
    v_action := 'updated';  v_title := new.title;
  end if;
  v_event := coalesce(new.id, old.id);

  -- 管理员选了「本次不通知全体」(经 admin_save_event 设置的事务级变量)
  if coalesce(current_setting('app.suppress_event_notify', true), '') = 'on' then
    return coalesce(new, old);
  end if;

  -- 防抖:同一活动已有未发的变更通知时,合并进那一条而不是再插一条
  if v_action = 'updated' then
    select id, payload->>'action' into v_pending, v_pending_action
      from public.notifications
     where type = 'event_changed' and event_id = v_event and sent_at is null
       and payload->>'date' is null                  -- 只与整体变更合并,不吞单次改动
     limit 1;

    if v_pending is not null then
      if v_pending_action = 'created' then
        -- 刚新建又编辑:保持「新增」语义并按原计划立即发,只刷新标题
        update public.notifications
           set payload = payload || jsonb_build_object('title', v_title)
         where id = v_pending;
      else
        update public.notifications
           set payload      = payload || jsonb_build_object('action', 'updated', 'title', v_title),
               scheduled_at = now() + interval '5 minutes'
         where id = v_pending;
      end if;
      return coalesce(new, old);
    end if;
  end if;

  -- ⚠️ deleted 动作不能写 event_id 列:AFTER DELETE 触发器执行时该行已不存在,
  --    写入会违反 notifications_event_id_fkey(2026-08-08 本地实测)。payload 也一并
  --    不带 event_id —— 活动都删了,深链过去只会看到空态,客户端据此退化到 /calendar。
  insert into public.notifications (scope, type, event_id, payload, channels, scheduled_at)
  values ('all', 'event_changed',
          case when v_action = 'deleted' then null else v_event end,
          case when v_action = 'deleted'
               then jsonb_build_object('action', v_action, 'title', v_title)
               else jsonb_build_object('action', v_action, 'title', v_title, 'event_id', v_event)
          end,
          '{inapp,push}',
          case when v_action = 'updated' then now() + interval '5 minutes' end);
  return coalesce(new, old);
end $$;

-- ---------------------------------------------------------------- 单次改动(含恢复)
create or replace function public.notify_override_change() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  -- DELETE 时 NEW 未赋值,统一走 jsonb 取值(与 resync_event_reminders 同一处置)
  v_rec     jsonb := coalesce(to_jsonb(new), to_jsonb(old));
  v_event   uuid := (v_rec->>'event_id')::uuid;
  v_date    date := (v_rec->>'occurrence_date')::date;
  v_title   text;
  v_action  text;
  v_pending uuid;
begin
  select title into v_title from public.events where id = v_event;
  -- 活动本身已被删(override 随之级联)→ 不发「单次恢复」,由 deleted 通知说明
  if v_title is null then return coalesce(new, old); end if;

  if tg_op = 'DELETE' then
    v_action := 'occurrence_restored';
  elsif coalesce(v_rec->'patch'->>'cancelled', '') = 'true' then
    v_action := 'occurrence_cancelled';
  else
    v_action := 'occurrence_changed';
  end if;

  if coalesce(current_setting('app.suppress_event_notify', true), '') = 'on' then
    return coalesce(new, old);
  end if;

  -- 防抖键含 date:不同场次各自通知,同一场次的反复调整才合并
  select id into v_pending
    from public.notifications
   where type = 'event_changed' and event_id = v_event and sent_at is null
     and payload->>'date' = v_date::text
   limit 1;

  if v_pending is not null then
    update public.notifications
       set payload      = payload || jsonb_build_object('action', v_action, 'title', v_title),
           scheduled_at = now() + interval '5 minutes'
     where id = v_pending;
    return coalesce(new, old);
  end if;

  insert into public.notifications (scope, type, event_id, payload, channels, scheduled_at)
  values ('all', 'event_changed', v_event,
          jsonb_build_object('action', v_action, 'title', v_title,
                             'event_id', v_event, 'date', v_date),
          '{inapp,push}', now() + interval '5 minutes');
  return coalesce(new, old);
end $$;

-- 原触发器只有 insert or update;重建以覆盖 delete(撤销取消/改期 → 單次恢復)
drop trigger if exists trg_notify_override_change on public.event_overrides;
create trigger trg_notify_override_change
  after insert or update or delete on public.event_overrides
  for each row execute function public.notify_override_change();

-- ---------------------------------------------------------------- 活动保存 RPC
-- 客户端与管理后台改调此 RPC(不再直接 insert/update events),以便传递「本次是否通知全体」。
create or replace function public.admin_save_event(
  p_event jsonb, p_notify boolean default true
) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid := nullif(p_event->>'id', '')::uuid;
begin
  if not public.is_app_admin() then
    raise exception '仅管理员可编辑活动' using errcode = '42501';
  end if;
  if coalesce(trim(p_event->>'title'), '') = '' then
    raise exception '活动名称不能为空';
  end if;
  if coalesce(p_event->>'event_type_id', '') = '' then
    raise exception '活动类型不能为空';
  end if;

  -- 事务级(local)设置,RPC 返回即失效;客户端无 set_config 权限,无法伪造
  if not coalesce(p_notify, true) then
    perform set_config('app.suppress_event_notify', 'on', true);
  end if;

  if v_id is null then
    insert into public.events (
      title, event_type_id, start_at, timezone, duration_minutes,
      recurrence_rule, youtube_url, webex_url, content, created_by)
    values (
      trim(p_event->>'title'),
      (p_event->>'event_type_id')::uuid,
      (p_event->>'start_at')::timestamptz,
      coalesce(nullif(p_event->>'timezone', ''), 'Asia/Shanghai'),
      nullif(p_event->>'duration_minutes', '')::int,
      nullif(p_event->>'recurrence_rule', ''),
      nullif(p_event->>'youtube_url', ''),
      nullif(p_event->>'webex_url', ''),
      nullif(p_event->>'content', ''),
      auth.uid())
    returning id into v_id;
  else
    update public.events set
      title            = trim(p_event->>'title'),
      event_type_id    = (p_event->>'event_type_id')::uuid,
      start_at         = (p_event->>'start_at')::timestamptz,
      timezone         = coalesce(nullif(p_event->>'timezone', ''), 'Asia/Shanghai'),
      duration_minutes = nullif(p_event->>'duration_minutes', '')::int,
      recurrence_rule  = nullif(p_event->>'recurrence_rule', ''),
      youtube_url      = nullif(p_event->>'youtube_url', ''),
      webex_url        = nullif(p_event->>'webex_url', ''),
      content          = nullif(p_event->>'content', '')
     where id = v_id;
    if not found then raise exception '活动不存在'; end if;
  end if;

  return v_id;
end $$;

revoke execute on function public.admin_save_event(jsonb, boolean) from public, anon;
grant  execute on function public.admin_save_event(jsonb, boolean) to authenticated;
