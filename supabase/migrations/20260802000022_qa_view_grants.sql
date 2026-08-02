-- ============================================================================
-- qa_message_display 视图授权收紧(P8.6 复核发现,0016/0019 同款教训第三次):
-- 生产库默认授权给新视图塞了 authenticated 全权(INSERT/UPDATE/DELETE/...),
-- 0021 只显式收了 anon。视图含 JOIN 不可自动更新,实际写入会报错,
-- 但纵深防御要求授权面与设计一致:authenticated 仅 SELECT。
-- (本地无默认授权,本文件为幂等 no-op。)
-- ============================================================================

revoke insert, update, delete, truncate, references, trigger
  on public.qa_message_display from authenticated;
