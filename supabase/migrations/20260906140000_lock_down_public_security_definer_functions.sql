-- Keep public lawyer directory RPCs intentionally callable by clients,
-- but do not expose any broader SECURITY DEFINER surface through PUBLIC.
-- Explicit grants document the intended API surface.
revoke execute on function public.get_public_lawyer(uuid) from public;
revoke execute on function public.get_public_lawyers(integer, integer) from public;
grant execute on function public.get_public_lawyer(uuid) to anon, authenticated;
grant execute on function public.get_public_lawyers(integer, integer) to anon, authenticated;
