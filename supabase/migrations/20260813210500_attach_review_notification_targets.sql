CREATE OR REPLACE FUNCTION public.notify_review_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.enqueue_user_notification_with_reference(
    NEW.lawyer_id,
    'تقييم جديد للاستشارة',
    'أضاف أحد العملاء تقييماً جديداً لاستشارتك.',
    'review',
    'booking',
    NEW.booking_id
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_review_event ON public.reviews;
CREATE TRIGGER trg_notify_review_event
AFTER INSERT ON public.reviews
FOR EACH ROW EXECUTE FUNCTION public.notify_review_event();

REVOKE ALL ON FUNCTION public.notify_review_event() FROM PUBLIC;
