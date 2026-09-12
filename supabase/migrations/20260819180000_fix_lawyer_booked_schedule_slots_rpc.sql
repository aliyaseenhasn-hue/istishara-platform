-- إصلاح RPC جلب المواعيد المحجوزة للمحامي.
-- bookings لا يحتوي slot_id؛ الربط الصحيح يتم بواسطة lawyer_id و scheduled_at.

create or replace function public.get_my_booked_schedule_slots()
returns table(
  slot_id uuid,
  booking_id uuid,
  starts_at timestamptz,
  ends_at timestamptz,
  booking_status text
)
language sql
security definer
set search_path=public
as $$
  select
    s.id as slot_id,
    b.id as booking_id,
    s.starts_at,
    s.ends_at,
    b.status as booking_status
  from public.lawyer_availability_slots s
  join public.bookings b
    on b.lawyer_id = s.lawyer_id
   and b.scheduled_at = s.starts_at
  join public.profiles p
    on p.id = s.lawyer_id
  where p.auth_id = auth.uid()
    and b.status not in ('ملغي','مسترد','مكتمل')
    and b.scheduled_at > now()
  order by s.starts_at desc;
$$;

revoke execute on function public.get_my_booked_schedule_slots() from public, anon;
grant execute on function public.get_my_booked_schedule_slots() to authenticated;
