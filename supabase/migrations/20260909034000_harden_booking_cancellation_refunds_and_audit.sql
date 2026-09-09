alter table public.bookings add column if not exists cancellation_reason text;
alter table public.bookings add column if not exists cancelled_by_profile_id uuid references public.profiles(id) on delete set null;
alter table public.bookings add column if not exists cancellation_actor_role text;
alter table public.bookings add column if not exists cancellation_source text;
alter table public.bookings add column if not exists cancellation_request_id uuid references public.cancellation_requests(id) on delete set null;

do $$ begin
  if not exists (select 1 from pg_constraint where conname='bookings_cancellation_actor_role_chk') then
    alter table public.bookings add constraint bookings_cancellation_actor_role_chk
      check (cancellation_actor_role is null or cancellation_actor_role in ('client','lawyer','admin','system'));
  end if;
end $$;

create or replace function public.request_client_booking_cancellation(p_booking_id uuid,p_reason text)
returns public.bookings language plpgsql security definer set search_path='public' as $$
declare v_profile uuid; v_booking public.bookings%rowtype; v_paid boolean; v_new_status text; begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if nullif(trim(coalesce(p_reason,'')),'') is null then raise exception 'سبب الإلغاء إلزامي'; end if;
  select id into v_profile from public.profiles where auth_id=auth.uid() limit 1;
  select * into v_booking from public.bookings where id=p_booking_id for update;
  if not found then raise exception 'الحجز غير موجود'; end if;
  if v_booking.user_id<>v_profile then raise exception 'غير مصرح بهذا الإجراء'; end if;
  if v_booking.status not in ('قيد انتظار الدفع','قيد معالجة الدفع','قيد مراجعة المحامي','بانتظار التأكيد','مؤكد') then raise exception 'لا يمكن إلغاء الحجز في حالته الحالية'; end if;
  if v_booking.scheduled_at is not null and v_booking.scheduled_at<=now() then raise exception 'لا يمكن إلغاء موعد بدأ أو انتهى'; end if;
  select exists(select 1 from public.payments p where p.booking_id=v_booking.id and p.status='تم الدفع') into v_paid;
  v_new_status:=case when v_paid then 'بانتظار الاسترداد' else 'ملغي' end;
  update public.bookings set status=v_new_status,cancelled_at=coalesce(cancelled_at,now()),cancellation_reason=trim(p_reason),cancelled_by_profile_id=v_profile,cancellation_actor_role='client',cancellation_source='client_direct',cancellation_request_id=null where id=v_booking.id returning * into v_booking;
  perform public.enqueue_user_notification(v_booking.lawyer_id,'ألغى العميل الحجز','ألغى طالب الاستشارة الحجز. السبب: '||trim(p_reason),'booking_cancelled_by_client',v_booking.id,'booking');
  perform public.enqueue_user_notification(v_booking.user_id,case when v_paid then 'تم إلغاء الحجز وبدء الاسترداد' else 'تم إلغاء الحجز' end,case when v_paid then 'تم إلغاء الحجز وتسجيل مبلغ الاستشارة للاسترداد. يمكنك متابعة التحويل من حساب الاستلام.' else 'تم إلغاء الحجز بنجاح.' end,'booking_cancelled',v_booking.id,'booking');
  return v_booking;
end $$;
revoke all on function public.request_client_booking_cancellation(uuid,text) from public,anon;
grant execute on function public.request_client_booking_cancellation(uuid,text) to authenticated;

create or replace function public.review_booking(p_booking_id uuid,p_approved boolean)
returns public.bookings language plpgsql security definer set search_path='public' as $$
declare v_profile uuid; v_booking public.bookings; v_paid boolean; begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  select id into v_profile from public.profiles where auth_id=auth.uid() limit 1;
  select * into v_booking from public.bookings where id=p_booking_id for update;
  if not found then raise exception 'الحجز غير موجود'; end if;
  if v_booking.lawyer_id<>v_profile then raise exception 'غير مصرح بهذا الإجراء'; end if;
  if v_booking.lawyer_approved then raise exception 'تمت مراجعة هذا الطلب مسبقاً'; end if;
  if v_booking.status not in ('قيد انتظار الدفع','قيد معالجة الدفع','قيد مراجعة المحامي') then raise exception 'لا يمكن مراجعة هذا الطلب في حالته الحالية'; end if;
  select exists(select 1 from public.payments where booking_id=v_booking.id and status='تم الدفع') into v_paid;
  if p_approved then
    update public.bookings set lawyer_approved=true,lawyer_approved_at=now(),status=case when not payment_required or v_paid then 'مؤكد' else v_booking.status end where id=p_booking_id returning * into v_booking;
  else
    update public.bookings set lawyer_approved=false,lawyer_approved_at=null,status=case when v_paid then 'بانتظار الاسترداد' else 'ملغي' end,cancelled_at=coalesce(cancelled_at,now()),cancellation_reason='رفض المحامي طلب الاستشارة',cancelled_by_profile_id=v_profile,cancellation_actor_role='lawyer',cancellation_source='lawyer_rejected_request',cancellation_request_id=null where id=p_booking_id returning * into v_booking;
  end if;
  return v_booking;
end $$;

create or replace function public.get_booking_cancellation_summary(p_booking_id uuid)
returns jsonb language plpgsql security definer set search_path='public' as $$
declare v_me uuid; v_b public.bookings%rowtype; v_req jsonb; v_credits jsonb; begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  select id into v_me from public.profiles where auth_id=auth.uid() limit 1;
  select * into v_b from public.bookings where id=p_booking_id;
  if not found or ((v_me<>v_b.user_id and v_me<>v_b.lawyer_id) and not public.is_admin()) then raise exception 'غير مصرح'; end if;
  select to_jsonb(x) into v_req from (select cr.id,cr.status,cr.reason,cr.decision,cr.penalty_rate,cr.penalty_amount,cr.currency,cr.requested_at,cr.reviewed_at from public.cancellation_requests cr where cr.booking_id=p_booking_id order by cr.requested_at desc limit 1) x;
  select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'amount',c.amount,'currency',c.currency,'transaction_type',c.transaction_type,'status',c.status,'created_at',c.created_at,'settled_at',c.settled_at) order by c.created_at),'[]'::jsonb) into v_credits from public.client_credits c where c.booking_id=p_booking_id and (v_me=v_b.user_id or public.is_admin());
  return jsonb_build_object('booking_status',v_b.status,'cancelled_at',v_b.cancelled_at,'cancelled_by_profile_id',v_b.cancelled_by_profile_id,'cancellation_actor_role',v_b.cancellation_actor_role,'cancellation_reason',v_b.cancellation_reason,'cancellation_source',v_b.cancellation_source,'cancellation_request',v_req,'credits',v_credits);
end $$;
revoke all on function public.get_booking_cancellation_summary(uuid) from public,anon;
grant execute on function public.get_booking_cancellation_summary(uuid) to authenticated;

-- Keep older clients safe: direct cancellation of a paid booking becomes refund-pending instead of silently cancelled.
create or replace function public.change_booking_status(p_booking_id uuid,p_new_status text)
returns public.bookings language plpgsql security definer set search_path='public' as $$
declare v_actor uuid:=auth.uid(); v_profile uuid; v_booking public.bookings; v_admin boolean:=public.is_admin(); v_paid boolean; v_payment_satisfied boolean; v_duration integer; v_now timestamptz:=now(); begin
  if v_actor is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if p_new_status not in ('مؤكد','قيد التنفيذ','مكتمل','ملغي','مسترد') then raise exception 'حالة الحجز غير صالحة'; end if;
  select id into v_profile from public.profiles where auth_id=v_actor limit 1;
  select * into v_booking from public.bookings where id=p_booking_id for update; if not found then raise exception 'الحجز غير موجود'; end if;
  select exists(select 1 from public.payments where booking_id=v_booking.id and status='تم الدفع') into v_paid; v_payment_satisfied:=(not v_booking.payment_required) or v_paid;
  if not v_admin and v_booking.user_id=v_profile and p_new_status='ملغي' and v_booking.status in ('قيد انتظار الدفع','قيد معالجة الدفع','قيد مراجعة المحامي','مؤكد') then
    update public.bookings set status=case when v_paid then 'بانتظار الاسترداد' else 'ملغي' end,cancelled_at=coalesce(cancelled_at,now()),cancellation_reason=coalesce(cancellation_reason,'إلغاء من طالب الاستشارة'),cancelled_by_profile_id=v_profile,cancellation_actor_role='client',cancellation_source='client_legacy' where id=p_booking_id returning * into v_booking; return v_booking;
  elsif v_admin then null;
  elsif v_booking.lawyer_id=v_profile and p_new_status='قيد التنفيذ' then
    if v_booking.status<>'مؤكد' or not v_payment_satisfied or not v_booking.lawyer_approved or v_booking.consultation_status<>'لم تبدأ' then raise exception 'لا يمكن بدء الاستشارة قبل تأكيد الحجز وموافقة المحامي والدفع عند استحقاقه'; end if;
    v_duration:=coalesce(v_booking.package_duration_minutes,30);
    if v_now<v_booking.scheduled_at-interval '5 minutes' then raise exception 'لم يحِن موعد الاستشارة بعد'; end if;
    if v_now>v_booking.scheduled_at+make_interval(mins=>v_duration) then raise exception 'انتهى وقت الاستشارة المحدد'; end if;
  elsif v_booking.lawyer_id=v_profile and p_new_status='مكتمل' then
    if v_booking.status<>'قيد التنفيذ' or v_booking.consultation_status<>'قيد التنفيذ' or v_booking.started_at is null then raise exception 'لا يمكن إنهاء الاستشارة في حالتها الحالية'; end if;
  else raise exception 'غير مصرح بهذا الإجراء'; end if;
  update public.bookings set status=p_new_status,consultation_status=case when p_new_status='قيد التنفيذ' then 'قيد التنفيذ' when p_new_status='مكتمل' then 'انتهت' when p_new_status='ملغي' and status='قيد التنفيذ' then 'أُلغيت' else consultation_status end,started_at=case when p_new_status='قيد التنفيذ' then coalesce(started_at,now()) else started_at end,completed_at=case when p_new_status='مكتمل' then now() else completed_at end,cancelled_at=case when p_new_status='ملغي' then coalesce(cancelled_at,now()) else cancelled_at end where id=p_booking_id returning * into v_booking; return v_booking;
end $$;

-- The full review_booking_cancellation body is intentionally kept in the live migration history; this repository migration is followed by the reconciliation migration below and preserves the hardened client/refund path for fresh deployments.