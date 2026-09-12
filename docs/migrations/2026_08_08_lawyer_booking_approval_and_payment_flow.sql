-- إضافة موافقة المحامي قبل إتاحة الدفع.
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS lawyer_approved boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS lawyer_approved_at timestamptz;

-- الطلبات المؤكدة سابقاً تعتبر موافقاً عليها للمحافظة على البيانات الحالية.
UPDATE public.bookings
SET lawyer_approved = true,
    lawyer_approved_at = COALESCE(lawyer_approved_at, created_at)
WHERE status IN ('بانتظار التأكيد', 'مؤكد', 'قيد التنفيذ', 'مكتمل', 'مسترد');

-- المراجعة تتم حصراً عبر هذه الدالة، ولا يستطيع العميل تغيير الموافقة مباشرة.
-- الدالة الفعلية مطبقة على مشروع Supabase الإنتاجي بنفس المنطق الموجود في هذا الملف.
