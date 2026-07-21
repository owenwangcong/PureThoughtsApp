-- ============================================================================
-- 安全修复(PLAN §7,2026-07-20 发现):
-- push_dispatch_url / push_dispatch_key 原存 app_settings,而该表 anon 可读,
-- 等于匿名可读投递密钥(DISPATCH_SECRET)。迁至新表 app_secrets:
-- RLS 开启且【零策略、零客户端授权】——anon/authenticated(含管理员会话)一律不可达,
-- 仅 service_role 与 definer 函数(owner 绕过 RLS)可读;运维改值走 Studio/psql
-- (deploy 文档 §11②)。invoke_push_dispatch() 改读新表,其余链路不变。
-- ============================================================================

create table public.app_secrets (
  key        text primary key,
  value      text not null,
  updated_at timestamptz not null default now()
);

alter table public.app_secrets enable row level security;
-- 故意不建任何策略;并显式 REVOKE——自托管生产存在“新表默认授权 anon/authenticated”的
-- default privileges(实测),仅靠零策略 RLS 是空结果而非权限拒绝,双保险收干净。
revoke all on public.app_secrets from public, anon, authenticated;
grant all on public.app_secrets to service_role;

-- 迁移现有值(生产上是真实密钥),随后从可读表中删除
insert into public.app_secrets (key, value)
select key, value from public.app_settings
 where key in ('push_dispatch_url', 'push_dispatch_key')
on conflict (key) do nothing;

delete from public.app_settings
 where key in ('push_dispatch_url', 'push_dispatch_key');

-- 兜底:全新环境(app_settings 里没有种子)也要保证两键存在
insert into public.app_secrets (key, value) values
  ('push_dispatch_url', ''),
  ('push_dispatch_key', '')
on conflict (key) do nothing;

-- 与 migration 0014 相同,仅改读 app_secrets
create or replace function public.invoke_push_dispatch() returns void
language plpgsql security definer set search_path = public as $$
declare
  v_url text;
  v_key text;
begin
  select value into v_url from app_secrets where key = 'push_dispatch_url';
  if v_url is null or v_url = '' then return; end if;
  select value into v_key from app_secrets where key = 'push_dispatch_key';
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
