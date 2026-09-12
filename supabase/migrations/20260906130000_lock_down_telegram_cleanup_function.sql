-- Prevent any authenticated client from forcing all pending Telegram login requests to expire.
-- Cleanup is an internal maintenance operation and must run only with service_role.
revoke execute on function public.cleanup_expired_telegram_login_requests() from public, anon, authenticated;
grant execute on function public.cleanup_expired_telegram_login_requests() to service_role;
