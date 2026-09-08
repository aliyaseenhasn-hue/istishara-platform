create or replace function public.cleanup_stale_processing_bookings()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking_id uuid;
  v_count integer := 0;
begin
  for v_booking_id in
    select b.id
    from public.bookings b
    where b.status = 'قيد معالجة الدفع'
      and not exists (
        select 1 from public.payments paid
        where paid.booking_id = b.id
          and paid.status = 'تم الدفع'
      )
      and exists (
        select 1 from public.payments p
        where p.booking_id = b.id
          and p.status = 'قيد معالجة الدفع'
      )
      and not exists (
        select 1 from public.payments recent
        where recent.booking_id = b.id
          and recent.created_at > now() - interval '24 hours'
      )
    for update
  loop
    update public.payments
    set status = 'فشل الدفع'
    where booking_id = v_booking_id
      and status = 'قيد معالجة الدفع';

    update public.bookings
    set status = 'ملغي',
        cancelled_at = coalesce(cancelled_at, now())
    where id = v_booking_id
      and status in ('قيد انتظار الدفع', 'قيد معالجة الدفع');

    if found then
      v_count := v_count + 1;
    end if;
  end loop;

  return v_count;
end;
$$;

revoke all on function public.cleanup_stale_processing_bookings() from public, anon, authenticated;

do $$
declare
  v_jobid bigint;
begin
  select jobid into v_jobid
  from cron.job
  where jobname = 'cleanup-stale-processing-bookings'
  limit 1;

  if v_jobid is not null then
    perform cron.unschedule(v_jobid);
  end if;

  perform cron.schedule(
    'cleanup-stale-processing-bookings',
    '17 * * * *',
    'select public.cleanup_stale_processing_bookings();'
  );
end $$;

select public.cleanup_stale_processing_bookings();
