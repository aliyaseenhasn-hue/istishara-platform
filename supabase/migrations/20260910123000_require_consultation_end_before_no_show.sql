-- No-show reports are only allowed after the consultation's usable time window ends.
-- This mirrors the consultation timing UI: normal bookings use the booked duration,
-- delayed payment keeps the existing one-hour protected start window, and a started
-- consultation uses its actual started_at plus the booked duration.

create or replace function public.report_booking_no_show(p_booking_id uuid)
returns public.bookings
language plpgsql
security definer
set search_path=public
as $$
declare
  v_actor uuid:=auth.uid();
  v_profile_id uuid;
  v_booking public.bookings%rowtype;
  v_now timestamptz:=now();
  v_duration_minutes integer;
  v_eligible_at timestamptz;
  v_delayed_start_deadline timestamptz;
  v_reason text;
  v_previous_status text;
  v_previous_consultation_status text;
begin
  if v_actor is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  select id into v_profile_id from public.profiles where auth_id=v_actor limit 1;
  if v_profile_id is null then raise exception 'ملف المستخدم غير مكتمل'; end if;

  select * into v_booking from public.bookings where id=p_booking_id for update;
  if not found then raise exception 'الحجز غير موجود'; end if;

  if exists(
    select 1 from public.no_show_review_requests
    where booking_id=p_booking_id and status='pending'
  ) then
    raise exception 'يوجد بلاغ عدم حضور قيد المراجعة لهذا الحجز';
  end if;

  v_previous_status:=v_booking.status;
  v_previous_consultation_status:=v_booking.consultation_status;
  v_duration_minutes:=greatest(coalesce(v_booking.package_duration_minutes,30),1);

  if v_booking.lawyer_id=v_profile_id then
    if v_booking.status='مؤكد' then
      v_eligible_at:=v_booking.scheduled_at + make_interval(mins => v_duration_minutes);
      if v_booking.payment_required
         and v_booking.payment_confirmed_at is not null
         and v_booking.payment_confirmed_at>v_booking.scheduled_at then
        v_delayed_start_deadline:=v_booking.payment_confirmed_at + interval '1 hour';
        v_eligible_at:=greatest(v_eligible_at,v_delayed_start_deadline);
      end if;
    elsif v_booking.status='قيد التنفيذ' and v_booking.started_at is not null then
      v_eligible_at:=v_booking.started_at + make_interval(mins => v_duration_minutes);
    else
      raise exception 'لا يمكن تسجيل عدم حضور طالب الاستشارة في هذه الحالة';
    end if;

    if v_now<v_eligible_at then
      raise exception 'لا يمكن الإبلاغ عن عدم حضور طالب الاستشارة قبل انتهاء الوقت المحدد للاستشارة';
    end if;
    v_reason:='عدم حضور طالب الاستشارة';

  elsif v_booking.user_id=v_profile_id then
    if v_booking.status<>'مؤكد' or v_booking.started_at is not null then
      raise exception 'لا يمكن تسجيل عدم حضور المحامي بعد بدء الاستشارة';
    end if;

    v_eligible_at:=v_booking.scheduled_at + make_interval(mins => v_duration_minutes);
    if v_booking.payment_required
       and v_booking.payment_confirmed_at is not null
       and v_booking.payment_confirmed_at>v_booking.scheduled_at then
      v_delayed_start_deadline:=v_booking.payment_confirmed_at + interval '1 hour';
      v_eligible_at:=greatest(v_eligible_at,v_delayed_start_deadline);
    end if;

    if v_now<v_eligible_at then
      raise exception 'لا يمكن الإبلاغ عن عدم حضور المحامي قبل انتهاء الوقت المحدد للاستشارة';
    end if;
    v_reason:='عدم حضور المحامي';
  else
    raise exception 'غير مصرح بهذا الإجراء';
  end if;

  insert into public.no_show_review_requests(
    booking_id,reporter_id,reason,status,previous_booking_status,previous_consultation_status
  ) values(
    p_booking_id,v_profile_id,v_reason,'pending',v_previous_status,v_previous_consultation_status
  );

  update public.bookings
  set status='بانتظار مراجعة عدم الحضور',consultation_status=v_reason
  where id=p_booking_id
  returning * into v_booking;

  return v_booking;
end;
$$;
