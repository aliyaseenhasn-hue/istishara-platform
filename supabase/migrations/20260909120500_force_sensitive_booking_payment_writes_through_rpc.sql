revoke insert, update, delete on table public.bookings from authenticated, anon;
revoke insert, update, delete on table public.payments from authenticated, anon;
revoke insert, update, delete on table public.cancellation_requests from authenticated, anon;
revoke insert, update, delete on table public.no_show_review_requests from authenticated, anon;
revoke insert, update, delete on table public.lawyer_payout_requests from authenticated, anon;

revoke truncate, references, trigger on table public.client_payout_accounts from authenticated, anon;
revoke insert, update, delete on table public.client_payout_accounts from authenticated, anon;

-- Reads remain governed by RLS. Mutations are performed only through
-- SECURITY DEFINER RPCs that validate actor, state transitions and money rules.
