create or replace function public.get_my_conversations_summary()
returns setof jsonb
language plpgsql
stable
security definer
set search_path=public,pg_catalog
as $$
declare
  v_profile_id uuid;
begin
  if auth.uid() is null then
    return;
  end if;

  select p.id into v_profile_id
  from public.profiles p
  where p.auth_id=auth.uid()
  limit 1;

  if v_profile_id is null then
    return;
  end if;

  return query
  select jsonb_build_object(
    'id', c.id,
    'user_id', c.user_id,
    'lawyer_id', c.lawyer_id,
    'last_message', c.last_message,
    'last_message_at', c.last_message_at,
    'other_party_profile_id', case when c.user_id=v_profile_id then c.lawyer_id else c.user_id end,
    'other_party_name', case
      when c.user_id=v_profile_id then
        'المحامي / ' || coalesce(nullif(trim(lp.full_name),''),nullif(trim(lawyer_base.full_name),''),'محامي استشارة')
      else
        'طالب الاستشارة / ' || coalesce(nullif(trim(client_profile.full_name),''),'طالب الاستشارة')
    end
  )
  from public.conversations c
  left join public.profiles client_profile on client_profile.id=c.user_id
  left join public.profiles lawyer_base on lawyer_base.id=c.lawyer_id
  left join public.lawyer_profiles lp on lp.profile_id=c.lawyer_id
  where c.user_id=v_profile_id or c.lawyer_id=v_profile_id
  order by c.last_message_at desc nulls last, c.created_at desc;
end;
$$;

revoke all on function public.get_my_conversations_summary() from public,anon;
grant execute on function public.get_my_conversations_summary() to authenticated;
