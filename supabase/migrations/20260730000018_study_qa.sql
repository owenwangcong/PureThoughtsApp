-- ============================================================================
-- 学修问答(PRD v0.5.18 §16,设计 docs/design/study-qa.md,任务 P8.1)
-- 私密一对一提问:一个问题 = 一个线程(qa_threads),首问与全部往来存 qa_messages。
-- 可见性:仅提问人本人 + 管理员(RLS);删除为硬删(线程级联,账号删除连带清空)。
-- 通知:触发器写 notifications(qa_reply 通知提问人 / qa_question 通知全体管理员),
--       文案不带正文(隐私定案);推送文案在 push-dispatch renderText 渲染。
-- ============================================================================

-- ---------------------------------------------------------------- 表
create table public.qa_threads (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null references public.profiles(id) on delete cascade,
  last_sender_role      text not null default 'user'
                          check (last_sender_role in ('user','admin')),
  last_message_at       timestamptz not null default now(),
  first_message_preview text not null default '',   -- 首问前 100 字,列表标题用;触发器维护
  last_message_preview  text not null default '',   -- 最后一条前 100 字;触发器维护
  user_last_read_at     timestamptz not null default now(),  -- 提问人已读位点(未读红点)
  created_at            timestamptz not null default now()
);
create index idx_qa_threads_user    on public.qa_threads (user_id, last_message_at desc);
create index idx_qa_threads_pending on public.qa_threads (last_message_at desc)
  where last_sender_role = 'user';   -- 管理员「待回覆」筛选

create table public.qa_messages (
  id          uuid primary key default gen_random_uuid(),
  thread_id   uuid not null references public.qa_threads(id) on delete cascade,
  sender_id   uuid references public.profiles(id) on delete set null,  -- 发送者删号后消息保留,按 role 显示
  sender_role text not null check (sender_role in ('user','admin')),
  body        text not null check (char_length(btrim(body)) between 1 and 2000),
  created_at  timestamptz not null default now()
);
create index idx_qa_messages_thread on public.qa_messages (thread_id, created_at);

-- ---------------------------------------------------------------- RLS 辅助
create or replace function public.qa_thread_owner(tid uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select t.user_id from qa_threads t where t.id = tid;
$$;

-- ---------------------------------------------------------------- 授权(最小面:anon 无任何权限)
-- qa_threads 不授 update(冗余列走触发器,已读走 RPC);qa_messages 不授 update/delete
-- (消息只随线程级联硬删)——表级即锁死,RLS 再按行把关。
grant select, insert, delete on public.qa_threads  to authenticated;
grant select, insert         on public.qa_messages to authenticated;
grant all on public.qa_threads, public.qa_messages to service_role;

-- ---------------------------------------------------------------- RLS
alter table public.qa_threads  enable row level security;
alter table public.qa_messages enable row level security;

create policy qa_threads_select on public.qa_threads for select
  using (user_id = auth.uid() or public.is_app_admin());
create policy qa_threads_insert on public.qa_threads for insert
  with check (user_id = auth.uid() and public.is_active_user());
-- update 不开放:冗余列走触发器,已读走 mark_qa_thread_read RPC
create policy qa_threads_delete on public.qa_threads for delete
  using (user_id = auth.uid() or public.is_app_admin());

create policy qa_messages_select on public.qa_messages for select
  using (public.qa_thread_owner(thread_id) = auth.uid() or public.is_app_admin());
create policy qa_messages_insert on public.qa_messages for insert
  with check (
    sender_id = auth.uid() and public.is_active_user()
    and ((sender_role = 'user'  and public.qa_thread_owner(thread_id) = auth.uid())
      or (sender_role = 'admin' and public.is_app_admin())));
-- 消息不可单条改删,只随线程整删级联

-- ---------------------------------------------------------------- 触发器
-- ① 待回覆上限:同一用户 last_sender_role='user' 的线程 ≥3 时拒绝新建
create or replace function public.guard_qa_thread_cap() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from qa_threads
       where user_id = new.user_id and last_sender_role = 'user') >= 3 then
    raise exception 'QA_PENDING_LIMIT';   -- 客户端据此渲染友好文案
  end if;
  return new;
end $$;

create trigger trg_qa_thread_cap
  before insert on public.qa_threads
  for each row execute function public.guard_qa_thread_cap();

-- ② 消息后处理:维护线程冗余列 + 生成通知(notifications 维持「仅服务端写」)
create or replace function public.on_qa_message_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_owner uuid;
  v_first boolean;
begin
  select user_id into v_owner from qa_threads where id = new.thread_id;
  v_first := not exists (select 1 from qa_messages
                          where thread_id = new.thread_id and id <> new.id);
  update qa_threads
     set last_sender_role     = new.sender_role,
         last_message_at      = new.created_at,
         last_message_preview = left(new.body, 100),
         first_message_preview = case when v_first then left(new.body, 100)
                                      else first_message_preview end
   where id = new.thread_id;

  if new.sender_role = 'admin' then
    -- 回复自己的线程不产生自通知
    if v_owner is distinct from new.sender_id then
      insert into notifications (scope, target_id, type, payload, channels)
      values ('user', v_owner, 'qa_reply',
              jsonb_build_object('thread_id', new.thread_id), '{inapp,push}');
    end if;
  else
    -- 用户提问/追问 → 通知全体未封禁管理员(发送者本人除外)
    insert into notifications (scope, target_id, type, payload, channels)
    select 'user', p.id, 'qa_question',
           jsonb_build_object('thread_id', new.thread_id), '{inapp,push}'
      from profiles p
     where p.is_app_admin and p.banned_at is null and p.id <> new.sender_id;
  end if;
  return new;
end $$;

create trigger trg_qa_message_insert
  after insert on public.qa_messages
  for each row execute function public.on_qa_message_insert();

-- ---------------------------------------------------------------- RPC
-- 原子创建线程 + 首条消息(security invoker:RLS 与上限触发器正常生效,不绕权限)
create or replace function public.create_qa_thread(p_body text) returns uuid
language plpgsql security invoker set search_path = public as $$
declare
  v_id uuid;
begin
  insert into qa_threads (user_id) values (auth.uid()) returning id into v_id;
  insert into qa_messages (thread_id, sender_id, sender_role, body)
  values (v_id, auth.uid(), 'user', p_body);
  return v_id;
end $$;

-- 提问人已读位点(update 不对客户端开放,已读只能走此口)
create or replace function public.mark_qa_thread_read(p_thread_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update qa_threads set user_last_read_at = now()
   where id = p_thread_id and user_id = auth.uid();
end $$;

revoke execute on function public.create_qa_thread(text) from public, anon;
revoke execute on function public.mark_qa_thread_read(uuid) from public, anon;
grant execute on function public.create_qa_thread(text) to authenticated;
grant execute on function public.mark_qa_thread_read(uuid) to authenticated;
