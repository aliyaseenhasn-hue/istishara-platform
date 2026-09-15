create extension if not exists pg_cron with schema extensions;

alter table public.bookings
  add column if not exists consultation_start_notification_sent_at timestamptz;

create or replace function public.send_due_consultation_start_notifications()
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
      and b.scheduled_at <= now()
      and b.scheduled_at >= now() - interval '10 minutes'
      and b.consultation_start_notification_sent_at is null
    for update of b skip locked
  loop
    perform public.enqueue_user_notification(
      v_booking.user_id,
      'بدأ موعد الاستشارة الآن',
      format('حان الآن موعد استشارتك مع المحامي %s. افتح تفاصيل الاستشارة واضغط زر واتساب للتواصل.', v_booking.lawyer_name),
      'consultation_started',
      v_booking.id,
      'booking'
    );

    perform public.enqueue_user_notification(
      v_booking.lawyer_id,
      'بدأ موعد الاستشارة الآن',
      format('حان الآن موعد استشارتك مع طالب الاستشارة %s. افتح تفاصيل الاستشارة لبدء التواصل.', v_booking.client_name),
      'consultation_started',
      v_booking.id,
      'booking'
    );

    update public.bookings
    set consultation_start_notification_sent_at = now()
    where id = v_booking.id
      and consultation_start_notification_sent_at is null;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

revoke all on function public.send_due_consultation_start_notifications()
from public, anon, authenticated;

do $$
begin
  if exists (
    select 1
    from cron.job
    where jobname = 'consultation-start-notifications'
  ) then
    perform cron.unschedule('consultation-start-notifications');
  end if;

  perform cron.schedule(
    'consultation-start-notifications',
    '* * * * *',
    'select public.send_due_consultation_start_notifications();'
  );
end $$;
