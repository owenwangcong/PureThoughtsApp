-- ============================================================================
-- 投递管道加固(PRD v0.5.21 §5.4,设计 docs/design/notification-overhaul.md §4,任务 P2.12)
-- 修 PLAN §7(2026-08-07)登记的两个 P0 缺陷:
--   A. 取数窗口以 created_at 为基准(且只有 24 小时)→ 定时超过 24 小时的通知到点时
--      已滑出窗口,永久发不出去且永久计入「通知积压」告警。窗口基准改为**到点时刻**
--      coalesce(scheduled_at, created_at),保留 6 小时上限,防服务长时间宕机恢复后
--      把一堆过期提醒雪崩推出。不修这条,P2.14 的活动提醒排程做出来一条也发不出去。
--   B. sent_at 在发送**之前**抢占写入,失败不回滚 / 不重试 / 不留痕迹 → 一次网络抖动
--      即静默丢失。改租约式:抢占写 claimed_at(2 分钟租约)+ attempts 自增,发送结果
--      经 complete_notification 回写;全失败则释放租约,由每分钟 cron 自动重投,
--      连续 5 次仍失败记 failed_at 并停止重试(后台可见)。
-- 另:语句级触发器改「转换表」写法,仅当本批含已到点行才外呼,避免未来排程行
--    (管理员定时通知 / 活动提醒 / 免打扰顺延克隆)每插一批就白白触发一次 pg_net 外呼。
--
-- 重试粒度为**整条通知**而非单个 token(取舍详见设计 §4.3):一条 scope=all 的通知若
-- 发到一半崩溃,重试会对已成功的用户重复推送一次,由 P2.15 的 collapse-id 折叠兜底;
-- per-token 投递状态表成本远高于收益,明确不做。
-- ============================================================================

-- ---------------------------------------------------------------- 投递状态列
alter table public.notifications
  add column if not exists claimed_at timestamptz,
  add column if not exists attempts   smallint not null default 0,
  add column if not exists failed_at  timestamptz,
  add column if not exists last_error text;

comment on column public.notifications.claimed_at is
  '投递租约:抢占时置位,完成时清空;超过 2 分钟未完成视为租约过期,可被重新抢占(防函数崩溃后永久卡住)';
comment on column public.notifications.attempts is
  '投递尝试次数;达 5 次仍全部失败则置 failed_at 停止重试';
comment on column public.notifications.failed_at is
  '终局失败时刻;非空则不再被 claim_notifications 捞取,后台看板据此显示失败明细';
comment on column public.notifications.last_error is
  '最近一次投递结果摘要(ok=/invalid=/failed= 计数 + 错误信息)';

-- 投递队列索引:原表只有 (scope, target_id, created_at desc),对抢占查询完全帮不上
create index if not exists idx_notifications_pending
  on public.notifications (coalesce(scheduled_at, created_at))
  where sent_at is null and failed_at is null;

-- ---------------------------------------------------------------- 抢占(租约式)
-- FOR UPDATE SKIP LOCKED:语句级触发器与每分钟 cron 可能同时外呼,原「先 select 再条件
-- update」的两步写法在并发下会互相空转;跳锁抢占让并发调用各取各的批次。
create or replace function public.claim_notifications(p_limit int default 50)
returns setof public.notifications
language plpgsql security definer set search_path = public as $$
begin
  return query
  with picked as (
    select id from public.notifications
     where sent_at  is null
       and failed_at is null
       and (scheduled_at is null or scheduled_at <= now())
       -- 缺陷 A 修复点:基准是「到点时刻」而不是 created_at
       and coalesce(scheduled_at, created_at) > now() - interval '6 hours'
       -- 租约过期或从未抢占
       and (claimed_at is null or claimed_at < now() - interval '2 minutes')
     order by coalesce(scheduled_at, created_at)
     limit p_limit
     for update skip locked
  )
  update public.notifications n
     set claimed_at = now(),
         attempts   = n.attempts + 1
    from picked
   where n.id = picked.id
  returning n.*;
end $$;

revoke execute on function public.claim_notifications(int) from public, anon, authenticated;

-- ---------------------------------------------------------------- 完成 / 失败回写
create or replace function public.complete_notification(
  p_id      uuid,
  p_ok      int,
  p_invalid int,
  p_failed  int,
  p_error   text default null
) returns void
language plpgsql security definer set search_path = public as $$
declare v_summary text;
begin
  v_summary := format('ok=%s invalid=%s failed=%s%s',
                      p_ok, p_invalid, p_failed,
                      case when p_error is null or p_error = '' then ''
                           else ' · ' || left(p_error, 300) end);

  -- p_failed = 0 覆盖两种「无需重试」的情形:受众为空(无 token / 全被偏好过滤),
  -- 以及只命中失效 token(已删,重投也没有意义)。
  if p_ok > 0 or p_failed = 0 then
    update public.notifications
       set sent_at    = now(),
           claimed_at = null,
           last_error = v_summary
     where id = p_id;
  else
    update public.notifications
       set claimed_at = null,
           last_error = v_summary,
           failed_at  = case when attempts >= 5 then now() else null end
     where id = p_id;
  end if;
end $$;

revoke execute on function public.complete_notification(uuid, int, int, int, text)
  from public, anon, authenticated;

-- ---------------------------------------------------------------- 触发器改转换表
-- 原实现无条件外呼:插一条 scheduled_at 在未来的行(管理员定时、活动提醒、免打扰克隆)
-- 也会调一次 push-dispatch,函数捞不到东西空转返回。转换表 inserted 让语句级触发器
-- 也能看到本批插入的行,据此判断是否真有已到点的通知。
create or replace function public.trg_invoke_push_dispatch() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from inserted
              where scheduled_at is null or scheduled_at <= now()) then
    perform public.invoke_push_dispatch();
  end if;
  return null;
end $$;

drop trigger if exists trg_push_dispatch on public.notifications;
create trigger trg_push_dispatch
  after insert on public.notifications
  referencing new table as inserted
  for each statement execute function public.trg_invoke_push_dispatch();
