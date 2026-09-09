-- Client cancellations are final for the slot, but the financial outcome is reviewed by admin.
-- Convincing reason: 100% refund. Unconvincing reason: 99% refund + 1% lawyer compensation.

alter table public.cancellation_requests
  add column if not exists requester_role text not null default 'lawyer';

do $$ begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.cancellation_requests'::regclass
      and conname='cancellation_requests_requester_role_chk'
  ) then
    alter table public.cancellation_requests
      add constraint cancellation_requests_requester_role_chk
      check (requester_role in ('lawyer','client'));
  end if;
end $$;

create table if not exists public.client_cancellation_compensations (
  id uuid primary key default gen_random_uuid(),
  cancellation_request_id uuid not null unique references public.cancellation_requests(id) on delete restrict,
  booking_id uuid not null references public.bookings(id) on delete restrict,
  client_id uuid not null references public.profiles(id) on delete restrict,
  lawyer_id uuid not null references public.profiles(id) on delete restrict,
  gross_amount numeric(18,2) not null check (gross_amount > 0),
  penalty_rate numeric(6,2) not null default 1 check (penalty_rate > 0 and penalty_rate <= 100),
  amount numeric(18,2) not null check (amount > 0),
  currency text not null default 'IQD',
  status text not null default 'credited' check (status in ('credited','reversed')),
  created_at timestamptz not null default now(),
  credited_at timestamptz not null default now()
);

alter table public.client_cancellation_compensations enable row level security;
revoke all on public.client_cancellation_compensations from anon, authenticated;
grant select on public.client_cancellation_compensations to authenticated;

drop policy if exists client_cancellation_compensations_select_participants on public.client_cancellation_compensations;
create policy client_cancellation_compensations_select_participants
on public.client_cancellation_compensations for select to authenticated
using (
  public.is_admin()
  or exists (
    select 1 from public.profiles p
    where p.auth_id=auth.uid() and p.id in (client_id,lawyer_id)
  )
);

alter table public.financial_ledger drop constraint if exists financial_ledger_entry_type_check;
alter table public.financial_ledger add constraint financial_ledger_entry_type_check
check (entry_type = any (array[
  'payment_gross','platform_commission','lawyer_earning','lawyer_earning_settlement',
  'lawyer_penalty','client_credit','refund','payout','lawyer_cancellation_compensation'
]));

create or replace function public.finalize_client_cancellation_financials(p_booking_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare
  v_req public.cancellation_requests%rowtype;
  v_booking public.bookings%rowtype;
  v_payment public.payments%rowtype;
  v_penalty numeric(18,2):=0;
  v_refund numeric(18,2):=0;
  v_comp_id uuid;
begin
  select * into v_req
  from public.cancellation_requests
  where booking_id=p_booking_id
    and requester_role='client'
    and decision in ('الموافقة بدون غرامة','الموافقة مع غرامة')
  order by requested_at desc limit 1;
  if not found then return; end if;

  select * into v_booking from public.bookings where id=p_booking_id;
  if not found then return; end if;

  select * into v_payment
  from public.payments
  where booking_id=p_booking_id and status='تم الدفع'
  order by created_at desc limit 1;
  if not found then return; end if;

  if v_req.decision='الموافقة مع غرامة' then
    v_penalty:=round(v_payment.amount*0.01,2);
  end if;
  v_refund:=greatest(0,v_payment.amount-v_penalty);

  if v_refund>0 then
    insert into public.client_credits(user_id,booking_id,lawyer_id,amount,currency,transaction_type,status,reference_id)
    values(v_booking.user_id,v_booking.id,v_booking.lawyer_id,v_refund,coalesce(v_req.currency,'IQD'),'استرداد قيمة استشارة','مستحق',v_payment.id)
    on conflict (booking_id,transaction_type) where booking_id is not null
    do update set amount=excluded.amount,reference_id=excluded.reference_id
    where public.client_credits.status in ('مستحق','pending','قيد الانتظار');
  end if;

  if v_penalty>0 then
    insert into public.client_cancellation_compensations(
      cancellation_request_id,booking_id,client_id,lawyer_id,gross_amount,penalty_rate,amount,currency
    ) values(v_req.id,v_booking.id,v_booking.user_id,v_booking.lawyer_id,v_payment.amount,1,v_penalty,coalesce(v_req.currency,'IQD'))
    on conflict (cancellation_request_id) do nothing
    returning id into v_comp_id;

    if v_comp_id is not null then
      insert into public.lawyer_wallets(lawyer_id,currency)
      values(v_booking.lawyer_id,coalesce(v_req.currency,'IQD'))
      on conflict (lawyer_id) do nothing;
      update public.lawyer_wallets
      set available_balance=available_balance+v_penalty,
          lifetime_earned=lifetime_earned+v_penalty,
          updated_at=now()
      where lawyer_id=v_booking.lawyer_id;
      insert into public.financial_ledger(
        payment_id,booking_id,client_id,lawyer_id,entry_type,amount,currency,reference_id,idempotency_key,metadata
      ) values(
        v_payment.id,v_booking.id,v_booking.user_id,v_booking.lawyer_id,
        'lawyer_cancellation_compensation',v_penalty,coalesce(v_req.currency,'IQD'),v_req.id,
        'client-cancellation:'||v_req.id||':lawyer-compensation',
        jsonb_build_object('penalty_rate',1,'gross_payment',v_payment.amount,'reason',v_req.reason)
      ) on conflict (idempotency_key) do nothing;
    end if;
  end if;

  update public.cancellation_requests
  set penalty_rate=case when decision='الموافقة مع غرامة' then 1 else 0 end,
      penalty_amount=case when decision='الموافقة مع غرامة' then v_penalty else 0 end,
      status=case when decision='الموافقة مع غرامة' then 'تمت الموافقة مع غرامة' else 'تمت الموافقة' end
  where id=v_req.id;
end $$;
revoke all on function public.finalize_client_cancellation_financials(uuid) from public,anon,authenticated;

create or replace function public.ensure_client_refund_credit_for_booking()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_payment public.payments%rowtype;
  v_currency text:='IQD';
  v_has_account boolean:=false;
begin
  if new.status='بانتظار الاسترداد' and old.status is distinct from new.status then
    if new.cancellation_source='client_cancellation_request' then return new; end if;
    select * into v_payment from public.payments where booking_id=new.id and status='تم الدفع' order by created_at desc limit 1;
    if found then
      select coalesce(currency,'IQD') into v_currency from public.platform_financial_settings where id=true;
      insert into public.client_credits(user_id,booking_id,lawyer_id,amount,currency,transaction_type,status,reference_id)
      values(new.user_id,new.id,new.lawyer_id,v_payment.amount,v_currency,'استرداد قيمة استشارة','مستحق',v_payment.id)
      on conflict (booking_id,transaction_type) where booking_id is not null do nothing;
      select exists(select 1 from public.client_payout_accounts a where a.user_id=new.user_id and a.is_default=true and a.account_number<>'REMOVED' and nullif(trim(coalesce(a.account_number,'')),'') is not null) into v_has_account;
      perform public.enqueue_user_notification(new.user_id,
        case when v_has_account then 'تم إنشاء طلب استرداد' else 'أضف حساب استلام لإكمال الاسترداد' end,
        case when v_has_account then 'تم تسجيل قيمة الاستشارة للاسترداد بعد اكتمال قرار الإلغاء. ستقوم الإدارة بتحويلها إلى حساب الاستلام المرتبط.' else 'تم تسجيل قيمة الاستشارة للاسترداد بعد اكتمال قرار الإلغاء، لكن لا يوجد حساب استلام مرتبط. أضف حساب استلام لإكمال التحويل.' end,
        case when v_has_account then 'client_refund_pending' else 'client_refund_account_required' end,
        new.id,'booking');
    end if;
  end if;
  return new;
end $$;

create or replace function public.reconcile_pending_cancellation_request_for_booking()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  if new.status is distinct from old.status then
    if new.status in ('ملغي','مسترد') then
      update public.cancellation_requests
      set status='تمت الموافقة',reviewed_at=coalesce(reviewed_at,now()),decision=coalesce(decision,'الموافقة بدون غرامة'),penalty_rate=coalesce(penalty_rate,0),penalty_amount=coalesce(penalty_amount,0)
      where booking_id=new.id and requester_role='lawyer' and status='بانتظار مراجعة الإدارة';
    elsif new.status in ('قيد التنفيذ','مكتمل') then
      update public.cancellation_requests
      set status='تم رفض الطلب',reviewed_at=coalesce(reviewed_at,now()),decision=coalesce(decision,'رفض الإلغاء')
      where booking_id=new.id and requester_role='lawyer' and status='بانتظار مراجعة الإدارة';
    end if;
  end if;
  return new;
end $$;

create or replace function public.request_client_booking_cancellation(p_booking_id uuid,p_reason text)
returns public.bookings
language plpgsql
security definer
set search_path=public
as $$
declare
  v_profile uuid; v_booking public.bookings%rowtype; v_paid boolean; v_pending_manual boolean;
  v_new_status text; v_request public.cancellation_requests%rowtype; v_admin record;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if nullif(trim(coalesce(p_reason,'')),'') is null then raise exception 'سبب الإلغاء إلزامي'; end if;
  select id into v_profile from public.profiles where auth_id=auth.uid() limit 1;
  select * into v_booking from public.bookings where id=p_booking_id for update;
  if not found then raise exception 'الحجز غير موجود'; end if;
  if v_booking.user_id<>v_profile then raise exception 'غير مصرح بهذا الإجراء'; end if;
  if v_booking.status not in ('قيد انتظار الدفع','قيد معالجة الدفع','قيد مراجعة المحامي','بانتظار التأكيد','مؤكد') then raise exception 'لا يمكن إلغاء الحجز في حالته الحالية'; end if;
  if v_booking.scheduled_at is not null and v_booking.scheduled_at<=now() then raise exception 'لا يمكن إلغاء موعد بدأ أو انتهى'; end if;
  if exists(select 1 from public.cancellation_requests where booking_id=p_booking_id and requester_role='client' and status='بانتظار مراجعة الإدارة') then raise exception 'طلب الإلغاء قيد مراجعة الإدارة بالفعل'; end if;

  select exists(select 1 from public.payments p where p.booking_id=v_booking.id and p.status='تم الدفع') into v_paid;
  select exists(select 1 from public.payments p where p.booking_id=v_booking.id and p.status='قيد معالجة الدفع' and coalesce(p.is_manual,false) and nullif(trim(coalesce(p.receipt_url,'')),'') is not null) into v_pending_manual;
  v_new_status:=case when v_paid or v_pending_manual then 'بانتظار الاسترداد' else 'ملغي' end;

  insert into public.cancellation_requests(booking_id,lawyer_id,client_id,reason,requester_role)
  values(v_booking.id,v_booking.lawyer_id,v_booking.user_id,trim(p_reason),'client') returning * into v_request;

  update public.bookings set status=v_new_status,cancelled_at=coalesce(cancelled_at,now()),cancellation_reason=trim(p_reason),cancelled_by_profile_id=v_profile,cancellation_actor_role='client',cancellation_source='client_cancellation_request',cancellation_request_id=v_request.id
  where id=v_booking.id returning * into v_booking;

  perform public.enqueue_user_notification(v_booking.lawyer_id,'ألغى العميل الحجز','ألغى طالب الاستشارة الحجز. السبب: '||trim(p_reason)||'. ستراجع الإدارة السبب لتحديد ما إذا كانت هناك غرامة 1% لصالحك.','booking_cancelled_by_client',v_booking.id,'booking');
  perform public.enqueue_user_notification(v_booking.user_id,'طلب الإلغاء قيد مراجعة الإدارة',case when v_paid or v_pending_manual then 'تم إلغاء الموعد وتحريره للحجز من جديد. لم يتم تحديد مبلغ الاسترداد بعد؛ ستراجع الإدارة السبب، وقد يكون الاسترداد كاملاً أو يُستقطع 1% كغرامة للمحامي إذا اعتُبر السبب غير مقنع.' else 'تم إلغاء الموعد. ستراجع الإدارة سبب الإلغاء، ولا توجد دفعة مؤكدة حالياً لاستردادها.' end,'client_cancellation_pending_review',v_booking.id,'booking');
  for v_admin in select id from public.profiles where role::text in ('admin','super_admin') loop
    perform public.enqueue_user_notification(v_admin.id,'طلب إلغاء من العميل يحتاج مراجعة','ألغى طالب الاستشارة حجزاً، ويجب تقييم السبب لتحديد الاسترداد الكامل أو تطبيق غرامة 1%.','client_cancellation_admin_review',v_request.id,'cancellation_request');
  end loop;
  return v_booking;
end $$;
revoke all on function public.request_client_booking_cancellation(uuid,text) from public,anon;
grant execute on function public.request_client_booking_cancellation(uuid,text) to authenticated;

create or replace function public.get_booking_cancellation_summary(p_booking_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare v_me uuid; v_b public.bookings%rowtype; v_req jsonb; v_credits jsonb; v_actor_name text; v_has_payout boolean:=false; v_payout_provider text;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  select id into v_me from public.profiles where auth_id=auth.uid() limit 1;
  select * into v_b from public.bookings where id=p_booking_id;
  if not found or ((v_me<>v_b.user_id and v_me<>v_b.lawyer_id) and not public.is_admin()) then raise exception 'غير مصرح'; end if;
  if v_b.cancelled_by_profile_id is not null then select coalesce(nullif(trim(p.full_name),''),case when v_b.cancellation_actor_role='lawyer' then 'المحامي' when v_b.cancellation_actor_role='client' then 'طالب الاستشارة' else 'الإدارة' end) into v_actor_name from public.profiles p where p.id=v_b.cancelled_by_profile_id; end if;
  select to_jsonb(x) into v_req from (select cr.id,cr.status,cr.reason,cr.decision,cr.penalty_rate,cr.penalty_amount,cr.currency,cr.requested_at,cr.reviewed_at,cr.requester_role from public.cancellation_requests cr where cr.booking_id=p_booking_id order by cr.requested_at desc limit 1) x;
  if v_me=v_b.user_id or public.is_admin() then
    select exists(select 1 from public.client_payout_accounts a where a.user_id=v_b.user_id and a.is_default=true and nullif(trim(coalesce(a.account_number,'')),'') is not null and a.account_number<>'REMOVED') into v_has_payout;
    select a.provider_type into v_payout_provider from public.client_payout_accounts a where a.user_id=v_b.user_id and a.is_default=true and a.account_number<>'REMOVED' limit 1;
    select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'amount',c.amount,'currency',c.currency,'transaction_type',c.transaction_type,'status',c.status,'created_at',c.created_at,'settled_at',c.settled_at,'settlement_status',s.status,'provider_type',s.provider_type,'provider_reference',s.provider_reference,'paid_at',s.paid_at) order by c.created_at),'[]'::jsonb) into v_credits from public.client_credits c left join public.client_credit_settlements s on s.credit_id=c.id where c.booking_id=p_booking_id;
  else v_credits:='[]'::jsonb; end if;
  return jsonb_build_object('booking_status',v_b.status,'cancelled_at',v_b.cancelled_at,'cancelled_by_profile_id',v_b.cancelled_by_profile_id,'cancelled_by_name',v_actor_name,'cancellation_actor_role',v_b.cancellation_actor_role,'cancellation_reason',v_b.cancellation_reason,'cancellation_source',v_b.cancellation_source,'cancellation_request',v_req,'credits',v_credits,'has_payout_account',v_has_payout,'payout_provider',v_payout_provider);
end $$;

-- The existing review_booking_cancellation function is extended on production so that requester_role='client'
-- uses the fixed 1% rule and requester_role='lawyer' keeps the existing lawyer-cancellation compensation flow.
-- The existing admin_review_manual_payment function is extended to call finalize_client_cancellation_financials
-- after a manual payment is approved.
