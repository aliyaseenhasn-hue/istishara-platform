alter table public.platform_financial_settings add column if not exists automatic_payout_enabled boolean not null default false;
alter table public.platform_financial_settings add column if not exists minimum_payout_amount numeric(18,2) not null default 1000;
alter table public.platform_financial_settings add column if not exists maximum_payout_amount numeric(18,2) not null default 500000;

alter table public.platform_financial_settings add constraint platform_financial_settings_payout_limits_check check (minimum_payout_amount >= 0 and maximum_payout_amount >= minimum_payout_amount);

create table if not exists public.lawyer_payout_attempts (
  id uuid primary key default gen_random_uuid(),
  payout_id uuid not null references public.lawyer_payout_requests(id) on delete cascade,
  attempt_number integer not null,
  provider text not null,
  status text not null default 'queued',
  external_reference text,
  provider_reference text,
  error_code text,
  error_message text,
  request_payload jsonb not null default '{}'::jsonb,
  response_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (payout_id, attempt_number)
);

alter table public.lawyer_payout_requests drop constraint if exists lawyer_payout_requests_status_check;
alter table public.lawyer_payout_requests add constraint lawyer_payout_requests_status_check check (status in ('pending_review','queued','approved','processing','paid','rejected','failed'));

create or replace function public.request_lawyer_payout(p_amount numeric)
returns uuid language plpgsql security definer set search_path=public as $$
declare
  v_lawyer uuid;
  v_wallet record;
  v_profile record;
  v_settings record;
  v_request uuid;
  v_status text;
begin
  select id into v_lawyer from public.profiles where auth_id=auth.uid() and role='lawyer';
  if v_lawyer is null then raise exception 'المستخدم ليس محامياً'; end if;
  select * into v_profile from public.profiles where id=v_lawyer for update;
  select * into v_settings from public.platform_financial_settings where id=true;
  select * into v_wallet from public.lawyer_wallets where lawyer_id=v_lawyer for update;
  if not found then raise exception 'محفظة المحامي غير موجودة'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'مبلغ السحب غير صالح'; end if;
  if p_amount < v_settings.minimum_payout_amount then raise exception using message='الحد الأدنى للسحب هو '||v_settings.minimum_payout_amount||' د.ع'; end if;
  if p_amount > v_settings.maximum_payout_amount then raise exception using message='الحد الأقصى للسحب هو '||v_settings.maximum_payout_amount||' د.ع'; end if;
  if v_wallet.available_balance < p_amount then raise exception 'الرصيد المتاح غير كافٍ'; end if;
  if v_profile.wallet_type is null or v_profile.wallet_number is null or v_profile.wallet_holder_name is null then raise exception 'أكمل بيانات وسيلة استلام المستحقات أولاً'; end if;
  if exists(select 1 from public.lawyer_payout_requests where lawyer_id=v_lawyer and status in ('queued','approved','processing')) then raise exception 'لديك طلب سحب قيد التنفيذ بالفعل'; end if;

  v_status := case when v_settings.automatic_payout_enabled and v_settings.payout_mode='automatic' then 'queued' else 'pending_review' end;

  update public.lawyer_wallets
  set available_balance=available_balance-p_amount,
      pending_balance=pending_balance+p_amount,
      updated_at=now()
  where lawyer_id=v_lawyer;

  insert into public.lawyer_payout_requests(lawyer_id,amount,currency,wallet_number,wallet_type,wallet_holder_name,status)
  values(v_lawyer,p_amount,coalesce(v_settings.currency,'IQD'),v_profile.wallet_number,v_profile.wallet_type,v_profile.wallet_holder_name,v_status)
  returning id into v_request;

  if v_status='queued' then
    insert into public.lawyer_payout_attempts(payout_id,attempt_number,provider,status,external_reference)
    values(v_request,1,v_profile.wallet_type,'queued','payout-'||v_request);
  end if;

  return v_request;
end;
$$;

revoke all on function public.request_lawyer_payout(numeric) from public;
grant execute on function public.request_lawyer_payout(numeric) to authenticated;

create index if not exists idx_lawyer_payout_attempts_status on public.lawyer_payout_attempts(status,created_at);
create index if not exists idx_lawyer_payout_requests_status on public.lawyer_payout_requests(status,created_at);
