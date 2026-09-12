-- Final cancellation/refund/compensation hardening.
-- This migration is intentionally idempotent because equivalent fixes were
-- already applied to production while auditing the live application.

alter table public.bookings add column if not exists cancellation_reason text;
alter table public.bookings add column if not exists cancelled_by_profile_id uuid;
alter table public.bookings add column if not exists cancellation_actor_role text;
alter table public.bookings add column if not exists cancellation_source text;
alter table public.bookings add column if not exists cancellation_request_id uuid;

do $$
begin
  if not exists(select 1 from pg_constraint where conrelid='public.bookings'::regclass and conname='bookings_cancelled_by_profile_id_fkey') then
    alter table public.bookings add constraint bookings_cancelled_by_profile_id_fkey foreign key(cancelled_by_profile_id) references public.profiles(id) on delete set null;
  end if;
  if not exists(select 1 from pg_constraint where conrelid='public.bookings'::regclass and conname='bookings_cancellation_request_id_fkey') then
    alter table public.bookings add constraint bookings_cancellation_request_id_fkey foreign key(cancellation_request_id) references public.cancellation_requests(id) on delete set null;
  end if;
  if not exists(select 1 from pg_constraint where conrelid='public.bookings'::regclass and conname='bookings_cancellation_actor_role_chk') then
    alter table public.bookings add constraint bookings_cancellation_actor_role_chk check(cancellation_actor_role is null or cancellation_actor_role in ('client','lawyer','admin','system'));
  end if;
end $$;

create or replace function public.request_client_booking_cancellation(p_booking_id uuid,p_reason text)
returns public.bookings
language plpgsql
security definer
set search_path=public
as $$
declare
  v_profile uuid;
  v_booking public.bookings%rowtype;
  v_paid boolean;
  v_new_status text;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if nullif(trim(coalesce(p_reason,'')),'') is null then raise exception 'سبب الإلغاء إلزامي'; end if;
  select id into v_profile from public.profiles where auth_id=auth.uid() limit 1;
  select * into v_booking from public.bookings where id=p_booking_id for update;
  if not found then raise exception 'الحجز غير موجود'; end if;
  if v_booking.user_id<>v_profile then raise exception 'غير مصرح بهذا الإجراء'; end if;
  if v_booking.status not in ('قيد انتظار الدفع','قيد معالجة الدفع','قيد مراجعة المحامي','بانتظار التأكيد','مؤكد') then
    raise exception 'لا يمكن إلغاء الحجز في حالته الحالية';
  end if;
  if v_booking.scheduled_at is not null and v_booking.scheduled_at<=now() then raise exception 'لا يمكن إلغاء موعد بدأ أو انتهى'; end if;
  select exists(select 1 from public.payments p where p.booking_id=v_booking.id and p.status='تم الدفع') into v_paid;
  v_new_status:=case when v_paid then 'بانتظار الاسترداد' else 'ملغي' end;
  update public.bookings
  set status=v_new_status,
      cancelled_at=coalesce(cancelled_at,now()),
      cancellation_reason=trim(p_reason),
      cancelled_by_profile_id=v_profile,
      cancellation_actor_role='client',
      cancellation_source='client_direct',
      cancellation_request_id=null
  where id=v_booking.id
  returning * into v_booking;
  perform public.enqueue_user_notification(v_booking.lawyer_id,'ألغى العميل الحجز','ألغى طالب الاستشارة الحجز. السبب: '||trim(p_reason),'booking_cancelled_by_client',v_booking.id,'booking');
  perform public.enqueue_user_notification(v_booking.user_id,case when v_paid then 'تم إلغاء الحجز وبدء الاسترداد' else 'تم إلغاء الحجز' end,case when v_paid then 'تم إلغاء الحجز وتسجيل مبلغ الاستشارة للاسترداد. يمكنك متابعة التحويل من حساب الاستلام.' else 'تم إلغاء الحجز بنجاح.' end,'booking_cancelled',v_booking.id,'booking');
  return v_booking;
end $$;
revoke all on function public.request_client_booking_cancellation(uuid,text) from public,anon;
grant execute on function public.request_client_booking_cancellation(uuid,text) to authenticated;

create or replace function public.review_booking_cancellation(p_request_id uuid,p_decision text,p_penalty_rate numeric default null)
returns public.cancellation_requests
language plpgsql
security definer
set search_path=public
as $$
declare
  v_admin uuid;
  v_request public.cancellation_requests;
  v_booking public.bookings%rowtype;
  v_amount numeric(18,2);
  v_penalty_id uuid;
  v_paid boolean;
  v_target text;
begin
  if auth.uid() is null or not public.is_admin() then raise exception 'غير مصرح: هذه العملية للإدارة فقط'; end if;
  select id into v_admin from public.profiles where auth_id=auth.uid() limit 1;
  select * into v_request from public.cancellation_requests where id=p_request_id for update;
  if not found then raise exception 'طلب الإلغاء غير موجود'; end if;
  if v_request.status<>'بانتظار مراجعة الإدارة' then return v_request; end if;
  select * into v_booking from public.bookings where id=v_request.booking_id for update;
  if not found then raise exception 'الحجز غير موجود'; end if;

  if v_booking.status in ('ملغي','مسترد','بانتظار الاسترداد') then
    update public.cancellation_requests set status='تمت الموافقة',reviewed_at=now(),reviewed_by=v_admin,decision='الموافقة بدون غرامة',penalty_rate=coalesce(penalty_rate,0),penalty_amount=coalesce(penalty_amount,0) where id=v_request.id returning * into v_request;
    return v_request;
  end if;
  if v_booking.status in ('مكتمل','قيد التنفيذ') then
    update public.cancellation_requests set status='تم رفض الطلب',reviewed_at=now(),reviewed_by=v_admin,decision='رفض الإلغاء' where id=v_request.id returning * into v_request;
    return v_request;
  end if;
  if p_decision='رفض الإلغاء' then
    update public.cancellation_requests set status='تم رفض الطلب',reviewed_at=now(),reviewed_by=v_admin,decision=p_decision where id=v_request.id returning * into v_request;
    perform public.enqueue_user_notification(v_request.lawyer_id,'تم رفض طلب إلغاء الحجز','تم رفض طلب الإلغاء من الإدارة ويبقى الحجز فعالاً.','cancellation_request_rejected',v_request.id,'cancellation_request');
    return v_request;
  end if;

  select exists(select 1 from public.payments p where p.booking_id=v_booking.id and p.status='تم الدفع') into v_paid;
  v_target:=case when v_paid then 'بانتظار الاسترداد' else 'ملغي' end;

  if p_decision='الموافقة بدون غرامة' then
    update public.bookings set status=v_target,cancelled_at=coalesce(cancelled_at,now()),cancellation_reason=v_request.reason,cancelled_by_profile_id=v_request.lawyer_id,cancellation_actor_role='lawyer',cancellation_source='lawyer_cancellation_request',cancellation_request_id=v_request.id where id=v_booking.id;
    update public.cancellation_requests set status='تمت الموافقة',reviewed_at=now(),reviewed_by=v_admin,decision=p_decision,penalty_rate=0,penalty_amount=0 where id=v_request.id returning * into v_request;
    perform public.enqueue_user_notification(v_request.lawyer_id,'تمت الموافقة على إلغاء الحجز','وافقت الإدارة على طلب الإلغاء بدون غرامة.','cancellation_request_approved',v_request.id,'cancellation_request');
    perform public.enqueue_user_notification(v_request.client_id,case when v_paid then 'تم إلغاء الحجز وبدء الاسترداد' else 'تم إلغاء الحجز' end,case when v_paid then 'تم اعتماد إلغاء المحامي وتم تسجيل كامل مبلغ الاستشارة للاسترداد.' else 'تم اعتماد إلغاء الحجز من الإدارة.' end,'booking_cancelled_by_lawyer',v_booking.id,'booking');
    return v_request;
  end if;

  if p_decision<>'الموافقة مع غرامة' then raise exception 'نوع القرار غير صالح'; end if;
  if p_penalty_rate is null or p_penalty_rate<=0 or p_penalty_rate>100 then raise exception 'نسبة الغرامة يجب أن تكون أكبر من صفر ولا تتجاوز 100%%'; end if;
  v_amount:=round(coalesce(v_booking.price,0)::numeric*p_penalty_rate/100,2);
  if v_amount<=0 then raise exception 'قيمة الغرامة المحسوبة غير صالحة'; end if;

  update public.bookings set status=v_target,cancelled_at=coalesce(cancelled_at,now()),cancellation_reason=v_request.reason,cancelled_by_profile_id=v_request.lawyer_id,cancellation_actor_role='lawyer',cancellation_source='lawyer_cancellation_request',cancellation_request_id=v_request.id where id=v_booking.id;
  update public.cancellation_requests set status='بانتظار تحصيل الغرامة',reviewed_at=now(),reviewed_by=v_admin,decision=p_decision,penalty_rate=p_penalty_rate,penalty_amount=v_amount where id=v_request.id returning * into v_request;
  insert into public.lawyer_penalties(cancellation_request_id,booking_id,lawyer_id,client_id,amount,remaining_amount,currency) values(v_request.id,v_request.booking_id,v_request.lawyer_id,v_request.client_id,v_amount,v_amount,v_request.currency) returning id into v_penalty_id;
  insert into public.client_credits(user_id,booking_id,lawyer_id,amount,currency,transaction_type,status,reference_id) values(v_request.client_id,v_request.booking_id,v_request.lawyer_id,v_amount,v_request.currency,'تعويض إلغاء حجز من المحامي','بانتظار تحصيل الغرامة',v_penalty_id) on conflict (booking_id,transaction_type) where booking_id is not null do nothing;
  perform public.enqueue_user_notification(v_request.lawyer_id,'تم اعتماد الإلغاء مع غرامة','تم إلغاء الحجز وتسجيل غرامة مالية عليك.','lawyer_penalty_created',v_penalty_id,'lawyer_penalty');
  perform public.enqueue_user_notification(v_request.client_id,'تم اعتماد الإلغاء والتعويض',case when v_paid then 'سيُعاد كامل مبلغ الاستشارة إليك، إضافة إلى تعويض بقيمة '||to_char(v_amount,'FM999G999G999G990D00')||' '||v_request.currency||' بعد تحصيل الغرامة.' else 'تم اعتماد تعويض لك بقيمة '||to_char(v_amount,'FM999G999G999G990D00')||' '||v_request.currency||' بعد تحصيل الغرامة.' end,'client_credit_pending',v_penalty_id,'client_credit');
  return v_request;
exception when unique_violation then raise exception 'تم تنفيذ هذا القرار مسبقاً';
end $$;

create or replace function public.get_booking_cancellation_summary(p_booking_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_me uuid;
  v_b public.bookings%rowtype;
  v_req jsonb;
  v_credits jsonb;
  v_actor_name text;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  select id into v_me from public.profiles where auth_id=auth.uid() limit 1;
  select * into v_b from public.bookings where id=p_booking_id;
  if not found or ((v_me<>v_b.user_id and v_me<>v_b.lawyer_id) and not public.is_admin()) then raise exception 'غير مصرح'; end if;
  if v_b.cancelled_by_profile_id is not null then
    select coalesce(nullif(trim(p.full_name),''),case when v_b.cancellation_actor_role='lawyer' then 'المحامي' when v_b.cancellation_actor_role='client' then 'طالب الاستشارة' else 'الإدارة' end) into v_actor_name from public.profiles p where p.id=v_b.cancelled_by_profile_id;
  end if;
  select to_jsonb(x) into v_req from (select cr.id,cr.status,cr.reason,cr.decision,cr.penalty_rate,cr.penalty_amount,cr.currency,cr.requested_at,cr.reviewed_at from public.cancellation_requests cr where cr.booking_id=p_booking_id order by cr.requested_at desc limit 1) x;
  if v_me=v_b.user_id or public.is_admin() then
    select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'amount',c.amount,'currency',c.currency,'transaction_type',c.transaction_type,'status',c.status,'created_at',c.created_at,'settled_at',c.settled_at,'settlement_status',s.status,'provider_type',s.provider_type,'provider_reference',s.provider_reference,'paid_at',s.paid_at) order by c.created_at),'[]'::jsonb) into v_credits from public.client_credits c left join public.client_credit_settlements s on s.credit_id=c.id where c.booking_id=p_booking_id;
  else
    v_credits:='[]'::jsonb;
  end if;
  return jsonb_build_object('booking_status',v_b.status,'cancelled_at',v_b.cancelled_at,'cancelled_by_profile_id',v_b.cancelled_by_profile_id,'cancelled_by_name',v_actor_name,'cancellation_actor_role',v_b.cancellation_actor_role,'cancellation_reason',v_b.cancellation_reason,'cancellation_source',v_b.cancellation_source,'cancellation_request',v_req,'credits',v_credits);
end $$;
revoke all on function public.get_booking_cancellation_summary(uuid) from public,anon;
grant execute on function public.get_booking_cancellation_summary(uuid) to authenticated;

-- Refunds use the existing client-credit trigger when a paid cancelled booking
-- moves to بانتظار الاسترداد.

alter table public.financial_ledger drop constraint if exists financial_ledger_entry_type_check;
alter table public.financial_ledger add constraint financial_ledger_entry_type_check check(entry_type=any(array['payment_gross'::text,'platform_commission'::text,'lawyer_earning'::text,'lawyer_earning_settlement'::text,'lawyer_penalty'::text,'client_credit'::text,'refund'::text,'payout'::text]));

drop trigger if exists settle_penalties_after_payment on public.payments;

create or replace function public.settle_oldest_lawyer_penalties_for_completed_booking(p_booking_id uuid)
returns numeric
language plpgsql
security definer
set search_path=public
as $$
declare
  v_booking public.bookings%rowtype;
  v_financial public.payment_financials%rowtype;
  v_penalty public.lawyer_penalties%rowtype;
  v_available numeric(18,2);
  v_take numeric(18,2);
  v_total numeric(18,2):=0;
  v_settlement_id uuid;
  v_collected numeric(18,2);
begin
  select * into v_booking from public.bookings where id=p_booking_id for update;
  if not found or v_booking.status<>'مكتمل' or v_booking.lawyer_id is null then return 0; end if;
  for v_financial in select pf.* from public.payment_financials pf where pf.booking_id=p_booking_id and pf.status='pending' order by pf.created_at for update loop
    v_available:=greatest(0,coalesce(v_financial.lawyer_net_amount,0));
    while v_available>0 loop
      select * into v_penalty from public.lawyer_penalties where lawyer_id=v_booking.lawyer_id and remaining_amount>0 order by created_at asc limit 1 for update;
      exit when not found;
      if exists(select 1 from public.lawyer_penalty_settlements where penalty_id=v_penalty.id and payment_id=v_financial.payment_id) then exit; end if;
      v_take:=least(v_available,v_penalty.remaining_amount);
      if v_take<=0 then exit; end if;
      insert into public.lawyer_penalty_settlements(penalty_id,payment_id,lawyer_id,client_id,booking_id,amount,currency) values(v_penalty.id,v_financial.payment_id,v_penalty.lawyer_id,v_penalty.client_id,v_penalty.booking_id,v_take,v_penalty.currency) returning id into v_settlement_id;
      update public.lawyer_penalties set remaining_amount=greatest(0,remaining_amount-v_take),status=case when remaining_amount-v_take<=0 then 'تم التحصيل' else 'تسوية جزئية' end,settled_at=case when remaining_amount-v_take<=0 then now() else settled_at end where id=v_penalty.id;
      select coalesce(sum(s.amount),0) into v_collected from public.lawyer_penalty_settlements s where s.penalty_id=v_penalty.id;
      update public.client_credits set status=case when amount<=v_collected then 'مستحق' else status end,settled_at=case when amount<=v_collected then now() else settled_at end,reference_id=case when amount<=v_collected then v_settlement_id else reference_id end where booking_id=v_penalty.booking_id and transaction_type='تعويض إلغاء حجز من المحامي';
      update public.payment_financials set penalty_amount=penalty_amount+v_take,client_credit_amount=client_credit_amount+v_take,lawyer_net_amount=greatest(0,lawyer_net_amount-v_take),updated_at=now() where payment_id=v_financial.payment_id;
      update public.lawyer_wallets set pending_balance=greatest(0,pending_balance-v_take),lifetime_earned=greatest(0,lifetime_earned-v_take),updated_at=now() where lawyer_id=v_booking.lawyer_id;
      insert into public.financial_ledger(payment_id,booking_id,client_id,lawyer_id,entry_type,amount,currency,reference_id,idempotency_key,metadata) values(v_financial.payment_id,p_booking_id,v_penalty.client_id,v_booking.lawyer_id,'lawyer_penalty',v_take,v_penalty.currency,v_settlement_id,'penalty:'||v_settlement_id,jsonb_build_object('source','completed_consultation_earning','penalty_booking_id',v_penalty.booking_id)) on conflict(idempotency_key) do nothing;
      insert into public.financial_ledger(payment_id,booking_id,client_id,lawyer_id,entry_type,amount,currency,reference_id,idempotency_key,metadata) values(v_financial.payment_id,p_booking_id,v_penalty.client_id,v_booking.lawyer_id,'client_credit',v_take,v_penalty.currency,v_settlement_id,'credit:'||v_settlement_id,jsonb_build_object('source','lawyer_penalty','penalty_booking_id',v_penalty.booking_id)) on conflict(idempotency_key) do nothing;
      v_available:=v_available-v_take;
      v_total:=v_total+v_take;
    end loop;
  end loop;
  return v_total;
end $$;

create or replace function public.release_lawyer_earnings_for_completed_booking(p_booking_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare
  v_booking public.bookings%rowtype;
  v_financial record;
  moved numeric(18,2);
begin
  select * into v_booking from public.bookings where id=p_booking_id for update;
  if not found or v_booking.status<>'مكتمل' or v_booking.lawyer_id is null then return; end if;
  for v_financial in select pf.payment_id,pf.lawyer_id,pf.lawyer_net_amount,pf.currency from public.payment_financials pf where pf.booking_id=p_booking_id and pf.status='pending' for update loop
    moved:=greatest(0,coalesce(v_financial.lawyer_net_amount,0));
    update public.lawyer_wallets set pending_balance=greatest(0,pending_balance-moved),available_balance=available_balance+moved,updated_at=now() where lawyer_id=v_financial.lawyer_id;
    if not found then raise exception 'محفظة المحامي غير موجودة'; end if;
    update public.payment_financials set status='settled',updated_at=now() where payment_id=v_financial.payment_id and status='pending';
    insert into public.financial_ledger(payment_id,booking_id,lawyer_id,entry_type,amount,currency,idempotency_key,metadata) values(v_financial.payment_id,p_booking_id,v_financial.lawyer_id,'lawyer_earning_settlement',moved,v_financial.currency,'payment:'||v_financial.payment_id||':release',jsonb_build_object('source','consultation_completed')) on conflict(idempotency_key) do nothing;
  end loop;
end $$;

create or replace function public.track_completed_consultation()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  if old.status<>'مكتمل' and new.status='مكتمل' then
    new.completed_at:=coalesce(new.completed_at,now());
    update public.lawyer_profiles set completed_consultations=completed_consultations+1 where profile_id=new.lawyer_id;
  end if;
  if new.status='ملغي' then new.cancelled_at:=coalesce(new.cancelled_at,now()); end if;
  return new;
end $$;

create or replace function public.finalize_lawyer_financials_after_completed_booking()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  if old.status is distinct from new.status and new.status='مكتمل' then
    perform public.settle_oldest_lawyer_penalties_for_completed_booking(new.id);
    perform public.release_lawyer_earnings_for_completed_booking(new.id);
  end if;
  return new;
end $$;
drop trigger if exists trg_finalize_lawyer_financials_after_completed_booking on public.bookings;
create trigger trg_finalize_lawyer_financials_after_completed_booking after update of status on public.bookings for each row execute function public.finalize_lawyer_financials_after_completed_booking();

create or replace function public.admin_review_no_show_request(p_request_id uuid,p_decision text,p_note text default null)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare
  v_admin uuid;
  v_request public.no_show_review_requests%rowtype;
  v_booking public.bookings%rowtype;
  v_is_paid boolean;
  v_restore_status text;
  v_restore_consultation text;
begin
  select id into v_admin from public.profiles where auth_id=auth.uid() and role='admin' limit 1;
  if v_admin is null then raise exception 'غير مصرح'; end if;
  if p_decision not in ('approved','rejected') then raise exception 'قرار غير صالح'; end if;
  select * into v_request from public.no_show_review_requests where id=p_request_id for update;
  if not found then raise exception 'الطلب غير موجود'; end if;
  if v_request.status<>'pending' then raise exception 'تمت مراجعة الطلب مسبقاً'; end if;
  select * into v_booking from public.bookings where id=v_request.booking_id for update;
  if not found then raise exception 'الحجز المرتبط بالطلب غير موجود'; end if;
  if v_booking.status<>'بانتظار مراجعة عدم الحضور' then raise exception 'الحجز لم يعد بانتظار مراجعة عدم الحضور'; end if;
  update public.no_show_review_requests set status=p_decision,reviewed_by=v_admin,review_note=nullif(trim(coalesce(p_note,'')),''),reviewed_at=now() where id=p_request_id;
  if p_decision='rejected' then
    v_restore_status:=coalesce(nullif(v_request.previous_booking_status,''),'مؤكد');
    v_restore_consultation:=coalesce(nullif(v_request.previous_consultation_status,''),case when v_restore_status='قيد التنفيذ' then 'قيد التنفيذ' else 'لم تبدأ' end);
    update public.bookings set status=v_restore_status,consultation_status=v_restore_consultation where id=v_booking.id;
    perform public.enqueue_user_notification(v_request.reporter_id,'تم رفض بلاغ عدم الحضور','راجعت الإدارة البلاغ وتم رفضه، وأُعيدت الاستشارة إلى حالتها السابقة.','no_show_rejected',v_booking.id,'booking');
    return;
  end if;
  select exists(select 1 from public.payments where booking_id=v_booking.id and status='تم الدفع') into v_is_paid;
  if v_request.reason='عدم حضور طالب الاستشارة' then
    update public.bookings set status='مكتمل',consultation_status='عدم حضور طالب الاستشارة - تمت الموافقة',completed_at=now() where id=v_booking.id;
    perform public.enqueue_user_notification(v_booking.lawyer_id,'تم اعتماد بلاغ عدم الحضور','تم اعتماد عدم حضور طالب الاستشارة وإنهاء الحجز وفق القرار الإداري.','no_show_approved',v_booking.id,'booking');
    perform public.enqueue_user_notification(v_booking.user_id,'تم اعتماد بلاغ عدم الحضور','اعتمدت الإدارة بلاغ عدم الحضور الخاص بهذه الاستشارة.','no_show_approved',v_booking.id,'booking');
  elsif v_request.reason='عدم حضور المحامي' then
    update public.bookings set status=case when v_is_paid then 'بانتظار الاسترداد' else 'ملغي' end,consultation_status='عدم حضور المحامي - تمت الموافقة',cancelled_at=now(),cancellation_reason='عدم حضور المحامي',cancelled_by_profile_id=v_booking.lawyer_id,cancellation_actor_role='lawyer',cancellation_source='no_show' where id=v_booking.id;
    perform public.enqueue_user_notification(v_booking.user_id,'تم اعتماد عدم حضور المحامي',case when v_is_paid then 'تم اعتماد البلاغ وإنشاء طلب استرداد كامل لقيمة الاستشارة.' else 'تم اعتماد البلاغ وإلغاء الاستشارة.' end,'no_show_approved',v_booking.id,'booking');
    perform public.enqueue_user_notification(v_booking.lawyer_id,'تم اعتماد بلاغ عدم الحضور','اعتمدت الإدارة بلاغ عدم الحضور المقدم ضدك لهذه الاستشارة.','no_show_approved',v_booking.id,'booking');
  else
    raise exception 'نوع بلاغ عدم الحضور غير معروف';
  end if;
end $$;

update public.bookings set cancellation_actor_role='lawyer',cancellation_source='no_show',cancellation_reason='عدم حضور المحامي',cancelled_by_profile_id=lawyer_id where consultation_status='عدم حضور المحامي - تمت الموافقة' and status in ('ملغي','بانتظار الاسترداد','مسترد') and (cancellation_source is null or cancellation_source='legacy_cancellation');

create or replace function public.sync_lawyer_slot_availability(p_slot_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare v_has_booking boolean;
begin
  select exists(select 1 from public.bookings b join public.lawyer_availability_slots s on s.lawyer_id=b.lawyer_id where s.id=p_slot_id and b.scheduled_at between s.starts_at-interval '5 seconds' and s.starts_at+interval '5 seconds' and b.status not in ('ملغي','ملغى','مسترد','مكتمل','بانتظار الاسترداد')) into v_has_booking;
  update public.lawyer_availability_slots set is_available=not v_has_booking where id=p_slot_id;
end $$;

do $$
declare r record;
begin
  for r in select id from public.lawyer_availability_slots loop
    perform public.sync_lawyer_slot_availability(r.id);
  end loop;
end $$;
