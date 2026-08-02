-- ============================================================================
-- 学修问答角色语义修复(P8.6,PRD v0.5.19 §16,设计 study-qa.md §9):
-- 0018 版 on_qa_message_insert 对「管理员回复自己的线程」抑制 qa_reply 自通知,
-- 叠加客户端角色从所有权推导的缺陷后,管理员自问自答收不到任何通知。
-- 定案:admin 消息一律向线程主人发 qa_reply(文案本就不带正文,自答亦通知,
-- 保证多设备可达与可测);qa_question 维持排除发送者本人。
-- ============================================================================

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
    -- 一律通知线程主人(含自答:owner == sender 时不再抑制,P8.6 定案)
    insert into notifications (scope, target_id, type, payload, channels)
    values ('user', v_owner, 'qa_reply',
            jsonb_build_object('thread_id', new.thread_id), '{inapp,push}');
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
