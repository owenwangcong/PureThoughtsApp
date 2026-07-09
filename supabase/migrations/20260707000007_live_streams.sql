-- ============================================================================
-- 直播状态(PRD v0.5.6 §6):live-probe Edge Function 探测 YouTube 开播后
-- 写入本表并生成全员通知;App 直播页读取当前进行中的直播(ended_at is null)。
-- 公开内容:匿名可读;写仅服务端(service_role)。
-- ============================================================================

create table public.live_streams (
  id         uuid primary key default gen_random_uuid(),
  platform   text not null check (platform in ('youtube', 'webex')),
  video_id   text,
  url        text not null,
  title      text,
  started_at timestamptz not null default now(),
  ended_at   timestamptz
);

create index idx_live_streams_open on public.live_streams (platform)
  where ended_at is null;

alter table public.live_streams enable row level security;
create policy live_streams_select on public.live_streams for select using (true);

grant select on public.live_streams to anon, authenticated;
grant all on public.live_streams to service_role;
