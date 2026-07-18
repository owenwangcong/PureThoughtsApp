-- ============================================================================
-- 管理员发布通用通知(PRD v0.5.16 §5.3,设计 docs/design/admin-notifications.md)
-- notifications 维持「客户端不可直写」,发布/撤回一律走 security definer RPC:
--   admin_publish_notification(title, body, scheduled_at) → uuid
--     立即发:insert 触发器秒级推送;定时发:push-dispatch 只抢占到点行,cron 到点投递。
--   admin_cancel_notification(id)
--     取消排程与撤回已发同一语义(删行,级联清 notification_reads);
--     仅限 type='general',防误删系统生成的代报/活动/佛历类通知。
-- ============================================================================

create or replace function public.admin_publish_notification(
  p_title text,
  p_body text default null,
  p_scheduled_at timestamptz default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
begin
  if not public.is_app_admin() then
    raise exception '仅管理员可发布通知' using errcode = '42501';
  end if;
  if coalesce(trim(p_title), '') = '' then
    raise exception '标题不能为空';
  end if;
  insert into public.notifications (scope, type, title, body, channels, scheduled_at)
  values ('all', 'general', trim(p_title),
          nullif(trim(coalesce(p_body, '')), ''), '{inapp}', p_scheduled_at)
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.admin_cancel_notification(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_app_admin() then
    raise exception '仅管理员可撤回通知' using errcode = '42501';
  end if;
  delete from public.notifications where id = p_id and type = 'general';
  if not found then
    raise exception '通知不存在或不可撤回(仅限通用通知)';
  end if;
end $$;

revoke execute on function public.admin_publish_notification(text, text, timestamptz)
  from public, anon;
revoke execute on function public.admin_cancel_notification(uuid) from public, anon;
grant execute on function public.admin_publish_notification(text, text, timestamptz)
  to authenticated;
grant execute on function public.admin_cancel_notification(uuid) to authenticated;
