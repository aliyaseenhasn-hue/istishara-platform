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
           admin_review_note = coalesce(admin_review_note, 'أُغلقت عملية الدفع تلقائياً لأن الحجز أصبح في حالة نهائية قبل اعتماد الدفع')
     where booking_id = new.id
       and status = 'قيد معالجة الدفع';
  end if;
  return new;
end;
$$;

update public.payments p
set status = 'فشل الدفع',
    admin_review_note = coalesce(p.admin_review_note, 'أُغلقت عملية الدفع تلقائياً لأن الحجز أصبح ملغياً قبل اعتماد الدفع')
from public.bookings b
where p.booking_id = b.id
  and p.status = 'قيد معالجة الدفع'
  and b.status in ('ملغي', 'مرفوض');