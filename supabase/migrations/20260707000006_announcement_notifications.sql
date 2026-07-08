-- ============================================================================
-- 群公告更新 → 群范围 App 内通知(PRD §3.2,P1.4 遗留至通知中心一并落地)
-- ============================================================================

create or replace function public.notify_announcement() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.announcement is distinct from old.announcement
     and new.announcement is not null then
    insert into public.notifications (scope, target_id, type, payload, channels)
    values ('group', new.id, 'announcement',
            jsonb_build_object('group_id', new.id, 'text', left(new.announcement, 200)),
            '{inapp}');
  end if;
  return new;
end $$;

create trigger trg_notify_announcement
  after update on public.groups
  for each row execute function public.notify_announcement();
