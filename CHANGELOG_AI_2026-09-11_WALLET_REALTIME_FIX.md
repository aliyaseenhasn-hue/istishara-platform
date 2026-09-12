# إصلاح خطأ Realtime في المحفظة — 2026-09-11

## المشكلة
ظهرت للمستخدم رسالة تقنية حمراء:
`RealtimeSubscribeException(status: channelError)`
داخل صفحة المحفظة.

## التشخيص
تم التحقق من قاعدة الإنتاج قبل التعديل:
- جدول `public.client_wallets` مضاف فعلياً إلى publication باسم `supabase_realtime`.
- جدول `public.client_wallet_topups` مضاف أيضاً إلى `supabase_realtime`.
- المفتاح الأساسي لجدول `client_wallets` هو `user_id`، وهو نفس المفتاح المستخدم في `stream(primaryKey: ['user_id'])`.
- توجد سياسة SELECT فعالة باسم `client_wallets_select_participant` تسمح لصاحب المحفظة أو الإدارة بالقراءة.

بناءً على ذلك، لم يكن السبب غياب الجدول من Realtime ولا اختيار مفتاح أساسي خاطئ. المشكلة هي أن قناة WebSocket/Realtime نفسها دخلت حالة `channelError` مؤقتاً، وكان الـStreamProvider يمرر الاستثناء مباشرة إلى واجهة المستخدم.

## التعديلات المنفذة

### 1. `lib/features/payments/presentation/providers/client_wallet_provider.dart`
Commit: `ecaca5596ffc2244f25a6a176d8680f19b76f7e0`

- إضافة قراءة أولية مستقرة للرصيد عبر PostgREST قبل بدء الاشتراك اللحظي.
- الاحتفاظ بقيمة الرصيد المعروضة حتى لو تعطلت قناة Realtime مؤقتاً.
- عند فشل القناة:
  - يحاول التطبيق إعادة قراءة الرصيد بالطريقة العادية.
  - يعيد الاشتراك في Realtime تلقائياً.
  - يستخدم backoff محدود يبدأ من ثانيتين ويصل إلى 15 ثانية كحد أقصى.
- لم يعد فشل قناة Realtime وحده يؤدي إلى اختفاء رصيد المحفظة أو تحويل الصفحة إلى خطأ.

### 2. `lib/core/utils/user_facing_error.dart`
Commit: `9800cbd428f09b8114f7f10b82c3fab2abd6b32d`

- إضافة معالجة صريحة للأخطاء التالية:
  - `RealtimeSubscribeException`
  - `channelError`
  - أخطاء WebSocket
- منع عرض أسماء الاستثناءات الداخلية للمستخدم.
- عند الحاجة تظهر رسالة عربية مفهومة بدلاً من النص البرمجي الخام.

## ما لم يتغير
- منطق المحفظة المالي.
- رصيد المستخدم أو المبالغ المحجوزة.
- RPCs الخاصة بالشحن والدفع.
- RLS.
- إعدادات publication في Supabase؛ لم تكن بحاجة إلى تعديل.

## التحقق المطلوب
- Flutter Analyze.
- Flutter Tests.
- Flutter Web Build.
- GitHub Pages Deploy.
