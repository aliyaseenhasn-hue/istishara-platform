create or replace function public.get_admin_cancellation_requests_v2()
returns table(
  id uuid,
  booking_id uuid,
  lawyer_id uuid,
  client_id uuid,
  lawyer_name text,
  client_name text,
  consultation_type text,
  consultation_mode text,
  description text,
  scheduled_at timestamptz,
  price numeric,
  reason text,
  requested_at timestamptz,
  status text,
  reviewed_at timestamptz,
  reviewed_by uuid,
  decision text,
  penalty_rate numeric,
  penalty_amount numeric,
  currency text,
  payment_status text,
  refund_required boolean,
  refund_amount numeric
)
language plpgsql
security definer
set search_path=public
as $$
begin
  if not public.is_admin() then raise exception 'غير مصرح: هذه العملية للإدارة فقط'; end if;
  return query
  select
    cr.id,cr.booking_id,cr.lawyer_id,cr.client_id,
    coalesce(lp.full_name,lppr.full_name,'المحامي')::text,
    coalesce(cp.full_name,'طالب الاستشارة')::text,
    b.consultation_type,b.consultation_mode,b.description,b.scheduled_at,b.price,
    cr.reason,cr.requested_at,cr.status,cr.reviewed_at,cr.reviewed_by,cr.decision,
    cr.penalty_rate,cr.penalty_amount,cr.currency,
    pay.status,
    (pay.status='تم الدفع')::boolean,
    case when pay.status='تم الدفع' then coalesce(pay.amount,0) else 0 end::numeric
  from public.cancellation_requests cr
  join public.bookings b on b.id=cr.booking_id
  left join public.lawyer_profiles lp on lp.profile_id=cr.lawyer_id
  left join public.profiles lppr on lppr.id=cr.lawyer_id
  left join public.profiles cp on cp.id=cr.client_id
  left join lateral (
    select p.status,p.amount
    from public.payments p
    where p.booking_id=b.id
    order by p.created_at desc
    limit 1
  ) pay on true
  order by case when cr.status='بانتظار مراجعة الإدارة' then 0 else 1 end,cr.requested_at desc;
end $$;

revoke all on function public.get_admin_cancellation_requests_v2() from public,anon;
grant execute on function public.get_admin_cancellation_requests_v2() to authenticated;
