-- ============================================================================
-- 通知数据治理(PRD v0.5.21 §5.4,设计 notification-overhaul.md §9,任务 P2.17)
-- 改造前 notifications 无任何清理机制(建库以来只增不减),且缺两个查询必需的索引。
--   · 保留期 180 天(Q9),每日 cron 清理,notification_reads 随 FK 级联清除;
--   · notification_reads 只有复合主键 (notification_id, user_id),按用户算未读只能扫;
--   · push_tokens.fcm_failed 标注废弃 —— 大陆机拿不到 token 即无行可标,该字段生产恒为
--     false,判据已移至 notification_prefs.push_unavailable(见 migration 0024)。
-- ============================================================================

create or replace function public.purge_old_notifications(p_days int default 180)
returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  delete from public.notifications
   where created_at < now() - make_interval(days => p_days);
  get diagnostics n = row_count;
  return n;
end $$;

revoke execute on function public.purge_old_notifications(int)
  from public, anon, authenticated;

-- 「我的未读数」与已读标记查询用
create index if not exists idx_notification_reads_user
  on public.notification_reads (user_id);

comment on column public.push_tokens.fcm_failed is
  '已废弃(v0.5.21):大陆 Android 拿不到 token,push_tokens 里根本没有该设备的行可标记,'
  '此列生产恒为 false。邮件兜底判据改用 notification_prefs.push_unavailable';

-- ---------------------------------------------------------------- Realtime
-- 通知中心的红点要即时反映新通知(P2.17),客户端订阅 notifications 的 INSERT。
-- ⚠️ supabase_realtime publication 默认只含 practice_logs(P5.2 加的),不加这张表
--    订阅建得起来但永远收不到事件 —— 功能静默失效(2026-08-08 本地实测发现)。
-- 可见性仍由 RLS 把关(scope 命中者才收到),不会泄露他人通知。
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public' and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
exception when others then
  raise warning 'notifications 加入 supabase_realtime 失败,红点降级为下拉刷新: %', sqlerrm;
end $$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'notifications-retention') then
      perform cron.unschedule('notifications-retention');
    end if;
    -- 17:00 UTC:避开 event-reminders-daily(15:00)与 almanac-daily(16:05)
    perform cron.schedule('notifications-retention', '0 17 * * *',
      $job$select public.purge_old_notifications(180)$job$);
  end if;
end $$;
