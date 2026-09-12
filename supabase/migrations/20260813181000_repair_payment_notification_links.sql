-- Repair payment notifications that were backfilled by the previous migration using only the latest booking.
UPDATE public.notifications n
SET reference_id = p.booking_id::text,
    reference_type = 'booking'
FROM LATERAL (
  SELECT p1.booking_id
  FROM public.payments p1
  JOIN public.bookings b1 ON b1.id = p1.booking_id
  WHERE b1.user_id = n.user_id
    AND n.type = 'payment'
    AND p1.created_at <= n.created_at
  ORDER BY p1.created_at DESC
  LIMIT 1
) p
WHERE n.type = 'payment';
