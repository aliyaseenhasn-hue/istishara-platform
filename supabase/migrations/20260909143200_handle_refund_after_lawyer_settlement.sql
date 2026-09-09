create or replace function public.sync_financial_payment_trigger()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking_status text;
  v_pf public.payment_financials%rowtype;
begin
  if new.status='تم الدفع' and (tg_op='INSERT' or old.status is distinct from new.status) then
    select status into v_booking_status from public.bookings where id=new.booking_id;
    -- A payment confirmed after cancellation is money held solely for refund;
    -- it must not create platform commission or lawyer earnings.
    if v_booking_status<>'بانتظار الاسترداد' then
      perform public.ensure_financial_accounting_for_payment(new.id);
    end if;

  elsif new.status='تم استرداد المبلغ' and old.status is distinct from new.status then
    select * into v_pf
    from public.payment_financials
    where payment_id=new.id
    for update;

    if not found or v_pf.status='refunded' then
      return new;
    end if;

    if v_pf.status='pending' then
      perform public.reverse_financial_accounting_for_refund(new.id);
    else
      -- The lawyer earning has already been settled/paid. Do not silently
      -- debit the lawyer wallet. Complete the client refund and record that
      -- a separate administrative financial follow-up is required.
      update public.payment_financials
      set status='refunded', updated_at=now()
      where payment_id=new.id;

      insert into public.financial_ledger(
        payment_id, booking_id, client_id, lawyer_id,
        entry_type, amount, currency, idempotency_key, metadata
      ) values (
        v_pf.payment_id,
        v_pf.booking_id,
        v_pf.client_id,
        v_pf.lawyer_id,
        'refund',
        v_pf.gross_amount,
        v_pf.currency,
        'payment:'||v_pf.payment_id||':refund',
        jsonb_build_object(
          'lawyer_pending_reversed', 0,
          'lawyer_net_already_settled', v_pf.lawyer_net_amount,
          'platform_commission_previously_recorded', v_pf.platform_commission,
          'requires_admin_financial_followup', true,
          'previous_financial_status', v_pf.status
        )
      )
      on conflict(idempotency_key) do nothing;
    end if;
  end if;

  return new;
end;
$$;
