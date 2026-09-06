-- Trigger functions are invoked by PostgreSQL triggers, not by PostgREST clients.
-- Removing direct EXECUTE closes an unnecessary RPC surface.

REVOKE EXECUTE ON FUNCTION public.set_push_device_tokens_updated_at() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.touch_pwa_push_subscription() FROM anon, authenticated;
