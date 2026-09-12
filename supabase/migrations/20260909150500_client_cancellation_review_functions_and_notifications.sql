create or replace function public.review_booking_cancellation(p_request_id uuid,p_decision text,p_penalty_rate numeric default null)
returns public.cancellation_requests
language plpgsql
security definer
set search_path=public
as $$
declare
  v_admin uuid; v_request public.cancellation_requests; v_booking public.bookings%rowtype;
  v_amount numeric(18,2); v_penalty_id uuid; v_paid boolean; v_pending_manual boolean; v_target text;
begin
  if auth.uid() is null or not public.is_admin() then raise exception 'غير مصرح: هذه العملية للإدارة فقط'; end if;
  select id into v_admin from public.profiles where auth_id=auth.uid() limit 1;
  select * into v_request from public.cancellation_requests where id=p_request_id for update;
  if not found then raise exception 'طلب الإلغاء غير موجود'; end if;
  if v_request.status<>'بانتظار مراجعة الإدارة' then return v_request; end if;
  select * into v_booking from public.bookings where id=v_request.booking_id for update;
  if not found then raise exception 'الحجز غير موجود'; end if;

  if v_request.requester_role='client' then
    if p_decision='رفض الإلغاء' then
      raise exception 'إلغاء العميل نهائي بعد تحرير الموعد؛ قرار الإدارة هنا يحدد فقط وجود غرامة 1%% أو عدمها';
    end if;
    if p_decision not in ('الموافقة بدون غرامة','الموافقة مع غرامة') then raise exception 'نوع القرار غير صالح'; end if;

    select exists(select 1 from public.payments where booking_id=v_booking.id and status='تم الدفع') into v_paid;
    select exists(select 1 from public.payments where booking_id=v_booking.id and status='قيد معالجة الدفع' and coalesce(is_manual,false) and nullif(trim(coalesce(receipt_url,'')),'') is not null) into v_pending_manual;

    if p_decision='الموافقة مع غرامة' and not (v_paid or v_pending_manual) then
      raise exception 'لا توجد دفعة أو إيصال قيد المراجعة يمكن استقطاع غرامة 1%% منه';
    end if;

    update public.cancellation_requests
    set reviewed_at=now(),reviewed_by=v_admin,decision=p_decision,
        penalty_rate=case when p_decision='الموافقة مع غرامة' then 1 else 0 end,
        status=case when p_decision='الموافقة مع غرامة' then 'تمت الموافقة مع غرامة' else 'تمت الموافقة' end
    where id=v_request.id returning * into v_request;

    perform public.finalize_client_cancellation_financials(v_booking.id);
    select * into v_request from public.cancellation_requests where id=p_request_id;

    if p_decision='الموافقة مع غرامة' then
      perform public.enqueue_user_notification(v_request.client_id,'تم اعتماد الإلغاء مع غرامة 1%',case when v_paid then 'اعتبرت الإدارة سبب الإلغاء غير مقنع. سيتم استرداد 99% من المبلغ المدفوع، وتحويل 1% إلى المحامي.' else 'اعتبرت الإدارة سبب الإلغاء غير مقنع. عند إثبات وصول الدفعة سيُسترد 99% ويُحوّل 1% إلى المحامي.' end,'client_cancellation_reviewed',v_booking.id,'booking');
      perform public.enqueue_user_notification(v_request.lawyer_id,'تم اعتماد تعويض 1% لصالحك',case when v_paid then 'اعتمدت الإدارة غرامة 1% على إلغاء العميل، وتم تسجيلها ضمن مستحقاتك.' else 'اعتمدت الإدارة غرامة 1% على إلغاء العميل، وستسجل ضمن مستحقاتك بعد إثبات وصول الدفعة.' end,'client_cancellation_compensation',v_booking.id,'booking');
    else
      perform public.enqueue_user_notification(v_request.client_id,'تم اعتماد الإلغاء بدون غرامة',case when v_paid then 'اعتبرت الإدارة سبب الإلغاء مقنعاً. تم اعتماد استرداد كامل المبلغ المدفوع.' else 'اعتبرت الإدارة سبب الإلغاء مقنعاً، ولا توجد غرامة على الإلغاء.' end,'client_cancellation_reviewed',v_booking.id,'booking');
      perform public.enqueue_user_notification(v_request.lawyer_id,'تمت مراجعة إلغاء العميل','اعتمدت الإدارة إلغاء العميل بدون غرامة.','client_cancellation_reviewed',v_booking.id,'booking');
    end if;
    return v_request;
  end if;

  if v_booking.status in ('ملغي','مسترد','بانتظار الاسترداد') then
    update public.cancellation_requests set status='تمت الموافقة',reviewed_at=now(),reviewed_by=v_admin,decision='الموافقة بدون غرامة',penalty_rate=coalesce(penalty_rate,0),penalty_amount=coalesce(penalty_amount,0) where id=v_request.id returning * into v_request; return v_request;
  end if;
  if v_booking.status in ('مكتمل','قيد التنفيذ') then
    update public.cancellation_requests set status='تم رفض الطلب',reviewed_at=now(),reviewed_by=v_admin,decision='رفض الإلغاء' where id=v_request.id returning * into v_request; return v_request;
  end if;
  if p_decision='رفض الإلغاء' then
    update public.cancellation_requests set status='تم رفض الطلب',reviewed_at=now(),reviewed_by=v_admin,decision=p_decision where id=v_request.id returning * into v_request;
    perform public.enqueue_user_notification(v_request.lawyer_id,'تم رفض طلب إلغاء الحجز','تم رفض طلب الإلغاء من الإدارة ويبقى الحجز فعالاً.','cancellation_request_rejected',v_request.id,'cancellation_request'); return v_request;
  end if;
  select exists(select 1 from public.payments where booking_id=v_booking.id and status='تم الدفع') into v_paid;
  select exists(select 1 from public.payments where booking_id=v_booking.id and status='قيد معالجة الدفع' and coalesce(is_manual,false) and nullif(trim(coalesce(receipt_url,'')),'') is not null) into v_pending_manual;
  v_target:=case when v_paid or v_pending_manual then 'بانتظار الاسترداد' else 'ملغي' end;
  if p_decision='الموافقة بدون غرامة' then
    update public.bookings set status=v_target,cancelled_at=coalesce(cancelled_at,now()),cancellation_reason=v_request.reason,cancelled_by_profile_id=v_request.lawyer_id,cancellation_actor_role='lawyer',cancellation_source='lawyer_cancellation_request',cancellation_request_id=v_request.id where id=v_booking.id;
    update public.cancellation_requests set status='تمت الموافقة',reviewed_at=now(),reviewed_by=v_admin,decision=p_decision,penalty_rate=0,penalty_amount=0 where id=v_request.id returning * into v_request;
    perform public.enqueue_user_notification(v_request.lawyer_id,'تمت الموافقة على إلغاء الحجز','وافقت الإدارة على طلب الإلغاء بدون غرامة.','cancellation_request_approved',v_request.id,'cancellation_request');
    perform public.enqueue_user_notification(v_request.client_id,case when v_paid then 'تم إلغاء الحجز وبدء الاسترداد' when v_pending_manual then 'تم إلغاء الحجز والإيصال بانتظار المطابقة' else 'تم إلغاء الحجز' end,case when v_paid then 'تم اعتماد إلغاء المحامي وتم تسجيل كامل مبلغ الاستشارة للاسترداد.' when v_pending_manual then 'تم اعتماد الإلغاء وسيبقى إيصال الدفع لدى الإدارة للتحقق؛ إذا ثبت وصول المبلغ فسيُعاد كاملاً.' else 'تم اعتماد إلغاء الحجز من الإدارة.' end,'booking_cancelled_by_lawyer',v_booking.id,'booking'); return v_request;
  end if;
  if p_decision<>'الموافقة مع غرامة' then raise exception 'نوع القرار غير صالح'; end if;
  if p_penalty_rate is null or p_penalty_rate<=0 or p_penalty_rate>100 then raise exception 'نسبة الغرامة يجب أن تكون أكبر من صفر ولا تتجاوز 100%%'; end if;
  v_amount:=round(coalesce(v_booking.price,0)::numeric*p_penalty_rate/100,2);
  if v_amount<=0 then raise exception 'قيمة الغرامة المحسوبة غير صالحة'; end if;
  update public.bookings set status=v_target,cancelled_at=coalesce(cancelled_at,now()),cancellation_reason=v_request.reason,cancelled_by_profile_id=v_request.lawyer_id,cancellation_actor_role='lawyer',cancellation_source='lawyer_cancellation_request',cancellation_request_id=v_request.id where id=v_booking.id;
  update public.cancellation_requests set status='بانتظار تحصيل الغرامة',reviewed_at=now(),reviewed_by=v_admin,decision=p_decision,penalty_rate=p_penalty_rate,penalty_amount=v_amount where id=v_request.id returning * into v_request;
  insert into public.lawyer_penalties(cancellation_request_id,booking_id,lawyer_id,client_id,amount,remaining_amount,currency) values(v_request.id,v_request.booking_id,v_request.lawyer_id,v_request.client_id,v_amount,v_amount,v_request.currency) returning id into v_penalty_id;
  insert into public.client_credits(user_id,booking_id,lawyer_id,amount,currency,transaction_type,status,reference_id) values(v_request.client_id,v_request.booking_id,v_request.lawyer_id,v_amount,v_request.currency,'تعويض إلغاء حجز من المحامي','بانتظار تحصيل الغرامة',v_penalty_id) on conflict (booking_id,transaction_type) where booking_id is not null do nothing;
  perform public.enqueue_user_notification(v_request.lawyer_id,'تم اعتماد الإلغاء مع غرامة','تم إلغاء الحجز وتسجيل غرامة مالية عليك.','lawyer_penalty_created',v_penalty_id,'lawyer_penalty');
  perform public.enqueue_user_notification(v_request.client_id,'تم اعتماد الإلغاء والتعويض',case when v_paid then 'سيُعاد كامل مبلغ الاستشارة إليك، إضافة إلى تعويض بقيمة '||to_char(v_amount,'FM999G999G999G990D00')||' '||v_request.currency||' بعد تحصيل الغرامة.' when v_pending_manual then 'تم اعتماد التعويض، كما سيُراجع إيصال الدفع؛ إذا ثبت وصول المبلغ فسيُعاد كاملاً إضافة إلى التعويض.' else 'تم اعتماد تعويض لك بقيمة '||to_char(v_amount,'FM999G999G999G990D00')||' '||v_request.currency||' بعد تحصيل الغرامة.' end,'client_credit_pending',v_penalty_id,'client_credit'); return v_request;
exception when unique_violation then raise exception 'تم تنفيذ هذا القرار مسبقاً';
end $$;

create or replace function public.admin_review_manual_payment(p_payment_id uuid,p_approved boolean,p_note text default null)
returns public.payments
language plpgsql
security definer
set search_path=public
as $$
declare v_payment public.payments;
begin
  if auth.uid() is null or not public.is_admin() then raise exception 'غير مصرح: هذه العملية للإدارة فقط'; end if;
  select * into v_payment from public.payments where id=p_payment_id for update;
  if not found then raise exception 'عملية الدفع غير موجودة'; end if;
  if v_payment.status<>'قيد معالجة الدفع' or not coalesce(v_payment.is_manual,false) then raise exception 'هذه الدفعة ليست بانتظار مراجعة يدوية'; end if;
  if nullif(trim(coalesce(v_payment.receipt_url,'')),'') is null then raise exception 'لا يوجد إيصال دفع مرفوع'; end if;
  update public.payments set status=case when p_approved then 'تم الدفع' else 'فشل الدفع' end,admin_review_note=nullif(trim(coalesce(p_note,'')),'') where id=p_payment_id returning * into v_payment;
  if p_approved then perform public.finalize_client_cancellation_financials(v_payment.booking_id); end if;
  return v_payment;
end $$;
revoke all on function public.admin_review_manual_payment(uuid,boolean,text) from public,anon;
grant execute on function public.admin_review_manual_payment(uuid,boolean,text) to authenticated;

create or replace function public.notify_payment_events()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_user_id uuid; v_lawyer_id uuid; v_client_name text; v_lawyer_name text; v_type text;
  v_scheduled_at timestamptz; v_price numeric; v_booking_status text; v_admin record; v_date_text text;
  v_booking_id uuid:=coalesce(new.booking_id,old.booking_id); v_client_cancel_decision text; v_client_cancel_status text;
begin
  select b.user_id,b.lawyer_id,b.price,b.consultation_type,b.scheduled_at,b.status,coalesce(nullif(trim(cp.full_name),''),'طالب الاستشارة'),coalesce(nullif(trim(lp.full_name),''),nullif(trim(lpp.full_name),''),'المحامي')
  into v_user_id,v_lawyer_id,v_price,v_type,v_scheduled_at,v_booking_status,v_client_name,v_lawyer_name
  from public.bookings b left join public.profiles cp on cp.id=b.user_id left join public.lawyer_profiles lp on lp.profile_id=b.lawyer_id left join public.profiles lpp on lpp.id=b.lawyer_id where b.id=v_booking_id;
  select cr.decision,cr.status into v_client_cancel_decision,v_client_cancel_status from public.cancellation_requests cr where cr.booking_id=v_booking_id and cr.requester_role='client' order by cr.requested_at desc limit 1;
  v_date_text:=case when v_scheduled_at is null then 'غير محدد' else to_char(v_scheduled_at at time zone 'Asia/Baghdad','YYYY/MM/DD HH24:MI') end;
  if tg_op='INSERT' or new.status is distinct from old.status then
    if new.status='قيد معالجة الدفع' and coalesce(new.is_manual,false) then
      perform public.enqueue_user_notification(v_user_id,'تم إرسال إثبات الدفع','تم إرسال إيصال بقيمة '||coalesce(to_char(v_price,'FM999G999G999G990'),'0')||' د.ع لاستشارة '||coalesce(v_type,'قانونية')||' مع '||v_lawyer_name||' بتاريخ '||v_date_text||'. بانتظار تحقق الإدارة.','manual_payment_submitted',v_booking_id,'booking');
      perform public.enqueue_user_notification(v_lawyer_id,'أرسل العميل إثبات الدفع',v_client_name||' أرسل إثبات دفع بقيمة '||coalesce(to_char(v_price,'FM999G999G999G990'),'0')||' د.ع لاستشارة '||coalesce(v_type,'قانونية')||' بتاريخ '||v_date_text||'. بانتظار تحقق الإدارة.','manual_payment_submitted',v_booking_id,'booking');
      for v_admin in select id from public.profiles where role::text='admin' loop perform public.enqueue_user_notification(v_admin.id,'دفعة تحتاج مراجعة',v_client_name||' رفع إيصالاً بقيمة '||coalesce(to_char(v_price,'FM999G999G999G990'),'0')||' د.ع لحجز مع '||v_lawyer_name||' ('||coalesce(v_type,'استشارة قانونية')||') بتاريخ '||v_date_text||'.','manual_payment_admin_review',v_booking_id,'booking'); end loop;
    elsif new.status='تم الدفع' and v_booking_status='بانتظار الاسترداد' then
      if v_client_cancel_status='بانتظار مراجعة الإدارة' then
        perform public.enqueue_user_notification(v_user_id,'تم إثبات وصول المبلغ','تحققت الإدارة من وصول مبلغ '||coalesce(to_char(new.amount,'FM999G999G999G990'),'0')||' د.ع للحجز الملغي. مبلغ الاسترداد النهائي لم يُحدد بعد وسيعتمد على قرار الإدارة بشأن سبب الإلغاء.','payment_received_cancellation_pending_review',v_booking_id,'booking');
        perform public.enqueue_user_notification(v_lawyer_id,'تم إثبات دفع الحجز الملغي','تحققت الإدارة من وصول دفعة الحجز الملغي، وما زال قرار الغرامة أو الإعفاء قيد مراجعة الإدارة.','payment_received_cancellation_pending_review',v_booking_id,'booking');
      elsif v_client_cancel_decision='الموافقة مع غرامة' then
        perform public.enqueue_user_notification(v_user_id,'تم إثبات وصول المبلغ','تحققت الإدارة من وصول الدفعة. سيتم استرداد 99% من المبلغ وتحويل 1% للمحامي وفق قرار الإدارة.','payment_received_for_refund',v_booking_id,'booking');
        perform public.enqueue_user_notification(v_lawyer_id,'تم إثبات دفع الحجز الملغي','تحققت الإدارة من وصول الدفعة، وسيتم تسجيل تعويض 1% لصالحك وفق قرار الإدارة.','payment_received_for_refund',v_booking_id,'booking');
      else
        perform public.enqueue_user_notification(v_user_id,'تم إثبات وصول المبلغ وسيتم استرداده','تحققت الإدارة من وصول مبلغ '||coalesce(to_char(new.amount,'FM999G999G999G990'),'0')||' د.ع للحجز الملغي. تم اعتماد الاسترداد الكامل بدون غرامة.','payment_received_for_refund',v_booking_id,'booking');
        perform public.enqueue_user_notification(v_lawyer_id,'تم إثبات دفع الحجز الملغي','تحققت الإدارة من وصول دفعة الحجز الملغي، وتم اعتماد الاسترداد الكامل للعميل بدون غرامة.','payment_received_for_refund',v_booking_id,'booking');
      end if;
    elsif new.status='تم الدفع' then
      perform public.enqueue_user_notification(v_user_id,'تم تأكيد الدفع','تحققت الإدارة من دفع مبلغ '||coalesce(to_char(v_price,'FM999G999G999G990'),'0')||' د.ع لاستشارتك مع '||v_lawyer_name||'.','payment_confirmed',v_booking_id,'booking');
      perform public.enqueue_user_notification(v_lawyer_id,'تم تأكيد دفع الاستشارة','تحققت الإدارة من دفع '||v_client_name||' مبلغ '||coalesce(to_char(v_price,'FM999G999G999G990'),'0')||' د.ع للاستشارة بتاريخ '||v_date_text||'.','payment_confirmed',v_booking_id,'booking');
    elsif new.status='فشل الدفع' and v_booking_status='ملغي' then
      perform public.enqueue_user_notification(v_user_id,'أُغلق إثبات الدفع للحجز الملغي','راجعت الإدارة الإثبات ولم يتم تأكيد وصول مبلغ يحتاج إلى استرداد. بقي الحجز ملغياً.','payment_rejected_after_cancellation',v_booking_id,'booking');
    elsif new.status='فشل الدفع' then
      perform public.enqueue_user_notification(v_user_id,'تم رفض إثبات الدفع','تعذر اعتماد إثبات دفع استشارتك مع '||v_lawyer_name||'. راجع بيانات التحويل وأعد المحاولة.','payment_rejected',v_booking_id,'booking');
    elsif new.status='تم استرداد المبلغ' then
      perform public.enqueue_user_notification(v_user_id,'تم استرداد المبلغ','تم تسجيل استرداد مبلغ الاستشارة.','payment_refunded',v_booking_id,'booking');
    end if;
  end if;
  return new;
end $$;

update public.notifications n
set title='طلب الإلغاء قيد مراجعة الإدارة',body='لم يتم اعتماد مبلغ الاسترداد النهائي بعد. ستقرر الإدارة ما إذا كان الاسترداد 100% أو 99% مع غرامة 1% للمحامي.'
where n.reference_type='booking'
  and n.reference_id in (
    select b.id from public.bookings b join public.cancellation_requests cr on cr.id=b.cancellation_request_id
    where b.cancellation_source='client_cancellation_request' and cr.requester_role='client' and cr.status='بانتظار مراجعة الإدارة'
  )
  and n.type in ('client_refund_pending','client_refund_account_required','booking_cancelled');
