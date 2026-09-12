-- Preserve the client's full consultation time when payment confirmation is delayed.
-- A paid booking keeps its original start window, but if payment is confirmed after
-- the scheduled time the lawyer receives a fresh 60-minute window to start it.
-- Once started, the consultation duration is measured from started_at, never from
-- the original scheduled_at.

alter table public.bookings
  add column if not exists payment_confirmed_at timestamptz;

comment on column public.bookings.payment_confirmed_at is
  'First successful payment confirmation time used to protect consultation start time from administrative payment-review delays.';

-- Backfill existing successful payments so old confirmed bookings follow the same rule.
with paid as (
  select booking_id,
         min(coalesce(verified_at, created_at)) as confirmed_at
  from public.payments
  where status = 'تم الدفع'
  group by booking_id
)
update public.bookings b
set payment_confirmed_at = paid.confirmed_at
from paid
where b.id = paid.booking_id
  and b.payment_confirmed_at is null;

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
  v_pending_manual boolean;
  v_payment_satisfied boolean;
  v_duration integer;
  v_now timestamptz:=now();
  v_target_status text;
  v_paid_at timestamptz;
  v_payment_confirmed_at timestamptz;
  v_start_deadline timestamptz;
begin
  if v_actor is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if p_new_status not in ('مؤكد','قيد التنفيذ','مكتمل','ملغي','مسترد') then raise exception 'حالة الحجز غير صالحة'; end if;

  select id into v_profile_id from public.profiles where auth_id=v_actor limit 1;
  select * into v_booking from public.bookings where id=p_booking_id for update;
  if not found then raise exception 'الحجز غير موجود'; end if;

  select
    exists(select 1 from public.payments where booking_id=v_booking.id and status='تم الدفع'),
    min(coalesce(verified_at, created_at)) filter (where status='تم الدفع')
  into v_is_paid, v_paid_at
  from public.payments
  where booking_id=v_booking.id;

  select exists(
    select 1 from public.payments
    where booking_id=v_booking.id
      and status='قيد معالجة الدفع'
      and coalesce(is_manual,false)
      and nullif(trim(coalesce(receipt_url,'')),'') is not null
  ) into v_pending_manual;

  v_payment_satisfied := (not v_booking.payment_required) or v_is_paid;
  v_payment_confirmed_at := coalesce(v_booking.payment_confirmed_at, v_paid_at);

  if p_new_status='مسترد' then
    raise exception 'لا يمكن تسجيل الاسترداد يدوياً؛ يجب إكمال تحويل الاسترداد من الإدارة المالية';
  end if;

  if p_new_status='ملغي' then
    if v_booking.status not in ('قيد انتظار الدفع','قيد معالجة الدفع','قيد مراجعة المحامي','بانتظار التأكيد','مؤكد') then
      raise exception 'لا يمكن إلغاء الحجز في حالته الحالية';
    end if;
    if not v_is_admin and v_booking.user_id<>v_profile_id then
      raise exception 'غير مصرح بهذا الإجراء';
    end if;

    v_target_status := case when v_is_paid or v_pending_manual then 'بانتظار الاسترداد' else 'ملغي' end;
    update public.bookings
    set status=v_target_status,
        cancelled_at=coalesce(cancelled_at,now()),
        cancellation_reason=coalesce(nullif(cancellation_reason,''),case when v_is_admin then 'إلغاء إداري' else 'إلغاء بواسطة طالب الاستشارة' end),
        cancelled_by_profile_id=coalesce(cancelled_by_profile_id,v_profile_id),
        cancellation_actor_role=coalesce(cancellation_actor_role,case when v_is_admin then 'admin' else 'client' end),
        cancellation_source=coalesce(cancellation_source,case when v_is_admin then 'admin_status_change' else 'legacy_client_status_change' end)
    where id=p_booking_id
    returning * into v_booking;
    return v_booking;
  end if;

  if v_is_admin then
    null;
  elsif v_booking.lawyer_id=v_profile_id and p_new_status='قيد التنفيذ' then
    if v_booking.status<>'مؤكد'
       or not v_payment_satisfied
       or not v_booking.lawyer_approved
       or v_booking.consultation_status<>'لم تبدأ' then
      raise exception 'لا يمكن بدء الاستشارة قبل تأكيد الحجز وموافقة المحامي والدفع عند استحقاقه';
    end if;

    v_duration := greatest(coalesce(v_booking.package_duration_minutes,30),1);
    if v_now < v_booking.scheduled_at - interval '5 minutes' then
      raise exception 'لم يحِن موعد الاستشارة بعد';
    end if;

    -- Original start window ends at the scheduled consultation end. If payment
    -- was confirmed late, grant a new full hour to START after that confirmation.
    -- The consultation duration itself starts only when the lawyer presses Start.
    v_start_deadline := v_booking.scheduled_at + make_interval(mins=>v_duration);
    if v_booking.payment_required
       and v_payment_confirmed_at is not null
       and v_payment_confirmed_at > v_booking.scheduled_at then
      v_start_deadline := greatest(v_start_deadline, v_payment_confirmed_at + interval '60 minutes');
    end if;

    if v_now > v_start_deadline then
      raise exception 'انتهت نافذة بدء الاستشارة. عند تأخر تأكيد الدفع تتاح ساعة كاملة للبدء بعد التأكيد';
    end if;
  elsif v_booking.lawyer_id=v_profile_id and p_new_status='مكتمل' then
    if v_booking.status<>'قيد التنفيذ'
       or v_booking.consultation_status<>'قيد التنفيذ'
       or v_booking.started_at is null then
      raise exception 'لا يمكن إنهاء الاستشارة في حالتها الحالية';
    end if;
  else
    raise exception 'غير مصرح بهذا الإجراء';
  end if;

  update public.bookings
  set status=p_new_status,
      consultation_status=case
        when p_new_status='قيد التنفيذ' then 'قيد التنفيذ'
        when p_new_status='مكتمل' then 'انتهت'
        else consultation_status
      end,
      started_at=case when p_new_status='قيد التنفيذ' then coalesce(started_at,now()) else started_at end,
      completed_at=case when p_new_status='مكتمل' then now() else completed_at end
  where id=p_booking_id
  returning * into v_booking;

  return v_booking;
end;
$$;

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
  v_confirmed_at timestamptz;
begin
  select * into v_booking from public.bookings where id=new.booking_id for update;
  if not found then raise exception 'الحجز غير موجود'; end if;
  if not v_booking.payment_required then raise exception 'لا يمكن إنشاء أو اعتماد دفعة لحجز مجاني تجريبي'; end if;
  select id into v_verifier from public.profiles where auth_id=auth.uid() limit 1;

  if new.status='تم الدفع' then
    v_confirmed_at := coalesce(new.verified_at, now());

    update public.payments
    set verified_by=coalesce(v_verifier,verified_by),
        verified_at=coalesce(verified_at,v_confirmed_at)
    where id=new.id;

    if v_booking.status='بانتظار الاسترداد' then
      select coalesce(currency,'IQD') into v_currency from public.platform_financial_settings where id=true;
      insert into public.client_credits(user_id,booking_id,lawyer_id,amount,currency,transaction_type,status,reference_id)
      values(v_booking.user_id,v_booking.id,v_booking.lawyer_id,new.amount,v_currency,'استرداد قيمة استشارة','مستحق',new.id)
      on conflict (booking_id,transaction_type) where booking_id is not null do nothing;
      return new;
    end if;

    if v_booking.status not in ('قيد معالجة الدفع','قيد انتظار الدفع','قيد مراجعة المحامي') then
      raise exception 'لا يمكن اعتماد الدفع في حالة الحجز الحالية';
    end if;

    update public.bookings
    set status=case when lawyer_approved then 'مؤكد' else 'قيد مراجعة المحامي' end,
        payment_confirmed_at=coalesce(payment_confirmed_at,v_confirmed_at)
    where id=new.booking_id;

  elsif new.status='فشل الدفع' then
    update public.payments
    set verified_by=coalesce(v_verifier,verified_by),verified_at=coalesce(verified_at,now())
    where id=new.id;

    if v_booking.status='بانتظار الاسترداد'
       and v_booking.cancellation_actor_role is not null then
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
    update public.payments
    set verified_by=coalesce(v_verifier,verified_by),verified_at=coalesce(verified_at,now())
    where id=new.id;
    update public.bookings set status='مسترد' where id=new.booking_id;
  end if;

  return new;
end;
$$;

create or replace function public.record_manual_payment(p_booking_id uuid, p_received_amount numeric)
returns public.bookings
language plpgsql
security definer
set search_path=public
as $$
declare
  v_actor uuid := auth.uid();
  v_profile_id uuid;
  v_booking public.bookings;
  v_confirmed_at timestamptz := now();
begin
  if v_actor is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if p_received_amount is null or p_received_amount <= 0 then raise exception 'يجب إدخال مبلغ مستلم صحيح'; end if;

  select id into v_profile_id
  from public.profiles
  where auth_id = v_actor
  limit 1;

  select * into v_booking
  from public.bookings
  where id = p_booking_id
  for update;

  if not found then raise exception 'الحجز غير موجود'; end if;
  if v_booking.lawyer_id <> v_profile_id then raise exception 'غير مصرح بهذا الإجراء'; end if;
  if v_booking.consultation_mode <> 'في المكتب' or not v_booking.manual_payment_required then
    raise exception 'هذا الحجز لا يستخدم الدفع اليدوي';
  end if;
  if v_booking.status not in ('بانتظار التأكيد','قيد مراجعة المحامي') then
    raise exception 'لا يمكن تسجيل الدفع في حالة الحجز الحالية';
  end if;
  if round(p_received_amount::numeric, 2) <> round(v_booking.price::numeric, 2) then
    raise exception 'المبلغ المستلم يجب أن يطابق رسوم الاستشارة بالكامل';
  end if;

  insert into public.payments(
    booking_id, amount, payment_method, status, verified_at, verified_by,
    is_manual, manual_received_amount, manual_received_at, manual_received_by
  ) values (
    v_booking.id, v_booking.price, 'يدوي', 'تم الدفع', v_confirmed_at, v_profile_id,
    true, p_received_amount, v_confirmed_at, v_profile_id
  );

  update public.bookings
  set manual_received_amount = p_received_amount,
      manual_received_at = v_confirmed_at,
      manual_received_by = v_profile_id,
      payment_confirmed_at = coalesce(payment_confirmed_at, v_confirmed_at),
      status = case when lawyer_approved then 'مؤكد' else 'قيد مراجعة المحامي' end
  where id = v_booking.id
  returning * into v_booking;

  return v_booking;
end;
$$;
