-- إصلاح ربط الحجوزات بمواعيد المحامي.
-- الإصدار السابق كان يشترط role='lawyer' وقد يفشل مع الأدوار/الـenum الحالية،
-- كما كان يعيد وقت الحجز فقط. هنا نحدد profile من auth.uid() ثم نطابق الحجز
-- مع slot على مستوى lawyer + وقت الموعد، ونعيد slot_id للواجهة.
drop function if exists public.get_my_booked_schedule_slots();

create or replace function public.get_my_booked_schedule_slots()
returns table(
  booking_id uuid,
  slot_id uuid,
  scheduled_at timestamptz,
  status text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  select p.id
    into v_profile_id
  from public.profiles p
  where p.auth_id = auth.uid()
  limit 1;

  if v_profile_id is null then
    raise exception 'ملف المستخدم غير مكتمل';
  end if;

  return query
  select
    b.id as booking_id,
    s.id as slot_id,
    b.scheduled_at,
    b.status::text
  from public.bookings b
  join public.lawyer_availability_slots s
    on s.lawyer_id = b.lawyer_id
   and s.starts_at between b.scheduled_at - interval '120 seconds'
                       and b.scheduled_at + interval '120 seconds'
  where b.lawyer_id = v_profile_id
    and b.scheduled_at >= now() - interval '1 day'
    and b.status::text not in ('ملغي', 'ملغى', 'مسترد')
  order by b.scheduled_at asc;
end;
$$;

revoke all on function public.get_my_booked_schedule_slots() from public, anon;
grant execute on function public.get_my_booked_schedule_slots() to authenticated;
