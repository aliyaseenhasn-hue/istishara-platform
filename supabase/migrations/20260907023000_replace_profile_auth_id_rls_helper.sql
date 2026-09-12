create or replace function public.is_profile_owned_by_actor(p_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = p_profile_id
      and p.auth_id = auth.uid()
  );
$$;

revoke execute on function public.is_profile_owned_by_actor(uuid) from public, anon;
grant execute on function public.is_profile_owned_by_actor(uuid) to authenticated;

-- Remove the old helper from the client-callable surface. It returned raw auth_id values.
revoke execute on function public.get_profile_auth_id(uuid) from public, anon, authenticated;

-- Replace every RLS dependency on the raw auth_id helper with a boolean ownership check.
drop policy if exists conversations_insert on public.conversations;
create policy conversations_insert on public.conversations for insert to authenticated
with check (is_profile_owned_by_actor(user_id) or is_profile_owned_by_actor(lawyer_id));

drop policy if exists conversations_select on public.conversations;
create policy conversations_select on public.conversations for select to authenticated
using (is_profile_owned_by_actor(user_id) or is_profile_owned_by_actor(lawyer_id) or get_my_role() = any (array['admin'::user_role,'moderator'::user_role]));

drop policy if exists conversations_update on public.conversations;
create policy conversations_update on public.conversations for update to authenticated
using (is_profile_owned_by_actor(user_id) or is_profile_owned_by_actor(lawyer_id))
with check (is_profile_owned_by_actor(user_id) or is_profile_owned_by_actor(lawyer_id));

drop policy if exists lawyer_profiles_insert_auth on public.lawyer_profiles;
create policy lawyer_profiles_insert_auth on public.lawyer_profiles for insert to authenticated
with check (is_profile_owned_by_actor(profile_id) or get_my_role() = any (array['admin'::user_role,'moderator'::user_role]));

drop policy if exists messages_insert on public.messages;
create policy messages_insert on public.messages for insert to authenticated
with check (
  is_profile_owned_by_actor(sender_id)
  and exists (
    select 1 from public.conversations c
    where c.id = messages.conversation_id
      and (is_profile_owned_by_actor(c.user_id) or is_profile_owned_by_actor(c.lawyer_id))
  )
);

drop policy if exists messages_select on public.messages;
create policy messages_select on public.messages for select to authenticated
using (
  exists (
    select 1 from public.conversations c
    where c.id = messages.conversation_id
      and (is_profile_owned_by_actor(c.user_id) or is_profile_owned_by_actor(c.lawyer_id))
  )
);

drop policy if exists messages_update on public.messages;
create policy messages_update on public.messages for update to authenticated
using (is_profile_owned_by_actor(sender_id))
with check (is_profile_owned_by_actor(sender_id));

drop policy if exists notifications_delete on public.notifications;
create policy notifications_delete on public.notifications for delete to authenticated
using (is_profile_owned_by_actor(user_id) or get_my_role() = any (array['admin'::user_role,'moderator'::user_role]));

drop policy if exists notifications_select on public.notifications;
create policy notifications_select on public.notifications for select to authenticated
using (is_profile_owned_by_actor(user_id) or get_my_role() = any (array['admin'::user_role,'moderator'::user_role]));

drop policy if exists notifications_update on public.notifications;
create policy notifications_update on public.notifications for update to authenticated
using (is_profile_owned_by_actor(user_id) or get_my_role() = any (array['admin'::user_role,'moderator'::user_role]))
with check (is_profile_owned_by_actor(user_id) or get_my_role() = any (array['admin'::user_role,'moderator'::user_role]));

drop policy if exists specialization_requests_delete on public.specialization_change_requests;
create policy specialization_requests_delete on public.specialization_change_requests for delete to authenticated
using (is_profile_owned_by_actor(lawyer_id) or get_my_role() = any (array['admin'::user_role,'moderator'::user_role]));

drop policy if exists specialization_requests_insert on public.specialization_change_requests;
create policy specialization_requests_insert on public.specialization_change_requests for insert to authenticated
with check (is_profile_owned_by_actor(lawyer_id));

drop policy if exists specialization_requests_select on public.specialization_change_requests;
create policy specialization_requests_select on public.specialization_change_requests for select to authenticated
using (is_profile_owned_by_actor(lawyer_id) or get_my_role() = any (array['admin'::user_role,'moderator'::user_role]));
