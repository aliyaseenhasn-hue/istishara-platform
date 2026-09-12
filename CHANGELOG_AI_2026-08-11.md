# سجل تغييرات الوكيل الذكي — 2026-08-11

## الهدف
استكمال متطلبات إعادة تصميم تطبيق «استشارة» اعتماداً على تصميم Stitch، مع الحفاظ على منطق الحجز والدفع والأمان الحاليين.

## قاعدة إلزامية قبل أي تعديل جديد
- مراجعة آخر commits أولاً وعدم إعادة تنفيذ شاشة أو ملف سبق تعديله إلا إذا كان الإصلاح يستهدف خطأ مثبتاً.
- مراجعة الملفات التي تم تعديلها سابقاً قبل إنشاء commit جديد.
- تسجيل كل تغيير جوهري في هذا الملف مع: commit، الملف/الصفحة، نوع التعديل، والنتيجة.
- لا يعتبر أي إصلاح ناجحاً قبل فحص CI المرتبط بالـcommit نفسه.
- لا إنشاء نسخ مكررة من الملفات؛ التعديل يتم على الملف الأصلي فقط.

## تدقيق 2026-08-12 قبل دفعة التصميم الحالية
تمت مراجعة سجل التنفيذ والملفات الفعلية قبل أي تعديل. تم تأكيد أن تسجيل الدخول وOTP والملف الشخصي والدفع اليدوي وقائمة الاستشارات وتفاصيل الحجز ودليل المحامين والرئيسية والتنبيهات وتدفقات الدفع سبق تنفيذها، لذلك لا تتم إعادة إنشائها.

### تعديل منفذ
- الملف: `lib/features/home/presentation/pages/home_page.dart`
- commit: `2fa48f4bc92f125d6f3f86612162faff2758cf91`
- التعديل: إزالة الخلفية الداكنة الثابتة من Header الصفحة الرئيسية واستبدالها بـ`ColorScheme.surface`، واستبدال لون خلفية الصورة الافتراضية الثابت في الوضع الفاتح بـ`surfaceContainerHighest`.
- السبب: مطابقة أفضل لـStitch Light/Dark ومنع اختلاف السطوح عند تغيير الثيم.

## إصلاح FCM — 2026-09-07
- الملف: `lib/core/services/push_notification_service.dart`
- commit: `24c61757291f6246e545e76a20b8a03c36fa7b79`
- التعديل: إصلاح توقيت تسجيل FCM token بحيث تتم مراقبة `initialSession`/`signedIn` قبل محاولة التسجيل، وإضافة إعادة محاولة للعثور على profile، ومعالجة أخطاء التسجيل واسترجاع token و`onTokenRefresh` دون إيقاف التطبيق.
- النتيجة: أصبح مسار تسجيل جهاز Android/iOS في `push_device_tokens` أكثر موثوقية بعد تسجيل الدخول، مع الإبقاء على Realtime وWeb/PWA Push دون تغيير.
- ملاحظة التحقق: يلزم تشغيل النسخة الأصلية Android/iOS بعد هذا commit والتحقق من ظهور سجل في `push_device_tokens`؛ اختبار المتصفح لا يسجل FCM native لأن الكود يعزل FCM native عن Web عمداً.

## إصلاح PWA Web Push — 2026-09-07
### 1. Edge Function
- الملف: `supabase/functions/send-pwa-push/index.ts`
- commit: `21563b25cc358ab943ad283cd5e56621e4b452ba`
- التعديل: تحويل المصادقة الداخلية إلى `withSupabase({ auth: "secret" })`، تعطيل الاعتماد على JWT للمكالمات الداخلية، التحقق من أن payload هو `INSERT` على `public.notifications`، أخذ `user_id` حصراً من `payload.record.user_id`، جلب اشتراكات المستخدم من `pwa_push_subscriptions`، إرسال Web Push لكل اشتراك، حذف الاشتراكات المنتهية 404/410، وعدم فشل العملية بسبب اشتراك منفرد تالف، وإضافة routing للإشعار بما في ذلك فتح المحادثة عند `reference_type=conversation`.
- النتيجة البرمجية: المسار أصبح مطابقاً لنمط service-to-service الحديث في Supabase، ولا يعتمد على `user_id` يختاره العميل.

### 2. Function configuration
- الملف: `supabase/config.toml`
- commit: `1393f2a40a705817982f185466a178bd37c91771`
- التعديل: إضافة `[functions.send-pwa-push] verify_jwt = false` لأن المصادقة تتم بواسطة secret key عبر `withSupabase`.
- النتيجة: إعداد المستودع أصبح متوافقاً مع نمط Supabase الحالي للـservice-to-service functions.

### 3. تدقيق الإنتاج
- Supabase: `send-pwa-push` كانت ACTIVE قبل التعديل، الإصدار 4، مع `verify_jwt=true`؛ لذلك كان إعداد الإنتاج لا يطابق إعداد webhook الداخلي المطلوب.
- قاعدة البيانات: تم التحقق من schema الفعلي لـ`public.notifications`، ومن وجود `public.pwa_push_subscriptions` مع RLS مقيدة بالمستخدم.
- الاشتراكات: تم العثور على **3** سجلات PWA push، دون كشف endpoint أو مفاتيح الاشتراك.
- Webhook الحالي: يوجد trigger أصلي لإرسال native push عند INSERT على `public.notifications`.
- تنبيه أمني: أثناء التدقيق ظهرت بيانات اعتماد سرية داخل تعريف trigger في نتيجة قاعدة البيانات. لم يتم تسجيل القيمة في المستودع أو سجل التغييرات. يجب اعتبار المفتاح المكشوف compromised وتدويره من Supabase Dashboard، ثم تحديث Webhook بالمفتاح الجديد.

### 4. نشر الإنتاج — 2026-09-07
- Supabase Function: `send-pwa-push` أصبحت **ACTIVE version 5** بعد نشر الإصلاح.
- `verify_jwt`: أصبح **false** كما يتطلب webhook الداخلي، مع بقاء المصادقة الداخلية عبر `withSupabase({ auth: "secret" })`.
- النشر الأول فشل بسبب تمرير مسار import-map قديم؛ لم يتم تعديل الإنتاج في تلك المحاولة.
- أُعيد النشر باستخدام `deno.json` كـimport-map path، ونجح النشر فعلياً.
- إعادة القراءة من Supabase أكدت أن الإصدار النشط هو **5** وأن كود الإصدار المنشور هو الكود الموجود في المستودع.

### 5. اختبار Push حقيقي — 2026-09-07
- تم نشر النسخة المصححة التالية في الإنتاج: `send-pwa-push` **ACTIVE version 6**.
- سبب النشر الجديد: نسخة المستودع الحالية تحتوي على routing نسبي `./...` المتوافق مع نطاق PWA، بينما النسخة الإنتاجية السابقة كانت تستخدم مسارات جذرية `/...`.
- تم التحقق بعد النشر من أن الإصدار النشط أصبح **v6**.
- تم العثور على **3** اشتراكات PWA للمستخدم الاختباري، منها اشتراكات Web Push الخاصة بـApple.
- تم إنشاء إشعار اختبار حقيقي في `public.notifications` بعنوان `اختبار إشعار PWA`.
- Database webhook/trigger استجاب فعلياً: ظهرت استجابتان HTTP ناجحتان `200` في `net._http_response`، وكانت إحداهما ناتجها `{"sent":3,"removed":0}`.
- النتيجة: **تم إثبات وصول طلب Web Push إلى Edge Function وإرسال الإشعار إلى 3 اشتراكات دون حذف أي اشتراك منتهي.**
- ملاحظة مهمة: السجل يثبت الإرسال الفعلي من الخادم، لكنه لا يستطيع من داخل Supabase إثبات أن نافذة إشعار iPhone ظهرت على شاشة الجهاز؛ ذلك يتطلب تأكيداً بصرياً على iPhone نفسه.

### 6. Service Worker / Background
- الملف: `web/pwa_service_worker.js`
- التحقق: يحتوي على `push` event ويستخدم `self.registration.showNotification(...)`، مع `silent: false`، و`notificationclick` لفتح الرابط المستهدف.
- النتيجة: بنية Service Worker تدعم استقبال Push في الخلفية وإظهار Notification، بما في ذلك الصوت وفق إعدادات النظام/الجهاز، ولا يوجد في الكود ما يطلب إشعاراً صامتاً.

### 7. الحالة الحالية
- `send-pwa-push`: **PRODUCTION ACTIVE — v6**.
- PWA subscriptions: **3**.
- Server-side Web Push delivery: **PASS — sent=3, removed=0**.
- Database trigger → Edge Function: **PASS — HTTP 200 responses observed**.
- Service Worker background handler: **PASS by code inspection**.
- iPhone visible background notification: **requires physical-device confirmation**.
- CI: يجب فحص run المرتبط بآخر commit التوثيقي قبل إعلان الإغلاق الكامل.
- Security: المفتاح السري الذي ظهر سابقاً في تعريف trigger يجب تدويره وتحديث webhook به قبل اعتبار الجانب الأمني مغلقاً بالكامل.
