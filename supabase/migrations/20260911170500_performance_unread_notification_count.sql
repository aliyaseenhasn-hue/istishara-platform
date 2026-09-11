create or replace function public.get_my_unread_notification_count()
returns integer
language sql
stable
security invoker
set search_path = public
as $$
  select count(*)::integer
  from public.notifications n
  join public.profiles p on p.id = n.user_id
  where p.auth_id = auth.uid()
    and n.is_read = false;
$$;

grant execute on function public.get_my_unread_notification_count() to authenticated;
