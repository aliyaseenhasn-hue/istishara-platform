-- تدفق الحجز المعتمد:
-- 1) العميل ينشئ الحجز -> قيد انتظار الدفع.
-- 2) العميل يدفع عبر كي كارد -> قيد مراجعة المحامي.
-- 3) المحامي يوافق -> مؤكد إذا كان الدفع مكتملًا.
-- 4) المحامي يرفض بعد الدفع -> بانتظار الاسترداد، ولا تبدأ الاستشارة.
-- 5) تسجيل الاسترداد -> مسترد.
-- الدفع لا يُلغى لمجرد أن موافقة المحامي لم تصل بعد.

create or replace function public.review_booking(
  p_booking_id uuid,
  p_approved boolean
)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_actor uuid := auth.uid();
  v_profile_id uuid;
  v_booking public.bookings;
  v_is_paid boolean;
begin
  if v_actor is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  select id into v_profile_id
  from public.profiles
  where auth_id = v_actor
  limit 1;

  select * into v_booking
  from public.bookings
  where id = p_booking_id
  for update;

  if not found then
    raise exception 'الحجز غير موجود';
  end if;

  if v_booking.lawyer_id <> v_profile_id then
    raise exception 'غير مصرح بهذا الإجراء';
  end if;

  if v_booking.lawyer_approved then
    raise exception 'تمت مراجعة هذا الطلب مسبقاً';
  end if;

  if v_booking.status not in ('قيد انتظار الدفع', 'قيد معالجة الدفع', 'قيد مراجعة المحامي') then
    raise exception 'لا يمكن مراجعة هذا الطلب في حالته الحالية';
  end if;

  select exists (
    select 1
    from public.payments
    where booking_id = v_booking.id
      and status = 'تم الدفع'
  ) into v_is_paid;

  if p_approved then
    update public.bookings
    set lawyer_approved = true,
        lawyer_approved_at = now(),
        status = case
          when v_is_paid then 'مؤكد'
          else v_booking.status
        end
    where id = p_booking_id
    returning * into v_booking;
  else
    update public.bookings
    set lawyer_approved = false,
        lawyer_approved_at = null,
        status = case
          when v_is_paid then 'بانتظار الاسترداد'
          else 'ملغي'
        end,
        cancelled_at = case when not v_is_paid then now() else null end
    where id = p_booking_id
    returning * into v_booking;
  end if;

  return v_booking;
end;
$function$;

grant execute on function public.review_booking(uuid, boolean) to authenticated;

create or replace function public.sync_booking_from_payment()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_booking public.bookings%rowtype;
  v_verifier uuid;
begin
  select * into v_booking
  from public.bookings
  where id = new.booking_id
  for update;

  if not found then
    raise exception 'الحجز غير موجود';
  end if;

  select id into v_verifier
  from public.profiles
  where auth_id = auth.uid()
  limit 1;

  if new.status = 'تم الدفع' then
    if v_booking.status not in ('قيد معالجة الدفع', 'قيد انتظار الدفع', 'قيد مراجعة المحامي') then
      raise exception 'لا يمكن اعتماد الدفع في حالة الحجز الحالية';
    end if;

    new.verified_by := v_verifier;
    new.verified_at := now();

    update public.bookings
    set status = case
      when lawyer_approved then 'مؤكد'
      else 'قيد مراجعة المحامي'
    end
    where id = new.booking_id;

  elsif new.status = 'فشل الدفع' then
    if v_booking.status not in ('قيد معالجة الدفع', 'قيد انتظار الدفع') then
      raise exception 'لا يمكن رفض الدفع في حالة الحجز الحالية';
    end if;

    new.verified_by := v_verifier;
    new.verified_at := now();

    update public.bookings
    set status = 'قيد انتظار الدفع'
    where id = new.booking_id;

  elsif new.status = 'تم استرداد المبلغ' then
    if v_booking.status not in ('بانتظار الاسترداد', 'مؤكد', 'قيد التنفيذ', 'مكتمل') then
      raise exception 'لا يمكن استرداد هذا الحجز في حالته الحالية';
    end if;

    new.verified_by := v_verifier;
    new.verified_at := now();

    update public.bookings
    set status = 'مسترد'
    where id = new.booking_id;
  end if;

  return new;
end;
$function$;

grant execute on function public.sync_booking_from_payment() to authenticated;
