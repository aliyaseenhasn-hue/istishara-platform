-- This function is invoked by the bookings trigger and is not a client API.
-- Prevent direct invocation by anon/authenticated while preserving trigger execution.
revoke execute on function public.sync_slot_after_booking_change() from public, anon, authenticated;
grant execute on function public.sync_slot_after_booking_change() to service_role;
