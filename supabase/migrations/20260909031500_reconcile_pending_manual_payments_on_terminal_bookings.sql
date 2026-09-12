create or replace function public.sync_booking_from_payment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking public.bookings%rowtype;
  v_verifier uuid;
begin
  select * into v_booking
  from public.bookings
  where id = new.booking_id
  for update;
  if not found then raise exception 'الحجز غير موجود'; end if;

  if not v_booking.payment_required then
    raise exception 'لا يمكن إنشاء أو اعتماد دفعة لحجز مجاني تجريبي';
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
    set status = case when lawyer_approved then 'مؤكد' else 'قيد مراجعة المحامي' end
    where id = new.booking_id;
  elsif new.status = 'فشل الدفع' then
    if v_booking.status in ('ملغي', 'مرفوض') then
      new.verified_by := coalesce(v_verifier, new.verified_by);
      new.verified_at := coalesce(new.verified_at, now());
    elsif v_booking.status in ('قيد معالجة الدفع', 'قيد انتظار الدفع') then
      new.verified_by := v_verifier;
      new.verified_at := now();
      update public.bookings set status = 'قيد انتظار الدفع' where id = new.booking_id;
    else
      raise exception 'لا يمكن رفض الدفع في حالة الحجز الحالية';
    end if;
  elsif new.status = 'تم استرداد المبلغ' then
    if v_booking.status not in ('بانتظار الاسترداد', 'مؤكد', 'قيد التنفيذ', 'مكتمل') then
      raise exception 'لا يمكن استرداد هذا الحجز في حالته الحالية';
    end if;
    new.verified_by := v_verifier;
    new.verified_at := now();
    update public.bookings set status = 'مسترد' where id = new.booking_id;
  end if;

  return new;
end;
$$;

create or replace function public.close_pending_manual_payments_for_terminal_booking()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status in ('ملغي', 'مرفوض')
     and old.status is distinct from new.status then
    update public.payments
       set status = 'فشل الدفع',
           admin_review_note = coalesce(admin_review_note, 'أُغلق إثبات الدفع تلقائياً لأن الحجز أصبح في حالة نهائية قبل اعتماد الدفع')
     where booking_id = new.id
       and status = 'قيد معالجة الدفع'
       and coalesce(is_manual, false) = true;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_close_pending_manual_payments_for_terminal_booking on public.bookings;
create trigger trg_close_pending_manual_payments_for_terminal_booking
after update of status on public.bookings
for each row
execute function public.close_pending_manual_payments_for_terminal_booking();

update public.payments p
set status = 'فشل الدفع',
    admin_review_note = coalesce(p.admin_review_note, 'أُغلق إثبات الدفع تلقائياً لأن الحجز أصبح ملغياً قبل اعتماد الدفع')
from public.bookings b
where p.booking_id = b.id
  and p.status = 'قيد معالجة الدفع'
  and coalesce(p.is_manual, false) = true
  and b.status in ('ملغي', 'مرفوض');