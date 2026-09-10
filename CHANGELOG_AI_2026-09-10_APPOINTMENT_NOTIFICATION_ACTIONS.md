# سجل تعديل إشعارات وإجراءات المواعيد — 2026-09-10

يوثق هذا الملف دفعة العمل الخاصة بجعل المواعيد المقترحة متساوية في تجربة العميل والمحامي، وربط الإشعارات بالطلب المحدد، وإظهار رد العميل مباشرة في الصفحة الرئيسية.

## 1. منطق رد العميل على اقتراح المحامي
- Supabase production migration: `symmetric_appointment_responses_and_deep_links`.
- ملف المستودع: `supabase/migrations/20260910203000_symmetric_appointment_responses_and_deep_links.sql`.
- commit: `0f9fd81495ec527fe378511203710ba8f1318625`.
- أضيفت `client_respond_custom_appointment_request`.
- يستطيع العميل عند وصول اقتراح المحامي: قبول موعد، اقتراح تغيير عبر 1–3 فترات، أو رفض نهائي مع سبب.
- اقتراح التغيير يبقي المبلغ محجوزاً ويعيد الطلب إلى `بانتظار رد المحامي`.
- الرفض النهائي يعيد المبلغ إلى محفظة العميل وينهي الطلب ويرسل إشعاراً للمحامي.
- أضيف `negotiation_round` بحد أقصى ثلاث جولات تعديل لمنع حلقة تفاوض مفتوحة.
- أضيف `rejected_by` لتمييز الطرف الذي رفض الطلب نهائياً.

## 2. توحيد صفحة متابعة المواعيد للطرفين
- الملف: `lib/features/bookings/presentation/pages/appointment_requests_page.dart`.
- commit: `2448262ebfe6bde1a97a923a8c75bd2a206b48a3`.
- العميل يرى المواعيد المقترحة من المحامي داخل نفس بطاقة الطلب.
- أزرار العميل: قبول موعد محدد، اقتراح تغيير، رفض نهائي.
- أزرار المحامي: اختيار وقت من فترات العميل، موعد بديل، رفض نهائي.
- أضيف منع الضغط المتكرر أثناء تنفيذ RPC.
- أضيف `focusRequestId`، وجلب الطلب المحدد إذا لم يكن في أول 60 طلباً، ثم `Scrollable.ensureVisible` للانتقال إلى الكارت المحدد وإبرازه.

## 3. Deep Link دقيق لإشعارات الموعد
- `lib/core/services/notification_service.dart` — commit `45261722c3aed2038f851dd3ba4f6e6e1620c4e4`.
- `lib/app/router.dart` — commit `d53b8b28676871461aea842a75ca1f49ccce3e2c`.
- `lib/features/profile/presentation/pages/notifications_page.dart` — commit `ef7d1fd1bd5bc42feb9bc0f34fb0481aea993e9c`.
- `supabase/functions/send-pwa-push/index.ts` — commit `1f4046c29394749a5727c1d38984a061c0fd04fd`.
- إشعار `appointment_request` يحمل `request_id` ويفتح `/appointment-requests?request_id=<id>`.
- الضغط من مركز التنبيهات داخل التطبيق يستخدم نفس الوجهة الدقيقة.
- الإشعار Native يحل `notification_id` إلى `reference_id` ثم يفتح نفس الطلب.
- PWA Push يفتح نفس الطلب مباشرة.
- تم نشر `send-pwa-push` في Supabase كنسخة حية version 10.

## 4. إظهار اقتراح المحامي مباشرة في الرئيسية لدى العميل
- ملف جديد: `lib/features/bookings/presentation/widgets/client_appointment_requests_home_card.dart`.
- commit: `60626044572f933eb1fdc24191e307df21ee9ec2`.
- يعرض أحدث طلب حالته `بانتظار اختيار العميل` فورياً عبر Realtime.
- يعرض مواعيد المحامي المقترحة كتفاصيل واضحة في الكارت.
- يستطيع العميل من الكارت مباشرة:
  - قبول أي موعد مقترح.
  - اقتراح تغيير وتحديد 1–3 فترات جديدة.
  - رفض الموعد نهائياً مع سبب.
- قبول الموعد يستدعي `client_confirm_custom_appointment` ويحدث الاستشارات والمحفظة.
- اقتراح التغيير يستدعي `client_respond_custom_appointment_request` دون تحرير المبلغ المحجوز.
- الرفض النهائي يستدعي نفس RPC مع سبب ويعيد المبلغ وفق منطق قاعدة البيانات.
- زر `فتح تفاصيل هذا الطلب` يستخدم `request_id` نفسه.
- إذا كان هناك أكثر من طلب ينتظر العميل، يظهر عدد الطلبات الإضافية ويمكن الوصول إلى القائمة الكاملة.

## 5. دمج بطاقة الموعد في شاشة العميل الرئيسية
- الملف: `lib/shared/widgets/app_shell.dart`.
- commit: `755ddc2fab64466237391d1d14686e205743400b`.
- عند المسار `/home` ولحساب العميل، يعرض `ClientAppointmentRequestsHomeCard` فوق محتوى الرئيسية.
- إذا لم يوجد موعد ينتظر رد العميل، لا يظهر الكارت ولا يضيف محتوى مرئياً.
- استخدم `SafeArea` و`MediaQuery.removePadding(removeTop: true)` لمنع تكرار مساحة شريط الحالة عند إدراج الكارت فوق صفحة Home الحالية.
- لا يظهر هذا الكارت للمحامي ولا يغير شريط التنقل السفلي.

## 6. التحقق
- تم التحقق في قاعدة الإنتاج من وجود `negotiation_round` و`rejected_by` ومن صلاحية `authenticated` لتنفيذ `client_respond_custom_appointment_request`.
- تم التحقق من إشعاري `appointment_options_ready` و`appointment_client_counter_offer` وربطهما بـ `reference_type=appointment_request`.
- دفعة ما قبل بطاقة الرئيسية نجحت في Flutter Analyze وFlutter Tests وFlutter Web Build ونشر GitHub Pages.
- بعد إضافة بطاقة الرئيسية ودمجها في `AppShell` يجب اعتماد نتيجة GitHub Actions الخاصة بآخر commit قبل اعتبار فحص البناء النهائي مكتملًا.
