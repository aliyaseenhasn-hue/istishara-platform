-- Finalize notification delivery semantics:
-- - actions performed by a user do not create an in-app/push notification back to that same actor;
-- - legacy PWA registrations without a stable device key are removed once, because they cannot
--   be safely associated with the currently signed-in account after account switching.

create or replace function public.suppress_self_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.actor_profile_id is not null
     and new.user_id = new.actor_profile_id then
    return null;
  end if;
  return new;
end;
$$;

revoke all on function public.suppress_self_notification()
  from public, anon, authenticated;

drop trigger if exists trg_suppress_self_notification on public.notifications;
create trigger trg_suppress_self_notification
before insert on public.notifications
for each row execute function public.suppress_self_notification();

-- These rows predate stable device ownership. Leaving them active can deliver notifications
-- for an old client/lawyer account to the same browser after switching accounts. The updated
-- app re-registers an existing browser PushSubscription automatically on the next load/login.
delete from public.pwa_push_subscriptions
where device_key is null;
