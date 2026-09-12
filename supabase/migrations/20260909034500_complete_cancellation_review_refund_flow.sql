create or replace function public.review_booking_cancellation(p_request_id uuid,p_decision text,p_penalty_rate numeric default null)
returns public.cancellation_requests
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_admin uuid;
  v_request public.cancellation_requests;
  v_booking public.bookings%rowtype;
  v_amount numeric(18,2);
  v_penalty_id uuid;
  v_paid boolean;
  v_target text;
begin
  if auth.uid() is null or not public.is_admin() then raise exception 'غير مصرح: هذه العملية للإدارة فقط'; end if;
  select id into v_admin from public.profiles where auth_id=auth.uid() limit 1;
  select * into v_request from public.cancellation_requests where id=p_request_id for update;
  if not found then raise exception 'طلب الإلغاء غير موجود'; end if;
  if v_request.status<>'بانتظار مراجعة الإدارة' then return v_request; end if;
  select * into v_booking from public.bookings where id=v_request.booking_id for update;
  if not found then raise exception 'الحجز غير موجود'; end if;

  if v_booking.status in ('ملغي','مسترد','بانتظار الاسترداد') then
    update public.cancellation_requests
    set status='تمت الموافقة',reviewed_at=now(),reviewed_by=v_admin,
        decision='الموافقة بدون غرامة',penalty_rate=coalesce(penalty_rate,0),penalty_amount=coalesce(penalty_amount,0)
    where id=v_request.id returning * into v_request;
    return v_request;
  end if;

  if v_booking.status in ('مكتمل','قيد التنفيذ') then
    update public.cancellation_requests
    set status='تم رفض الطلب',reviewed_at=now(),reviewed_by=v_admin,decision='رفض الإلغاء'
    where id=v_request.id returning * into v_request;
    return v_request;
  end if;

  if p_decision='رفض الإلغاء' then
    update public.cancellation_requests
    set status='تم رفض الطلب',reviewed_at=now(),reviewed_by=v_admin,decision=p_decision
    where id=v_request.id returning * into v_request;
    perform public.enqueue_user_notification(v_request.lawyer_id,'تم رفض طلب إلغاء الحجز','تم رفض طلب الإلغاء من الإدارة ويبقى الحجز فعالاً.','cancellation_request_rejected',v_request.id,'cancellation_request');
    return v_request;
  end if;

  select exists(select 1 from public.payments p where p.booking_id=v_booking.id and p.status='تم الدفع') into v_paid;
  v_target:=case when v_paid then 'بانتظار الاسترداد' else 'ملغي' end;

  if p_decision='الموافقة بدون غرامة' then
    update public.bookings
    set status=v_target,
        cancelled_at=coalesce(cancelled_at,now()),
        cancellation_reason=v_request.reason,
        cancelled_by_profile_id=v_request.lawyer_id,
        cancellation_actor_role='lawyer',
        cancellation_source='lawyer_cancellation_request',
        cancellation_request_id=v_request.id
    where id=v_booking.id;

    update public.cancellation_requests
    set status='تمت الموافقة',reviewed_at=now(),reviewed_by=v_admin,
        decision=p_decision,penalty_rate=0,penalty_amount=0
    where id=v_request.id returning * into v_request;

    perform public.enqueue_user_notification(v_request.lawyer_id,'تمت الموافقة على إلغاء الحجز','وافقت الإدارة على طلب الإلغاء بدون غرامة.','cancellation_request_approved',v_request.id,'cancellation_request');
    perform public.enqueue_user_notification(v_request.client_id,
      case when v_paid then 'تم إلغاء الحجز وبدء الاسترداد' else 'تم إلغاء الحجز' end,
      case when v_paid then 'تم اعتماد إلغاء المحامي وتم تسجيل كامل مبلغ الاستشارة للاسترداد.' else 'تم اعتماد إلغاء الحجز من الإدارة.' end,
      'booking_cancelled_by_lawyer',v_booking.id,'booking');
    return v_request;
  end if;

  if p_decision<>'الموافقة مع غرامة' then raise exception 'نوع القرار غير صالح'; end if;
  if p_penalty_rate is null or p_penalty_rate<=0 or p_penalty_rate>100 then raise exception 'نسبة الغرامة يجب أن تكون أكبر من صفر ولا تتجاوز 100%%'; end if;

  v_amount:=round(coalesce(v_booking.price,0)::numeric*p_penalty_rate/100,2);
  if v_amount<=0 then raise exception 'قيمة الغرامة المحسوبة غير صالحة'; end if;

  update public.bookings
  set status=v_target,
      cancelled_at=coalesce(cancelled_at,now()),
      cancellation_reason=v_request.reason,
      cancelled_by_profile_id=v_request.lawyer_id,
      cancellation_actor_role='lawyer',
      cancellation_source='lawyer_cancellation_request',
      cancellation_request_id=v_request.id
  where id=v_booking.id;

  update public.cancellation_requests
  set status='بانتظار تحصيل الغرامة',reviewed_at=now(),reviewed_by=v_admin,
      decision=p_decision,penalty_rate=p_penalty_rate,penalty_amount=v_amount
  where id=v_request.id returning * into v_request;

  insert into public.lawyer_penalties(cancellation_request_id,booking_id,lawyer_id,client_id,amount,remaining_amount,currency)
  values(v_request.id,v_request.booking_id,v_request.lawyer_id,v_request.client_id,v_amount,v_amount,v_request.currency)
  returning id into v_penalty_id;

  insert into public.client_credits(user_id,booking_id,lawyer_id,amount,currency,transaction_type,status,reference_id)
  values(v_request.client_id,v_request.booking_id,v_request.lawyer_id,v_amount,v_request.currency,'تعويض إلغاء حجز من المحامي','بانتظار تحصيل الغرامة',v_penalty_id)
  on conflict (booking_id,transaction_type) where booking_id is not null do nothing;

  perform public.enqueue_user_notification(v_request.lawyer_id,'تم اعتماد الإلغاء مع غرامة','تم إلغاء الحجز وتسجيل غرامة مالية عليك.','lawyer_penalty_created',v_penalty_id,'lawyer_penalty');
  perform public.enqueue_user_notification(v_request.client_id,'تم اعتماد الإلغاء والتعويض',
    case when v_paid
      then 'سيُعاد كامل مبلغ الاستشارة إليك، إضافة إلى تعويض بقيمة '||to_char(v_amount,'FM999G999G999G990D00')||' '||v_request.currency||' بعد تحصيل الغرامة.'
      else 'تم اعتماد تعويض لك بقيمة '||to_char(v_amount,'FM999G999G999G990D00')||' '||v_request.currency||' بعد تحصيل الغرامة.'
    end,
    'client_credit_pending',v_penalty_id,'client_credit');
  return v_request;
exception
  when unique_violation then raise exception 'تم تنفيذ هذا القرار مسبقاً';
end;
$$;

create or replace function public.sync_cancellation_request_from_penalty()
returns trigger
language plpgsql
security definer
set search_path='public'
as $$
begin
  if new.status='تم التحصيل' and old.status is distinct from new.status then
    update public.cancellation_requests
    set status='تم تحصيل الغرامة'
    where id=new.cancellation_request_id
      and status='بانتظار تحصيل الغرامة';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_sync_cancellation_request_from_penalty on public.lawyer_penalties;
create trigger trg_sync_cancellation_request_from_penalty
after update of status on public.lawyer_penalties
for each row execute function public.sync_cancellation_request_from_penalty();

update public.bookings b
set cancellation_reason=coalesce(b.cancellation_reason,cr.reason),
    cancelled_by_profile_id=coalesce(b.cancelled_by_profile_id,cr.lawyer_id),
    cancellation_actor_role=coalesce(b.cancellation_actor_role,'lawyer'),
    cancellation_source=coalesce(b.cancellation_source,'lawyer_cancellation_request'),
    cancellation_request_id=coalesce(b.cancellation_request_id,cr.id)
from public.cancellation_requests cr
where b.cancelled_at is not null
  and cr.booking_id=b.id
  and cr.id=(select x.id from public.cancellation_requests x where x.booking_id=b.id order by x.requested_at desc limit 1);

update public.bookings
set cancellation_actor_role='system',
    cancellation_source='legacy_cancellation',
    cancellation_reason=coalesce(cancellation_reason,'إلغاء سابق قبل إضافة سجل تفاصيل الإلغاء')
where cancelled_at is not null
  and cancellation_actor_role is null
  and status in ('ملغي','بانتظار الاسترداد','مسترد');

-- A paid cancellation is not final until the money is actually returned.
update public.bookings b
set status='بانتظار الاسترداد',
    cancelled_at=coalesce(cancelled_at,now())
where b.status='ملغي'
  and exists(select 1 from public.payments p where p.booking_id=b.id and p.status='تم الدفع');