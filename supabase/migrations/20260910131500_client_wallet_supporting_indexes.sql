-- Supporting indexes for wallet audit and review relations.
create index if not exists client_wallet_ledger_topup_idx
  on public.client_wallet_ledger(topup_id)
  where topup_id is not null;

create index if not exists client_wallet_ledger_booking_idx
  on public.client_wallet_ledger(booking_id)
  where booking_id is not null;

create index if not exists client_wallet_ledger_appointment_request_idx
  on public.client_wallet_ledger(appointment_request_id)
  where appointment_request_id is not null;

create index if not exists client_wallet_topups_reviewed_by_idx
  on public.client_wallet_topups(reviewed_by)
  where reviewed_by is not null;
