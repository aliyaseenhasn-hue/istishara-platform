-- Store the exact domain record behind every business notification.
-- Existing 4-argument calls remain valid because the reference parameters have defaults.
CREATE OR REPLACE FUNCTION public.enqueue_user_notification(
  p_user_id uuid,
  p_title text,
  p_body text,
  p_type text,
  p_reference_id text DEFAULT NULL,
  p_reference_type text DEFAULT NULL
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

  INSERT INTO public.notifications(
    user_id, title, body, type, is_read, reference_id, reference_type
  )
  VALUES (
    p_user_id, p_title, p_body, p_type, false, p_reference_id, p_reference_type
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_booking_events()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM public.enqueue_user_notification(NEW.user_id, 'تم إرسال طلب الاستشارة', 'تم إنشاء طلب الاستشارة بنجاح، وسيتم إشعارك عند تحديث حالته.', 'booking', NEW.id::text, 'booking');
    PERFORM public.enqueue_user_notification(NEW.lawyer_id, 'طلب استشارة جديد', 'وصل طلب استشارة جديد من أحد العملاء.', 'booking', NEW.id::text, 'booking');
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
      'booking', NEW.id::text, 'booking'
    );
    PERFORM public.enqueue_user_notification(NEW.lawyer_id, 'تحديث حجز العميل', 'تم تحديث حالة أحد الحجوزات في لوحة المحامي.', 'booking', NEW.id::text, 'booking');
  END IF;

  IF NEW.manual_received_at IS DISTINCT FROM OLD.manual_received_at AND NEW.manual_received_at IS NOT NULL THEN
    PERFORM public.enqueue_user_notification(NEW.user_id, 'تم تسجيل الدفع اليدوي', 'تم تسجيل مبلغ الاستشارة المستلم يدوياً من المحامي.', 'payment', NEW.id::text, 'booking');
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_payment_events()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_lawyer_id uuid;
  v_booking_id text;
BEGIN
  v_booking_id := COALESCE(NEW.booking_id, OLD.booking_id)::text;
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
      'payment', v_booking_id, 'booking'
    );
    IF NEW.status = 'تم الدفع' THEN
      PERFORM public.enqueue_user_notification(v_lawyer_id, 'تم استلام الدفع', 'تم تأكيد دفع العميل المرتبط بأحد حجوزاتك.', 'payment', v_booking_id, 'booking');
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_custom_request_events()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM public.enqueue_user_notification(NEW.user_id, 'تم إرسال طلب الاستشارة', 'تم إرسال طلب الاستشارة المخصص بنجاح.', 'booking', NEW.id::text, 'custom_request');
    PERFORM public.enqueue_user_notification(NEW.lawyer_id, 'طلب استشارة مخصص جديد', 'وصلتك طلب استشارة مخصص جديد من العميل.', 'booking', NEW.id::text, 'custom_request');
  ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
    PERFORM public.enqueue_user_notification(
      NEW.user_id,
      CASE NEW.status WHEN 'مقبول' THEN 'تم قبول طلب الاستشارة' WHEN 'مرفوض' THEN 'تم رفض طلب الاستشارة' WHEN 'ملغي' THEN 'تم إلغاء طلب الاستشارة' WHEN 'مكتمل' THEN 'اكتمل طلب الاستشارة' ELSE 'تم تحديث طلب الاستشارة' END,
      CASE NEW.status WHEN 'مقبول' THEN 'وافق المحامي على طلب الاستشارة.' WHEN 'مرفوض' THEN 'اعتذر المحامي عن قبول طلب الاستشارة.' WHEN 'ملغي' THEN 'تم إلغاء طلب الاستشارة.' WHEN 'مكتمل' THEN 'تم إكمال طلب الاستشارة.' ELSE 'تم تحديث حالة طلب الاستشارة.' END,
      'booking', NEW.id::text, 'custom_request'
    );
    PERFORM public.enqueue_user_notification(NEW.lawyer_id, 'تحديث طلب الاستشارة', 'تم تحديث حالة أحد طلبات الاستشارة المخصصة.', 'booking', NEW.id::text, 'custom_request');
  END IF;
  RETURN NEW;
END;
$$;

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
  PERFORM public.enqueue_user_notification(v_recipient, 'رسالة جديدة', 'لديك رسالة جديدة في المحادثة.', 'chat', NEW.conversation_id::text, 'conversation');
  RETURN NEW;
END;
$$;

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
      PERFORM public.enqueue_user_notification(admin_id, 'طلب تغيير تخصص جديد', 'وصل طلب تغيير تخصص من محامٍ ويحتاج إلى مراجعة الإدارة.', 'admin', NEW.id::text, 'specialization_request');
    END LOOP;
  ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
    PERFORM public.enqueue_user_notification(
      NEW.lawyer_id,
      CASE NEW.status WHEN 'approved' THEN 'تمت الموافقة على تغيير التخصص' WHEN 'rejected' THEN 'تم رفض تغيير التخصص' ELSE 'تحديث طلب تغيير التخصص' END,
      CASE NEW.status WHEN 'approved' THEN 'وافقت الإدارة على طلب تغيير تخصصك.' WHEN 'rejected' THEN 'رفضت الإدارة طلب تغيير تخصصك.' ELSE 'تم تحديث حالة طلب تغيير التخصص.' END,
      'admin', NEW.id::text, 'specialization_request'
    );
  END IF;
  RETURN NEW;
END;
$$;

-- Backfill the existing notifications that were created without references.
UPDATE public.notifications n
SET reference_id = b.id::text,
    reference_type = 'booking'
FROM LATERAL (
  SELECT b1.id
  FROM public.bookings b1
  WHERE b1.user_id = n.user_id
    AND n.type IN ('booking', 'payment')
    AND b1.created_at <= n.created_at
  ORDER BY b1.created_at DESC
  LIMIT 1
) b
WHERE n.reference_id IS NULL;

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
WHERE n.reference_id IS NULL;

REVOKE ALL ON FUNCTION public.enqueue_user_notification(uuid,text,text,text,text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notify_booking_events() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.notify_payment_events() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.notify_custom_request_events() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.notify_message_event() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.notify_specialization_request_events() FROM PUBLIC;
