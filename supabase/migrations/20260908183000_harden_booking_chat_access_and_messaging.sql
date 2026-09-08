-- Chat is available only to the two booking participants after a confirmed/active booking.
-- Sending and read receipts use SECURITY DEFINER RPCs so both client and lawyer
-- follow the same validated path and do not depend on direct table writes.

create or replace function public.can_access_conversation(p_conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.conversations c
    join public.profiles me on me.auth_id = auth.uid()
    where c.id = p_conversation_id
      and me.id in (c.user_id, c.lawyer_id)
      and exists (
        select 1
        from public.bookings b
        where b.user_id = c.user_id
          and b.lawyer_id = c.lawyer_id
          and b.status in ('مؤكد', 'قيد التنفيذ', 'مكتمل')
      )
  );
$$;

revoke all on function public.can_access_conversation(uuid) from public, anon;
grant execute on function public.can_access_conversation(uuid) to authenticated;

drop policy if exists conversations_select on public.conversations;
create policy conversations_select on public.conversations
for select to authenticated
using (
  public.can_access_conversation(id)
  or public.get_my_role() = any (array['admin'::public.user_role, 'moderator'::public.user_role])
);

drop policy if exists conversations_update on public.conversations;
create policy conversations_update on public.conversations
for update to authenticated
using (public.can_access_conversation(id))
with check (public.can_access_conversation(id));

drop policy if exists messages_select on public.messages;
create policy messages_select on public.messages
for select to authenticated
using (public.can_access_conversation(conversation_id));

drop policy if exists messages_insert on public.messages;
create policy messages_insert on public.messages
for insert to authenticated
with check (
  public.can_access_conversation(conversation_id)
  and public.is_profile_owned_by_actor(sender_id)
);

drop policy if exists messages_update on public.messages;

create or replace function public.send_chat_message(p_conversation_id uuid, p_content text)
returns public.messages
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid;
  v_conversation public.conversations%rowtype;
  v_message public.messages%rowtype;
  v_text text := btrim(coalesce(p_content, ''));
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً' using errcode = 'P0001';
  end if;
  if v_text = '' then
    raise exception 'لا يمكن إرسال رسالة فارغة' using errcode = 'P0001';
  end if;
  if char_length(v_text) > 4000 then
    raise exception 'الرسالة طويلة جداً' using errcode = 'P0001';
  end if;

  select id into v_profile_id
  from public.profiles
  where auth_id = auth.uid()
  limit 1;

  if v_profile_id is null then
    raise exception 'تعذر تحديد حساب المستخدم' using errcode = 'P0001';
  end if;

  select * into v_conversation
  from public.conversations
  where id = p_conversation_id;

  if not found or v_profile_id not in (v_conversation.user_id, v_conversation.lawyer_id) then
    raise exception 'لا يمكنك الوصول إلى هذه المحادثة' using errcode = 'P0001';
  end if;

  if not exists (
    select 1 from public.bookings b
    where b.user_id = v_conversation.user_id
      and b.lawyer_id = v_conversation.lawyer_id
      and b.status in ('مؤكد', 'قيد التنفيذ', 'مكتمل')
  ) then
    raise exception 'المحادثة متاحة فقط بعد تأكيد الحجز' using errcode = 'P0001';
  end if;

  insert into public.messages(conversation_id, sender_id, content, is_read)
  values (p_conversation_id, v_profile_id, v_text, false)
  returning * into v_message;

  update public.conversations
  set last_message = v_text,
      last_message_at = now()
  where id = p_conversation_id;

  return v_message;
end;
$$;

revoke all on function public.send_chat_message(uuid, text) from public, anon;
grant execute on function public.send_chat_message(uuid, text) to authenticated;

create or replace function public.mark_chat_read(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid;
begin
  select id into v_profile_id
  from public.profiles
  where auth_id = auth.uid()
  limit 1;

  if v_profile_id is null or not public.can_access_conversation(p_conversation_id) then
    return;
  end if;

  update public.messages
  set is_read = true
  where conversation_id = p_conversation_id
    and sender_id <> v_profile_id
    and is_read = false;
end;
$$;

revoke all on function public.mark_chat_read(uuid) from public, anon;
grant execute on function public.mark_chat_read(uuid) to authenticated;

-- reference_id is uuid in production. The previous trigger compared it to text,
-- which aborted message insertion with PostgreSQL error 42883.
create or replace function public.notify_message_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_lawyer_id uuid;
  v_recipient uuid;
begin
  select user_id, lawyer_id
    into v_user_id, v_lawyer_id
  from public.conversations
  where id = new.conversation_id;

  v_recipient := case
    when new.sender_id = v_user_id then v_lawyer_id
    when new.sender_id = v_lawyer_id then v_user_id
    else null
  end;

  if v_recipient is null then
    return new;
  end if;

  if not exists (
    select 1
    from public.notifications
    where user_id = v_recipient
      and type = 'chat'
      and reference_id = new.conversation_id
      and reference_type = 'conversation'
      and created_at > now() - interval '5 seconds'
  ) then
    insert into public.notifications(
      user_id,
      title,
      body,
      type,
      is_read,
      reference_id,
      reference_type
    ) values (
      v_recipient,
      'رسالة جديدة',
      'لديك رسالة جديدة في المحادثة.',
      'chat',
      false,
      new.conversation_id,
      'conversation'
    );
  end if;

  return new;
end;
$$;
