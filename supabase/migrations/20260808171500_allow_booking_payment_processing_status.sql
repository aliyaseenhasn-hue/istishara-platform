ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS bookings_status_check;

ALTER TABLE public.bookings
ADD CONSTRAINT bookings_status_check CHECK (
  status = ANY (ARRAY[
    'قيد انتظار الدفع'::text,
    'قيد معالجة الدفع'::text,
    'بانتظار التأكيد'::text,
    'مؤكد'::text,
    'قيد التنفيذ'::text,
    'مكتمل'::text,
    'ملغي'::text,
    'مسترد'::text
  ])
);
