-- Keep cancellation review requests aligned with the live booking state.

create or replace function public.reconcile_pending_cancellation_request_for_booking()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$
begin
  if new.status is distinct from old.status then
    if new.status in ('ملغي', 'مسترد') then
      update public.cancellation_requests
      set status = 'تمت الموافقة',
          reviewed_at = coalesce(reviewed_at, now()),
          decision = coalesce(decision, 'الموافقة بدون غرامة'),
          penalty_rate = coalesce(penalty_rate, 0),
          penalty_amount = coalesce(penalty_amount, 0)
      where booking_id = new.id
        and status = 'بانتظار مراجعة الإدارة';
    elsif new.status in ('قيد التنفيذ', 'مكتمل') then
      update public.cancellation_requests
      set status = 'تم رفض الطلب',
          reviewed_at = coalesce(reviewed_at, now()),
          decision = coalesce(decision, 'رفض الإلغاء')
      where booking_id = new.id
        and status = 'بانتظار مراجعة الإدارة';
    end if;
  end if;
  return new;
end;
$function$;

drop trigger if exists reconcile_pending_cancellation_request_on_booking_status on public.bookings;
create trigger reconcile_pending_cancellation_request_on_booking_status
after update of status on public.bookings
for each row
execute function public.reconcile_pending_cancellation_request_for_booking();

update public.cancellation_requests cr
set status = case
      when b.status in ('ملغي', 'مسترد') then 'تمت الموافقة'
      else 'تم رفض الطلب'
    end,
    reviewed_at = coalesce(cr.reviewed_at, now()),
    decision = coalesce(
      cr.decision,
      case
        when b.status in ('ملغي', 'مسترد') then 'الموافقة بدون غرامة'
        else 'رفض الإلغاء'
      end
    ),
    penalty_rate = case
      when b.status in ('ملغي', 'مسترد') then coalesce(cr.penalty_rate, 0)
      else cr.penalty_rate
    end,
    penalty_amount = case
      when b.status in ('ملغي', 'مسترد') then coalesce(cr.penalty_amount, 0)
      else cr.penalty_amount
    end
from public.bookings b
where cr.booking_id = b.id
  and cr.status = 'بانتظار مراجعة الإدارة'
  and b.status in ('ملغي', 'مسترد', 'قيد التنفيذ', 'مكتمل');

create or replace function public.review_booking_cancellation(
  p_request_id uuid,
  p_decision text,
  p_penalty_rate numeric default null
)
returns public.cancellation_requests
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_admin_profile uuid;
  v_request public.cancellation_requests;
  v_booking public.bookings%rowtype;
  v_amount numeric(18,2);
  v_previous_status text;
  v_penalty_id uuid;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'غير مصرح: هذه العملية للإدارة فقط';
  end if;

  select id into v_admin_profile
  from public.profiles
  where auth_id = auth.uid()
  limit 1;

  select * into v_request
  from public.cancellation_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'طلب الإلغاء غير موجود';
  end if;

  if v_request.status <> 'بانتظار مراجعة الإدارة' then
    return v_request;
  end if;

  select * into v_booking
  from public.bookings
  where id = v_request.booking_id
  for update;

  if not found then
    raise exception 'الحجز غير موجود';
  end if;

  -- The booking can change while the admin review screen is open.
  if v_booking.status in ('ملغي', 'مسترد') then
    update public.cancellation_requests
    set status = 'تمت الموافقة',
        reviewed_at = now(),
        reviewed_by = v_admin_profile,
        decision = 'الموافقة بدون غرامة',
        penalty_rate = coalesce(penalty_rate, 0),
        penalty_amount = coalesce(penalty_amount, 0)
    where id = v_request.id
    returning * into v_request;
    return v_request;
  end if;

  if v_booking.status in ('مكتمل', 'قيد التنفيذ') then
    update public.cancellation_requests
    set status = 'تم رفض الطلب',
        reviewed_at = now(),
        reviewed_by = v_admin_profile,
        decision = 'رفض الإلغاء'
    where id = v_request.id
    returning * into v_request;
    return v_request;
  end if;

  v_previous_status := v_booking.status;

  if p_decision = 'رفض الإلغاء' then
    update public.cancellation_requests
    set status = 'تم رفض الطلب', reviewed_at = now(), reviewed_by = v_admin_profile, decision = p_decision
    where id = v_request.id
    returning * into v_request;

    insert into public.financial_audit_log(
      actor_id, actor_role, booking_id, lawyer_id, client_id, event_type, decision,
      currency, previous_status, new_status, reference_id
    ) values (
      v_admin_profile, 'admin', v_request.booking_id, v_request.lawyer_id, v_request.client_id,
      'قرار إلغاء حجز', p_decision, v_request.currency, v_previous_status, v_previous_status, v_request.id
    );

    perform public.enqueue_user_notification(
      v_request.lawyer_id,
      'تم رفض طلب إلغاء الحجز',
      'تم رفض طلب إلغاء الحجز من الإدارة، ويبقى الحجز على حالته الحالية.',
      'cancellation_request_rejected',
      v_request.id,
      'cancellation_request'
    );
    return v_request;
  end if;

  if p_decision = 'الموافقة بدون غرامة' then
    update public.bookings set status = 'ملغي', cancelled_at = now() where id = v_booking.id;
    update public.cancellation_requests
    set status = 'تمت الموافقة', reviewed_at = now(), reviewed_by = v_admin_profile,
        decision = p_decision, penalty_rate = 0, penalty_amount = 0
    where id = v_request.id
    returning * into v_request;

    insert into public.financial_audit_log(
      actor_id, actor_role, booking_id, lawyer_id, client_id, event_type, decision,
      penalty_rate, amount, currency, previous_status, new_status, reference_id
    ) values (
      v_admin_profile, 'admin', v_request.booking_id, v_request.lawyer_id, v_request.client_id,
      'قرار إلغاء حجز', p_decision, 0, 0, v_request.currency, v_previous_status, 'ملغي', v_request.id
    );

    perform public.enqueue_user_notification(
      v_request.lawyer_id,
      'تمت الموافقة على إلغاء الحجز',
      'وافقت الإدارة على طلب إلغاء الحجز بدون غرامة.',
      'cancellation_request_approved',
      v_request.id,
      'cancellation_request'
    );
    perform public.enqueue_user_notification(
      v_request.client_id,
      'تم إلغاء الحجز',
      'تم اعتماد إلغاء الحجز من الإدارة.',
      'booking_cancelled_by_lawyer',
      v_request.id,
      'cancellation_request'
    );
    return v_request;
  end if;

  if p_decision <> 'الموافقة مع غرامة' then
    raise exception 'نوع القرار غير صالح';
  end if;

  if p_penalty_rate is null or p_penalty_rate <= 0 or p_penalty_rate > 100 then
    raise exception 'نسبة الغرامة يجب أن تكون أكبر من صفر ولا تتجاوز 100%%';
  end if;

  v_amount := round(coalesce(v_booking.price, 0)::numeric * p_penalty_rate / 100, 2);
  if v_amount <= 0 then
    raise exception 'قيمة الغرامة المحسوبة غير صالحة';
  end if;

  update public.bookings set status = 'ملغي', cancelled_at = now() where id = v_booking.id;
  update public.cancellation_requests
  set status = 'بانتظار تحصيل الغرامة', reviewed_at = now(), reviewed_by = v_admin_profile,
      decision = p_decision, penalty_rate = p_penalty_rate, penalty_amount = v_amount
  where id = v_request.id
  returning * into v_request;

  insert into public.lawyer_penalties(
    cancellation_request_id, booking_id, lawyer_id, client_id, amount, remaining_amount, currency
  ) values (
    v_request.id, v_request.booking_id, v_request.lawyer_id, v_request.client_id,
    v_amount, v_amount, v_request.currency
  ) returning id into v_penalty_id;

  insert into public.client_credits(
    user_id, booking_id, lawyer_id, amount, currency, transaction_type, status, reference_id
  ) values (
    v_request.client_id, v_request.booking_id, v_request.lawyer_id, v_amount, v_request.currency,
    'تعويض إلغاء حجز من المحامي', 'بانتظار تحصيل الغرامة', v_penalty_id
  );

  insert into public.financial_audit_log(
    actor_id, actor_role, booking_id, lawyer_id, client_id, event_type, decision,
    penalty_rate, amount, currency, previous_status, new_status, reference_id
  ) values (
    v_admin_profile, 'admin', v_request.booking_id, v_request.lawyer_id, v_request.client_id,
    'اعتماد غرامة وتعويض', p_decision, p_penalty_rate, v_amount, v_request.currency,
    v_previous_status, 'ملغي', v_penalty_id
  );

  perform public.enqueue_user_notification(
    v_request.lawyer_id,
    'تم اعتماد إلغاء الحجز مع غرامة',
    'وافقت الإدارة على إلغاء الحجز وتم تسجيل غرامة مالية ستُحصّل من أول استشارة مدفوعة مستقبلاً.',
    'lawyer_penalty_created',
    v_penalty_id,
    'lawyer_penalty'
  );
  perform public.enqueue_user_notification(
    v_request.client_id,
    'تم اعتماد تعويض الإلغاء',
    'تم اعتماد تعويض لصالحك بقيمة ' || to_char(v_amount, 'FM999G999G999G990D00') || ' ' || v_request.currency || '، وسيصبح متاحاً بعد تحصيل الغرامة.',
    'client_credit_pending',
    v_penalty_id,
    'client_credit'
  );
  return v_request;

exception
  when unique_violation then
    raise exception 'تم تنفيذ هذا القرار مسبقاً أو تم إنشاء الغرامة/التعويض لهذا الحجز بالفعل';
end;
$function$;

revoke execute on function public.review_booking_cancellation(uuid, text, numeric) from public, anon;
grant execute on function public.review_booking_cancellation(uuid, text, numeric) to authenticated;
