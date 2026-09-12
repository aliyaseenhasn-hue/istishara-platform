alter table public.custom_appointment_requests
  add column if not exists financial_policy_version integer,
  add column if not exists commission_rate_snapshot numeric(7,2),
  add column if not exists lawyer_earnings_hold_hours_snapshot integer,
  add column if not exists financial_policy_snapshot jsonb not null default '{}'::jsonb;

update public.custom_appointment_requests r
set financial_policy_version=coalesce(r.financial_policy_version,1),
    commission_rate_snapshot=coalesce(r.commission_rate_snapshot,v.commission_rate),
    lawyer_earnings_hold_hours_snapshot=coalesce(r.lawyer_earnings_hold_hours_snapshot,v.lawyer_earnings_hold_hours),
    financial_policy_snapshot=case when r.financial_policy_snapshot='{}'::jsonb then
      jsonb_build_object(
        'policy_version',v.policy_version,
        'commission_rate',v.commission_rate,
        'currency',v.currency,
        'client_withdrawal_enabled',v.client_withdrawal_enabled,
        'client_withdrawal_min_amount',v.client_withdrawal_min_amount,
        'client_withdrawal_processing_min_business_days',v.client_withdrawal_processing_min_business_days,
        'client_withdrawal_processing_max_business_days',v.client_withdrawal_processing_max_business_days,
        'client_withdrawal_fee_mode',v.client_withdrawal_fee_mode,
        'lawyer_earnings_hold_hours',v.lawyer_earnings_hold_hours,
        'lawyer_payout_frequency',v.lawyer_payout_frequency,
        'lawyer_payout_weekday',v.lawyer_payout_weekday,
        'effective_from',v.effective_from
      ) else r.financial_policy_snapshot end
from public.platform_financial_policy_versions v
where v.policy_version=1 and r.financial_policy_version is null;

create or replace function public.snapshot_financial_policy_on_custom_request()
returns trigger
language plpgsql
security definer
set search_path=public,pg_catalog
as $$
declare s public.platform_financial_settings%rowtype;
begin
  select * into s from public.platform_financial_settings where id=true;
  if not found then raise exception 'إعدادات السياسة المالية غير موجودة'; end if;
  new.financial_policy_version:=coalesce(new.financial_policy_version,s.financial_policy_version);
  new.commission_rate_snapshot:=coalesce(new.commission_rate_snapshot,s.commission_rate);
  new.lawyer_earnings_hold_hours_snapshot:=coalesce(new.lawyer_earnings_hold_hours_snapshot,s.lawyer_earnings_hold_hours);
  if new.financial_policy_snapshot='{}'::jsonb then
    new.financial_policy_snapshot:=jsonb_build_object(
      'policy_version',new.financial_policy_version,
      'commission_rate',new.commission_rate_snapshot,
      'currency',s.currency,
      'client_withdrawal_enabled',s.client_withdrawal_enabled,
      'client_withdrawal_min_amount',s.client_withdrawal_min_amount,
      'client_withdrawal_processing_min_business_days',s.client_withdrawal_processing_min_business_days,
      'client_withdrawal_processing_max_business_days',s.client_withdrawal_processing_max_business_days,
      'client_withdrawal_fee_mode',s.client_withdrawal_fee_mode,
      'lawyer_earnings_hold_hours',new.lawyer_earnings_hold_hours_snapshot,
      'lawyer_payout_frequency',s.lawyer_payout_frequency,
      'lawyer_payout_weekday',s.lawyer_payout_weekday,
      'effective_from',s.updated_at
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_snapshot_financial_policy_on_custom_request on public.custom_appointment_requests;
create trigger trg_snapshot_financial_policy_on_custom_request
before insert on public.custom_appointment_requests
for each row execute function public.snapshot_financial_policy_on_custom_request();

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
  new.financial_policy_version:=coalesce(new.financial_policy_version,s.financial_policy_version);
  new.commission_rate_snapshot:=coalesce(new.commission_rate_snapshot,s.commission_rate);
  new.lawyer_earnings_hold_hours_snapshot:=coalesce(new.lawyer_earnings_hold_hours_snapshot,s.lawyer_earnings_hold_hours);
  if new.financial_policy_snapshot='{}'::jsonb then
    new.financial_policy_snapshot:=jsonb_build_object(
      'policy_version',new.financial_policy_version,
      'commission_rate',new.commission_rate_snapshot,
      'currency',s.currency,
      'client_withdrawal_enabled',s.client_withdrawal_enabled,
      'client_withdrawal_min_amount',s.client_withdrawal_min_amount,
      'client_withdrawal_processing_min_business_days',s.client_withdrawal_processing_min_business_days,
      'client_withdrawal_processing_max_business_days',s.client_withdrawal_processing_max_business_days,
      'client_withdrawal_fee_mode',s.client_withdrawal_fee_mode,
      'lawyer_earnings_hold_hours',new.lawyer_earnings_hold_hours_snapshot,
      'lawyer_payout_frequency',s.lawyer_payout_frequency,
      'lawyer_payout_weekday',s.lawyer_payout_weekday,
      'effective_from',s.updated_at
    );
  end if;
  return new;
end;
$$;

create or replace function public.client_confirm_custom_appointment(p_request_id uuid,p_option_index integer)
returns public.bookings
language plpgsql
security definer
set search_path=public
as $$
declare
  v_user_id uuid; v_whatsapp text; v_request public.custom_appointment_requests;
  v_option jsonb; v_start timestamptz; v_booking public.bookings; v_wallet public.client_wallets%rowtype;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  perform public.expire_stale_custom_appointment_requests();
  select id,nullif(trim(whatsapp_number),'') into v_user_id,v_whatsapp from public.profiles
  where auth_id=auth.uid() and role='user' and status='active' limit 1;
  select * into v_request from public.custom_appointment_requests where id=p_request_id and user_id=v_user_id for update;
  if not found then raise exception 'طلب الموعد غير موجود'; end if;
  if v_request.status<>'بانتظار اختيار العميل' or v_request.expires_at<=now() then raise exception 'انتهت مهلة اختيار الموعد'; end if;
  if p_option_index is null or p_option_index<0 or p_option_index>=jsonb_array_length(v_request.lawyer_options) then raise exception 'الموعد المختار غير صالح'; end if;
  v_option:=v_request.lawyer_options->p_option_index;
  v_start:=(v_option->>'start')::timestamptz;
  if v_start<=now() then raise exception 'الموعد المختار انتهى'; end if;

  perform pg_advisory_xact_lock(hashtextextended(v_request.lawyer_id::text,0));
  if public.is_lawyer_time_blocked(v_request.lawyer_id,v_start,v_request.duration_minutes,v_request.id) then
    raise exception 'الموعد لم يعد متاحاً لأنه يتداخل مع حجز آخر؛ اطلب من المحامي اقتراح موعد جديد';
  end if;

  if v_request.payment_required then
    select * into v_wallet from public.client_wallets where user_id=v_user_id for update;
    if not found or v_wallet.held_balance<v_request.reserved_amount then raise exception 'تعذر العثور على المبلغ المحجوز لهذا الطلب'; end if;
    update public.client_wallets set held_balance=held_balance-v_request.reserved_amount,updated_at=now() where user_id=v_user_id;
  end if;

  update public.custom_appointment_requests
  set status='مؤكد',selected_option=p_option_index,expired_waiting_on=null,expired_at=null,updated_at=now()
  where id=v_request.id;

  insert into public.bookings(
    user_id,lawyer_id,status,scheduled_at,price,consultation_type,consultation_mode,
    manual_payment_required,payment_required,payment_confirmed_at,payment_waived_at,payment_waiver_reason,
    description,document_url,whatsapp_number,package_name,package_description,package_duration_minutes,
    consultation_status,lawyer_approved,lawyer_approved_at,
    financial_policy_version,commission_rate_snapshot,lawyer_earnings_hold_hours_snapshot,financial_policy_snapshot
  ) values(
    v_user_id,v_request.lawyer_id,case when v_request.payment_required then 'قيد معالجة الدفع' else 'مؤكد' end,
    v_start,v_request.price,v_request.consultation_type,v_request.consultation_mode,false,v_request.payment_required,
    case when v_request.payment_required then now() else null end,
    case when v_request.payment_required then null else now() end,
    case when v_request.payment_required then null else 'free_beta' end,
    v_request.description,v_request.document_url,v_whatsapp,v_request.package_name,v_request.package_description,
    v_request.duration_minutes,'لم تبدأ',true,now(),
    v_request.financial_policy_version,v_request.commission_rate_snapshot,v_request.lawyer_earnings_hold_hours_snapshot,v_request.financial_policy_snapshot
  ) returning * into v_booking;

  if v_request.payment_required then
    insert into public.client_wallet_ledger(user_id,amount,entry_type,appointment_request_id,booking_id,balance_after,idempotency_key)
    values(v_user_id,0,'appointment_capture',v_request.id,v_booking.id,v_wallet.available_balance,'appointment:'||v_request.id||':capture');
    insert into public.payments(booking_id,amount,payment_method,transaction_number,status,verified_at,is_manual)
    values(v_booking.id,v_request.price,'wallet','wallet-'||v_booking.id,'تم الدفع',now(),false);
  end if;

  update public.custom_appointment_requests set booking_id=v_booking.id,updated_at=now() where id=v_request.id;
  select * into v_booking from public.bookings where id=v_booking.id;
  return v_booking;
end;
$$;
