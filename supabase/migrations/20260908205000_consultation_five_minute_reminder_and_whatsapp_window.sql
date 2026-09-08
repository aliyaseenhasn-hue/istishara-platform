create extension if not exists pg_cron with schema extensions;

alter table public.bookings
  add column if not exists consultation_reminder_sent_at timestamptz;

create or replace function public.send_due_consultation_reminders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking record;
  v_count integer := 0;
begin
  for v_booking in
    select
      b.id,
      b.user_id,
      b.lawyer_id,
      coalesce(nullif(trim(client.full_name), ''), 'طالب الاستشارة') as client_name,
      coalesce(nullif(trim(lawyer.full_name), ''), 'المحامي') as lawyer_name
    from public.bookings b
    join public.profiles client on client.id = b.user_id
    join public.profiles lawyer on lawyer.id = b.lawyer_id
    where b.lawyer_approved = true
      and b.status in ('مؤكد', 'قيد التنفيذ')
      and b.scheduled_at > now()
      and b.scheduled_at <= now() + interval '5 minutes'
      and b.consultation_reminder_sent_at is null
    for update of b skip locked
  loop
    perform public.enqueue_user_notification(
      v_booking.user_id,
      'موعد الاستشارة بعد ٥ دقائق',
      format('بقي على موعد استشارتك مع المحامي %s ٥ دقائق. يمكنك العودة إلى التطبيق والبدء بالاستشارة.', v_booking.lawyer_name),
      'consultation_reminder',
      v_booking.id,
      'booking'
    );

    perform public.enqueue_user_notification(
      v_booking.lawyer_id,
      'موعد الاستشارة بعد ٥ دقائق',
      format('بقي على موعد استشارتك مع طالب الاستشارة %s ٥ دقائق. يمكنك العودة إلى التطبيق والبدء بالاستشارة.', v_booking.client_name),
      'consultation_reminder',
      v_booking.id,
      'booking'
    );

    update public.bookings
    set consultation_reminder_sent_at = now()
    where id = v_booking.id
      and consultation_reminder_sent_at is null;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

revoke all on function public.send_due_consultation_reminders() from public, anon, authenticated;

create or replace function public.get_lawyer_whatsapp_after_accepted(p_lawyer_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_client_id uuid;
  v_number text;
begin
  if auth.uid() is null then return null; end if;

  select id into v_client_id
  from public.profiles
  where auth_id = auth.uid()
  limit 1;
  if v_client_id is null then return null; end if;

  if not exists (
    select 1
    from public.bookings b
    where b.user_id = v_client_id
      and b.lawyer_id = p_lawyer_id
      and b.lawyer_approved = true
      and b.status in ('مؤكد', 'قيد التنفيذ')
      and now() >= b.scheduled_at - interval '5 minutes'
      and now() <= b.scheduled_at + make_interval(mins => greatest(coalesce(b.package_duration_minutes, 30), 30))
  ) then
    return null;
  end if;

  select coalesce(nullif(trim(lp.whatsapp), ''), nullif(trim(p.whatsapp_number), ''))
  into v_number
  from public.lawyer_profiles lp
  join public.profiles p on p.id = lp.profile_id
  where lp.profile_id = p_lawyer_id;

  return v_number;
end;
$$;

revoke all on function public.get_lawyer_whatsapp_after_accepted(uuid) from public, anon;
grant execute on function public.get_lawyer_whatsapp_after_accepted(uuid) to authenticated;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'consultation-five-minute-reminders') then
    perform cron.unschedule('consultation-five-minute-reminders');
  end if;
  perform cron.schedule(
    'consultation-five-minute-reminders',
    '* * * * *',
    'select public.send_due_consultation_reminders();'
  );
end $$;
