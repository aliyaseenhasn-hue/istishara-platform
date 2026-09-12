-- Booking archive/restore are client-domain operations and must not be callable
-- through the public/anon SQL API. The application uses authenticated flows
-- where ownership is enforced by the functions themselves; keep service_role
-- available for trusted maintenance paths.

revoke execute on function public.archive_booking_for_user(uuid) from anon, authenticated, public;
revoke execute on function public.restore_booking_from_archive(uuid) from anon, authenticated, public;

grant execute on function public.archive_booking_for_user(uuid) to service_role;
grant execute on function public.restore_booking_from_archive(uuid) to service_role;
