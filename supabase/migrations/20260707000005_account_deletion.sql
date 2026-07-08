-- ============================================================================
-- 账号删除支持(PRD §10.1,PLAN P1.9)
-- 删号 = auth.users 删除 → profiles 级联删 → practice_logs 的 reporter/subject
-- 经 FK SET NULL 匿名化(群总量不变,已确认)。
-- 前置修正:groups.owner_id 原为 NOT NULL 无删除动作,群主(含已解散群的
-- 前群主)删号会被 FK 阻断。改为 nullable + ON DELETE SET NULL:
--   * 活跃群:delete-account Edge Function 强制要求先转让/解散;
--   * 已解散群:owner_id 置空,群数据保留供管理员追溯。
-- ============================================================================

alter table public.groups alter column owner_id drop not null;
alter table public.groups drop constraint groups_owner_id_fkey;
alter table public.groups
  add constraint groups_owner_id_fkey
  foreign key (owner_id) references public.profiles(id) on delete set null;
