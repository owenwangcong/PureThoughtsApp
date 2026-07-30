-- ============================================================================
-- 学修问答表权限收紧(P8.5 生产验证发现,同 migration 0016 的教训):
-- 生产库对新表有「默认授权」(anon/authenticated 全权),migration 0018 的
-- 最小授权在生产被默认授权覆盖——RLS 零策略仅返回空结果,表级纵深防御失效。
-- 显式 REVOKE 对齐设计口径(本地无多余授权,revoke 为幂等 no-op):
--   anon:两表无任何权限;
--   authenticated:qa_threads 无 update(冗余列走触发器/已读走 RPC),
--                  qa_messages 无 update/delete(消息只随线程级联硬删)。
-- ============================================================================

revoke all on public.qa_threads  from anon;
revoke all on public.qa_messages from anon;

revoke update, truncate, references, trigger on public.qa_threads from authenticated;
revoke update, delete, truncate, references, trigger on public.qa_messages from authenticated;
