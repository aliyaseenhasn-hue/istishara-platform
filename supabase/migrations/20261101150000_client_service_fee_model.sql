-- Client service fee model
-- ---------------------------------------------------------------------------
-- Until now the platform commission was deducted from the lawyer's price.
-- This migration adds a second, opt-in fee model where the lawyer keeps the
-- full price he set and the client pays a separate platform service fee on top.
--
-- Backward compatibility:
--   * bookings.price keeps its meaning: the exact amount the client pays.
--     Every payment path (Qi Card, wallet, manual, refunds) already uses it,
--     so none of them needs to change.
--   * Existing bookings/requests have fee_model_snapshot = NULL and keep the
--     old commission accounting exactly as before.
--   * The model is snapshotted per booking/request at creation time, so
--     switching the model later never changes historical bookings.
--   * The service fee rate is the same admin-managed commission_rate, so the
--     existing financial-management page keeps controlling the percentage.
-- ---------------------------------------------------------------------------

alter table public.platform_financial_settings
  add column if not exists fee_model text not null default 'lawyer_commission';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'platform_financial_settings_fee_model_check'
  ) then
    alter table public.platform_financial_settings
      add constraint platform_financial_settings_fee_model_check
      check (fee_model in ('lawyer_commission','client_service_fee'));
  end if;
end $$;

alter table public.bookings
  add column if not exists fee_model_snapshot text,
  add column if not exists lawyer_price numeric(18,2),
  add column if not exists service_fee_amount numeric(18,2) not null default 0;

alter table public.custom_appointment_requests
  add column if not exists fee_model_snapshot text,
  add column if not exists lawyer_price numeric(18,2),
  add column if not exists service_fee_amount numeric(18,2) not null default 0;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'bookings_fee_model_snapshot_check') then
    alter table public.bookings add constraint bookings_fee_model_snapshot_check
      check (fee_model_snapshot is null or fee_model_snapshot in ('lawyer_commission','client_service_fee'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'bookings_service_fee_amount_check') then
    alter table public.bookings add constraint bookings_service_fee_amount_check
      check (service_fee_amount >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'custom_appointment_requests_fee_model_snapshot_check') then
    alter table public.custom_appointment_requests add constraint custom_appointment_requests_fee_model_snapshot_check
      check (fee_model_snapshot is null or fee_model_snapshot in ('lawyer_commission','client_service_fee'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'custom_appointment_requests_service_fee_amount_check') then
    alter table public.custom_appointment_requests add constraint custom_appointment_requests_service_fee_amount_check
      check (service_fee_amount >= 0);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Fee calculation (single source of truth).
-- Fee is rounded UP to the nearest 250 IQD, the smallest practical unit.
-- ---------------------------------------------------------------------------
create or replace function public.platform_service_fee_for(
  p_lawyer_price numeric,
  p_payment_required boolean default true
)
returns table(fee_model text, lawyer_price numeric, service_fee numeric, client_total numeric, fee_rate numeric)
language plpgsql
stable
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare
  s public.platform_financial_settings%rowtype;
  v_fee numeric := 0;
  v_model text;
begin
  select * into s from public.platform_financial_settings where id = true;
  v_model := coalesce(s.fee_model, 'lawyer_commission');

  if v_model = 'client_service_fee'
     and coalesce(p_payment_required, true)
     and coalesce(p_lawyer_price, 0) > 0
     and coalesce(s.commission_rate, 0) > 0 then
    v_fee := ceil(p_lawyer_price * s.commission_rate / 100 / 250) * 250;
  end if;

  fee_model := v_model;
  lawyer_price := p_lawyer_price;
  service_fee := v_fee;
  client_total := coalesce(p_lawyer_price, 0) + v_fee;
  fee_rate := coalesce(s.commission_rate, 0);
  return next;
end;
$function$;

revoke all on function public.platform_service_fee_for(numeric, boolean) from public, anon, authenticated;

-- Read-only preview used by the booking screen to show the breakdown before
-- the client confirms. Mirrors exactly what create_booking will charge.
create or replace function public.get_service_fee_preview(p_lawyer_price numeric)
returns table(fee_model text, lawyer_price numeric, service_fee numeric, client_total numeric, fee_rate numeric)
language sql
stable
security definer
set search_path to 'public', 'pg_catalog'
as $function$
  select f.fee_model, f.lawyer_price, f.service_fee, f.client_total, f.fee_rate
  from public.platform_service_fee_for(
    p_lawyer_price,
    not coalesce((select free_beta_enabled from public.app_release_settings where id = true), false)
  ) f;
$function$;

revoke all on function public.get_service_fee_preview(numeric) from public, anon, authenticated;
grant execute on function public.get_service_fee_preview(numeric) to anon, authenticated;

-- Admin switch for the fee model (rate stays managed by the existing page).
create or replace function public.admin_set_fee_model(p_fee_model text)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
begin
  if not public.is_admin() then raise exception 'غير مصرح'; end if;
  if p_fee_model not in ('lawyer_commission','client_service_fee') then
    raise exception 'نموذج الرسوم غير صالح';
  end if;
  update public.platform_financial_settings
  set fee_model = p_fee_model, updated_at = now()
  where id = true;
end;
$function$;

revoke all on function public.admin_set_fee_model(text) from public, anon, authenticated;
grant execute on function public.admin_set_fee_model(text) to authenticated;

create or replace function public.get_fee_model()
returns text
language sql
stable
security definer
set search_path to 'public', 'pg_catalog'
as $function$
  select coalesce(fee_model, 'lawyer_commission')
  from public.platform_financial_settings
  where id = true and auth.uid() is not null;
$function$;

revoke all on function public.get_fee_model() from public, anon, authenticated;
grant execute on function public.get_fee_model() to authenticated;

-- ---------------------------------------------------------------------------
-- Surgical patches of the live functions. Each patch must match exactly once,
-- otherwise the whole migration aborts and nothing changes.
-- CREATE OR REPLACE keeps the functions' existing grants.
-- ---------------------------------------------------------------------------
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

-- 1) create_booking: charge lawyer price + service fee, keep breakdown.
select pg_temp.istishara_patch_fn(
  'public.create_booking(uuid,timestamp with time zone,text,text,text,text,text,uuid,text)'::regprocedure,
  '  v_payment_required boolean;',
  E'  v_payment_required boolean;\n  v_fee record;'
);
select pg_temp.istishara_patch_fn(
  'public.create_booking(uuid,timestamp with time zone,text,text,text,text,text,uuid,text)'::regprocedure,
  E'if v_price is null or v_price<=0 then raise exception \'سعر الموعد غير صالح\'; end if;',
  E'if v_price is null or v_price<=0 then raise exception \'سعر الموعد غير صالح\'; end if;\n  select * into v_fee from public.platform_service_fee_for(v_price, v_payment_required);\n  v_price := v_fee.client_total;'
);
select pg_temp.istishara_patch_fn(
  'public.create_booking(uuid,timestamp with time zone,text,text,text,text,text,uuid,text)'::regprocedure,
  'package_duration_minutes,consultation_status,lawyer_approved,lawyer_approved_at',
  'package_duration_minutes,consultation_status,lawyer_approved,lawyer_approved_at,fee_model_snapshot,lawyer_price,service_fee_amount'
);
select pg_temp.istishara_patch_fn(
  'public.create_booking(uuid,timestamp with time zone,text,text,text,text,text,uuid,text)'::regprocedure,
  E'v_description,v_duration,\'لم تبدأ\',false,null',
  E'v_description,v_duration,\'لم تبدأ\',false,null,v_fee.fee_model,v_fee.lawyer_price,v_fee.service_fee'
);

-- 2) submit_custom_appointment_request: hold and store the client total.
select pg_temp.istishara_patch_fn(
  'public.submit_custom_appointment_request(uuid,text,text,text,text,text,jsonb)'::regprocedure,
  '  v_item jsonb; v_start timestamptz; v_end timestamptz; v_request public.custom_appointment_requests;',
  E'  v_item jsonb; v_start timestamptz; v_end timestamptz; v_request public.custom_appointment_requests;\n  v_fee record;'
);
select pg_temp.istishara_patch_fn(
  'public.submit_custom_appointment_request(uuid,text,text,text,text,text,jsonb)'::regprocedure,
  E'then raise exception \'الحجوزات المدفوعة متوقفة مؤقتاً\'; end if;',
  E'then raise exception \'الحجوزات المدفوعة متوقفة مؤقتاً\'; end if;\n  select * into v_fee from public.platform_service_fee_for(v_price, v_payment_required);\n  v_price := v_fee.client_total;'
);
select pg_temp.istishara_patch_fn(
  'public.submit_custom_appointment_request(uuid,text,text,text,text,text,jsonb)'::regprocedure,
  'description,document_url,price,duration_minutes,payment_required,reserved_amount,client_windows,expires_at',
  'description,document_url,price,duration_minutes,payment_required,reserved_amount,client_windows,expires_at,fee_model_snapshot,lawyer_price,service_fee_amount'
);
select pg_temp.istishara_patch_fn(
  'public.submit_custom_appointment_request(uuid,text,text,text,text,text,jsonb)'::regprocedure,
  E'public.appointment_response_deadline(\'lawyer\')\n  ) returning * into v_request;',
  E'public.appointment_response_deadline(\'lawyer\'),\n    v_fee.fee_model,\n    case when v_payment_required then v_fee.lawyer_price else 0 end,\n    case when v_payment_required then v_fee.service_fee else 0 end\n  ) returning * into v_request;'
);

-- 3) client_confirm_custom_appointment: carry the breakdown to the booking.
select pg_temp.istishara_patch_fn(
  'public.client_confirm_custom_appointment(uuid,integer)'::regprocedure,
  'financial_policy_version,commission_rate_snapshot,lawyer_earnings_hold_hours_snapshot,financial_policy_snapshot',
  'financial_policy_version,commission_rate_snapshot,lawyer_earnings_hold_hours_snapshot,financial_policy_snapshot,fee_model_snapshot,lawyer_price,service_fee_amount'
);
select pg_temp.istishara_patch_fn(
  'public.client_confirm_custom_appointment(uuid,integer)'::regprocedure,
  'v_request.lawyer_earnings_hold_hours_snapshot,v_request.financial_policy_snapshot',
  'v_request.lawyer_earnings_hold_hours_snapshot,v_request.financial_policy_snapshot,v_request.fee_model_snapshot,v_request.lawyer_price,v_request.service_fee_amount'
);

-- 4) Accounting: under the service-fee model the platform revenue is the
--    fee itself and the lawyer receives his full price.
select pg_temp.istishara_patch_fn(
  'public.ensure_financial_accounting_for_payment(uuid)'::regprocedure,
  '  c := round(coalesce(p.amount,0)*v_rate/100,2);',
  E'  if b.fee_model_snapshot = \'client_service_fee\' then\n    c := round(least(coalesce(b.service_fee_amount,0), coalesce(p.amount,0)),2);\n  else\n    c := round(coalesce(p.amount,0)*v_rate/100,2);\n  end if;'
);
select pg_temp.istishara_patch_fn(
  'public.ensure_financial_accounting_for_payment(uuid)'::regprocedure,
  E'jsonb_build_object(\'commission_rate\',v_rate,\'financial_policy_version\',v_policy_version)',
  E'jsonb_build_object(\'commission_rate\',v_rate,\'financial_policy_version\',v_policy_version,\'fee_model\',coalesce(b.fee_model_snapshot,\'lawyer_commission\'),\'service_fee_amount\',coalesce(b.service_fee_amount,0))'
);

-- Activate the new model for NEW bookings only.
update public.platform_financial_settings
set fee_model = 'client_service_fee', updated_at = now()
where id = true;
