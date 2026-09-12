-- Repair legacy notifications for both the client and the lawyer.
-- Earlier backfill logic only matched bookings.user_id, which left lawyer-side
-- notifications without a usable booking target.
UPDATE public.notifications n
SET reference_id = target.booking_id::text,
    reference_type = 'booking'
FROM LATERAL (
  SELECT b.id AS booking_id
  FROM public.bookings b
  WHERE n.type IN ('booking', 'payment')
    AND (b.user_id = n.user_id OR b.lawyer_id = n.user_id)
    AND b.created_at <= n.created_at
    AND (
      n.title IN ('تم إرسال طلب الاستشارة', 'طلب استشارة جديد', 'طلبك قيد مراجعة المحامي', 'تم تأكيد الاستشارة', 'بدأت الاستشارة', 'اكتملت الاستشارة', 'تم إلغاء الاستشارة', 'تم استرداد المبلغ', 'طلب الاسترداد قيد المعالجة', 'تم تحديث حالة الحجز', 'تحديث حجز العميل', 'تم تسجيل الدفع اليدوي', 'تم تأكيد الدفع', 'فشل الدفع', 'الدفع قيد المعالجة', 'تم استرداد المبلغ', 'تحديث حالة الدفع', 'تم استلام الدفع')
      OR n.body ILIKE '%الاستشارة%'
      OR n.body ILIKE '%الحجز%'
      OR n.body ILIKE '%الدفع%'
    )
  ORDER BY b.created_at DESC
  LIMIT 1
) target
WHERE n.reference_id IS NULL;

-- Make sure future notifications keep their exact booking target. The
-- deep-link functions introduced earlier already pass reference_id/type;
-- this migration is deliberately data-repair only and does not alter them.
