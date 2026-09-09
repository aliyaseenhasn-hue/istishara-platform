create or replace function public.sync_booking_from_payment()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_booking public.bookings%rowtype;
  v_verifier uuid;
  v_currency text:='IQD';
begin
  select * into v_booking from public.bookings where id=new.booking_id for update;
  if not found then raise exception 'الحجز غير موجود'; end if;
  if not v_booking.payment_required then raise exception 'لا يمكن إنشاء أو اعتماد دفعة لحجز مجاني تجريبي'; end if;
  select id into v_verifier from public.profiles where auth_id=auth.uid() limit 1;

  if new.status='تم الدفع' then
    update public.payments set verified_by=coalesce(v_verifier,verified_by),verified_at=coalesce(verified_at,now()) where id=new.id;
    if v_booking.status='بانتظار الاسترداد' then
      select coalesce(currency,'IQD') into v_currency from public.platform_financial_settings where id=true;
      insert into public.client_credits(user_id,booking_id,lawyer_id,amount,currency,transaction_type,status,reference_id)
      values(v_booking.user_id,v_booking.id,v_booking.lawyer_id,new.amount,v_currency,'استرداد قيمة استشارة','مستحق',new.id)
      on conflict (booking_id,transaction_type) where booking_id is not null do nothing;
      return new;
    end if;
    if v_booking.status not in ('قيد معالجة الدفع','قيد انتظار الدفع','قيد مراجعة المحامي') then raise exception 'لا يمكن اعتماد الدفع في حالة الحجز الحالية'; end if;
    update public.bookings set status=case when lawyer_approved then 'مؤكد' else 'قيد مراجعة المحامي' end where id=new.booking_id;
  elsif new.status='فشل الدفع' then
    update public.payments set verified_by=coalesce(v_verifier,verified_by),verified_at=coalesce(verified_at,now()) where id=new.id;
    if v_booking.status='بانتظار الاسترداد' and v_booking.cancellation_actor_role is not null then
      update public.bookings set status='ملغي' where id=new.booking_id;
    elsif v_booking.status in ('ملغي','مرفوض') then
      null;
    elsif v_booking.status in ('قيد معالجة الدفع','قيد انتظار الدفع') then
      update public.bookings set status='قيد انتظار الدفع' where id=new.booking_id;
    else
      raise exception 'لا يمكن رفض الدفع في حالة الحجز الحالية';
    end if;
  elsif new.status='تم استرداد المبلغ' then
    if v_booking.status<>'بانتظار الاسترداد' then raise exception 'يجب أن يكون الحجز بانتظار الاسترداد قبل تسجيل رد المبلغ'; end if;
    update public.payments set verified_by=coalesce(v_verifier,verified_by),verified_at=coalesce(verified_at,now()) where id=new.id;
    update public.bookings set status='مسترد' where id=new.booking_id;
  end if;
  return new;
end $$;

create or replace function public.sync_financial_payment_trigger()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare v_booking_status text;
begin
  if new.status='تم الدفع' and (tg_op='INSERT' or old.status is distinct from new.status) then
    select status into v_booking_status from public.bookings where id=new.booking_id;
    if v_booking_status<>'بانتظار الاسترداد' then perform public.ensure_financial_accounting_for_payment(new.id); end if;
  elsif new.status='تم استرداد المبلغ' and old.status is distinct from new.status then
    perform public.reverse_financial_accounting_for_refund(new.id);
  end if;
  return new;
end $$;

create or replace function public.notify_payment_events()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_user_id uuid; v_lawyer_id uuid; v_client_name text; v_lawyer_name text; v_type text;
  v_scheduled_at timestamptz; v_price numeric; v_booking_status text; v_admin record;
  v_date_text text; v_booking_id uuid:=coalesce(new.booking_id,old.booking_id);
begin
  select b.user_id,b.lawyer_id,b.price,b.consultation_type,b.scheduled_at,b.status,
         coalesce(nullif(trim(cp.full_name),''),'طالب الاستشارة'),
         coalesce(nullif(trim(lp.full_name),''),nullif(trim(lpp.full_name),''),'المحامي')
  into v_user_id,v_lawyer_id,v_price,v_type,v_scheduled_at,v_booking_status,v_client_name,v_lawyer_name
  from public.bookings b
  left join public.profiles cp on cp.id=b.user_id
  left join public.lawyer_profiles lp on lp.profile_id=b.lawyer_id
  left join public.profiles lpp on lpp.id=b.lawyer_id
  where b.id=v_booking_id;
  v_date_text:=case when v_scheduled_at is null then 'غير محدد' else to_char(v_scheduled_at at time zone 'Asia/Baghdad','YYYY/MM/DD HH24:MI') end;
  if tg_op='INSERT' or new.status is distinct from old.status then
    if new.status='قيد معالجة الدفع' and coalesce(new.is_manual,false) then
      perform public.enqueue_user_notification(v_user_id,'تم إرسال إثبات الدفع','تم إرسال إيصال بقيمة '||coalesce(to_char(v_price,'FM999G999G999G990'),'0')||' د.ع لاستشارة '||coalesce(v_type,'قانونية')||' مع '||v_lawyer_name||' بتاريخ '||v_date_text||'. بانتظار تحقق الإدارة.','manual_payment_submitted',v_booking_id,'booking');
      perform public.enqueue_user_notification(v_lawyer_id,'أرسل العميل إثبات الدفع',v_client_name||' أرسل إثبات دفع بقيمة '||coalesce(to_char(v_price,'FM999G999G999G990'),'0')||' د.ع لاستشارة '||coalesce(v_type,'قانونية')||' بتاريخ '||v_date_text||'. بانتظار تحقق الإدارة.','manual_payment_submitted',v_booking_id,'booking');
      for v_admin in select id from public.profiles where role::text='admin' loop
        perform public.enqueue_user_notification(v_admin.id,'دفعة تحتاج مراجعة',v_client_name||' رفع إيصالاً بقيمة '||coalesce(to_char(v_price,'FM999G999G999G990'),'0')||' د.ع لحجز مع '||v_lawyer_name||' ('||coalesce(v_type,'استشارة قانونية')||') بتاريخ '||v_date_text||'.','manual_payment_admin_review',v_booking_id,'booking');
      end loop;
    elsif new.status='تم الدفع' and v_booking_status='بانتظار الاسترداد' then
      perform public.enqueue_user_notification(v_user_id,'تم إثبات وصول المبلغ وسيتم استرداده','تحققت الإدارة من وصول مبلغ '||coalesce(to_char(new.amount,'FM999G999G999G990'),'0')||' د.ع للحجز الذي تم إلغاؤه. تم تسجيل المبلغ كاملاً للاسترداد إلى حساب الاستلام.','payment_received_for_refund',v_booking_id,'booking');
      perform public.enqueue_user_notification(v_lawyer_id,'تم إثبات دفع الحجز الملغي','تحققت الإدارة من وصول دفعة الحجز الملغي. سيعاد كامل المبلغ للعميل ولا تُسجل لك مستحقات عن هذه الدفعة.','payment_received_for_refund',v_booking_id,'booking');
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

create or replace function public.request_client_booking_cancellation(p_booking_id uuid,p_reason text)
returns public.bookings
language plpgsql
security definer
set search_path=public
as $$
declare
  v_profile uuid; v_booking public.bookings%rowtype; v_paid boolean; v_pending_manual boolean; v_new_status text;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if nullif(trim(coalesce(p_reason,'')),'') is null then raise exception 'سبب الإلغاء إلزامي'; end if;
  select id into v_profile from public.profiles where auth_id=auth.uid() limit 1;
  select * into v_booking from public.bookings where id=p_booking_id for update;
  if not found then raise exception 'الحجز غير موجود'; end if;
  if v_booking.user_id<>v_profile then raise exception 'غير مصرح بهذا الإجراء'; end if;
  if v_booking.status not in ('قيد انتظار الدفع','قيد معالجة الدفع','قيد مراجعة المحامي','بانتظار التأكيد','مؤكد') then raise exception 'لا يمكن إلغاء الحجز في حالته الحالية'; end if;
  if v_booking.scheduled_at is not null and v_booking.scheduled_at<=now() then raise exception 'لا يمكن إلغاء موعد بدأ أو انتهى'; end if;
  select exists(select 1 from public.payments p where p.booking_id=v_booking.id and p.status='تم الدفع') into v_paid;
  select exists(select 1 from public.payments p where p.booking_id=v_booking.id and p.status='قيد معالجة الدفع' and coalesce(p.is_manual,false) and nullif(trim(coalesce(p.receipt_url,'')),'') is not null) into v_pending_manual;
  v_new_status:=case when v_paid or v_pending_manual then 'بانتظار الاسترداد' else 'ملغي' end;
  update public.bookings set status=v_new_status,cancelled_at=coalesce(cancelled_at,now()),cancellation_reason=trim(p_reason),cancelled_by_profile_id=v_profile,cancellation_actor_role='client',cancellation_source='client_direct',cancellation_request_id=null where id=v_booking.id returning * into v_booking;
  perform public.enqueue_user_notification(v_booking.lawyer_id,'ألغى العميل الحجز','ألغى طالب الاستشارة الحجز. السبب: '||trim(p_reason),'booking_cancelled_by_client',v_booking.id,'booking');
  perform public.enqueue_user_notification(v_booking.user_id,case when v_paid then 'تم إلغاء الحجز وبدء الاسترداد' when v_pending_manual then 'تم إلغاء الحجز والإيصال بانتظار المطابقة' else 'تم إلغاء الحجز' end,case when v_paid then 'تم إلغاء الحجز وتسجيل مبلغ الاستشارة للاسترداد.' when v_pending_manual then 'تم تحرير الموعد، وسيبقى إيصال الدفع لدى الإدارة للتحقق. إذا ثبت وصول المبلغ فسيُعاد إليك كاملاً.' else 'تم إلغاء الحجز بنجاح.' end,'booking_cancelled',v_booking.id,'booking');
  return v_booking;
end $$;

create or replace function public.change_booking_status(p_booking_id uuid,p_new_status text)
returns public.bookings
language plpgsql
security definer
set search_path=public
as $$
declare
  v_actor uuid:=auth.uid(); v_profile_id uuid; v_booking public.bookings; v_is_admin boolean:=public.is_admin();
  v_is_paid boolean; v_pending_manual boolean; v_payment_satisfied boolean; v_duration integer; v_now timestamptz:=now(); v_target_status text;
begin
  if v_actor is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if p_new_status not in ('مؤكد','قيد التنفيذ','مكتمل','ملغي','مسترد') then raise exception 'حالة الحجز غير صالحة'; end if;
  select id into v_profile_id from public.profiles where auth_id=v_actor limit 1;
  select * into v_booking from public.bookings where id=p_booking_id for update;
  if not found then raise exception 'الحجز غير موجود'; end if;
  select exists(select 1 from public.payments where booking_id=v_booking.id and status='تم الدفع') into v_is_paid;
  select exists(select 1 from public.payments where booking_id=v_booking.id and status='قيد معالجة الدفع' and coalesce(is_manual,false) and nullif(trim(coalesce(receipt_url,'')),'') is not null) into v_pending_manual;
  v_payment_satisfied:=(not v_booking.payment_required) or v_is_paid;
  if p_new_status='مسترد' then raise exception 'لا يمكن تسجيل الاسترداد يدوياً؛ يجب إكمال تحويل الاسترداد من الإدارة المالية'; end if;
  if p_new_status='ملغي' then
    if v_booking.status not in ('قيد انتظار الدفع','قيد معالجة الدفع','قيد مراجعة المحامي','بانتظار التأكيد','مؤكد') then raise exception 'لا يمكن إلغاء الحجز في حالته الحالية'; end if;
    if not v_is_admin and v_booking.user_id<>v_profile_id then raise exception 'غير مصرح بهذا الإجراء'; end if;
    v_target_status:=case when v_is_paid or v_pending_manual then 'بانتظار الاسترداد' else 'ملغي' end;
    update public.bookings set status=v_target_status,cancelled_at=coalesce(cancelled_at,now()),cancellation_reason=coalesce(nullif(cancellation_reason,''),case when v_is_admin then 'إلغاء إداري' else 'إلغاء بواسطة طالب الاستشارة' end),cancelled_by_profile_id=coalesce(cancelled_by_profile_id,v_profile_id),cancellation_actor_role=coalesce(cancellation_actor_role,case when v_is_admin then 'admin' else 'client' end),cancellation_source=coalesce(cancellation_source,case when v_is_admin then 'admin_status_change' else 'legacy_client_status_change' end) where id=p_booking_id returning * into v_booking;
    return v_booking;
  end if;
  if v_is_admin then null;
  elsif v_booking.lawyer_id=v_profile_id and p_new_status='قيد التنفيذ' then
    if v_booking.status<>'مؤكد' or not v_payment_satisfied or not v_booking.lawyer_approved or v_booking.consultation_status<>'لم تبدأ' then raise exception 'لا يمكن بدء الاستشارة قبل تأكيد الحجز وموافقة المحامي والدفع عند استحقاقه'; end if;
    v_duration:=coalesce(v_booking.package_duration_minutes,30);
    if v_now<v_booking.scheduled_at-interval '5 minutes' then raise exception 'لم يحِن موعد الاستشارة بعد'; end if;
    if v_now>v_booking.scheduled_at+make_interval(mins=>v_duration) then raise exception 'انتهى وقت الاستشارة المحدد'; end if;
  elsif v_booking.lawyer_id=v_profile_id and p_new_status='مكتمل' then
    if v_booking.status<>'قيد التنفيذ' or v_booking.consultation_status<>'قيد التنفيذ' or v_booking.started_at is null then raise exception 'لا يمكن إنهاء الاستشارة في حالتها الحالية'; end if;
  else raise exception 'غير مصرح بهذا الإجراء'; end if;
  update public.bookings set status=p_new_status,consultation_status=case when p_new_status='قيد التنفيذ' then 'قيد التنفيذ' when p_new_status='مكتمل' then 'انتهت' else consultation_status end,started_at=case when p_new_status='قيد التنفيذ' then coalesce(started_at,now()) else started_at end,completed_at=case when p_new_status='مكتمل' then now() else completed_at end where id=p_booking_id returning * into v_booking;
  return v_booking;
end $$;

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
  if v_booking.status in ('ملغي','مسترد','بانتظار الاسترداد') then update public.cancellation_requests set status='تمت الموافقة',reviewed_at=now(),reviewed_by=v_admin,decision='الموافقة بدون غرامة',penalty_rate=coalesce(penalty_rate,0),penalty_amount=coalesce(penalty_amount,0) where id=v_request.id returning * into v_request; return v_request; end if;
  if v_booking.status in ('مكتمل','قيد التنفيذ') then update public.cancellation_requests set status='تم رفض الطلب',reviewed_at=now(),reviewed_by=v_admin,decision='رفض الإلغاء' where id=v_request.id returning * into v_request; return v_request; end if;
  if p_decision='رفض الإلغاء' then update public.cancellation_requests set status='تم رفض الطلب',reviewed_at=now(),reviewed_by=v_admin,decision=p_decision where id=v_request.id returning * into v_request; perform public.enqueue_user_notification(v_request.lawyer_id,'تم رفض طلب إلغاء الحجز','تم رفض طلب الإلغاء من الإدارة ويبقى الحجز فعالاً.','cancellation_request_rejected',v_request.id,'cancellation_request'); return v_request; end if;
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
