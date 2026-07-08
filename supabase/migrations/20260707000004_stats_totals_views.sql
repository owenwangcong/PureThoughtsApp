-- ============================================================================
-- 累计统计视图(PLAN P1.8 Dashboard)
-- daily_* 视图负责按日;此处补全历史累计(按功课项),避免客户端拉全量行自聚合。
-- 口径同 daily_*:排除软删;个人统计不含自由名字代报、含被代报;仅本人可见。
-- ============================================================================

create view public.user_practice_totals with (security_invoker = on) as
select coalesce(l.subject_user_id, l.reporter_id) as user_id,
       l.practice_type_id,
       l.unit,
       sum(l.quantity) as total,
       count(*)        as entries
from public.practice_logs l
where l.deleted_at is null
  and l.subject_name is null
  and coalesce(l.subject_user_id, l.reporter_id) = auth.uid()
group by 1, 2, 3;

create view public.group_practice_totals with (security_invoker = on) as
select l.group_id,
       l.practice_type_id,
       l.unit,
       sum(l.quantity) as total,
       count(*)        as entries
from public.practice_logs l
where l.deleted_at is null
group by 1, 2, 3;

grant select on public.user_practice_totals, public.group_practice_totals to authenticated;
