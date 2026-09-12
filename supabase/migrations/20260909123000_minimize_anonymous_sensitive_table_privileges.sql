revoke all on table public.bookings from anon;
revoke all on table public.client_credit_settlements from anon;
revoke all on table public.client_credits from anon;
revoke all on table public.client_payout_accounts from anon;
revoke all on table public.conversations from anon;
revoke all on table public.custom_consultation_requests from anon;
revoke all on table public.financial_ledger from anon;
revoke all on table public.lawyer_followers from anon;
revoke all on table public.lawyer_payout_requests from anon;
revoke all on table public.lawyer_wallets from anon;
revoke all on table public.messages from anon;
revoke all on table public.no_show_review_requests from anon;
revoke all on table public.notifications from anon;
revoke all on table public.payment_financials from anon;
revoke all on table public.payments from anon;
revoke all on table public.profiles from anon;
revoke all on table public.push_device_tokens from anon;
revoke all on table public.pwa_push_subscriptions from anon;
revoke all on table public.reviews from anon;
revoke all on table public.specialization_change_requests from anon;
revoke all on table public.platform_financial_settings from anon;

-- Intentionally public/pre-auth data remains available through dedicated
-- public tables/buckets and availability/release settings.
