# وضع الاستشارات التجريبي المجاني — 2026-09-08

## الهدف

تشغيل نسخة تجريبية لا تُحصّل أي مبلغ من طالب الاستشارة، مع الحفاظ على مسار الدفع الحالي ليُعاد تفعيله لاحقًا من الخادم.

## الملفات والتغييرات

- `supabase/migrations/20260908112040_add_free_beta_consultations.sql`
  - أضاف إعداد إصدار خادميًا قابلًا للتغيير، وحقولًا ثابتة تحدد ما إذا كان كل حجز يتطلب الدفع.
  - جعل الحجز المجاني ينتظر موافقة المحامي ثم يصبح مؤكدًا، بلا سجل دفع أو أثر مالي.
  - منع بدء الدفع أو تسجيله لحجز مجاني، وحافظ على تحقق الملكية وآلة حالات الحجز.
- `supabase/functions/qicard-create-payment/index.ts`
  - يرفض إنشاء عملية Qi Card إذا كان الحجز مجانيًا أو كان الدفع الإلكتروني معطلًا خادميًا.
- `lib/features/bookings/domain/entities/booking.dart`
  - أضاف تمثيل حالة الإعفاء من الدفع ومؤشر `isFreeBeta`.
- `lib/features/bookings/data/models/booking_model.dart`
  - يقرأ حقول الدفع التجريبي من Supabase.
- `lib/features/bookings/presentation/providers/bookings_provider.dart`
  - يحمّل إعدادات الإصدار العامة والحقول الجديدة لتفاصيل الحجز.
- `lib/features/bookings/presentation/pages/create_booking_page.dart`
  - يعرض إشعار الفترة التجريبية ويوجه الحجز المجاني إلى التفاصيل بدل صفحة الدفع.
- `lib/features/bookings/presentation/pages/booking_details_page.dart`
  - يعرض أن المبلغ المستحق صفر ويخفي إجراءات الدفع عن الحجز المجاني.
- `test/booking_invariants_test.dart`
  - يثبت أن الحجز المجاني لا يتطلب دفعًا إلكترونيًا أو يدويًا.

## النتيجة المتوقعة

- لا تُنشأ دفعات أو عمولات أو أرصدة أو قيود مالية للحجوزات المجانية.
- لا يمكن للعميل تحويل حجز مجاني إلى مدفوع من الواجهة أو Edge Function.
- يمكن إيقاف الوضع المجاني وتفعيل الدفع لاحقًا من إعداد خادمي دون إعادة تصميم مسار الحجز.

## Commit

التزام التنفيذ: `91e163f` (`feat: add server-controlled free beta consultations`).
