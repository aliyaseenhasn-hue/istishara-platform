create or replace function public.is_my_account_closed()
returns boolean
language sql
stable
security definer
set search_path=public
as $$
  select auth.uid() is not null
     and exists(select 1 from public.closed_auth_accounts c where c.auth_id=auth.uid());
$$;
revoke all on function public.is_my_account_closed() from public,anon;
grant execute on function public.is_my_account_closed() to authenticated;