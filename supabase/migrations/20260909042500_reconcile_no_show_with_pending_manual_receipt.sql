create or replace function public.admin_review_no_show_request(p_request_id uuid,p_decision text,p_note text default null)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare
  v_admin uuid;
  v_request public.no_show_review_requests%rowtype;
  v_booking public.bookings%rowtype;
  v_is_paid boolean;
  v_pending_manual boolean;
  v_restore_status text;
  v_restore_consultation text;
begin
  select id into v_admin from public.profiles where auth_id=auth.uid() and role='admin' limit 1;
  if v_admin is null then raise exception 'غير مصرح'; end if;
  if p_decision not in ('approved','rejected') then raise exception 'قرار غير صالح'; end if;

  select * into v_request from public.no_show_review_requests where id=p_request_id for update;
  if not found then raise exception 'الطلب غير موجود'; end if;
  if v_request.status<>'pending' then raise exception 'تمت مراجعة الطلب مسبقاً'; end if;
  select * into v_booking from public.bookings where id=v_request.booking_id for update;
  if not found then raise exception 'الحجز المرتبط بالطلب غير موجود'; end if;
  if v_booking.status<>'بانتظار مراجعة عدم الحضور' then raise exception 'الحجز لم يعد بانتظار مراجعة عدم الحضور'; end if;

  update public.no_show_review_requests
  set status=p_decision,reviewed_by=v_admin,review_note=nullif(trim(coalesce(p_note,'')),''),reviewed_at=now()
  where id=p_request_id;

  if p_decision='rejected' then
    v_restore_status:=coalesce(nullif(v_request.previous_booking_status,''),'مؤكد');
    v_restore_consultation:=coalesce(nullif(v_request.previous_consultation_status,''),case when v_restore_status='قيد التنفيذ' then 'قيد التنفيذ' else 'لم تبدأ' end);
    update public.bookings set status=v_restore_status,consultation_status=v_restore_consultation where id=v_booking.id;
    perform public.enqueue_user_notification(v_request.reporter_id,'تم رفض بلاغ عدم الحضور','راجعت الإدارة البلاغ وتم رفضه، وأُعيدت الاستشارة إلى حالتها السابقة.','no_show_rejected',v_booking.id,'booking');
    return;
  end if;

  select exists(select 1 from public.payments where booking_id=v_booking.id and status='تم الدفع') into v_is_paid;
  select exists(select 1 from public.payments where booking_id=v_booking.id and status='قيد معالجة الدفع' and coalesce(is_manual,false) and nullif(trim(coalesce(receipt_url,'')),'') is not null) into v_pending_manual;

  if v_request.reason='عدم حضور طالب الاستشارة' then
    if v_booking.payment_required and not v_is_paid then
      raise exception 'لا يمكن اعتماد عدم حضور طالب الاستشارة قبل حسم إثبات الدفع';
    end if;
    update public.bookings
    set status='مكتمل',consultation_status='عدم حضور طالب الاستشارة - تمت الموافقة',completed_at=now()
    where id=v_booking.id;
    perform public.enqueue_user_notification(v_booking.lawyer_id,'تم اعتماد بلاغ عدم الحضور','تم اعتماد عدم حضور طالب الاستشارة وإنهاء الحجز وفق القرار الإداري.','no_show_approved',v_booking.id,'booking');
    perform public.enqueue_user_notification(v_booking.user_id,'تم اعتماد بلاغ عدم الحضور','اعتمدت الإدارة بلاغ عدم الحضور الخاص بهذه الاستشارة.','no_show_approved',v_booking.id,'booking');
  elsif v_request.reason='عدم حضور المحامي' then
    update public.bookings
    set status=case when v_is_paid or v_pending_manual then 'بانتظار الاسترداد' else 'ملغي' end,
        consultation_status='عدم حضور المحامي - تمت الموافقة',
        cancelled_at=now(),
        cancellation_reason='عدم حضور المحامي',
        cancelled_by_profile_id=v_booking.lawyer_id,
        cancellation_actor_role='lawyer',
        cancellation_source='no_show'
    where id=v_booking.id;
    perform public.enqueue_user_notification(
      v_booking.user_id,
      'تم اعتماد عدم حضور المحامي',
      case when v_is_paid then 'تم اعتماد البلاغ وإنشاء طلب استرداد كامل لقيمة الاستشارة.'
           when v_pending_manual then 'تم اعتماد البلاغ وتحرير الموعد. سيُراجع إيصال الدفع، وإذا ثبت وصول المبلغ فسيُعاد إليك كاملاً.'
           else 'تم اعتماد البلاغ وإلغاء الاستشارة.' end,
      'no_show_approved',v_booking.id,'booking'
    );
    perform public.enqueue_user_notification(v_booking.lawyer_id,'تم اعتماد بلاغ عدم الحضور','اعتمدت الإدارة بلاغ عدم الحضور المقدم ضدك لهذه الاستشارة.','no_show_approved',v_booking.id,'booking');
  else
    raise exception 'نوع بلاغ عدم الحضور غير معروف';
  end if;
end $$;
