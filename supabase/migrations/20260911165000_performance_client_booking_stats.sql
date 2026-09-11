create or replace function public.get_my_booking_stats()
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select jsonb_build_object(
    'total', count(*)::int,
    'completed', count(*) filter (where b.status = 'مكتمل')::int
  )
  from public.bookings b
  join public.profiles p on p.id = b.user_id
  where p.auth_id = auth.uid()
    and b.archived_by_user_at is null;
$$;

grant execute on function public.get_my_booking_stats() to authenticated;
