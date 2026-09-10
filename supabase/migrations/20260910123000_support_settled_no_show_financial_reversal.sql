-- Keep normal post-settlement refunds guarded, but allow an admin-reviewed
-- no-show decision to reverse already released lawyer earnings.
create or replace function public.reverse_financial_accounting_for_refund(p_payment_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  pf public.payment_financials%rowtype;
  v_pending numeric(18,2);
  v_booking_status text;
  v_wallet_bucket text;
begin
  select * into pf from public.payment_financials where payment_id=p_payment_id for update;
  if not found or pf.status='refunded' then return; end if;

  if pf.status='pending' then
    select pending_balance into v_pending from public.lawyer_wallets where lawyer_id=pf.lawyer_id for update;
    if v_pending is null then raise exception 'محفظة المحامي غير موجودة'; end if;
    if v_pending < pf.lawyer_net_amount then
      raise exception 'الرصيد المعلق للمحامي لا يغطي عكس هذه العملية';
    end if;

    update public.lawyer_wallets
    set pending_balance=pending_balance-pf.lawyer_net_amount,
        lifetime_earned=greatest(0,lifetime_earned-pf.lawyer_net_amount),
        updated_at=now()
    where lawyer_id=pf.lawyer_id;
    v_wallet_bucket:='pending';

  elsif pf.status='settled' then
    select status into v_booking_status from public.bookings where id=pf.booking_id for update;
    if v_booking_status <> 'بانتظار مراجعة عدم الحضور' then
      raise exception 'لا يمكن تنفيذ الاسترداد التلقائي بعد تسوية مستحقات المحامي؛ يلزم إجراء مالي إداري منفصل';
    end if;

    update public.lawyer_wallets
    set available_balance=available_balance-pf.lawyer_net_amount,
        lifetime_earned=greatest(0,lifetime_earned-pf.lawyer_net_amount),
        updated_at=now()
    where lawyer_id=pf.lawyer_id;
    if not found then raise exception 'محفظة المحامي غير موجودة'; end if;
    v_wallet_bucket:='available';
  else
    raise exception 'لا يمكن عكس العملية المالية في حالتها الحالية';
  end if;

  update public.payment_financials
  set status='refunded',updated_at=now()
  where payment_id=p_payment_id;

  insert into public.financial_ledger(
    payment_id,booking_id,client_id,lawyer_id,entry_type,amount,currency,idempotency_key,metadata
  ) values(
    pf.payment_id,pf.booking_id,pf.client_id,pf.lawyer_id,'refund',pf.gross_amount,pf.currency,
    'payment:'||pf.payment_id||':refund',
    jsonb_build_object('lawyer_earnings_reversed',pf.lawyer_net_amount,'wallet_bucket',v_wallet_bucket,'source','admin_refund')
  ) on conflict(idempotency_key) do nothing;
end;
$$;
