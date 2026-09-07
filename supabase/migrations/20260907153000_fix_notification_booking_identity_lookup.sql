-- Production hardening: fix booking notification authorization to use profile IDs.
-- The bookings table stores user_id/lawyer_id as profiles.id, while auth.uid()
-- is auth.users.id. The previous RPC compared those different identifiers.

create or replace function public.get_booking_for_notification(p_booking_id uuid)
returns setof public.bookings
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_actor_profile uuid;
begin
  if (select auth.uid()) is null then
    return;
  end if;

  select id into v_actor_profile
  from public.profiles
  where auth_id = (select auth.uid())
  limit 1;

  if v_actor_profile is null then
    return;
  end if;

  return query
  select b.*
  from public.bookings b
  where b.id = p_booking_id
    and (b.user_id = v_actor_profile or b.lawyer_id = v_actor_profile);
end;
$$;

revoke all on function public.get_booking_for_notification(uuid) from public, anon;
grant execute on function public.get_booking_for_notification(uuid) to authenticated;
