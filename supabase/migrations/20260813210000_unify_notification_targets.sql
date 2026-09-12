CREATE OR REPLACE FUNCTION public.enqueue_user_notification_with_reference(p_user_id uuid,p_title text,p_body text,p_type text,p_reference_type text,p_reference_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
  IF p_user_id IS NULL THEN RETURN; END IF;
  IF EXISTS (SELECT 1 FROM public.notifications WHERE user_id=p_user_id AND type=p_type AND title=p_title AND body=p_body AND created_at>now()-interval '30 seconds') THEN RETURN; END IF;
  INSERT INTO public.notifications(user_id,title,body,type,is_read,reference_type,reference_id)
  VALUES(p_user_id,p_title,p_body,p_type,false,p_reference_type,p_reference_id);
END; $$;
REVOKE ALL ON FUNCTION public.enqueue_user_notification_with_reference(uuid,text,text,text,text,uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.notify_booking_events()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
  IF TG_OP='INSERT' THEN
    PERFORM public.enqueue_user_notification_with_reference(NEW.user_id,'تم إرسال طلب الاستشارة','تم إنشاء طلب الاستشارة بنجاح، وسيتم إشعارك عند تحديث حالته.','booking','booking',NEW.id);
    PERFORM public.enqueue_user_notification_with_reference(NEW.lawyer_id,'طلب استشارة جديد','وصل طلب استشارة جديد من أحد العملاء.','booking','booking',NEW.id);
    RETURN NEW;
  END IF;
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    PERFORM public.enqueue_user_notification_with_reference(NEW.user_id,
      CASE NEW.status WHEN 'قيد مراجعة المحامي' THEN 'طلبك قيد مراجعة المحامي' WHEN 'مؤكد' THEN 'تم تأكيد الاستشارة' WHEN 'قيد التنفيذ' THEN 'بدأت الاستشارة' WHEN 'مكتمل' THEN 'اكتملت الاستشارة' WHEN 'ملغي' THEN 'تم إلغاء الاستشارة' WHEN 'مسترد' THEN 'تم استرداد المبلغ' WHEN 'بانتظار الاسترداد' THEN 'طلب الاسترداد قيد المعالجة' ELSE 'تم تحديث حالة الحجز' END,
      CASE NEW.status WHEN 'قيد مراجعة المحامي' THEN 'تم استلام الدفع، والحجز الآن بانتظار قرار المحامي.' WHEN 'مؤكد' THEN 'تم تأكيد حجزك ويمكنك متابعة تفاصيل الاستشارة.' WHEN 'قيد التنفيذ' THEN 'بدأت جلسة الاستشارة ويمكنك الآن التواصل مع المحامي.' WHEN 'مكتمل' THEN 'انتهت الاستشارة ويمكنك تقييم المحامي.' WHEN 'ملغي' THEN 'تم إلغاء حجز الاستشارة.' WHEN 'مسترد' THEN 'تم تسجيل استرداد المبلغ المرتبط بالحجز.' WHEN 'بانتظار الاسترداد' THEN 'تم تسجيل طلب الاسترداد وسيتم تحديثك عند إتمامه.' ELSE 'تم تحديث حالة حجز الاستشارة.' END,
      'booking','booking',NEW.id);
    PERFORM public.enqueue_user_notification_with_reference(NEW.lawyer_id,'تحديث حجز العميل','تم تحديث حالة أحد الحجوزات في لوحة المحامي.','booking','booking',NEW.id);
  END IF;
  IF NEW.manual_received_at IS DISTINCT FROM OLD.manual_received_at AND NEW.manual_received_at IS NOT NULL THEN
    PERFORM public.enqueue_user_notification_with_reference(NEW.user_id,'تم تسجيل الدفع اليدوي','تم تسجيل مبلغ الاستشارة المستلم يدوياً من المحامي.','payment','booking',NEW.id);
  END IF;
  RETURN NEW;
END; $$;

CREATE OR REPLACE FUNCTION public.notify_payment_events()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_user_id uuid; v_lawyer_id uuid; v_booking_id uuid;
BEGIN
  v_booking_id:=COALESCE(NEW.booking_id,OLD.booking_id);
  SELECT user_id,lawyer_id INTO v_user_id,v_lawyer_id FROM public.bookings WHERE id=v_booking_id;
  IF TG_OP='INSERT' OR NEW.status IS DISTINCT FROM OLD.status THEN
    PERFORM public.enqueue_user_notification_with_reference(v_user_id,
      CASE NEW.status WHEN 'تم الدفع' THEN 'تم تأكيد الدفع' WHEN 'فشل الدفع' THEN 'فشل الدفع' WHEN 'قيد معالجة الدفع' THEN 'الدفع قيد المعالجة' WHEN 'تم استرداد المبلغ' THEN 'تم استرداد المبلغ' ELSE 'تحديث حالة الدفع' END,
      CASE NEW.status WHEN 'تم الدفع' THEN 'تم تسجيل الدفع بنجاح لحجز الاستشارة.' WHEN 'فشل الدفع' THEN 'تعذر تأكيد عملية الدفع. يرجى مراجعة تفاصيل الدفع.' WHEN 'قيد معالجة الدفع' THEN 'عملية الدفع قيد المعالجة وسيتم تحديثك عند اكتمال التحقق.' WHEN 'تم استرداد المبلغ' THEN 'تم تسجيل استرداد المبلغ.' ELSE 'تم تحديث حالة الدفع المرتبط بحجزك.' END,
      'payment','booking',v_booking_id);
    IF NEW.status='تم الدفع' THEN PERFORM public.enqueue_user_notification_with_reference(v_lawyer_id,'تم استلام الدفع','تم تأكيد دفع العميل المرتبط بأحد حجوزاتك.','payment','booking',v_booking_id); END IF;
  END IF;
  RETURN NEW;
END; $$;

REVOKE ALL ON FUNCTION public.notify_booking_events() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.notify_payment_events() FROM PUBLIC;
