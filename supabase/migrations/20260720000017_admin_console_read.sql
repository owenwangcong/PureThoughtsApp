-- ============================================================================
-- 管理后台读支持(PLAN P7.4):
-- 1. push_tokens / notifications 增加管理员只读策略(数据看板:推送投递健康、
--    通知积压需要跨用户/跨 scope 可见;写路径不变)。
-- 2. admin_list_logins():按 id 批量取登录名(auth.users.email,客户端剥内部
--    域名显示),用户管理页区分同名用户;仅管理员可调。
-- ============================================================================

create policy push_tokens_admin_read on public.push_tokens for select
  using (public.is_app_admin());

create policy notifications_admin_read on public.notifications for select
  using (public.is_app_admin());

create or replace function public.admin_list_logins(p_user_ids uuid[])
returns table(user_id uuid, login_email text)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_app_admin() then
    raise exception '仅管理员可用' using errcode = '42501';
  end if;
  return query
    select u.id, u.email::text from auth.users u where u.id = any(p_user_ids);
end $$;

revoke execute on function public.admin_list_logins(uuid[]) from public, anon;
grant execute on function public.admin_list_logins(uuid[]) to authenticated;
