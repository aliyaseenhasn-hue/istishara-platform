-- Resolve a notification's booking through a SECURITY DEFINER function so both
-- sides of a booking can open the exact referenced consultation even when the
-- bookings table has restrictive RLS policies.
CREATE OR REPLACE FUNCTION public.get_booking_for_notification(p_booking_id uuid)
RETURNS SETOF public.bookings
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT b.*
  FROM public.bookings b
  JOIN public.profiles requester ON requester.id = b.user_id
  JOIN public.profiles lawyer ON lawyer.id = b.lawyer_id
  WHERE b.id = p_booking_id
    AND (
      requester.auth_id = auth.uid()
      OR lawyer.auth_id = auth.uid()
    );
$$;

REVOKE ALL ON FUNCTION public.get_booking_for_notification(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_booking_for_notification(uuid) TO authenticated;
