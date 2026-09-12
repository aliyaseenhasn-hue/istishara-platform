-- Internal booking helpers must not be directly callable by clients.
-- They remain available to service_role and internal SECURITY DEFINER trigger execution.
revoke execute on function public.get_booking_id_for_slot(uuid) from public, anon, authenticated;
grant execute on function public.get_booking_id_for_slot(uuid) to service_role;

revoke execute on function public.sync_lawyer_slot_availability(uuid) from public, anon, authenticated;
grant execute on function public.sync_lawyer_slot_availability(uuid) to service_role;
