-- تمكين المحامي من رؤية الحجوزات المرتبطة بمواعيده المنشورة فقط.
-- لا تعتمد الواجهة على قراءة bookings مباشرة عبر RLS؛ هذه الدالة تعيد الحد الأدنى اللازم للواجهة.
create or replace function public.get_my_booked_schedule_slots()
returns table(booking_id uuid, scheduled_at timestamptz, status text)
language plpgsql security definer set search_path = public
as $$
declare v_lawyer_id uuid;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  select p.id into v_lawyer_id from public.profiles p where p.auth_id = auth.uid() and p.role::text = 'lawyer' limit 1;
  if v_lawyer_id is null then raise exception 'غير مصرح بهذا الإجراء'; end if;
  return query
    select b.id, b.scheduled_at, b.status
    from public.bookings b
    where b.lawyer_id = v_lawyer_id
      and b.scheduled_at >= now() - interval '1 day'
      and b.status not in ('ملغي', 'ملغى', 'مسترد')
    order by b.scheduled_at asc;
end;
$$;
revoke execute on function public.get_my_booked_schedule_slots() from public, anon;
grant execute on function public.get_my_booked_schedule_slots() to authenticated;
