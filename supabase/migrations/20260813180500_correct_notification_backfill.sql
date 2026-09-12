-- Correct the notification deep-link backfill and keep all future notifications linked.
-- This migration intentionally follows 20260813180000_fix_notification_deep_links.sql.
UPDATE public.notifications n
SET reference_id = b.id::text, reference_type = 'booking'
FROM LATERAL (
  SELECT b1.id
  FROM public.bookings b1
  WHERE b1.user_id = n.user_id
    AND n.type = 'booking'
    AND b1.created_at <= n.created_at
  ORDER BY b1.created_at DESC
  LIMIT 1
) b
WHERE n.reference_id IS NULL;

UPDATE public.notifications n
SET reference_id = p.booking_id::text, reference_type = 'booking'
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
WHERE n.reference_id IS NULL;
