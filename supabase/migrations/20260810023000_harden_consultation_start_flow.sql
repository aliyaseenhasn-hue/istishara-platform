-- تشديد دورة بدء الاستشارة:
-- 1) الاستشارة المكتبية لا تبدأ قبل تسجيل الدفع اليدوي بالكامل.
-- 2) لا تُعرض أرقام واتساب للاستشارة المكتبية.
-- 3) لا يمكن إنهاء الاستشارة قبل وجود وقت بدء فعلي.
-- 4) لا تسمح دوال دورة الحجز بتنفيذها من مستخدم مجهول.

create or replace function public.get_booking_participant_contact_info(p_booking_id uuid)
returns table(lawyer_name text, lawyer_phone text, lawyer_whatsapp text, client_name text, client_phone text, client_whatsapp text)
language plpgsql security definer set search_path = public
as $function$
declare v_profile_id uuid; v_booking public.bookings%rowtype;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  select id into v_profile_id from public.profiles where auth_id = auth.uid() limit 1;
  if v_profile_id is null then raise exception 'ملف المستخدم غير مكتمل'; end if;
  select * into v_booking from public.bookings where id = p_booking_id and (user_id = v_profile_id or lawyer_id = v_profile_id);
  if not found then raise exception 'غير مصرح بمعلومات التواصل لهذا الحجز'; end if;
  if v_booking.status not in ('مؤكد','قيد التنفيذ','مكتمل') then raise exception 'معلومات التواصل غير متاحة قبل تأكيد الحجز'; end if;
  return query
  select coalesce(lp.full_name, lp_profile.full_name, 'محامي')::text,
         lp_profile.phone::text,
         case when v_booking.consultation_mode = 'في المكتب' then null else lp.whatsapp::text end,
         client_profile.full_name::text,
         client_profile.phone::text,
         case when v_booking.consultation_mode = 'في المكتب' then null else coalesce(v_booking.whatsapp_number, client_profile.phone)::text end
  from public.lawyer_profiles lp
  join public.profiles lp_profile on lp_profile.id = lp.profile_id
  join public.profiles client_profile on client_profile.id = v_booking.user_id
  where lp.profile_id = v_booking.lawyer_id;
end;
$function$;
revoke execute on function public.get_booking_participant_contact_info(uuid) from public;
grant execute on function public.get_booking_participant_contact_info(uuid) to authenticated;

create or replace function public.change_booking_status(p_booking_id uuid, p_new_status text)
returns public.bookings
language plpgsql security definer set search_path = public
as $function$
declare v_actor uuid := auth.uid(); v_profile_id uuid; v_booking public.bookings; v_is_admin boolean := public.is_admin(); v_is_paid boolean; v_duration integer; v_now timestamptz := now();
begin
  if v_actor is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if p_new_status not in ('مؤكد','قيد التنفيذ','مكتمل','ملغي','مسترد') then raise exception 'حالة الحجز غير صالحة'; end if;
  select id into v_profile_id from public.profiles where auth_id = v_actor limit 1;
  select * into v_booking from public.bookings where id = p_booking_id for update;
  if not found then raise exception 'الحجز غير موجود'; end if;
  select exists(select 1 from public.payments where booking_id = v_booking.id and status = 'تم الدفع') into v_is_paid;
  if v_is_admin then null;
  elsif v_booking.user_id = v_profile_id and p_new_status = 'ملغي' and v_booking.status in ('قيد انتظار الدفع','قيد معالجة الدفع','مؤكد') then null;
  elsif v_booking.lawyer_id = v_profile_id and p_new_status = 'قيد التنفيذ' then
    if v_booking.status <> 'مؤكد' or not v_is_paid or not v_booking.lawyer_approved or v_booking.consultation_status <> 'لم تبدأ' then raise exception 'لا يمكن بدء الاستشارة قبل تأكيد الدفع والحجز وموافقة المحامي'; end if;
    if v_booking.consultation_mode = 'في المكتب' and (v_booking.manual_payment_required = false or v_booking.manual_received_at is null or round(coalesce(v_booking.manual_received_amount, 0)::numeric, 2) <> round(v_booking.price::numeric, 2)) then raise exception 'لا يمكن بدء الاستشارة المكتبية قبل تسجيل مبلغ الدفع المستلم بالكامل'; end if;
    v_duration := coalesce(v_booking.package_duration_minutes, 30);
    if v_now < v_booking.scheduled_at - interval '5 minutes' then raise exception 'لم يحِن موعد الاستشارة بعد'; end if;
    if v_now > v_booking.scheduled_at + make_interval(mins => v_duration) then raise exception 'انتهى وقت الاستشارة المحدد'; end if;
  elsif v_booking.lawyer_id = v_profile_id and p_new_status = 'مكتمل' then
    if v_booking.status <> 'قيد التنفيذ' or v_booking.consultation_status <> 'قيد التنفيذ' or v_booking.started_at is null then raise exception 'لا يمكن إنهاء الاستشارة في حالتها الحالية'; end if;
  elsif v_booking.lawyer_id = v_profile_id and p_new_status = 'ملغي' and v_booking.status in ('قيد انتظار الدفع','قيد معالجة الدفع','مؤكد','قيد التنفيذ') then null;
  else raise exception 'غير مصرح بهذا الإجراء'; end if;
  update public.bookings set status = p_new_status,
    consultation_status = case when p_new_status = 'قيد التنفيذ' then 'قيد التنفيذ' when p_new_status = 'مكتمل' then 'انتهت' when p_new_status = 'ملغي' and status = 'قيد التنفيذ' then 'أُلغيت' else consultation_status end,
    started_at = case when p_new_status = 'قيد التنفيذ' then coalesce(started_at, now()) else started_at end,
    completed_at = case when p_new_status = 'مكتمل' then now() else completed_at end,
    cancelled_at = case when p_new_status = 'ملغي' then now() else cancelled_at end
  where id = p_booking_id returning * into v_booking;
  return v_booking;
end;
$function$;
revoke execute on function public.change_booking_status(uuid,text) from public;
grant execute on function public.change_booking_status(uuid,text) to authenticated;
