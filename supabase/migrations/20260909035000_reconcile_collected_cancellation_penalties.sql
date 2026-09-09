update public.cancellation_requests cr
set status='تم تحصيل الغرامة'
where cr.status='بانتظار تحصيل الغرامة'
  and exists (
    select 1
    from public.lawyer_penalties lp
    where lp.cancellation_request_id=cr.id
      and lp.status='تم التحصيل'
      and coalesce(lp.remaining_amount,0)=0
  );
