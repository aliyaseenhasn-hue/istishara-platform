begin;

-- Reconcile historical paid transactions with the current platform commission (10%).
update public.payment_financials pf
set commission_rate = s.commission_rate,
    platform_commission = round(pf.gross_amount * s.commission_rate / 100, 2),
    lawyer_net_amount = round(greatest(0, pf.gross_amount - round(pf.gross_amount * s.commission_rate / 100, 2)), 2),
    updated_at = now()
from public.platform_financial_settings s, public.payments p
where s.id = true
  and p.id = pf.payment_id
  and p.status = 'تم الدفع'
  and pf.currency = s.currency;

-- Keep the ledger consistent with payment_financials.
update public.financial_ledger fl
set amount = round(pf.platform_commission, 2),
    metadata = jsonb_build_object(
      'commission_rate', pf.commission_rate,
      'reconciled_at', now()
    )
from public.payment_financials pf
where fl.payment_id = pf.payment_id
  and fl.entry_type = 'platform_commission';

update public.financial_ledger fl
set amount = round(pf.lawyer_net_amount, 2),
    metadata = jsonb_build_object(
      'availability', 'settled',
      'reconciled_at', now()
    )
from public.payment_financials pf
where fl.payment_id = pf.payment_id
  and fl.entry_type = 'lawyer_earning';

-- lifetime_earned represents the lawyer's net earnings, not gross client payments.
-- The existing payout reservation is intentionally left untouched.
update public.lawyer_wallets w
set lifetime_earned = coalesce((
      select sum(pf.lawyer_net_amount)
      from public.payment_financials pf
      where pf.lawyer_id = w.lawyer_id
        and pf.status in ('pending', 'settled')
    ), 0),
    updated_at = now()
where exists (
  select 1
  from public.payment_financials pf
  where pf.lawyer_id = w.lawyer_id
);

-- These functions are business operations and must not be callable anonymously.
revoke execute on function public.cleanup_expired_telegram_login_requests() from public, anon;
revoke execute on function public.update_own_lawyer_wallet_number(text) from public, anon;
grant execute on function public.update_own_lawyer_wallet_number(text) to authenticated;

commit;
