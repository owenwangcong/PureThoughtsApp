-- ============================================================================
-- Realtime 群统计(PLAN P5.2):practice_logs 加入 Realtime 发布,
-- 群统计/报数记录页订阅变更实时刷新;RLS 保证订阅者只收到有权限的行。
-- ============================================================================

alter publication supabase_realtime add table public.practice_logs;
