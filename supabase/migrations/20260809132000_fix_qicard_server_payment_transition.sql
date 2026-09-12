-- Qi Card verifies payments server-side. The payment verification trigger must allow
-- bookings that are still in the gateway processing state, not only manual confirmation.
CREATE OR REPLACE FUNCTION public.sync_booking_from_payment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_verifier uuid;
BEGIN
  SELECT * INTO v_booking
  FROM public.bookings
  WHERE id = NEW.booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'الحجز غير موجود';
  END IF;

  IF NEW.status = 'تم الدفع' THEN
    IF v_booking.status NOT IN ('قيد معالجة الدفع','بانتظار التأكيد') THEN
      RAISE EXCEPTION 'لا يمكن اعتماد الدفع في حالة الحجز الحالية';
    END IF;
    SELECT id INTO v_verifier FROM public.profiles WHERE auth_id = (SELECT auth.uid());
    NEW.verified_by := v_verifier;
    NEW.verified_at := COALESCE(NEW.verified_at, now());
    UPDATE public.bookings
    SET status = CASE WHEN lawyer_approved THEN 'مؤكد' ELSE 'قيد مراجعة المحامي' END
    WHERE id = NEW.booking_id;

  ELSIF NEW.status = 'فشل الدفع' THEN
    IF v_booking.status NOT IN ('قيد معالجة الدفع','بانتظار التأكيد') THEN
      RAISE EXCEPTION 'لا يمكن رفض الدفع في حالة الحجز الحالية';
    END IF;
    SELECT id INTO v_verifier FROM public.profiles WHERE auth_id = (SELECT auth.uid());
    NEW.verified_by := v_verifier;
    NEW.verified_at := COALESCE(NEW.verified_at, now());
    UPDATE public.bookings SET status = 'قيد انتظار الدفع' WHERE id = NEW.booking_id;

  ELSIF NEW.status = 'تم استرداد المبلغ' THEN
    IF v_booking.status NOT IN ('مؤكد','قيد التنفيذ','مكتمل') THEN
      RAISE EXCEPTION 'لا يمكن استرداد هذا الحجز في حالته الحالية';
    END IF;
    SELECT id INTO v_verifier FROM public.profiles WHERE auth_id = (SELECT auth.uid());
    NEW.verified_by := v_verifier;
    NEW.verified_at := COALESCE(NEW.verified_at, now());
    UPDATE public.bookings SET status = 'مسترد' WHERE id = NEW.booking_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_booking_from_payment ON public.payments;
CREATE TRIGGER sync_booking_from_payment
AFTER INSERT OR UPDATE OF status ON public.payments
FOR EACH ROW EXECUTE FUNCTION public.sync_booking_from_payment();

REVOKE ALL ON FUNCTION public.sync_booking_from_payment() FROM PUBLIC, anon, authenticated;
