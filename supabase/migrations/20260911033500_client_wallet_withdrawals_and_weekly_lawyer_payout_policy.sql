create or replace function public.add_iraqi_business_days(p_start timestamptz,p_days integer)
returns timestamptz
language plpgsql
stable
set search_path=pg_catalog
as $$
declare
  v_result timestamptz:=p_start;
  v_added integer:=0;
  v_dow integer;
begin
  if p_days is null or p_days<=0 then return p_start; end if;
  while v_added<p_days loop
    v_result:=v_result+interval '1 day';
    v_dow:=extract(dow from (v_result at time zone 'Asia/Baghdad'))::integer;
    if v_dow not in (5,6) then v_added:=v_added+1; end if;
  end loop;
  return v_result;
end;
$$;

create or replace function public.next_lawyer_payout_date(p_frequency text,p_weekday integer,p_from timestamptz default now())
returns date
language plpgsql
stable
set search_path=pg_catalog
as $$
declare
  v_date date := (p_from at time zone 'Asia/Baghdad')::date;
  v_dow integer := extract(dow from (p_from at time zone 'Asia/Baghdad'))::integer;
  v_delta integer;
begin
  if p_frequency='daily' then return v_date; end if;
  if p_frequency='weekly' then
    v_delta:=((p_weekday-v_dow)+7)%7;
    return v_date+v_delta;
  end if;
  return null;
end;
$$;

alter table public.lawyer_payout_requests
  add column if not exists financial_policy_version integer,
  add column if not exists scheduled_payout_date date;

create table if not exists public.client_wallet_withdrawal_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  amount numeric(18,2) not null check (amount>0),
  transfer_fee numeric(18,2) not null default 0 check (transfer_fee>=0),
  net_amount numeric(18,2) not null check (net_amount>0),
  currency text not null default 'IQD',
  payout_account_id uuid references public.client_payout_accounts(id) on delete set null,
  provider_type text not null,
  account_holder_name text not null,
  account_number text not null,
  bank_name text,
  fee_mode text not null check (fee_mode in ('none','actual_transfer_fee')),
  financial_policy_version integer not null,
  processing_min_business_days integer not null,
  processing_max_business_days integer not null,
  processing_deadline_at timestamptz not null,
  status text not null default 'pending_review' check (status in ('pending_review','processing','paid','rejected','cancelled')),
  provider_reference text,
  admin_note text,
  rejection_reason text,
  requested_at timestamptz not null default now(),
  processing_started_at timestamptz,
  processed_at timestamptz,
  paid_at timestamptz,
  rejected_at timestamptz,
  cancelled_at timestamptz,
  processed_by uuid references public.profiles(id) on delete set null,
  check (processing_min_business_days>=0 and processing_max_business_days>=processing_min_business_days and processing_max_business_days<=30),
  check (transfer_fee<=amount),
  check (net_amount<=amount)
);

create index if not exists idx_client_wallet_withdrawals_user_created
  on public.client_wallet_withdrawal_requests(user_id,requested_at desc);
create index if not exists idx_client_wallet_withdrawals_status_deadline
  on public.client_wallet_withdrawal_requests(status,processing_deadline_at);

alter table public.client_wallet_withdrawal_requests enable row level security;
drop policy if exists client_wallet_withdrawals_select_own_or_admin on public.client_wallet_withdrawal_requests;
create policy client_wallet_withdrawals_select_own_or_admin on public.client_wallet_withdrawal_requests
for select to authenticated using (
  user_id=(select id from public.profiles where auth_id=(select auth.uid()) limit 1)
  or (select public.is_admin())
);
revoke insert,update,delete on public.client_wallet_withdrawal_requests from anon,authenticated;
grant select on public.client_wallet_withdrawal_requests to authenticated;

do $$
begin
  if not exists(
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='client_wallet_withdrawal_requests'
  ) then
    alter publication supabase_realtime add table public.client_wallet_withdrawal_requests;
  end if;
end $$;

create or replace function public.request_client_wallet_withdrawal(p_amount numeric)
returns uuid
language plpgsql
security definer
set search_path=public,pg_catalog
as $$
declare
  v_user_id uuid;
  v_client_name text;
  v_wallet public.client_wallets%rowtype;
  v_settings public.platform_financial_settings%rowtype;
  v_account public.client_payout_accounts%rowtype;
  v_request_id uuid;
  v_balance numeric(18,2);
  v_deadline timestamptz;
  v_admin record;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  select id,coalesce(nullif(trim(full_name),''),'طالب الاستشارة') into v_user_id,v_client_name
  from public.profiles where auth_id=auth.uid() and role::text='user' and status::text='active' limit 1;
  if v_user_id is null then raise exception 'هذه العملية متاحة لطالب الاستشارة فقط'; end if;

  select * into v_settings from public.platform_financial_settings where id=true;
  if not coalesce(v_settings.client_withdrawal_enabled,false) then raise exception 'سحب الرصيد غير متاح حالياً'; end if;
  if p_amount is null or p_amount<=0 then raise exception 'مبلغ السحب غير صالح'; end if;
  if p_amount<v_settings.client_withdrawal_min_amount then
    raise exception using message='الحد الأدنى لسحب الرصيد هو '||trim(to_char(v_settings.client_withdrawal_min_amount,'FM999999999999990'))||' د.ع';
  end if;

  select * into v_account from public.client_payout_accounts
  where user_id=v_user_id and is_default=true and account_number<>'REMOVED'
  order by updated_at desc limit 1;
  if not found then raise exception 'أضف حساب استلام من طرق الدفع قبل طلب سحب الرصيد'; end if;

  if exists(
    select 1 from public.client_wallet_withdrawal_requests
    where user_id=v_user_id and status in ('pending_review','processing')
  ) then raise exception 'لديك طلب سحب قيد المعالجة بالفعل'; end if;

  select * into v_wallet from public.client_wallets where user_id=v_user_id for update;
  if not found then raise exception 'محفظة العميل غير موجودة'; end if;
  if v_wallet.available_balance<p_amount then raise exception 'الرصيد المتاح غير كافٍ للسحب'; end if;

  v_deadline:=public.add_iraqi_business_days(now(),v_settings.client_withdrawal_processing_max_business_days);
  insert into public.client_wallet_withdrawal_requests(
    user_id,amount,transfer_fee,net_amount,currency,payout_account_id,
    provider_type,account_holder_name,account_number,bank_name,fee_mode,
    financial_policy_version,processing_min_business_days,processing_max_business_days,processing_deadline_at,status
  ) values(
    v_user_id,p_amount,0,p_amount,coalesce(v_settings.currency,'IQD'),v_account.id,
    v_account.provider_type,v_account.account_holder_name,v_account.account_number,v_account.bank_name,v_settings.client_withdrawal_fee_mode,
    v_settings.financial_policy_version,v_settings.client_withdrawal_processing_min_business_days,
    v_settings.client_withdrawal_processing_max_business_days,v_deadline,'pending_review'
  ) returning id into v_request_id;

  update public.client_wallets
  set available_balance=available_balance-p_amount,
      held_balance=held_balance+p_amount,
      updated_at=now()
  where user_id=v_user_id
  returning available_balance into v_balance;

  insert into public.client_wallet_ledger(
    user_id,amount,entry_type,balance_after,idempotency_key,metadata
  ) values(
    v_user_id,-p_amount,'withdrawal_hold',v_balance,'withdrawal:'||v_request_id||':hold',
    jsonb_build_object('withdrawal_request_id',v_request_id,'policy_version',v_settings.financial_policy_version,
                       'provider_type',v_account.provider_type,'processing_deadline_at',v_deadline)
  ) on conflict(idempotency_key) do nothing;

  perform public.enqueue_user_notification(
    v_user_id,'تم إرسال طلب سحب الرصيد',
    'تم حجز '||trim(to_char(p_amount,'FM999999999999990'))||' د.ع من رصيدك المتاح. المدة المتوقعة للمعالجة '
      ||v_settings.client_withdrawal_processing_min_business_days||'–'||v_settings.client_withdrawal_processing_max_business_days||' أيام عمل.',
    'client_wallet_withdrawal',v_request_id,'client_wallet_withdrawal'
  );

  for v_admin in select id from public.profiles where role::text='admin' loop
    perform public.enqueue_user_notification(
      v_admin.id,'طلب سحب رصيد من '||v_client_name,
      'المبلغ: '||trim(to_char(p_amount,'FM999999999999990'))||' د.ع • وسيلة الاستلام: '||v_account.provider_type,
      'client_wallet_withdrawal_admin',v_request_id,'client_wallet_withdrawal'
    );
  end loop;

  return v_request_id;
end;
$$;
revoke all on function public.request_client_wallet_withdrawal(numeric) from public,anon;
grant execute on function public.request_client_wallet_withdrawal(numeric) to authenticated;

create or replace function public.cancel_client_wallet_withdrawal(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path=public,pg_catalog
as $$
declare
  v_user_id uuid;
  v_request public.client_wallet_withdrawal_requests%rowtype;
  v_balance numeric(18,2);
begin
  select id into v_user_id from public.profiles where auth_id=auth.uid() and role::text='user' limit 1;
  if v_user_id is null then raise exception 'غير مصرح'; end if;
  select * into v_request from public.client_wallet_withdrawal_requests
  where id=p_request_id and user_id=v_user_id for update;
  if not found then raise exception 'طلب السحب غير موجود'; end if;
  if v_request.status<>'pending_review' then raise exception 'لا يمكن إلغاء الطلب بعد بدء معالجته'; end if;

  update public.client_wallets
  set held_balance=held_balance-v_request.amount,
      available_balance=available_balance+v_request.amount,
      updated_at=now()
  where user_id=v_user_id and held_balance>=v_request.amount
  returning available_balance into v_balance;
  if not found then raise exception 'تعذر تحرير المبلغ المحجوز'; end if;

  update public.client_wallet_withdrawal_requests
  set status='cancelled',cancelled_at=now(),processed_at=now()
  where id=p_request_id;

  insert into public.client_wallet_ledger(user_id,amount,entry_type,balance_after,idempotency_key,metadata)
  values(v_user_id,v_request.amount,'withdrawal_release',v_balance,'withdrawal:'||p_request_id||':cancel',
         jsonb_build_object('withdrawal_request_id',p_request_id,'reason','cancelled_by_client'))
  on conflict(idempotency_key) do nothing;
end;
$$;
revoke all on function public.cancel_client_wallet_withdrawal(uuid) from public,anon;
grant execute on function public.cancel_client_wallet_withdrawal(uuid) to authenticated;

create or replace function public.admin_process_client_wallet_withdrawal(
  p_request_id uuid,
  p_action text,
  p_provider_reference text default null,
  p_transfer_fee numeric default 0,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path=public,pg_catalog
as $$
declare
  v_admin uuid;
  v_request public.client_wallet_withdrawal_requests%rowtype;
  v_balance numeric(18,2);
  v_fee numeric(18,2):=greatest(0,coalesce(p_transfer_fee,0));
  v_net numeric(18,2);
begin
  if not public.is_admin() then raise exception 'غير مصرح'; end if;
  select id into v_admin from public.profiles where auth_id=auth.uid() limit 1;
  if p_action not in ('processing','paid','rejected') then raise exception 'الإجراء غير صالح'; end if;

  select * into v_request from public.client_wallet_withdrawal_requests where id=p_request_id for update;
  if not found then raise exception 'طلب السحب غير موجود'; end if;
  if v_request.status not in ('pending_review','processing') then raise exception 'تمت معالجة هذا الطلب مسبقاً'; end if;

  if p_action='processing' then
    update public.client_wallet_withdrawal_requests
      set status='processing',processing_started_at=coalesce(processing_started_at,now()),processed_by=v_admin,admin_note=nullif(trim(coalesce(p_note,'')),'')
      where id=p_request_id;
    perform public.enqueue_user_notification(v_request.user_id,'بدأت معالجة طلب سحب الرصيد','تقوم الإدارة الآن بتنفيذ تحويل مبلغ '||trim(to_char(v_request.amount,'FM999999999999990'))||' د.ع إلى حساب الاستلام المسجل.','client_wallet_withdrawal_processing',p_request_id,'client_wallet_withdrawal');
    return;
  end if;

  if p_action='rejected' then
    if nullif(trim(coalesce(p_note,'')),'') is null then raise exception 'سبب الرفض إلزامي'; end if;
    update public.client_wallets
      set held_balance=held_balance-v_request.amount,available_balance=available_balance+v_request.amount,updated_at=now()
      where user_id=v_request.user_id and held_balance>=v_request.amount
      returning available_balance into v_balance;
    if not found then raise exception 'تعذر تحرير المبلغ المحجوز'; end if;

    update public.client_wallet_withdrawal_requests
      set status='rejected',rejection_reason=trim(p_note),admin_note=trim(p_note),rejected_at=now(),processed_at=now(),processed_by=v_admin
      where id=p_request_id;
    insert into public.client_wallet_ledger(user_id,amount,entry_type,balance_after,idempotency_key,metadata)
      values(v_request.user_id,v_request.amount,'withdrawal_release',v_balance,'withdrawal:'||p_request_id||':reject',jsonb_build_object('withdrawal_request_id',p_request_id,'reason','rejected_by_admin'))
      on conflict(idempotency_key) do nothing;
    perform public.enqueue_user_notification(v_request.user_id,'تم رفض طلب سحب الرصيد','تمت إعادة '||trim(to_char(v_request.amount,'FM999999999999990'))||' د.ع إلى رصيدك المتاح. السبب: '||trim(p_note),'client_wallet_withdrawal_rejected',p_request_id,'client_wallet_withdrawal');
    return;
  end if;

  if nullif(trim(coalesce(p_provider_reference,'')),'') is null then raise exception 'رقم مرجع التحويل إلزامي'; end if;
  if v_request.fee_mode='none' then v_fee:=0; end if;
  if v_fee<0 or v_fee>=v_request.amount then raise exception 'رسوم التحويل غير صالحة'; end if;
  v_net:=v_request.amount-v_fee;

  update public.client_wallets
    set held_balance=held_balance-v_request.amount,updated_at=now()
    where user_id=v_request.user_id and held_balance>=v_request.amount;
  if not found then raise exception 'الرصيد المحجوز لا يغطي طلب السحب'; end if;

  update public.client_wallet_withdrawal_requests
    set status='paid',transfer_fee=v_fee,net_amount=v_net,provider_reference=trim(p_provider_reference),
        admin_note=nullif(trim(coalesce(p_note,'')),''),paid_at=now(),processed_at=now(),processed_by=v_admin
    where id=p_request_id;

  insert into public.client_wallet_ledger(user_id,amount,entry_type,balance_after,idempotency_key,metadata)
    select v_request.user_id,0,'withdrawal_capture',w.available_balance,'withdrawal:'||p_request_id||':paid',
           jsonb_build_object('withdrawal_request_id',p_request_id,'gross_amount',v_request.amount,'transfer_fee',v_fee,'net_amount',v_net,'provider_reference',trim(p_provider_reference),'fee_mode',v_request.fee_mode)
    from public.client_wallets w where w.user_id=v_request.user_id
    on conflict(idempotency_key) do nothing;

  insert into public.financial_audit_log(actor_id,actor_role,client_id,event_type,decision,amount,currency,reference_id)
  values(v_admin,'admin',v_request.user_id,'client_wallet_withdrawal_paid','manual_transfer',v_request.amount,v_request.currency,p_request_id);

  perform public.enqueue_user_notification(
    v_request.user_id,'تم تحويل رصيدك',
    'تم تحويل '||trim(to_char(v_net,'FM999999999999990'))||' د.ع إلى حساب الاستلام المسجل.'
      ||case when v_fee>0 then ' رسوم التحويل الفعلية: '||trim(to_char(v_fee,'FM999999999999990'))||' د.ع.' else '' end
      ||' مرجع التحويل: '||trim(p_provider_reference),
    'client_wallet_withdrawal_paid',p_request_id,'client_wallet_withdrawal'
  );
end;
$$;
revoke all on function public.admin_process_client_wallet_withdrawal(uuid,text,text,numeric,text) from public,anon,authenticated;
grant execute on function public.admin_process_client_wallet_withdrawal(uuid,text,text,numeric,text) to authenticated;

create or replace function public.admin_list_client_wallet_withdrawals()
returns table(
  request_id uuid,user_id uuid,client_name text,amount numeric,transfer_fee numeric,net_amount numeric,currency text,
  status text,provider_type text,account_holder_name text,account_number text,bank_name text,
  financial_policy_version integer,processing_min_business_days integer,processing_max_business_days integer,
  processing_deadline_at timestamptz,requested_at timestamptz,provider_reference text,rejection_reason text,admin_note text
)
language sql
security definer
set search_path=public,pg_catalog
as $$
  select w.id,w.user_id,coalesce(nullif(trim(p.full_name),''),'طالب الاستشارة'),w.amount,w.transfer_fee,w.net_amount,w.currency,
         w.status,w.provider_type,w.account_holder_name,w.account_number,w.bank_name,w.financial_policy_version,
         w.processing_min_business_days,w.processing_max_business_days,w.processing_deadline_at,w.requested_at,w.provider_reference,w.rejection_reason,w.admin_note
  from public.client_wallet_withdrawal_requests w
  join public.profiles p on p.id=w.user_id
  where public.is_admin()
  order by case when w.status in ('pending_review','processing') then 0 else 1 end,w.requested_at desc
  limit 100;
$$;
revoke all on function public.admin_list_client_wallet_withdrawals() from public,anon,authenticated;
grant execute on function public.admin_list_client_wallet_withdrawals() to authenticated;

create or replace function public.request_lawyer_payout(p_amount numeric)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_lawyer uuid;
  v_wallet record;
  v_profile record;
  v_settings public.platform_financial_settings%rowtype;
  v_request uuid;
  v_status text;
  v_scheduled_date date;
begin
  select id into v_lawyer from public.profiles where auth_id=auth.uid() and role='lawyer';
  if v_lawyer is null then raise exception 'المستخدم ليس محامياً'; end if;
  select * into v_profile from public.profiles where id=v_lawyer for update;
  select * into v_settings from public.platform_financial_settings where id=true;
  select * into v_wallet from public.lawyer_wallets where lawyer_id=v_lawyer for update;
  if not found then raise exception 'محفظة المحامي غير موجودة'; end if;
  if p_amount is null or p_amount<=0 then raise exception 'مبلغ السحب غير صالح'; end if;
  if p_amount<v_settings.minimum_payout_amount then raise exception using message='الحد الأدنى للسحب هو '||v_settings.minimum_payout_amount||' د.ع'; end if;
  if p_amount>v_settings.maximum_payout_amount then raise exception using message='الحد الأقصى للسحب هو '||v_settings.maximum_payout_amount||' د.ع'; end if;
  if v_wallet.available_balance<p_amount then raise exception 'الرصيد المتاح غير كافٍ'; end if;
  if v_profile.wallet_type is null or v_profile.wallet_number is null or v_profile.wallet_holder_name is null then raise exception 'أكمل بيانات وسيلة استلام المستحقات أولاً'; end if;

  v_status:=case when v_settings.automatic_payout_enabled and v_settings.payout_mode='automatic' then 'queued' else 'pending_review' end;
  v_scheduled_date:=public.next_lawyer_payout_date(v_settings.lawyer_payout_frequency,v_settings.lawyer_payout_weekday,now());

  update public.lawyer_wallets
    set available_balance=available_balance-p_amount,pending_balance=pending_balance+p_amount,updated_at=now()
    where lawyer_id=v_lawyer;

  insert into public.lawyer_payout_requests(
    lawyer_id,amount,currency,wallet_number,wallet_type,wallet_holder_name,status,financial_policy_version,scheduled_payout_date
  ) values(
    v_lawyer,p_amount,coalesce(v_settings.currency,'IQD'),v_profile.wallet_number,v_profile.wallet_type,v_profile.wallet_holder_name,
    v_status,v_settings.financial_policy_version,v_scheduled_date
  ) returning id into v_request;

  if v_status='queued' then
    insert into public.lawyer_payout_attempts(payout_id,attempt_number,provider,status,external_reference)
    values(v_request,1,v_profile.wallet_type,'queued','payout-'||v_request);
  end if;
  return v_request;
end;
$$;
revoke all on function public.request_lawyer_payout(numeric) from public;
grant execute on function public.request_lawyer_payout(numeric) to authenticated;