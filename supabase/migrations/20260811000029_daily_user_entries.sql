-- ============================================================================
-- daily_user_stats 补 entries 列 · PLAN P9.2 · 设计 single-community.md §5.7
--
-- 「共修報數」页的近 14 天趋势要画「我的 / 全體」双系列,两条必须是同一个度量。
-- daily_group_stats 早有 count(*) as entries,daily_user_stats 只有 sum(quantity) ——
-- 数量跨功课项单位不同(部/遍/次/分钟),不能相加成一根柱子,故两边统一用**笔数**。
--
-- create or replace view 允许在末尾追加列,不影响现有 select 的调用方。
-- ============================================================================

create or replace view public.daily_user_stats with (security_invoker = on) as
select l.group_id,
       coalesce(l.subject_user_id, l.reporter_id) as user_id,
       l.practice_type_id, l.unit, l.local_date,
       sum(l.quantity) as total,
       count(*)        as entries
from public.practice_logs l
where l.deleted_at is null
  and l.subject_name is null
  and coalesce(l.subject_user_id, l.reporter_id) = auth.uid()
group by 1, 2, 3, 4, 5;
