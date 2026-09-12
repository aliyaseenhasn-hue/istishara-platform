-- تحرير موعد المحامي تلقائياً بعد اعتماد إلغاء الحجز.
-- لا يتم حذف سجل الحجز؛ يتم فقط تحرير خانة التوفر حتى يظهر الموعد متاحاً من جديد.

create or replace function public.release_lawyer_slot_after_booking_cancellation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status is distinct from new.status
     and new.status in ('ملغي', 'مسترد') then
    update public.lawyer_availability_slots s
       set is_available = true
     where s.lawyer_id = new.lawyer_id
       and s.starts_at between new.scheduled_at - interval '1 second'
                           and new.scheduled_at + interval '1 second'
       and not exists (
         select 1
           from public.bookings b
          where b.lawyer_id = new.lawyer_id
            and b.scheduled_at between s.starts_at - interval '1 second'
                                    and s.starts_at + interval '1 second'
            and b.id <> new.id
            and b.status not in ('ملغي', 'مسترد')
       );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_release_lawyer_slot_after_booking_cancellation on public.bookings;

create trigger trg_release_lawyer_slot_after_booking_cancellation
after update of status on public.bookings
for each row
when (new.status in ('ملغي', 'مسترد') and old.status is distinct from new.status)
execute function public.release_lawyer_slot_after_booking_cancellation();

revoke execute on function public.release_lawyer_slot_after_booking_cancellation() from public, anon, authenticated;

-- إصلاح البيانات السابقة: أي موعد مرتبط بحجز ملغى/مسترد يصبح متاحاً
-- ما لم يوجد حجز نشط آخر على نفس الفترة.
update public.lawyer_availability_slots s
   set is_available = true
 where s.is_available = false
   and exists (
     select 1
       from public.bookings b
      where b.lawyer_id = s.lawyer_id
        and b.scheduled_at between s.starts_at - interval '1 second'
                                and s.starts_at + interval '1 second'
        and b.status in ('ملغي', 'مسترد')
   )
   and not exists (
     select 1
       from public.bookings b2
      where b2.lawyer_id = s.lawyer_id
        and b2.scheduled_at between s.starts_at - interval '1 second'
                                 and s.starts_at + interval '1 second'
        and b2.status not in ('ملغي', 'مسترد')
   );
