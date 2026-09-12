create or replace function public.get_booking_lawyer_info(p_booking_id uuid)
returns table(full_name text, avatar_url text)
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_auth_uid uuid := auth.uid();
begin
  if v_auth_uid is null then
    raise exception 'غير مصرح';
  end if;

  return query
  select
    coalesce(
      nullif(trim(lp.full_name), ''),
      nullif(trim(p.full_name), '')
    )::text as full_name,
    p.avatar_url::text
  from public.bookings b
  left join public.profiles p on p.id = b.lawyer_id
  left join public.lawyer_profiles lp on lp.profile_id = b.lawyer_id
  left join public.profiles client on client.id = b.user_id
  where b.id = p_booking_id
    and (
      p.auth_id = v_auth_uid
      or client.auth_id = v_auth_uid
      or public.is_admin()
    )
  limit 1;
end;
$function$;

grant execute on function public.get_booking_lawyer_info(uuid) to authenticated;
revoke execute on function public.get_booking_lawyer_info(uuid) from anon;
