alter table public.platform_financial_settings
  add column if not exists financial_policy_version integer not null default 1,
  add column if not exists client_withdrawal_enabled boolean not null default false,
  add column if not exists client_withdrawal_min_amount numeric(18,2) not null default 10000,
  add column if not exists client_withdrawal_processing_min_business_days integer not null default 1,
  add column if not exists client_withdrawal_processing_max_business_days integer not null default 3,
  add column if not exists client_withdrawal_fee_mode text not null default 'actual_transfer_fee',
  add column if not exists lawyer_earnings_hold_hours integer not null default 0,
  add column if not exists lawyer_payout_frequency text not null default 'manual',
  add column if not exists lawyer_payout_weekday integer not null default 4;

alter table public.platform_financial_settings drop constraint if exists platform_financial_settings_client_withdrawal_days_check;
alter table public.platform_financial_settings add constraint platform_financial_settings_client_withdrawal_days_check
  check (client_withdrawal_processing_min_business_days >= 0
     and client_withdrawal_processing_max_business_days >= client_withdrawal_processing_min_business_days
     and client_withdrawal_processing_max_business_days <= 30);
alter table public.platform_financial_settings drop constraint if exists platform_financial_settings_client_withdrawal_fee_mode_check;
alter table public.platform_financial_settings add constraint platform_financial_settings_client_withdrawal_fee_mode_check
  check (client_withdrawal_fee_mode in ('none','actual_transfer_fee'));
alter table public.platform_financial_settings drop constraint if exists platform_financial_settings_lawyer_hold_check;
alter table public.platform_financial_settings add constraint platform_financial_settings_lawyer_hold_check
  check (lawyer_earnings_hold_hours between 0 and 720);
alter table public.platform_financial_settings drop constraint if exists platform_financial_settings_lawyer_payout_frequency_check;
alter table public.platform_financial_settings add constraint platform_financial_settings_lawyer_payout_frequency_check
  check (lawyer_payout_frequency in ('manual','daily','weekly'));
alter table public.platform_financial_settings drop constraint if exists platform_financial_settings_lawyer_payout_weekday_check;
alter table public.platform_financial_settings add constraint platform_financial_settings_lawyer_payout_weekday_check
  check (lawyer_payout_weekday between 0 and 6);

create table if not exists public.platform_financial_policy_versions (
  policy_version integer primary key,
  commission_rate numeric(7,2) not null check (commission_rate between 0 and 100),
  currency text not null default 'IQD',
  client_withdrawal_enabled boolean not null,
  client_withdrawal_min_amount numeric(18,2) not null check (client_withdrawal_min_amount >= 0),
  client_withdrawal_processing_min_business_days integer not null,
  client_withdrawal_processing_max_business_days integer not null,
  client_withdrawal_fee_mode text not null check (client_withdrawal_fee_mode in ('none','actual_transfer_fee')),
  lawyer_earnings_hold_hours integer not null check (lawyer_earnings_hold_hours between 0 and 720),
  lawyer_payout_frequency text not null check (lawyer_payout_frequency in ('manual','daily','weekly')),
  lawyer_payout_weekday integer not null check (lawyer_payout_weekday between 0 and 6),
  effective_from timestamptz not null default now(),
  created_at timestamptz not null default now(),
  created_by uuid references public.profiles(id) on delete set null,
  check (client_withdrawal_processing_min_business_days >= 0
     and client_withdrawal_processing_max_business_days >= client_withdrawal_processing_min_business_days
     and client_withdrawal_processing_max_business_days <= 30)
);
alter table public.platform_financial_policy_versions enable row level security;
drop policy if exists platform_financial_policy_versions_admin_select on public.platform_financial_policy_versions;
create policy platform_financial_policy_versions_admin_select on public.platform_financial_policy_versions
  for select to authenticated using ((select public.is_admin()));
revoke insert,update,delete on public.platform_financial_policy_versions from anon,authenticated;
grant select on public.platform_financial_policy_versions to authenticated;

insert into public.platform_financial_policy_versions(
  policy_version,commission_rate,currency,
  client_withdrawal_enabled,client_withdrawal_min_amount,
  client_withdrawal_processing_min_business_days,client_withdrawal_processing_max_business_days,
  client_withdrawal_fee_mode,lawyer_earnings_hold_hours,lawyer_payout_frequency,lawyer_payout_weekday,
  effective_from,created_at,created_by
)
select 1,commission_rate,currency,false,10000,1,3,'actual_transfer_fee',0,'manual',4,now(),now(),null
from public.platform_financial_settings where id=true
on conflict (policy_version) do nothing;

alter table public.bookings
  add column if not exists financial_policy_version integer,
  add column if not exists commission_rate_snapshot numeric(7,2),
  add column if not exists lawyer_earnings_hold_hours_snapshot integer,
  add column if not exists financial_policy_snapshot jsonb not null default '{}'::jsonb;

update public.bookings b
set financial_policy_version = coalesce(b.financial_policy_version,1),
    commission_rate_snapshot = coalesce(
      b.commission_rate_snapshot,
      (select pf.commission_rate from public.payment_financials pf where pf.booking_id=b.id order by pf.created_at desc limit 1),
      s.commission_rate
    ),
    lawyer_earnings_hold_hours_snapshot = coalesce(b.lawyer_earnings_hold_hours_snapshot,0),
    financial_policy_snapshot = case when b.financial_policy_snapshot='{}'::jsonb then
      jsonb_build_object(
        'policy_version',1,
        'commission_rate',coalesce((select pf.commission_rate from public.payment_financials pf where pf.booking_id=b.id order by pf.created_at desc limit 1),s.commission_rate),
        'currency',s.currency,
        'client_withdrawal_enabled',false,
        'client_withdrawal_min_amount',10000,
        'client_withdrawal_processing_business_days','1-3',
        'client_withdrawal_fee_mode','actual_transfer_fee',
        'lawyer_earnings_hold_hours',0,
        'lawyer_payout_frequency','manual',
        'lawyer_payout_weekday',4
      ) else b.financial_policy_snapshot end
from public.platform_financial_settings s
where s.id=true;

alter table public.payment_financials
  add column if not exists financial_policy_version integer,
  add column if not exists earnings_available_at timestamptz;
update public.payment_financials pf
set financial_policy_version=coalesce(pf.financial_policy_version,b.financial_policy_version,1)
from public.bookings b
where b.id=pf.booking_id and pf.financial_policy_version is null;

do $$
declare v_new_version integer;
begin
  select greatest(coalesce(max(policy_version),0)+1,2) into v_new_version
  from public.platform_financial_policy_versions;

  update public.platform_financial_settings
  set commission_rate=10,
      financial_policy_version=v_new_version,
      client_withdrawal_enabled=true,
      client_withdrawal_min_amount=10000,
      client_withdrawal_processing_min_business_days=1,
      client_withdrawal_processing_max_business_days=3,
      client_withdrawal_fee_mode='actual_transfer_fee',
      lawyer_earnings_hold_hours=24,
      lawyer_payout_frequency='weekly',
      lawyer_payout_weekday=4,
      updated_at=now()
  where id=true;

  insert into public.platform_financial_policy_versions(
    policy_version,commission_rate,currency,
    client_withdrawal_enabled,client_withdrawal_min_amount,
    client_withdrawal_processing_min_business_days,client_withdrawal_processing_max_business_days,
    client_withdrawal_fee_mode,lawyer_earnings_hold_hours,lawyer_payout_frequency,lawyer_payout_weekday,
    effective_from,created_at,created_by
  )
  select financial_policy_version,commission_rate,currency,
         client_withdrawal_enabled,client_withdrawal_min_amount,
         client_withdrawal_processing_min_business_days,client_withdrawal_processing_max_business_days,
         client_withdrawal_fee_mode,lawyer_earnings_hold_hours,lawyer_payout_frequency,lawyer_payout_weekday,
         now(),now(),null
  from public.platform_financial_settings where id=true;
end $$;

create or replace function public.snapshot_financial_policy_on_booking()
returns trigger
language plpgsql
security definer
set search_path=public,pg_catalog
as $$
declare s public.platform_financial_settings%rowtype;
begin
  select * into s from public.platform_financial_settings where id=true;
  if not found then raise exception 'إعدادات السياسة المالية غير موجودة'; end if;

  new.financial_policy_version := s.financial_policy_version;
  new.commission_rate_snapshot := s.commission_rate;
  new.lawyer_earnings_hold_hours_snapshot := s.lawyer_earnings_hold_hours;
  new.financial_policy_snapshot := jsonb_build_object(
    'policy_version',s.financial_policy_version,
    'commission_rate',s.commission_rate,
    'currency',s.currency,
    'client_withdrawal_enabled',s.client_withdrawal_enabled,
    'client_withdrawal_min_amount',s.client_withdrawal_min_amount,
    'client_withdrawal_processing_min_business_days',s.client_withdrawal_processing_min_business_days,
    'client_withdrawal_processing_max_business_days',s.client_withdrawal_processing_max_business_days,
    'client_withdrawal_fee_mode',s.client_withdrawal_fee_mode,
    'lawyer_earnings_hold_hours',s.lawyer_earnings_hold_hours,
    'lawyer_payout_frequency',s.lawyer_payout_frequency,
    'lawyer_payout_weekday',s.lawyer_payout_weekday,
    'effective_from',s.updated_at
  );
  return new;
end;
$$;

drop trigger if exists trg_snapshot_financial_policy_on_booking on public.bookings;
create trigger trg_snapshot_financial_policy_on_booking
before insert on public.bookings
for each row execute function public.snapshot_financial_policy_on_booking();

create or replace function public.ensure_financial_accounting_for_payment(p_payment_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare
  p public.payments%rowtype;
  b public.bookings%rowtype;
  s public.platform_financial_settings%rowtype;
  c numeric(18,2);
  net numeric(18,2);
  v_inserted integer := 0;
  v_rate numeric(7,2);
  v_currency text;
  v_policy_version integer;
begin
  select * into p from public.payments where id=p_payment_id for update;
  if not found or p.status <> 'تم الدفع' then return; end if;
  if coalesce(p.amount,0) <= 0 then raise exception 'لا يمكن تسجيل عملية دفع بمبلغ غير صالح'; end if;

  select * into b from public.bookings where id=p.booking_id for update;
  if not found or b.lawyer_id is null then return; end if;
  if exists(select 1 from public.payment_financials where payment_id=p.id) then return; end if;

  select * into s from public.platform_financial_settings where id=true;
  v_rate := coalesce(b.commission_rate_snapshot,s.commission_rate,0);
  v_currency := coalesce(nullif(b.financial_policy_snapshot->>'currency',''),s.currency,'IQD');
  v_policy_version := coalesce(b.financial_policy_version,s.financial_policy_version,1);
  c := round(coalesce(p.amount,0)*v_rate/100,2);
  net := round(greatest(0,coalesce(p.amount,0)-c),2);

  insert into public.payment_financials(
    payment_id,booking_id,client_id,lawyer_id,gross_amount,commission_rate,
    platform_commission,penalty_amount,client_credit_amount,lawyer_net_amount,currency,status,financial_policy_version
  ) values(
    p.id,b.id,b.user_id,b.lawyer_id,coalesce(p.amount,0),v_rate,
    c,0,0,net,v_currency,'pending',v_policy_version
  ) on conflict(payment_id) do nothing;
  get diagnostics v_inserted=row_count;
  if v_inserted=0 then return; end if;

  insert into public.financial_ledger(payment_id,booking_id,client_id,lawyer_id,entry_type,amount,currency,idempotency_key,metadata)
  values(p.id,b.id,b.user_id,b.lawyer_id,'payment_gross',coalesce(p.amount,0),v_currency,'payment:'||p.id||':gross',
         jsonb_build_object('qicard_payment_id',p.qicard_payment_id,'qicard_request_id',p.qicard_request_id,'financial_policy_version',v_policy_version))
  on conflict(idempotency_key) do nothing;

  insert into public.financial_ledger(payment_id,booking_id,client_id,lawyer_id,entry_type,amount,currency,idempotency_key,metadata)
  values(p.id,b.id,b.user_id,b.lawyer_id,'platform_commission',c,v_currency,'payment:'||p.id||':commission',
         jsonb_build_object('commission_rate',v_rate,'financial_policy_version',v_policy_version))
  on conflict(idempotency_key) do nothing;

  insert into public.financial_ledger(payment_id,booking_id,client_id,lawyer_id,entry_type,amount,currency,idempotency_key,metadata)
  values(p.id,b.id,b.user_id,b.lawyer_id,'lawyer_earning',net,v_currency,'payment:'||p.id||':lawyer',
         jsonb_build_object('availability','pending_until_hold_period_ends_after_consultation_completed','financial_policy_version',v_policy_version,'hold_hours',coalesce(b.lawyer_earnings_hold_hours_snapshot,0)))
  on conflict(idempotency_key) do nothing;

  insert into public.lawyer_wallets(lawyer_id,available_balance,pending_balance,lifetime_earned,currency,updated_at)
  values(b.lawyer_id,0,net,net,v_currency,now())
  on conflict(lawyer_id) do update
    set pending_balance=lawyer_wallets.pending_balance+excluded.pending_balance,
        lifetime_earned=lawyer_wallets.lifetime_earned+excluded.lifetime_earned,
        updated_at=now();
end;
$$;

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
  v_default_available_at timestamptz;
  v_release_at timestamptz;
begin
  select * into v_booking from public.bookings where id=p_booking_id for update;
  if not found or v_booking.status <> 'مكتمل' or v_booking.lawyer_id is null then return; end if;

  v_default_available_at := coalesce(v_booking.completed_at,now())
    + make_interval(hours => greatest(0,coalesce(v_booking.lawyer_earnings_hold_hours_snapshot,0)));

  for v_financial in
    select pf.payment_id,pf.lawyer_id,pf.lawyer_net_amount,pf.currency,pf.earnings_available_at
    from public.payment_financials pf
    where pf.booking_id=p_booking_id and pf.status='pending'
    for update
  loop
    v_release_at := coalesce(v_financial.earnings_available_at,v_default_available_at);
    update public.payment_financials
      set earnings_available_at=v_release_at,updated_at=now()
      where payment_id=v_financial.payment_id and status='pending';

    if v_release_at > now() then continue; end if;

    moved := greatest(0,coalesce(v_financial.lawyer_net_amount,0));
    update public.lawyer_wallets
      set pending_balance=greatest(0,pending_balance-moved),
          available_balance=available_balance+moved,
          updated_at=now()
      where lawyer_id=v_financial.lawyer_id;
    if not found then raise exception 'محفظة المحامي غير موجودة'; end if;

    update public.payment_financials
      set status='settled',updated_at=now(),earnings_available_at=v_release_at
      where payment_id=v_financial.payment_id and status='pending';

    insert into public.financial_ledger(payment_id,booking_id,lawyer_id,entry_type,amount,currency,idempotency_key,metadata)
    values(v_financial.payment_id,p_booking_id,v_financial.lawyer_id,'lawyer_earning_settlement',moved,v_financial.currency,
           'payment:'||v_financial.payment_id||':release',
           jsonb_build_object('source','consultation_completed_hold_elapsed','earnings_available_at',v_release_at,'hold_hours',coalesce(v_booking.lawyer_earnings_hold_hours_snapshot,0),'financial_policy_version',v_booking.financial_policy_version))
    on conflict(idempotency_key) do nothing;
  end loop;
end;
$$;

create or replace function public.release_matured_lawyer_earnings()
returns integer
language plpgsql
security definer
set search_path=public,pg_catalog
as $$
declare r record; v_count integer:=0;
begin
  for r in
    select distinct pf.booking_id
    from public.payment_financials pf
    join public.bookings b on b.id=pf.booking_id
    where pf.status='pending'
      and b.status='مكتمل'
      and coalesce(
        pf.earnings_available_at,
        coalesce(b.completed_at,now()) + make_interval(hours=>greatest(0,coalesce(b.lawyer_earnings_hold_hours_snapshot,0)))
      ) <= now()
  loop
    perform public.release_lawyer_earnings_for_completed_booking(r.booking_id);
    v_count:=v_count+1;
  end loop;
  return v_count;
end;
$$;
revoke all on function public.release_matured_lawyer_earnings() from public,anon,authenticated;

create or replace function public.get_financial_policy_summary()
returns table(
  policy_version integer,
  commission_rate numeric,
  currency text,
  client_withdrawal_enabled boolean,
  client_withdrawal_min_amount numeric,
  client_withdrawal_processing_min_business_days integer,
  client_withdrawal_processing_max_business_days integer,
  client_withdrawal_fee_mode text,
  lawyer_earnings_hold_hours integer,
  lawyer_payout_frequency text,
  lawyer_payout_weekday integer,
  effective_from timestamptz
)
language sql
security definer
set search_path=public,pg_catalog
as $$
  select s.financial_policy_version,s.commission_rate,s.currency,
         s.client_withdrawal_enabled,s.client_withdrawal_min_amount,
         s.client_withdrawal_processing_min_business_days,s.client_withdrawal_processing_max_business_days,
         s.client_withdrawal_fee_mode,s.lawyer_earnings_hold_hours,s.lawyer_payout_frequency,s.lawyer_payout_weekday,s.updated_at
  from public.platform_financial_settings s
  where s.id=true and auth.uid() is not null;
$$;
revoke all on function public.get_financial_policy_summary() from public,anon;
grant execute on function public.get_financial_policy_summary() to authenticated;

create or replace function public.admin_update_financial_policy(
  p_commission_rate numeric,
  p_client_withdrawal_enabled boolean,
  p_client_withdrawal_min_amount numeric,
  p_client_withdrawal_processing_min_business_days integer,
  p_client_withdrawal_processing_max_business_days integer,
  p_client_withdrawal_fee_mode text,
  p_lawyer_earnings_hold_hours integer,
  p_lawyer_payout_frequency text,
  p_lawyer_payout_weekday integer
)
returns integer
language plpgsql
security definer
set search_path=public,pg_catalog
as $$
declare
  s public.platform_financial_settings%rowtype;
  v_admin uuid;
  v_new_version integer;
begin
  if not public.is_admin() then raise exception 'غير مصرح'; end if;
  select id into v_admin from public.profiles where auth_id=auth.uid() limit 1;
  if p_commission_rate is null or p_commission_rate<0 or p_commission_rate>100 then raise exception 'نسبة العمولة يجب أن تكون بين 0 و100'; end if;
  if p_client_withdrawal_min_amount is null or p_client_withdrawal_min_amount<0 then raise exception 'الحد الأدنى لسحب العميل غير صالح'; end if;
  if p_client_withdrawal_processing_min_business_days<0 or p_client_withdrawal_processing_max_business_days<p_client_withdrawal_processing_min_business_days or p_client_withdrawal_processing_max_business_days>30 then raise exception 'مدة معالجة سحب العميل غير صالحة'; end if;
  if p_client_withdrawal_fee_mode not in ('none','actual_transfer_fee') then raise exception 'سياسة رسوم التحويل غير صالحة'; end if;
  if p_lawyer_earnings_hold_hours<0 or p_lawyer_earnings_hold_hours>720 then raise exception 'مدة حجز مستحق المحامي غير صالحة'; end if;
  if p_lawyer_payout_frequency not in ('manual','daily','weekly') then raise exception 'دورية تحويل مستحق المحامي غير صالحة'; end if;
  if p_lawyer_payout_weekday<0 or p_lawyer_payout_weekday>6 then raise exception 'يوم التحويل الأسبوعي غير صالح'; end if;

  select * into s from public.platform_financial_settings where id=true for update;
  v_new_version := coalesce(s.financial_policy_version,1)+1;

  update public.platform_financial_settings
  set financial_policy_version=v_new_version,
      commission_rate=p_commission_rate,
      client_withdrawal_enabled=p_client_withdrawal_enabled,
      client_withdrawal_min_amount=p_client_withdrawal_min_amount,
      client_withdrawal_processing_min_business_days=p_client_withdrawal_processing_min_business_days,
      client_withdrawal_processing_max_business_days=p_client_withdrawal_processing_max_business_days,
      client_withdrawal_fee_mode=p_client_withdrawal_fee_mode,
      lawyer_earnings_hold_hours=p_lawyer_earnings_hold_hours,
      lawyer_payout_frequency=p_lawyer_payout_frequency,
      lawyer_payout_weekday=p_lawyer_payout_weekday,
      updated_at=now()
  where id=true;

  insert into public.platform_financial_policy_versions(
    policy_version,commission_rate,currency,
    client_withdrawal_enabled,client_withdrawal_min_amount,
    client_withdrawal_processing_min_business_days,client_withdrawal_processing_max_business_days,
    client_withdrawal_fee_mode,lawyer_earnings_hold_hours,lawyer_payout_frequency,lawyer_payout_weekday,
    effective_from,created_at,created_by
  ) values(
    v_new_version,p_commission_rate,s.currency,
    p_client_withdrawal_enabled,p_client_withdrawal_min_amount,
    p_client_withdrawal_processing_min_business_days,p_client_withdrawal_processing_max_business_days,
    p_client_withdrawal_fee_mode,p_lawyer_earnings_hold_hours,p_lawyer_payout_frequency,p_lawyer_payout_weekday,
    now(),now(),v_admin
  );

  insert into public.financial_audit_log(actor_id,actor_role,event_type,decision,amount,currency,previous_status,new_status,reference_id)
  values(v_admin,'admin','financial_policy_updated','policy_version_'||v_new_version,p_commission_rate,s.currency,'policy_version_'||s.financial_policy_version,'policy_version_'||v_new_version,null);

  return v_new_version;
end;
$$;
revoke all on function public.admin_update_financial_policy(numeric,boolean,numeric,integer,integer,text,integer,text,integer) from public,anon,authenticated;
grant execute on function public.admin_update_financial_policy(numeric,boolean,numeric,integer,integer,text,integer,text,integer) to authenticated;

create or replace function public.admin_set_commission_rate(p_rate numeric)
returns void
language plpgsql
security definer
set search_path=public,pg_catalog
as $$
declare s public.platform_financial_settings%rowtype;
begin
  if not public.is_admin() then raise exception 'غير مصرح'; end if;
  select * into s from public.platform_financial_settings where id=true;
  perform public.admin_update_financial_policy(
    p_rate,s.client_withdrawal_enabled,s.client_withdrawal_min_amount,
    s.client_withdrawal_processing_min_business_days,s.client_withdrawal_processing_max_business_days,
    s.client_withdrawal_fee_mode,s.lawyer_earnings_hold_hours,s.lawyer_payout_frequency,s.lawyer_payout_weekday
  );
end;
$$;
revoke all on function public.admin_set_commission_rate(numeric) from public,anon,authenticated;
grant execute on function public.admin_set_commission_rate(numeric) to authenticated;

do $$
declare j record;
begin
  for j in select jobid from cron.job where jobname='release-matured-lawyer-earnings' loop
    perform cron.unschedule(j.jobid);
  end loop;
end $$;
select cron.schedule('release-matured-lawyer-earnings','*/5 * * * *','select public.release_matured_lawyer_earnings();');