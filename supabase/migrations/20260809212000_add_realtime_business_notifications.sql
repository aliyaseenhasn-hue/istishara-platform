CREATE OR REPLACE FUNCTION public.enqueue_user_notification(
  p_user_id uuid,
  p_title text,
  p_body text,
  p_type text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_user_id IS NULL THEN RETURN; END IF;
  IF EXISTS (
    SELECT 1 FROM public.notifications
    WHERE user_id = p_user_id
      AND type = p_type
      AND title = p_title
      AND body = p_body
      AND created_at > now() - interval '30 seconds'
  ) THEN
    RETURN;
  END IF;
  INSERT INTO public.notifications(user_id, title, body, type, is_read)
  VALUES (p_user_id, p_title, p_body, p_type, false);
END;
$$;

REVOKE ALL ON FUNCTION public.enqueue_user_notification(uuid,text,text,text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.notify_booking_events()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM public.enqueue_user_notification(NEW.user_id, 'تم إرسال طلب الاستشارة', 'تم إنشاء طلب الاستشارة بنجاح، وسيتم إشعارك عند تحديث حالته.', 'booking');
    PERFORM public.enqueue_user_notification(NEW.lawyer_id, 'طلب استشارة جديد', 'وصل طلب استشارة جديد من أحد العملاء.', 'booking');
    RETURN NEW;
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    PERFORM public.enqueue_user_notification(
      NEW.user_id,
      CASE NEW.status
        WHEN 'قيد مراجعة المحامي' THEN 'طلبك قيد مراجعة المحامي'
        WHEN 'مؤكد' THEN 'تم تأكيد الاستشارة'
        WHEN 'قيد التنفيذ' THEN 'بدأت الاستشارة'
        WHEN 'مكتمل' THEN 'اكتملت الاستشارة'
        WHEN 'ملغي' THEN 'تم إلغاء الاستشارة'
        WHEN 'مسترد' THEN 'تم استرداد المبلغ'
        WHEN 'بانتظار الاسترداد' THEN 'طلب الاسترداد قيد المعالجة'
        ELSE 'تم تحديث حالة الحجز'
      END,
      CASE NEW.status
        WHEN 'قيد مراجعة المحامي' THEN 'تم استلام الدفع، والحجز الآن بانتظار قرار المحامي.'
        WHEN 'مؤكد' THEN 'تم تأكيد حجزك ويمكنك متابعة تفاصيل الاستشارة.'
        WHEN 'قيد التنفيذ' THEN 'بدأت جلسة الاستشارة ويمكنك الآن التواصل مع المحامي.'
        WHEN 'مكتمل' THEN 'انتهت الاستشارة ويمكنك تقييم المحامي.'
        WHEN 'ملغي' THEN 'تم إلغاء حجز الاستشارة.'
        WHEN 'مسترد' THEN 'تم تسجيل استرداد المبلغ المرتبط بالحجز.'
        WHEN 'بانتظار الاسترداد' THEN 'تم تسجيل طلب الاسترداد وسيتم تحديثك عند إتمامه.'
        ELSE 'تم تحديث حالة حجز الاستشارة.'
      END,
      'booking'
    );
    PERFORM public.enqueue_user_notification(NEW.lawyer_id, 'تحديث حجز العميل', 'تم تحديث حالة أحد الحجوزات في لوحة المحامي.', 'booking');
  END IF;

  IF NEW.manual_received_at IS DISTINCT FROM OLD.manual_received_at AND NEW.manual_received_at IS NOT NULL THEN
    PERFORM public.enqueue_user_notification(NEW.user_id, 'تم تسجيل الدفع اليدوي', 'تم تسجيل مبلغ الاستشارة المستلم يدوياً من المحامي.', 'payment');
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_booking_events ON public.bookings;
CREATE TRIGGER trg_notify_booking_events
AFTER INSERT OR UPDATE OF status, manual_received_at ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.notify_booking_events();

CREATE OR REPLACE FUNCTION public.notify_payment_events()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_lawyer_id uuid;
BEGIN
  SELECT user_id, lawyer_id INTO v_user_id, v_lawyer_id
  FROM public.bookings WHERE id = COALESCE(NEW.booking_id, OLD.booking_id);

  IF TG_OP = 'INSERT' OR NEW.status IS DISTINCT FROM OLD.status THEN
    PERFORM public.enqueue_user_notification(
      v_user_id,
      CASE NEW.status
        WHEN 'تم الدفع' THEN 'تم تأكيد الدفع'
        WHEN 'فشل الدفع' THEN 'فشل الدفع'
        WHEN 'قيد معالجة الدفع' THEN 'الدفع قيد المعالجة'
        WHEN 'تم استرداد المبلغ' THEN 'تم استرداد المبلغ'
        ELSE 'تحديث حالة الدفع'
      END,
      CASE NEW.status
        WHEN 'تم الدفع' THEN 'تم تسجيل الدفع بنجاح لحجز الاستشارة.'
        WHEN 'فشل الدفع' THEN 'تعذر تأكيد عملية الدفع. يرجى مراجعة تفاصيل الدفع.'
        WHEN 'قيد معالجة الدفع' THEN 'عملية الدفع قيد المعالجة وسيتم تحديثك عند اكتمال التحقق.'
        WHEN 'تم استرداد المبلغ' THEN 'تم تسجيل استرداد المبلغ.'
        ELSE 'تم تحديث حالة الدفع المرتبط بحجزك.'
      END,
      'payment'
    );
    IF NEW.status = 'تم الدفع' THEN
      PERFORM public.enqueue_user_notification(v_lawyer_id, 'تم استلام الدفع', 'تم تأكيد دفع العميل المرتبط بأحد حجوزاتك.', 'payment');
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_payment_events ON public.payments;
CREATE TRIGGER trg_notify_payment_events
AFTER INSERT OR UPDATE OF status ON public.payments
FOR EACH ROW EXECUTE FUNCTION public.notify_payment_events();

CREATE OR REPLACE FUNCTION public.notify_custom_request_events()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM public.enqueue_user_notification(NEW.user_id, 'تم إرسال طلب الاستشارة', 'تم إرسال طلب الاستشارة المخصص بنجاح.', 'booking');
    PERFORM public.enqueue_user_notification(NEW.lawyer_id, 'طلب استشارة مخصص جديد', 'وصلتك طلب استشارة مخصص جديد من العميل.', 'booking');
  ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
    PERFORM public.enqueue_user_notification(
      NEW.user_id,
      CASE NEW.status WHEN 'مقبول' THEN 'تم قبول طلب الاستشارة' WHEN 'مرفوض' THEN 'تم رفض طلب الاستشارة' WHEN 'ملغي' THEN 'تم إلغاء طلب الاستشارة' WHEN 'مكتمل' THEN 'اكتمل طلب الاستشارة' ELSE 'تم تحديث طلب الاستشارة' END,
      CASE NEW.status WHEN 'مقبول' THEN 'وافق المحامي على طلب الاستشارة.' WHEN 'مرفوض' THEN 'اعتذر المحامي عن قبول طلب الاستشارة.' WHEN 'ملغي' THEN 'تم إلغاء طلب الاستشارة.' WHEN 'مكتمل' THEN 'تم إكمال طلب الاستشارة.' ELSE 'تم تحديث حالة طلب الاستشارة.' END,
      'booking'
    );
    PERFORM public.enqueue_user_notification(NEW.lawyer_id, 'تحديث طلب الاستشارة', 'تم تحديث حالة أحد طلبات الاستشارة المخصصة.', 'booking');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_custom_request_events ON public.custom_consultation_requests;
CREATE TRIGGER trg_notify_custom_request_events
AFTER INSERT OR UPDATE OF status ON public.custom_consultation_requests
FOR EACH ROW EXECUTE FUNCTION public.notify_custom_request_events();

CREATE OR REPLACE FUNCTION public.notify_message_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_lawyer_id uuid;
  v_recipient uuid;
BEGIN
  SELECT user_id, lawyer_id INTO v_user_id, v_lawyer_id
  FROM public.conversations WHERE id = NEW.conversation_id;
  v_recipient := CASE WHEN NEW.sender_id = v_user_id THEN v_lawyer_id ELSE v_user_id END;
  PERFORM public.enqueue_user_notification(v_recipient, 'رسالة جديدة', 'لديك رسالة جديدة في المحادثة.', 'chat');
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_message_event ON public.messages;
CREATE TRIGGER trg_notify_message_event
AFTER INSERT ON public.messages
FOR EACH ROW EXECUTE FUNCTION public.notify_message_event();

CREATE OR REPLACE FUNCTION public.notify_specialization_request_events()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  admin_id uuid;
BEGIN
  IF TG_OP = 'INSERT' THEN
    FOR admin_id IN SELECT id FROM public.profiles WHERE role = 'admin' LOOP
      PERFORM public.enqueue_user_notification(admin_id, 'طلب تغيير تخصص جديد', 'وصل طلب تغيير تخصص من محامٍ ويحتاج إلى مراجعة الإدارة.', 'admin');
    END LOOP;
  ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
    PERFORM public.enqueue_user_notification(
      NEW.lawyer_id,
      CASE NEW.status WHEN 'approved' THEN 'تمت الموافقة على تغيير التخصص' WHEN 'rejected' THEN 'تم رفض تغيير التخصص' ELSE 'تحديث طلب تغيير التخصص' END,
      CASE NEW.status WHEN 'approved' THEN 'وافقت الإدارة على طلب تغيير تخصصك.' WHEN 'rejected' THEN 'رفضت الإدارة طلب تغيير تخصصك.' ELSE 'تم تحديث حالة طلب تغيير التخصص.' END,
      'admin'
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_specialization_request_events ON public.specialization_change_requests;
CREATE TRIGGER trg_notify_specialization_request_events
AFTER INSERT OR UPDATE OF status ON public.specialization_change_requests
FOR EACH ROW EXECUTE FUNCTION public.notify_specialization_request_events();

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END $$;

REVOKE ALL ON FUNCTION public.notify_booking_events() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.notify_payment_events() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.notify_custom_request_events() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.notify_message_event() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.notify_specialization_request_events() FROM PUBLIC;
