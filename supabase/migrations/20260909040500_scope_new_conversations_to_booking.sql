create unique index if not exists conversations_booking_id_unique
on public.conversations(booking_id)
where booking_id is not null;

create or replace function public.ensure_conversation_for_confirmed_booking()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.status in ('مؤكد','قيد التنفيذ','مكتمل') and new.user_id is not null and new.lawyer_id is not null then
    if not exists(select 1 from public.conversations c where c.booking_id=new.id) then
      insert into public.conversations(booking_id,user_id,lawyer_id,last_message,last_message_at)
      values(new.id,new.user_id,new.lawyer_id,null,null)
      on conflict (booking_id) where booking_id is not null do nothing;
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.can_access_conversation(p_conversation_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(
    select 1 from public.conversations c
    join public.profiles me on me.auth_id=auth.uid()
    where c.id=p_conversation_id and me.id in (c.user_id,c.lawyer_id)
      and (
        (c.booking_id is not null and exists(select 1 from public.bookings b where b.id=c.booking_id and b.user_id=c.user_id and b.lawyer_id=c.lawyer_id and b.status in ('مؤكد','قيد التنفيذ','مكتمل')))
        or
        (c.booking_id is null and exists(select 1 from public.bookings b where b.user_id=c.user_id and b.lawyer_id=c.lawyer_id and b.status in ('مؤكد','قيد التنفيذ','مكتمل')))
      )
  );
$$;