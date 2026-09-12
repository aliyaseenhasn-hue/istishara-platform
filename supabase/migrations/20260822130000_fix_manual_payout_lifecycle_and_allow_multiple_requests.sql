-- Manual payouts are independent: a previous payout must not block a new payout.
-- Each payout reserves its own amount in pending_balance.

create or replace function public.request_lawyer_payout(p_amount numeric)
returns uuid language plpgsql security definer set search_path=public as $$
declare
  v_lawyer uuid; v_wallet record; v_profile record; v_settings record; v_request uuid; v_status text;
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

  -- Multiple independent manual payout requests are allowed. The amount is
  -- reserved from available_balance for this specific request.
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

-- Support legacy approved rows in the current manual lifecycle.
create or replace function public.admin_complete_payout(
  p_payout_id uuid,
  p_status text,
  p_provider_reference text default null,
  p_rejection_reason text default null
)
returns void language plpgsql security definer set search_path=public as $$
declare
  v_admin uuid; v_request record; v_wallet record;
begin
  select id into v_admin from public.profiles where auth_id=auth.uid() and role='admin';
  if v_admin is null then raise exception 'غير مصرح: هذه العملية للإدارة فقط'; end if;
  if p_status not in ('paid','rejected') then raise exception 'حالة غير صالحة'; end if;
  select * into v_request from public.lawyer_payout_requests where id=p_payout_id for update;
  if not found then raise exception 'طلب السحب غير موجود'; end if;
  if v_request.status not in ('pending_review','approved') then raise exception using message='لا يمكن معالجة طلب بهذه الحالة: '||v_request.status; end if;
  select * into v_wallet from public.lawyer_wallets where lawyer_id=v_request.lawyer_id for update;
  if not found then raise exception 'محفظة المحامي غير موجودة'; end if;
  if v_wallet.pending_balance < v_request.amount then raise exception 'الرصيد المعلق لا يغطي طلب السحب'; end if;

  if p_status='paid' then
    update public.lawyer_wallets
    set pending_balance=pending_balance-v_request.amount,
        lifetime_paid_out=lifetime_paid_out+v_request.amount,
        updated_at=now()
    where lawyer_id=v_request.lawyer_id;
    update public.lawyer_payout_requests
    set status='paid', provider_reference=coalesce(nullif(trim(p_provider_reference),''),provider_reference),
        processed_at=now(), completed_at=now(), approved_at=coalesce(approved_at,now())
    where id=p_payout_id;
  else
    update public.lawyer_wallets
    set available_balance=available_balance+v_request.amount,
        pending_balance=pending_balance-v_request.amount,
        updated_at=now()
    where lawyer_id=v_request.lawyer_id;
    update public.lawyer_payout_requests
    set status='rejected', rejection_reason=nullif(trim(p_rejection_reason),''),
        processed_at=now(), rejected_at=now()
    where id=p_payout_id;
  end if;
end;
$$;

revoke all on function public.admin_complete_payout(uuid,text,text,text) from public;
grant execute on function public.admin_complete_payout(uuid,text,text,text) to authenticated;

-- Repair the known legacy request that was approved but never transferred.
update public.lawyer_payout_requests
set status='pending_review'
where id='268125f7-44d8-4658-b6d7-aafceee7db69'
  and status='approved'
  and provider_reference is null;
