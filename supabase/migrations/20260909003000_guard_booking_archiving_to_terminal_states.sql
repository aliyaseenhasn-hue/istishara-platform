create or replace function public.archive_booking_for_user(p_booking_id uuid)
returns void
language plpgsql
set search_path = public
as $$
declare
  v_status text;
begin
  select status into v_status
  from public.bookings
  where id = p_booking_id
    and user_id = (select id from public.profiles where auth_id = auth.uid());

  if v_status is null then
    raise exception 'الحجز غير موجود أو غير مصرح لك';
  end if;

  if v_status not in ('مكتمل', 'ملغي', 'مسترد', 'مرفوض') then
    raise exception 'لا يمكن حذف الاستشارة قبل وصولها إلى حالة نهائية';
  end if;

  update public.bookings
  set archived_by_user_at = now()
  where id = p_booking_id;
end;
$$;

create or replace function public.archive_booking_for_lawyer(p_booking_id uuid)
returns void
language plpgsql
set search_path = public
as $$
declare
  v_status text;
begin
  select status into v_status
  from public.bookings
  where id = p_booking_id
    and lawyer_id = (select id from public.profiles where auth_id = auth.uid());

  if v_status is null then
    raise exception 'الحجز غير موجود أو غير مصرح لك';
  end if;

  if v_status not in ('مكتمل', 'ملغي', 'مسترد', 'مرفوض') then
    raise exception 'لا يمكن حذف الاستشارة قبل وصولها إلى حالة نهائية';
  end if;

  update public.bookings
  set archived_by_lawyer_at = now(),
      deleted_by_lawyer_at = coalesce(deleted_by_lawyer_at, now())
  where id = p_booking_id;
end;
$$;
