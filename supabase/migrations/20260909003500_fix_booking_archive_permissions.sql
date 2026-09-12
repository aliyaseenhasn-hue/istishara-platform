create or replace function public.archive_booking_for_user(p_booking_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid;
  v_status text;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  select id into v_profile_id
  from public.profiles
  where auth_id = auth.uid()
  limit 1;

  if v_profile_id is null then
    raise exception 'ملف المستخدم غير موجود';
  end if;

  select status into v_status
  from public.bookings
  where id = p_booking_id
    and user_id = v_profile_id
  for update;

  if v_status is null then
    raise exception 'الحجز غير موجود أو غير مصرح لك';
  end if;

  if v_status not in ('مكتمل', 'ملغي', 'مسترد', 'مرفوض') then
    raise exception 'لا يمكن حذف الاستشارة قبل وصولها إلى حالة نهائية';
  end if;

  update public.bookings
  set archived_by_user_at = coalesce(archived_by_user_at, now())
  where id = p_booking_id
    and user_id = v_profile_id;
end;
$$;

create or replace function public.archive_booking_for_lawyer(p_booking_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid;
  v_status text;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  select id into v_profile_id
  from public.profiles
  where auth_id = auth.uid()
  limit 1;

  if v_profile_id is null then
    raise exception 'ملف المستخدم غير موجود';
  end if;

  select status into v_status
  from public.bookings
  where id = p_booking_id
    and lawyer_id = v_profile_id
  for update;

  if v_status is null then
    raise exception 'الحجز غير موجود أو غير مصرح لك';
  end if;

  if v_status not in ('مكتمل', 'ملغي', 'مسترد', 'مرفوض') then
    raise exception 'لا يمكن حذف الاستشارة قبل وصولها إلى حالة نهائية';
  end if;

  update public.bookings
  set archived_by_lawyer_at = coalesce(archived_by_lawyer_at, now()),
      deleted_by_lawyer_at = coalesce(deleted_by_lawyer_at, now())
  where id = p_booking_id
    and lawyer_id = v_profile_id;
end;
$$;

create or replace function public.restore_booking_from_archive(p_booking_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid;
  v_user_id uuid;
  v_lawyer_id uuid;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  select id into v_profile_id
  from public.profiles
  where auth_id = auth.uid()
  limit 1;

  select user_id, lawyer_id into v_user_id, v_lawyer_id
  from public.bookings
  where id = p_booking_id;

  if not found then
    raise exception 'الحجز غير موجود';
  end if;

  if v_profile_id = v_user_id then
    update public.bookings
    set archived_by_user_at = null
    where id = p_booking_id;
  elsif v_profile_id = v_lawyer_id then
    update public.bookings
    set archived_by_lawyer_at = null,
        deleted_by_lawyer_at = null
    where id = p_booking_id;
  else
    raise exception 'غير مصرح لك';
  end if;
end;
$$;

revoke execute on function public.archive_booking_for_user(uuid) from public, anon;
revoke execute on function public.archive_booking_for_lawyer(uuid) from public, anon;
revoke execute on function public.restore_booking_from_archive(uuid) from public, anon;
grant execute on function public.archive_booking_for_user(uuid) to authenticated;
grant execute on function public.archive_booking_for_lawyer(uuid) to authenticated;
grant execute on function public.restore_booking_from_archive(uuid) to authenticated;
