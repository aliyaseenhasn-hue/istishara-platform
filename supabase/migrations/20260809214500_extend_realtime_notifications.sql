CREATE OR REPLACE FUNCTION public.notify_lawyer_profile_events()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.verified IS DISTINCT FROM OLD.verified THEN
    PERFORM public.enqueue_user_notification(
      NEW.profile_id,
      CASE WHEN NEW.verified THEN 'تم توثيق حساب المحامي' ELSE 'تم تحديث حالة توثيق حسابك' END,
      CASE WHEN NEW.verified THEN 'تمت الموافقة على توثيق حسابك ويمكنك استخدام مزايا المحامي.' ELSE 'تم تغيير حالة توثيق حسابك. راجع حسابك لمعرفة التفاصيل.' END,
      'admin'
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_lawyer_profile_events ON public.lawyer_profiles;
CREATE TRIGGER trg_notify_lawyer_profile_events
AFTER UPDATE OF verified ON public.lawyer_profiles
FOR EACH ROW EXECUTE FUNCTION public.notify_lawyer_profile_events();

CREATE OR REPLACE FUNCTION public.notify_review_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.enqueue_user_notification(
    NEW.lawyer_id,
    'تقييم جديد للاستشارة',
    'أضاف أحد العملاء تقييماً جديداً لاستشارتك.',
    'review'
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_review_event ON public.reviews;
CREATE TRIGGER trg_notify_review_event
AFTER INSERT ON public.reviews
FOR EACH ROW EXECUTE FUNCTION public.notify_review_event();

REVOKE ALL ON FUNCTION public.notify_lawyer_profile_events() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.notify_review_event() FROM PUBLIC;
