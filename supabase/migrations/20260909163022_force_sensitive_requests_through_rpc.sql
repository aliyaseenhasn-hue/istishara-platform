-- Force sensitive user-initiated workflows through their validated SECURITY DEFINER RPCs.
-- Direct table INSERTs could otherwise bypass validation/reservation/review invariants.

-- Lawyer payouts must go through request_lawyer_payout(), which validates balance,
-- payout limits and reserves the requested amount atomically.
revoke insert on table public.lawyer_payout_requests from authenticated, anon;
drop policy if exists "lawyer payout self insert" on public.lawyer_payout_requests;

-- Cancellation requests must go through request_booking_cancellation() or
-- request_client_booking_cancellation(), which validate booking ownership/state.
revoke insert on table public.cancellation_requests from authenticated, anon;
drop policy if exists "cancellation requests lawyer create" on public.cancellation_requests;

-- Specialization changes must go through request_specialization_change(), which
-- validates active-lawyer status, document presence and pending-request uniqueness.
revoke insert on table public.specialization_change_requests from authenticated, anon;
drop policy if exists specialization_requests_insert on public.specialization_change_requests;