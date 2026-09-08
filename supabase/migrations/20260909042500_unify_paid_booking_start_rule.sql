create or replace function public.change_booking_status(p_booking_id uuid, p_new_status text)
returns public.bookings
language plpgsql
security definer
set search_path=public
as $$
declare
  v_actor uuid:=auth.uid();
  v_profile_id uuid;
  v_booking public.bookings;
  v_is_admin boolean:=public.is_admin();
  v_is_paid boolean;
  v_payment_satisfied boolean;
  v_duration integer;
  v_now timestamptz:=now();
begin
  if v_actor is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if p_new_status not in ('مؤكد','قيد التنفيذ','مكتمل','ملغي','مسترد') then raise exception 'حالة الحجز غير صالحة'; end if;
  select id into v_profile_id from public.profiles where auth_id=v_actor limit 1;
  select * into v_booking from public.bookings where id=p_booking_id for update;
  if not found then raise exception 'الحجز غير موجود'; end if;
  select exists(select 1 from public.payments where booking_id=v_booking.id and status='تم الدفع') into v_is_paid;
  v_payment_satisfied := (not v_booking.payment_required) or v_is_paid;
  if v_is_admin then null;
  elsif v_booking.user_id=v_profile_id and p_new_status='ملغي' and v_booking.status in ('قيد انتظار الدفع','قيد معالجة الدفع','قيد مراجعة المحامي','مؤكد') then null;
  elsif v_booking.lawyer_id=v_profile_id and p_new_status='قيد التنفيذ' then
    if v_booking.status<>'مؤكد' or not v_payment_satisfied or not v_booking.lawyer_approved or v_booking.consultation_status<>'لم تبدأ' then raise exception 'لا يمكن بدء الاستشارة قبل تأكيد الحجز وموافقة المحامي والدفع عند استحقاقه'; end if;
    v_duration:=coalesce(v_booking.package_duration_minutes,30);
    if v_now<v_booking.scheduled_at-interval '5 minutes' then raise exception 'لم يحِن موعد الاستشارة بعد'; end if;
    if v_now>v_booking.scheduled_at+make_interval(mins=>v_duration) then raise exception 'انتهى وقت الاستشارة المحدد'; end if;
  elsif v_booking.lawyer_id=v_profile_id and p_new_status='مكتمل' then
    if v_booking.status<>'قيد التنفيذ' or v_booking.consultation_status<>'قيد التنفيذ' or v_booking.started_at is null then raise exception 'لا يمكن إنهاء الاستشارة في حالتها الحالية'; end if;
  else raise exception 'غير مصرح بهذا الإجراء'; end if;
  update public.bookings set status=p_new_status,
    consultation_status=case when p_new_status='قيد التنفيذ' then 'قيد التنفيذ' when p_new_status='مكتمل' then 'انتهت' when p_new_status='ملغي' and status='قيد التنفيذ' then 'أُلغيت' else consultation_status end,
    started_at=case when p_new_status='قيد التنفيذ' then coalesce(started_at,now()) else started_at end,
    completed_at=case when p_new_status='مكتمل' then now() else completed_at end,
    cancelled_at=case when p_new_status='ملغي' then now() else cancelled_at end
  where id=p_booking_id returning * into v_booking;
  return v_booking;
end;
$$;