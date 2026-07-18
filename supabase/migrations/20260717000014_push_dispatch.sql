-- ============================================================================
-- 推送触发链路(PRD §5.1/§12.4,PLAN P2.1-3)
-- notifications insert 触发器 + pg_cron 每分钟兜底 → 经 pg_net 调 push-dispatch
-- Edge Function(函数内以 sent_at 抢占,重复调用幂等)。
-- 调用地址/密钥存 app_settings(本地默认空 = 不外呼,便于本地开发不受影响;
-- 生产部署时 update 两个键,见 docs/infra/deploy-aws-ec2.md §12)。
-- ============================================================================

insert into public.app_settings (key, value) values
  ('push_dispatch_url', ''),   -- 生产:https://api.pure-thoughts.com/functions/v1/push-dispatch
  ('push_dispatch_key', '')    -- 与函数环境变量 DISPATCH_SECRET 一致(可留空=函数不校验)
on conflict (key) do nothing;

do $$
begin
  create extension if not exists pg_net;
exception when others then
  raise warning 'pg_net 不可用,推送触发链路跳过(生产须启用): %', sqlerrm;
end $$;

-- 外呼 push-dispatch(异步,不阻塞事务;url 未配置时静默跳过)
create or replace function public.invoke_push_dispatch() returns void
language plpgsql security definer set search_path = public as $$
declare
  v_url text;
  v_key text;
begin
  select value into v_url from app_settings where key = 'push_dispatch_url';
  if v_url is null or v_url = '' then return; end if;
  select value into v_key from app_settings where key = 'push_dispatch_key';
  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-dispatch-key', coalesce(v_key, '')),
    body := '{}'::jsonb,
    timeout_milliseconds := 5000
  );
exception when others then
  raise warning 'push-dispatch 外呼失败(cron 会兜底重试): %', sqlerrm;
end $$;

revoke execute on function public.invoke_push_dispatch() from public, anon, authenticated;

-- 新通知落库即触发投递(语句级:一次批量 insert 只外呼一次)
create or replace function public.trg_invoke_push_dispatch() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.invoke_push_dispatch();
  return null;
end $$;

drop trigger if exists trg_push_dispatch on public.notifications;
create trigger trg_push_dispatch
  after insert on public.notifications
  for each statement execute function public.trg_invoke_push_dispatch();

-- 每分钟兜底(补 scheduled_at 到点的与外呼失败的;函数幂等)
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'push-dispatch-sweep') then
      perform cron.unschedule('push-dispatch-sweep');
    end if;
    perform cron.schedule('push-dispatch-sweep', '* * * * *',
      $job$select public.invoke_push_dispatch()$job$);
  end if;
end $$;
