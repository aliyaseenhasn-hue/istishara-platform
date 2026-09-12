-- No-show timing must use the protected consultation start reference. If payment
-- is confirmed after the scheduled time, neither participant should be marked
-- absent before they have had a reasonable chance to start after confirmation.

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
  v_reference_at timestamptz;
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

  if v_booking.lawyer_id=v_profile_id then
    if v_booking.status='مؤكد' then
      v_reference_at:=v_booking.scheduled_at;
      if v_booking.payment_required
         and v_booking.payment_confirmed_at is not null
         and v_booking.payment_confirmed_at>v_reference_at then
        v_reference_at:=v_booking.payment_confirmed_at;
      end if;
    elsif v_booking.status='قيد التنفيذ' and v_booking.started_at is not null then
      v_reference_at:=v_booking.started_at;
    else
      raise exception 'لا يمكن تسجيل عدم حضور طالب الاستشارة في هذه الحالة';
    end if;

    if v_now<v_reference_at+interval '10 minutes' then
      raise exception 'يمكن تسجيل عدم حضور طالب الاستشارة بعد مرور 10 دقائق من وقت إتاحة الاستشارة';
    end if;
    v_reason:='عدم حضور طالب الاستشارة';

  elsif v_booking.user_id=v_profile_id then
    if v_booking.status<>'مؤكد' or v_booking.started_at is not null then
      raise exception 'لا يمكن تسجيل عدم حضور المحامي بعد بدء الاستشارة';
    end if;

    v_reference_at:=v_booking.scheduled_at;
    if v_booking.payment_required
       and v_booking.payment_confirmed_at is not null
       and v_booking.payment_confirmed_at>v_reference_at then
      v_reference_at:=v_booking.payment_confirmed_at;
    end if;

    if v_now<v_reference_at+interval '10 minutes' then
      raise exception 'يمكن تسجيل عدم حضور المحامي بعد مرور 10 دقائق من وقت إتاحة الاستشارة';
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
