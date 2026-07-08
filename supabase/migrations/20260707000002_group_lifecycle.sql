-- ============================================================================
-- 群生命周期补充(PLAN P1.4)
-- 1. 修复 guard_group_members:原实现用 auth.uid() is null 放行系统操作,
--    但 SECURITY DEFINER RPC 内 auth.uid() 不变,导致 transfer_group_ownership
--    的 role 更新被守卫误拦。改用 current_user 判断(definer 内为函数属主),
--    与 guard_practice_log_update 口径一致。
-- 2. 新增 dissolve_group():解散群置 deleted_at 后,行对群主的 SELECT 策略
--    (deleted_at is null)不可见,直接 UPDATE 会被 PG 判 RLS 违规
--    (与报数软删同一陷阱),故走 definer RPC。
-- ============================================================================

-- 注意:必须是 invoker(非 definer)函数,current_user 判断才有意义——
-- definer 函数内 current_user 恒为属主,守卫会被自己短路
create or replace function public.guard_group_members() returns trigger
language plpgsql set search_path = public as $$
begin
  -- 仅约束客户端直连;definer RPC / 服务端(current_user 非 authenticated)不受限
  if current_user <> 'authenticated' then return new; end if;
  if new.role is distinct from old.role then
    raise exception 'role can only change via ownership transfer';
  end if;
  if old.user_id = (select owner_id from groups where id = old.group_id)
     and new.status <> 'approved' then
    raise exception 'owner must transfer ownership before leaving';
  end if;
  return new;
end $$;

create or replace function public.dissolve_group(p_group_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if (public.is_group_owner(p_group_id) or public.is_app_admin()) is not true then
    raise exception 'only group owner can dissolve the group';
  end if;
  update groups set deleted_at = now() where id = p_group_id and deleted_at is null;
end $$;
