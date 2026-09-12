alter table public.client_wallet_ledger
  drop constraint if exists client_wallet_ledger_entry_type_check;

alter table public.client_wallet_ledger
  add constraint client_wallet_ledger_entry_type_check
  check (entry_type = any (array[
    'topup'::text,
    'booking_payment'::text,
    'appointment_hold'::text,
    'appointment_release'::text,
    'appointment_capture'::text,
    'withdrawal_hold'::text,
    'withdrawal_release'::text,
    'withdrawal_capture'::text,
    'admin_adjustment'::text
  ]));
