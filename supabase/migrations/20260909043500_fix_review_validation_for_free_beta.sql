create or replace function public.validate_review()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  b public.bookings%rowtype;
begin
  select * into b from public.bookings where id = new.booking_id;
  if not found then raise exception 'الحجز غير موجود'; end if;
  if b.user_id <> new.user_id or b.lawyer_id <> new.lawyer_id then
    raise exception 'بيانات التقييم لا تطابق الحجز';
  end if;
  if b.status <> 'مكتمل' or coalesce(b.consultation_status,'') <> 'انتهت' then
    raise exception 'لا يمكن تقييم الاستشارة قبل اكتمالها';
  end if;
  if coalesce(b.payment_required,true)
     and not exists(
       select 1 from public.payments p
       where p.booking_id = b.id and p.status = 'تم الدفع'
     ) then
    raise exception 'لا يمكن تقييم استشارة غير مدفوعة';
  end if;
  if exists(
    select 1 from public.reviews r
    where r.booking_id = new.booking_id
      and r.id <> coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid)
  ) then
    raise exception 'تم تقييم هذه الاستشارة مسبقاً';
  end if;
  if new.rating < 1 or new.rating > 5 then
    raise exception 'التقييم يجب أن يكون بين نجمة و5 نجوم';
  end if;
  return new;
end;
$function$;

drop trigger if exists on_review_deleted on public.reviews;
