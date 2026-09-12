create or replace function public.send_due_consultation_reminders()
returns integer
language plpgsql
security definer
set search_path=public
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
      and b.status = 'مؤكد'
      and b.scheduled_at > now()
      and b.scheduled_at <= now() + interval '5 minutes'
      and b.consultation_reminder_sent_at is null
    for update of b skip locked
  loop
    perform public.enqueue_user_notification(
      v_booking.user_id,
      'أصبح موعد الاستشارة متاحاً الآن',
      format('تبقى أقل من ٥ دقائق على موعد استشارتك مع المحامي %s. افتح تفاصيل الحجز الآن؛ أصبح وقت بدء الاستشارة متاحاً.', v_booking.lawyer_name),
      'consultation_reminder',
      v_booking.id,
      'booking'
    );

    perform public.enqueue_user_notification(
      v_booking.lawyer_id,
      'يمكنك بدء الاستشارة الآن',
      format('تبقى أقل من ٥ دقائق على موعدك مع طالب الاستشارة %s. أصبح زر «بدء الاستشارة الآن» متاحاً في تفاصيل الحجز.', v_booking.client_name),
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
