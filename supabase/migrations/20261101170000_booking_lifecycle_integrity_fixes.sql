-- Booking lifecycle integrity fixes (business-logic audit 2026-11-01)
-- ---------------------------------------------------------------------------
-- 1) Legacy cancellation bypass: change_booking_status('ملغي') let a client
--    cancel a PAID booking at any time (even long after the appointment) and
--    created an automatic full refund with no admin review. Clients must now
--    use request_client_booking_cancellation for paid bookings, and nobody but
--    an admin can cancel a booking whose time has already started.
-- 2) Client protection after "start": the client could not report anything
--    once the lawyer pressed start, and the lawyer alone could start+complete.
--    The client can now report that the consultation did not happen while it is
--    in progress (after its duration) or within the earnings-hold window after
--    completion. Earnings are not released while the report is under review.
--    Restoring a completed booking after a rejected report no longer
--    double-counts consultations or re-collects lawyer penalties.
-- 3) Stuck bookings: a scheduled job now
--    a) refers confirmed bookings that never started (12h after the start
--       window closed) to the admin no-show review, and
--    b) completes in-progress bookings 12h after their duration ended
--       (the client keeps the dispute window from 2).
-- 4) Partial refunds (client no-show) settled from the credits page now close
--    the booking and the no-show request, like full refunds already did.
-- Each function patch must match exactly once or the migration aborts.
-- ---------------------------------------------------------------------------

alter table public.no_show_review_requests
  add column if not exists auto_generated boolean not null default false;

create or replace function pg_temp.istishara_patch_fn(p_fn regprocedure, p_old text, p_new text)
returns void
language plpgsql
as $function$
declare
  v_def text := pg_get_functiondef(p_fn);
  v_count integer;
begin
  v_count := (length(v_def) - length(replace(v_def, p_old, ''))) / greatest(length(p_old), 1);
  if v_count <> 1 then
    raise exception 'patch for % expected exactly 1 match, found %: %', p_fn, v_count, left(p_old, 120);
  end if;
  execute replace(v_def, p_old, p_new);
end;
$function$;

-- 1) change_booking_status: close the legacy client cancellation path.
select pg_temp.istishara_patch_fn(
  'public.change_booking_status(uuid,text)'::regprocedure,
  E'    if not v_is_admin and v_booking.user_id<>v_profile_id then\n      raise exception \'غير مصرح بهذا الإجراء\';\n    end if;\n',
  E'    if not v_is_admin and v_booking.user_id<>v_profile_id then\n      raise exception \'غير مصرح بهذا الإجراء\';\n    end if;\n    if not v_is_admin then\n      if v_booking.scheduled_at is not null and v_booking.scheduled_at<=now() then\n        raise exception \'لا يمكن إلغاء موعد بدأ أو انتهى\';\n      end if;\n      if v_is_paid or v_pending_manual then\n        raise exception \'لإلغاء حجز مدفوع استخدم طلب الإلغاء حتى تُراجع الإدارة الاسترداد\';\n      end if;\n    end if;\n'
);

-- 2a) report_booking_no_show: let the client report after start/completion.
select pg_temp.istishara_patch_fn(
  'public.report_booking_no_show(uuid)'::regprocedure,
  E'    if v_booking.status<>\'مؤكد\' or v_booking.started_at is not null then\n      raise exception \'لا يمكن تسجيل عدم حضور المحامي بعد بدء الاستشارة\';\n    end if;\n\n    v_eligible_at:=v_booking.scheduled_at + make_interval(mins => v_duration_minutes);\n    if v_booking.payment_required\n       and v_booking.payment_confirmed_at is not null\n       and v_booking.payment_confirmed_at>v_booking.scheduled_at then\n      v_delayed_start_deadline:=v_booking.payment_confirmed_at + interval \'1 hour\';\n      v_eligible_at:=greatest(v_eligible_at,v_delayed_start_deadline);\n    end if;\n',
  E'    if v_booking.status=\'مؤكد\' and v_booking.started_at is null then\n      v_eligible_at:=v_booking.scheduled_at + make_interval(mins => v_duration_minutes);\n      if v_booking.payment_required\n         and v_booking.payment_confirmed_at is not null\n         and v_booking.payment_confirmed_at>v_booking.scheduled_at then\n        v_delayed_start_deadline:=v_booking.payment_confirmed_at + interval \'1 hour\';\n        v_eligible_at:=greatest(v_eligible_at,v_delayed_start_deadline);\n      end if;\n    elsif v_booking.status=\'قيد التنفيذ\' and v_booking.started_at is not null then\n      -- The lawyer pressed start but the consultation did not take place.\n      v_eligible_at:=v_booking.started_at + make_interval(mins => v_duration_minutes);\n    elsif v_booking.status=\'مكتمل\' and v_booking.completed_at is not null then\n      -- Dispute window while the lawyer earnings are still on hold.\n      if v_now > v_booking.completed_at + make_interval(hours => greatest(24, coalesce(v_booking.lawyer_earnings_hold_hours_snapshot,24))) then\n        raise exception \'انتهت مهلة الاعتراض على هذه الاستشارة\';\n      end if;\n      v_eligible_at:=v_booking.completed_at;\n    else\n      raise exception \'لا يمكن الإبلاغ عن عدم حضور المحامي في حالة الحجز الحالية\';\n    end if;\n'
);

-- 2b) Restoring a completed booking after a rejected report must not count
--     the consultation twice.
select pg_temp.istishara_patch_fn(
  'public.track_completed_consultation()'::regprocedure,
  E'  if old.status <> \'مكتمل\' and new.status = \'مكتمل\' then',
  E'  if old.status <> \'مكتمل\' and new.status = \'مكتمل\' and old.status <> \'بانتظار مراجعة عدم الحضور\' then'
);

-- 2c) ...and must not collect lawyer penalties from the same payment again.
--     Earnings release still runs (it only touches pending earnings).
select pg_temp.istishara_patch_fn(
  'public.finalize_lawyer_financials_after_completed_booking()'::regprocedure,
  E'    perform public.settle_oldest_lawyer_penalties_for_completed_booking(new.id);\n',
  E'    if old.status is distinct from \'بانتظار مراجعة عدم الحضور\' then\n      perform public.settle_oldest_lawyer_penalties_for_completed_booking(new.id);\n    end if;\n'
);

-- 4) Close bookings and no-show requests when a partial refund is settled.
select pg_temp.istishara_patch_fn(
  'public.admin_complete_client_credit_settlement(uuid,text,text)'::regprocedure,
  E'  perform public.enqueue_user_notification(\n    v_row.user_id,',
  E'  if v_credit.transaction_type=\'استرداد جزئي لعدم حضور طالب الاستشارة\' and v_credit.booking_id is not null then\n    update public.bookings set status=\'مسترد\' where id=v_credit.booking_id and status=\'بانتظار الاسترداد\';\n  end if;\n\n  update public.no_show_review_requests\n  set financial_status=\'refunded\',\n      refunded_at=coalesce(refunded_at,now()),\n      refund_reference=coalesce(refund_reference,trim(p_provider_reference)),\n      settlement_id=coalesce(settlement_id,p_settlement_id)\n  where client_credit_id=v_credit.id and status=\'approved\' and financial_status<>\'refunded\';\n\n  perform public.enqueue_user_notification(\n    v_row.user_id,'
);

-- 3) Resolve stuck bookings.
create or replace function public.resolve_stale_bookings()
returns integer
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare
  r record;
  v_count integer := 0;
  v_grace interval := interval '12 hours';
  v_admin record;
begin
  -- a) Confirmed bookings that never started: refer to admin review as a
  --    lawyer no-show reported on the client's behalf. Only once per booking,
  --    so an admin rejection is final and is never re-filed automatically.
  for r in
    select b.*
    from public.bookings b
    where b.status='مؤكد'
      and b.started_at is null
      and greatest(
            b.scheduled_at + make_interval(mins => greatest(coalesce(b.package_duration_minutes,30),1)),
            case when b.payment_required and b.payment_confirmed_at is not null and b.payment_confirmed_at>b.scheduled_at
                 then b.payment_confirmed_at + interval '1 hour' else b.scheduled_at end
          ) + v_grace < now()
      and not exists (select 1 from public.no_show_review_requests n where n.booking_id=b.id)
    for update of b skip locked
  loop
    insert into public.no_show_review_requests(
      booking_id,reporter_id,reason,status,previous_booking_status,previous_consultation_status,auto_generated
    ) values(
      r.id,r.user_id,'عدم حضور المحامي','pending',r.status,r.consultation_status,true
    );
    update public.bookings
    set status='بانتظار مراجعة عدم الحضور',consultation_status='عدم حضور المحامي'
    where id=r.id;

    perform public.enqueue_user_notification(
      r.user_id,'استشارتك لم تبدأ في موعدها',
      'لم تبدأ الاستشارة في وقتها، وأحلناها إلى الإدارة لمراجعتها وتحديد الاسترداد.',
      'no_show_auto_referred',r.id,'booking'
    );
    perform public.enqueue_user_notification(
      r.lawyer_id,'استشارة لم تبدأ في موعدها',
      'لم تُبدأ هذه الاستشارة في وقتها، وأُحيلت إلى الإدارة للمراجعة.',
      'no_show_auto_referred',r.id,'booking'
    );
    for v_admin in select id from public.profiles where role::text in ('admin','super_admin') loop
      perform public.enqueue_user_notification(
        v_admin.id,'استشارة لم تبدأ تحتاج مراجعة',
        'حجز مؤكد لم يبدأ حتى بعد انتهاء موعده، وأُحيل تلقائياً لمراجعة عدم الحضور.',
        'no_show_auto_referred',r.id,'booking'
      );
    end loop;
    v_count := v_count + 1;
  end loop;

  -- b) In-progress bookings never completed by the lawyer: complete them.
  --    The client can still dispute during the earnings-hold window.
  for r in
    select b.id
    from public.bookings b
    where b.status='قيد التنفيذ'
      and b.started_at is not null
      and b.started_at + make_interval(mins => greatest(coalesce(b.package_duration_minutes,30),1)) + v_grace < now()
      and not exists (select 1 from public.no_show_review_requests n where n.booking_id=b.id and n.status='pending')
    for update of b skip locked
  loop
    update public.bookings
    set status='مكتمل',consultation_status='انتهت',completed_at=now()
    where id=r.id and status='قيد التنفيذ';
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$function$;

revoke all on function public.resolve_stale_bookings() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from cron.job where jobname='resolve-stale-bookings') then
    perform cron.unschedule('resolve-stale-bookings');
  end if;
  perform cron.schedule('resolve-stale-bookings','*/10 * * * *','select public.resolve_stale_bookings();');
end $$;

-- Data repair -----------------------------------------------------------------
-- Partial refunds already settled but bookings left waiting.
update public.bookings b
set status='مسترد'
where b.status='بانتظار الاسترداد'
  and exists (select 1 from public.client_credits c where c.booking_id=b.id)
  and not exists (select 1 from public.client_credits c where c.booking_id=b.id and c.status<>'settled');

update public.no_show_review_requests n
set financial_status='refunded', refunded_at=coalesce(n.refunded_at,c.settled_at)
from public.client_credits c
where c.id=n.client_credit_id and c.status='settled'
  and n.status='approved' and n.financial_status<>'refunded';

-- Free booking whose lawyer cancellation was approved but stayed confirmed.
update public.bookings b
set status='ملغي', cancelled_at=coalesce(b.cancelled_at,now())
where b.status='مؤكد'
  and not b.payment_required
  and exists (
    select 1 from public.cancellation_requests cr
    where cr.booking_id=b.id and cr.status in ('تمت الموافقة','تمت الموافقة مع غرامة','تم تحصيل الغرامة')
  );
