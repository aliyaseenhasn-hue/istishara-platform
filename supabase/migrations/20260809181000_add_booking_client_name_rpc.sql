create or replace function public.get_booking_client_name(p_booking_id uuid)
returns table(full_name text)
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_auth_uid uuid := auth.uid();
begin
  if v_auth_uid is null then raise exception 'غير مصرح'; end if;
  return query
  select nullif(trim(p.full_name), '')::text
  from public.bookings b
  join public.profiles p on p.id = b.user_id
  where b.id = p_booking_id
    and (
      p.auth_id = v_auth_uid
      or exists (
        select 1 from public.lawyer_profiles lp
        where lp.id = b.lawyer_id and lp.auth_user_id = v_auth_uid
      )
      or public.is_admin()
    )
  limit 1;
end;
$function$;

grant execute on function public.get_booking_client_name(uuid) to authenticated;
revoke execute on function public.get_booking_client_name(uuid) from anon;
