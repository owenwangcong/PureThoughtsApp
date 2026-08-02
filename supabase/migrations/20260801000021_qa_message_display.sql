-- ============================================================================
-- 学修问答管理员署名真名(P8.6 增补,PRD v0.5.20 §16,设计 study-qa.md §9.4):
-- 管理员消息署该管理员的 display_name。普通用户读不了他人 profiles(RLS 只放
-- 本人+管理员),PostgREST 内嵌拿不到名字 → 循 group_member_display 先例建
-- definer 视图窄口暴露:qa_messages ⋈ profiles,守卫复刻消息 RLS
-- (线程主人或管理员)。App 与管理后台的消息查询均改走此视图;
-- sender_name 为空(已删号)时客户端回退显示「管理員」。
-- ============================================================================

create view public.qa_message_display as
select m.id, m.thread_id, m.sender_id, m.sender_role, m.body, m.created_at,
       p.display_name as sender_name
  from public.qa_messages m
  left join public.profiles p on p.id = m.sender_id
 where public.qa_thread_owner(m.thread_id) = auth.uid()
    or public.is_app_admin();

grant select on public.qa_message_display to authenticated, service_role;
-- 生产库对新对象有默认授权(0016/0019 教训),显式收掉 anon(本地为幂等 no-op)
revoke all on public.qa_message_display from anon;
