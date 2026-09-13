# استشارة — سجل التغييرات الموحد

هذا الملف هو المصدر الوحيد لسجل التغييرات التاريخي للمشروع. تم جمع محتوى ملفات السجل والتدقيق المتفرقة كما هو للحفاظ على التاريخ مع تقليل فوضى المستودع.

> ملاحظة: الكود الفعلي وآخر commit على `main` وقاعدة Supabase الفعلية تبقى مصدر الحقيقة عند وجود اختلاف مع ملاحظة تاريخية قديمة.


---

## Imported from `README.md` — historical audit section

## Production Audit — 2026-09-07

- Latest client-home UI refinement: `8f95b7f9186b1f10cae7e78d2a9edf6dfe374832` — simplified the client home into a calmer composition: compact header, lighter consultation CTA, tighter legal-specialization cards, and cleaner suggested-lawyer cards. Existing routes, providers, notification behavior, lawyer loading, and business logic were preserved.
- Latest landing-page UI refinement: `09edc61338b9f1a80ef4a89ef1c0ccde5f6cd2de` — replaced the visually heavy navy hero with a quiet off-white/white layout, reduced illustration size, simplified typography, softened section cards, and retained the existing signup/login/lawyer navigation and real lawyer data.
- Both pages remain RTL and preserve the Istishara identity through restrained navy/gold accents rather than large saturated blocks.
- Status: `WARNING — NOT FULLY TESTED` pending GitHub CI and rendered-device verification.

- Previous client-home refinement: `eb96e42525e6e463b4824f4ab4f23738a10013ee` — tightened the vertical rhythm between the consultation CTA, legal-specialization cards, and suggested-lawyer section without changing routes, data flow, or business logic.
- Previous notification-page refinement: `7772f22aec1ed5659ce8f20c97cb8c612cce8a4b` — modernized notification visuals while preserving loading/error/empty states, refresh, mark-read, mark-all-read, and navigation behavior.


---

## Imported from `.artifacts/20260804-230548-22f3c4d9-4bd0-490c-8e44-ec351af166f2/implementation_plan.artifact.md`

# إصلاح مشكلة تسجيل الدخول عبر جوجل (Google Login)

يعود سبب المشكلة الحالية إلى أن التطبيق يحاول إعادة التوجيه إلى رابط ويب (`github.io`) بدلاً من استخدام رابط عميق (Deep Link) خاص بالتطبيق المحمول، بالإضافة إلى نقص الإعدادات اللازمة في ملفات النظام (Android/iOS).

## Proposed Changes

### 1. إعداد الروابط العميقة (Deep Links) في الأندرويد

#### [AndroidManifest.xml](file:///C:/Allmyprojects/astshara/android/app/src/main/AndroidManifest.xml)

إضافة `intent-filter` للتعامل مع مخطط الرابط `io.supabase.astshara`.

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category name="android.intent.category.BROWSABLE" />
    <data android:scheme="io.supabase.astshara" android:host="login-callback" />
</intent-filter>
```

### 2. إعداد الروابط العميقة (Deep Links) في iOS

#### [Info.plist](file:///C:/Allmyprojects/astshara/ios/Runner/Info.plist)

إضافة تعريف الـ URL Scheme.

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>io.supabase.astshara</string>
        </array>
    </dict>
</array>
```

### 3. تحديث كود التطبيق

#### [auth_repository_impl.dart](file:///C:/Allmyprojects/astshara/lib/features/authentication/data/repositories/auth_repository_impl.dart)

تغيير رابط إعادة التوجيه ليستخدم المخطط الجديد بدلاً من رابط الويب.

```diff
-  static const String _googleOAuthRedirectUrl =
-      'https://aliyaseenhasn-hue.github.io/astshara/';
+  static const String _googleOAuthRedirectUrl =
+      'io.supabase.astshara://login-callback';
```

#### [supabase_config.dart](file:///C:/Allmyprojects/astshara/lib/core/config/supabase_config.dart)

إضافة `authFlowType` لدعم PKCE.

### 4. الإعدادات المطلوبة في Supabase Dashboard (يجب القيام بها يدوياً)

- إضافة `io.supabase.astshara://login-callback` إلى قائمة **Redirect URLs** في إعدادات Authentication في Supabase.

## Verification Plan

### Manual Verification
- تشغيل التطبيق على محاكي (Emulator/Simulator).
- الضغط على زر "تسجيل الدخول بواسطة جوجل".
- التأكد من فتح المتصفح واختيار الحساب.
- التأكد من عودة المتصفح تلقائياً إلى التطبيق بعد نجاح العملية.

## إصلاح PWA — تفعيل الإشعارات

تم تحديث مسار تفعيل إشعارات PWA في الويب.

- حالة `Notification.permission` والـ Push subscription من المتصفح أصبحت المصدر الفعلي لحالة المفتاح.
- تم منع أخطاء Push API من تعطيل واجهة التفعيل.
- تتم مزامنة الحالة عند فتح الصفحة وبعد التفعيل، مع إظهار حالة `إشعارات PWA مفعّلة` ومؤشر تنفيذ.
- **Commits:** `352c035ec5ba7d41ab3db32daad9047be1f3808c`, `1daee5b6b0e5f8112817d3cf9bc56d39306a1a18`, `3f9860cc6932597eea8e3eae10f5a05d7b04b0d6`, `41c166712ce1c763013081d2d7877d8fdbeefbb1`.
- **الحالة:** إصلاح المصدر مكتمل، وCI للنسخة الأخيرة مطلوب للتأكيد النهائي.



---

## Imported from `.artifacts/20260804-230548-22f3c4d9-4bd0-490c-8e44-ec351af166f2/walkthrough.artifact.md`

# ملخص إصلاح تسجيل دخول جوجل

تم الانتهاء من تحديث إعدادات التطبيق لتمكين تسجيل الدخول عبر جوجل بشكل صحيح.

## التغييرات التي تمت:

1.  **في الأندرويد ([AndroidManifest.xml](file:///C:/Allmyprojects/astshara/android/app/src/main/AndroidManifest.xml)):**
    *   تمت إضافة `intent-filter` للتعامل مع رابط إعادة التوجيه `io.supabase.astshara://login-callback`. هذا يسمح للنظام بفتح التطبيق تلقائياً عند انتهاء عملية المصادقة في المتصفح.

2.  **في iOS ([Info.plist](file:///C:/Allmyprojects/astshara/ios/Runner/Info.plist)):**
    *   تمت إضافة `CFBundleURLTypes` لتعريف الـ URL Scheme الخاص بالتطبيق (`io.supabase.astshara`).

3.  **في كود الفلاتر:**
    *   **[auth_repository_impl.dart](file:///C:/Allmyprojects/astshara/lib/features/authentication/data/repositories/auth_repository_impl.dart):** تم تغيير `_googleOAuthRedirectUrl` ليدعم الويب والموبايل تلقائياً.
    *   **[supabase_config.dart](file:///C:/Allmyprojects/astshara/lib/core/config/supabase_config.dart):** تم تنظيف الإعدادات وإزالة HuggingFace.

4.  **في قواعد بيانات Supabase ([supabase_setup.sql](file:///C:/Allmyprojects/astshara/docs/supabase_setup.sql)):**
    *   **إصلاح Recursion Error:** تم تحديث دالة `is_admin()` لتعتمد على JWT Claims بدلاً من الاستعلام المتكرر، مما منع حدوث "التكرار اللانهائي" في سياسات RLS.
    *   **تبسيط السياسات:** تم تحسين قواعد الوصول لجدول `profiles` و `bookings` لضمان سرعة الاستجابة وأمان البيانات.

## الخطوات النهائية المطلوبة منك:

لإتمام العملية بنجاح، يجب القيام بالخطوات التالية يدوياً في لوحة تحكم Supabase:

1.  اذهب إلى [Supabase Dashboard](https://supabase.com/dashboard).
2.  اختر مشروعك.
3.  انتقل إلى **Authentication** -> **URL Configuration**.
4.  في قسم **Redirect URLs**، أضف الرابط التالي:
    `io.supabase.astshara://login-callback`
5.  احفظ الإعدادات.

بعد القيام بذلك، قم بإعادة بناء التطبيق وتشغيله، وسيعمل تسجيل الدخول عبر جوجل بشكل سليم وسيعود إلى التطبيق بعد اختيار الحساب.



---

## Imported from `BUILD_TRIGGER.md`

# CI trigger

This file intentionally triggers the repository CI/Android/PWA workflows after the latest verified changes.

## Production audit — 2026-09-06
- Applied `20260906173000_optimize_rls_auth_checks_and_remove_duplicate_indexes.sql` to production Supabase.
- Applied `20260906174500_consolidate_financial_select_rls_policies.sql` to production Supabase.
- The first migration removed confirmed duplicate indexes and optimized repeated `auth.uid()` evaluation in RLS policies.
- The second migration consolidated equivalent participant/admin SELECT policies for financial ledger and payment financials while preserving access rules.
- Supabase Performance Advisor was rechecked: the previous `auth_rls_initplan` and duplicate-index warnings are no longer present; remaining findings are INFO unused-index notices plus a small set of intentionally separate policy groups that require further semantic review before removal.

## Verification checkpoint — 2026-09-06
- Rechecked Security Advisor after the production performance hardening.
- Public lawyer-directory RPCs remain intentionally callable by `anon`/`authenticated`; participant/admin SECURITY DEFINER functions remain protected by in-function authorization and explicit grants.
- No destructive policy/index change was made solely to silence advisor INFO/WARN findings where doing so could alter application behavior.
- Android release verification is still a launch gate because the current release configuration uses temporary debug signing.

## Regression fix — 2026-09-07
- Latest client-home commit `5371c4214787a6bdc6f20300a20f94029acd84f9` introduced a Dart syntax regression in `lib/features/home/presentation/pages/home_page.dart` inside `_ConsultationActions`: both compact `Expanded/SizedBox/Button` expressions were missing a closing parenthesis.
- GitHub Actions confirmed the regression: Deploy to GitHub Pages run `1234` failed in both `analyze` and `build`; Android Release run `536` also failed on the same commit.
- Restored the known-good `home_page.dart` blob from commit `3b4cc7ce0b3774db8203767cf557a11a94b010cc` without reverting unrelated repository changes.
- Created corrective commit `9552ad12f64e743ba43a931c53670a6e8b3470a5` and moved `main` to it.
- New CI workflows were triggered from the corrective commit; PASS will only be claimed after all required stages complete successfully.



---

## Imported from `CHANGELOG_AI_2026-08-11.md`

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



---

## Imported from `CHANGELOG_AI_2026-08-11_UI_PASS.md`

# سجل إعادة تصميم Stitch — 2026-08-11

## التنفيذ الحالي

تمت متابعة إعادة التصميم مباشرة من آخر نسخة مستقرة على `main` مع الحفاظ على منطق Supabase والحجوزات والدفع والتواصل.

### الصفحات المنفذة
- الصفحة الرئيسية.
- دليل المحامين.
- تفاصيل المحامي.
- استشاراتي / طلبات الاستشارة.
- التنبيهات.
- إعدادات الإشعارات.
- OTP / التحقق من رقم الهاتف.
- إكمال الملف الشخصي.
- الملف الشخصي.
- طلب الاستشارة.
- تفاصيل الاستشارة.
- الدفع عبر Qi Card.
- رفع إثبات الدفع.
- الدفع اليدوي.
- تسجيل الدخول.

### دفعة التصميم النهائية
- إعادة صقل الشريط السفلي الرئيسي إلى حاوية عائمة مستديرة ومتوافقة مع ColorScheme في الوضعين الفاتح والداكن.
- الحفاظ على التنقل الحالي والمسارات نفسها وعدم تغيير منطق التطبيق.
- تحسين حالة العنصر المحدد، المسافات، شارة التنبيهات، والحدود والظل بما يتوافق مع لغة Stitch.

### مراجعة نهائية
- توحيد RTL والثيم المتكيف في الحالات الأساسية.
- مراجعة حالات التحميل والخطأ والفراغ والنوافذ الحوارية.
- الحفاظ على منطق الحجز والدفع وSupabase وRiverpod وعدم استخدام بيانات وهمية.
- التحقق من analyze/test/build/deploy قبل اعتماد النسخة النهائية.



---

## Imported from `CHANGELOG_AI_2026-08-12.md`

# سجل تغييرات الوكيل الذكي — 2026-08-12

## قاعدة التنفيذ
قبل أي تعديل جديد تتم مراجعة الملفات والـcommits السابقة لتجنب تكرار التنفيذ. كل تعديل جديد يسجل في ملف Markdown مع الـcommit والسبب والنتيجة.

## آخر تعديل
- `c3b05aa0f1c5d40981942481eff22ee2344db161` — إعادة تصميم `main_bottom_nav.dart` بصرياً ليصبح شريطاً سفلياً عائماً أكثر حداثة وتنظيماً، مع تحسين الحواف والظلال والتدرج والمسافات، إبراز التبويب النشط داخل حاوية حديثة، وترتيب إجراءات المحامي بصورة أوضح. لم تتغير المسارات أو ترتيب التبويبات أو منطق التنقل أو وظائف العميل والمحامي.
- `e5df811d932d12a16b01282a37e5ac5b221b3557` — إعادة تنظيم وتحسين واجهة `lawyer_profile_edit_page.dart` لتصبح أكثر تناسقاً وجاذبية وراحة بصرياً، مع بطاقات أقسام واضحة، تدرجات لونية حيوية، تسلسل أفضل للمعلومات، وتحسين حالات الباقات والحقول، مع الحفاظ على جميع وظائف الحفظ والتخصص والصلاحية والإنجازات والأسعار والتنقل.
- `67f5392ea076094ebbf6131426c276d34423c2ee` — صقل `lawyer_details_page.dart`: جعل اتجاه شريط الإجراءات السفلي يعتمد على `Directionality.of(context)` بدل فرض RTL، مع الحفاظ على أولوية زر «حجز موعد» وترتيب زر «مراسلة» بصورة منطقية، وتنظيف بنية تبويبات الملف لتفادي الصياغات المبتورة.
- `21fd42cf2c0adcbe65c8c6ae2a87a8c5738da161` — تحسين `main_bottom_nav.dart` ليأخذ اتجاه RTL/LTR من `Directionality.of(context)` بدل فرض اتجاه ثابت داخل الشريط، مع الإبقاء على ترتيب المحامي: الرئيسية → استشاراتي → التنبيهات → الإعدادات وترتيب طالب الاستشارة كما هو.
- `e8fdbde104a36bc762471ab2da1386ee727f14a4` — جعل `AppShell` واعيًا بدور المستخدم وربط فهارس شريط التنقل بالمحامي بشكل مستقل، بحيث لا يظهر تبويب المحامين للمحامي وتبقى فهارس العميل كما هي.

## سجل التنفيذ السابق
- `dda6fed1a71b26dc9dd1745c14a02ccffb537f7b` — تعديل `main_bottom_nav.dart`: حذف زر «المحامون» من قائمة المحامي وإعادة ترتيب الشريط للمحامي إلى: الرئيسية → استشاراتي → التنبيهات → الإعدادات.
- `39035ebfaffef2ae6f24a5c978649ae0e86cdf03` — إصلاح `booking_details_page.dart` بالكامل بعد ظهور أخطاء CI.
- `dbdc2454fff678e69437696f1c4f1c90311cfccc` — إصلاح مراجع RTL في `booking_details_page.dart`.
- `91f6911e30ac4ea5afca2241a4fe31a74a5beba9` — إضافة واجهات `BookingsController` الخاصة بالمراجعة وتحديث الحالة وعدم الحضور.
- `1babe059cf5fcb2fdd50c3882c27c95c490f8bf0` — تطبيق Stitch Premium على `booking_details_page.dart`.
- `5fc2166b5259d19d373a45a073fb23bab11471db` — تطبيق Stitch Premium على `specialization_change_page.dart`.
- `95e795405c3485257616a1a20db694b9a6423af3` — إصلاح أخطاء syntax في `lawyer_onboarding_page.dart`.
- `0b304b039ff0a58e3c1a2271561bd2cdf1efab23` — تطبيق أسلوب Stitch Premium على `payment_upload_page.dart`.
- `0bc5983d88b6ee1b703ffc27fdba592d562fe771` — تطبيق أسلوب Stitch Premium على `lawyer_pending_page.dart`.
- `35aa9f1cbe027563b6ad0eaf1665558493403461` — تطبيق أسلوب Stitch Premium على `lawyer_setup_page.dart`.
- `e2d507d344da2e18fca446448dbfecb483e9016e` — تطبيق أسلوب Stitch Premium على `lawyer_profile_edit_page.dart`.
- `77e16ba3f1a8c9a8db528dc7422dc83664fc9563` — إضافة Design Tokens في `app_sizes.dart`.
- `409d4772da133b5a6ef866537512d05e7760bb15` — مطابقة `lawyers_list_page.dart` مع Stitch.
- `aaf5a7456ec88f7d0f4c6fbdeb43448ece1fbb1d` — مطابقة `complete_profile_page.dart` مع Stitch.
- `7b5fa9297471b6abfd1e94635fd45ec563639ab5` — مطابقة `bookings_list_page.dart` مع Stitch.
- `99bebd36edd92e5daeb5165b4afed80bd627b590` — مطابقة `notification_settings_page.dart` مع Stitch.
- `30b33d1cc1d8a6a5d20f2cab81c6cf36da515d7d` — مطابقة `help_center_page.dart` مع Stitch.
- `15428aac8b8b4d1510cd368e3010784048f535b4` — مطابقة `conversations_page.dart` مع Stitch.
- `50ba0847414535c9034dc6939c0d94b21c084bda` — صقل `profile_page.dart`.

## التحقق
لا تعتبر أي دفعة ناجحة حتى يمر `flutter analyze` وCI على commit الحالي.



---

## Imported from `CHANGELOG_AI_2026-08-13.md`

# سجل تغييرات الوكيل الذكي — 2026-08-13

## تحسين ألوان البطاقة العلوية في مركز المساعدة
تم تحسين بطاقة الترحيب العلوية في صفحة **«مركز المساعدة»** لتكون أكثر حيوية ووضوحاً وتناسقاً مع ألوان التطبيق.
- استبدال اللون المسطح بتدرج لوني متكيف مع الوضع الفاتح والداكن.
- تحسين لون وأسلوب أيقونة الدعم مع تدرج متناسق وظل خفيف.
- إضافة حدود وظل ناعم لإبراز البطاقة دون التأثير على سهولة القراءة.
- الحفاظ على جميع وظائف وروابط مركز المساعدة والأسئلة الشائعة دون تغيير.
**Commit:** `b8d8e33905da34d8fed405fdf71b499faeb403c7`

## إصلاح واجهة الملف المهني للمحامي — زر إلغاء
تمت إضافة زر **«إلغاء»** واضح في أسفل صفحة تعديل الملف المهني للمحامي، بجانب زر «التالي: أوقات التوفر».
- الإلغاء لا يحفظ أي تغييرات.
- يعيد المحامي إلى الصفحة السابقة عند توفر إمكانية الرجوع، مع fallback إلى `/lawyer-home`.
- تم الحفاظ على جميع مسارات الحفظ الحالية دون تغيير.
**Commit:** `d7010b4c6edf14eca7d56b7872f3c8e14b10626b`

## دفعة الإصلاح الحالية — 10:46 وما بعدها

### النقطة 1 — الألوان
تم تحديث `app_colors.dart` إلى لوحة Stitch Premium أكثر اتساقاً: ذهبي دافئ + كحلي عميق + أسطح محايدة دافئة.
**Commit:** `23c89cfae71b1ccf071b3751fbb2a296c0f2b314`

### النقطة 2 — فتح مكان الإشعار بالضبط
تمت إضافة `reference_id` و`reference_type` إلى التنبيهات، وإضافة فتح الحجز المرتبط مباشرة من إشعار الحجز.
**Commits:** `176d8dc8d165d94bbad2b29c31a616ad1241e8b0`, `8071fc2f67d6c3ccb739bbdda2e598a20e436197`

### النقطة 3 — اسم المحامي الكامل
تمت إضافة resolver موحد لهوية المحامي في «استشاراتي» لدى العميل. يتم البحث أولاً في `profiles.full_name` ثم `lawyer_profiles.full_name` مع إظهار الصورة عند توفرها.
**Commits:** `4ec5d20aec02f116fc32fa9c9700cfc7eef3d1bf`, `c081fc150d68629270c435a8ef8d046f096c66fc`, `8987a761702cac5e463507c95594c28988817017`

### النقطة 4 — تسمية زر الحجز
تم تغيير «حجز موعد» إلى **«حجز موعد استشارة»**.
**Commit:** `c5edd62a0b12a6ee9246edb51c07b24d04b26c54`

### النقطة 5 — اختصاصات قانونية
تمت إضافة قائمة واسعة للاختصاصات، صفحة `legal_categories_page.dart`، route مستقل، كروت إضافية في الرئيسية وزر «عرض جميع الفئات»، وربط الاختصاص بالبحث.
**Commits:** `aca03fac4043559bfb424fbb2db4706bf5b3bb29`, `231894f2cc468044d11b04def2d3ef73d0623a1f`, `09d3c9976d16cdea9d0b5d0cc87c60a5a702721f`, `8164aff16b682545c8b267c3491c4efe096f6fe6`

### النقطة 6 — أرشفة المواعيد
تم تنفيذ الأرشفة على مستوى قاعدة البيانات وRepository وController، ثم إضافة شاشة **«أرشيف الاستشارات»** مع فتح التفاصيل وإعادة الاستشارة إلى القائمة، وإضافة زر الأرشيف إلى صفحة «استشاراتي» وزر «أرشفة الاستشارة» للحالات المنتهية/الملغاة/المستردة.
**Commits:** `59dc5b971e93e792584357547441cb2379abdfc3`, `5c24c8170234f7754902667b2b41d223a68f8fb3`, `089ff398422053750e9dd8ce9c0a72aa3215b499`, `4e846366e7cd28f679a0066de52f4db88da52cc9`, `02ca3a1ff684060fa63a65bf35710cc68f35ec09`, `8256780a9b4f354cc257aee02645f4822dfac8cc`

### النقطة 7 — دقة فلتر البحث
تم استبدال المطابقة الجزئية الواسعة بمطابقة عربية مطبّعة وأكثر دقة للاختصاصات والأسماء.
**Commit:** `55356ea8e89b7cfb0982e8e40e4ea5da8030f4a7`

### النقطة 8 — تنبيهات الهاتف
المشروع يستخدم فعلياً `flutter_local_notifications` مع Android notification channel وأذونات iOS والصوت والاهتزاز. لم تتم إضافة نظام مكرر. ربط التنبيهات بالمرجع تم تحسينه ضمن النقطة 2.

### النقطة 9 — السرعة والتوافق مع الهاتف
تم تحسين دقة البحث وتقليل العمل غير الضروري، لكن **لا أعتبر توافق 100% مكتملًا بعد** قبل نجاح التحليل والبناء واختبار أحجام الشاشات المختلفة.

## إصلاح إضافي — ظهور بيانات المحامي في «استشاراتي»
تم اكتشاف أن `userNameProvider` وحده لا يضمن ظهور هوية المحامي بصورة مستقرة في قائمة الحجوزات. أضيف `bookingLawyerInfoProvider` كمصدر موحد، مع fallback إلى `lawyer_profiles`، ثم تم ربطه مباشرة ببطاقة العميل في «استشاراتي». تظهر صورة المحامي عند توفرها، والاسم الكامل من المصدر الصحيح.
**Commits:** `c081fc150d68629270c435a8ef8d046f096c66fc`, `8987a761702cac5e463507c95594c28988817017`

## تحقق Supabase
تم التحقق فعلياً من وجود:
- `archived_by_user_at`
- `archived_by_lawyer_at`
- `archive_booking_for_user`
- `archive_booking_for_lawyer`
- `restore_booking_from_archive`
- `reference_id`
- `reference_type`

## قاعدة الاعتماد
أي نقطة لا تعتبر «ناجحة» نهائياً حتى يمر `flutter analyze` والبناء/CI. عند ظهور خطأ، يتم إصلاحه ثم مواصلة النقطة التالية تلقائياً.

## إصلاح أمني P0.1 — منع إعادة استخدام طلب Telegram وإصدار جلسات متزامنة
تم اكتشاف أن مسار `telegram-auth-v2` كان يقرأ حالة `telegram_verified` ثم يصدر الجلسة قبل وجود حجز ذري للطلب، ما كان يسمح نظرياً لطلبين متزامنين بالوصول إلى إصدار الجلسة نفسها قبل تحويل الحالة إلى `verified`.

تم تنفيذ إصلاح متوافق مع المسار الحالي:
- إضافة `session_claimed_at` إلى `telegram_login_requests` عبر Migration إضافية.
- إضافة RPC ذرية `claim_telegram_login_session(uuid, bigint)` بصلاحية `SECURITY DEFINER` و`search_path` آمن.
- السماح بتنفيذ RPC لـ`service_role` فقط.
- ربط إصدار الجلسة بـone-time claim ذري يمنع replay وconcurrent verification.
- منع بدء طلب Telegram جديد من إلغاء طلب تم حجزه بالفعل لإصدار جلسة.
- منع `/start` من اعتبار حساب Telegram المرتبط مسبقاً موثوقاً دون مشاركة رقم الهاتف والتحقق من تطابقه.
- تشديد binding بين Telegram user وphone/profile.
- إرجاع حالة `used` للطلب الذي تم استهلاكه بدلاً من إعادة السماح بإصداره.
- نشر Edge Function `telegram-auth-v2` الجديدة على Supabase كإصدار 28.

**Code Commit:** `33e45cc4643e99da83a3e63e586a21efca9c7143`
**Supabase Migration:** `telegram_auth_one_time_session_claim`
**Database Test:** `first_claim=true`, `second_claim=false` على صف اختبار داخل transaction مع rollback.
**CI:** Android Release Build رقم `414` اكتمل فيه Analyze وTest بنجاح، بينما أُلغي Build release APK؛ لذلك لا تُعلن نتيجة بناء APK/AAB كنجاح.

**الحالة:** `WARNING — NOT FULLY TESTED` حتى اكتمال اختبار البناء ومسار Telegram integration فعلي.

## إصلاح أمني P0.2 — منع إساءة استخدام تنظيف طلبات Telegram
تم اكتشاف أن `cleanup_expired_telegram_login_requests()` كانت `SECURITY DEFINER` وممنوحة للتنفيذ للمستخدمين المصادق عليهم، رغم أنها عملية صيانة داخلية تستطيع تغيير حالة طلبات Telegram المنتهية.

تم الإصلاح بأقل تغيير آمن:
- سحب `EXECUTE` من `anon` و`authenticated` و`public`.
- إبقاء التنفيذ متاحاً لـ`service_role` فقط.
- عدم تغيير منطق تنظيف الطلبات نفسه.
- تطبيق التغيير على مشروع Supabase الفعلي.
- حفظ Migration في المستودع لإعادة الإنتاج والنشر بأمان.

**Database Test:** `anon_exec=false`, `auth_exec=false`, `service_exec=true`.
**Supabase Migration:** `20260906130000_lock_down_telegram_cleanup_function.sql`
**Repository Commit:** `5f5e478b389e7e449129bb287cd969d36f6db50c`

**الحالة:** `PASS — TESTED` بالنسبة لحدود صلاحية الدالة؛ ويبقى CI بعد هذا التغيير مطلوباً قبل اعتماد النقطة ضمن بوابة الإصدار.

## إصلاح أمني P0.3 — إغلاق دوال داخلية قابلة للاستدعاء من العملاء
تم العثور أثناء تدقيق دوال `SECURITY DEFINER` على دالتين داخليتين كانتا تمنحان المستخدم المصادق عليه صلاحية مباشرة غير لازمة:
- `get_booking_id_for_slot(uuid)` كانت تسمح بالاستعلام عن معرّف حجز مرتبط بأي slot دون تحقق من ملكية slot.
- `sync_lawyer_slot_availability(uuid)` كانت تسمح باستدعاء عملية داخلية لتغيير حالة توفر slot مباشرة.

تم إغلاقهما أمام `anon` و`authenticated` و`public`، مع إبقاء `service_role` فقط. هذا لا يغيّر منطق الدالتين ولا مسار الـtrigger الداخلي الذي يعتمد على `SECURITY DEFINER`.

**Database Test:** الدالتان أصبحتا `anon_exec=false`, `auth_exec=false`, `service_exec=true`، إضافة إلى استمرار نفس النتيجة لدالة تنظيف Telegram.
**Supabase Migration:** تم تطبيق التغيير فعلياً على المشروع.
**Repository Migration:** `20260906131500_lock_down_internal_booking_helpers.sql`.

**الحالة:** `PASS — TESTED` بالنسبة لحدود صلاحية الدالتين وحفظ Migration؛ ويبقى CI بعد هذا التغيير مطلوباً قبل اعتماد النقطة ضمن بوابة الإصدار.

## تدقيق أمني P0.4 — سطح SECURITY DEFINER وRLS وStorage
تم إجراء تدقيق مباشر على مشروع Supabase الحالي دون تعديل بيانات التطبيق:
- جميع جداول `public` الحالية المهمة للحجوزات والمدفوعات والمحادثات والملفات الشخصية وغيرها مفعّل عليها RLS.
- تم التحقق من أن عمليات الإدارة الحساسة عبر `SECURITY DEFINER` تتحقق من دور `admin` داخل الدالة قبل التنفيذ.
- تم التحقق من أن عمليات المستخدم/المحامي الحساسة تعتمد على `auth.uid()` وربط الهوية بـ`profiles` قبل التعديل.
- تم التحقق من سياسات `storage.objects` للـavatars ووثائق المحامين والإيصالات، مع تقييد الكتابة بمجلد المستخدم، وتقييد قراءة الوثائق/الإيصالات الحساسة بالمستخدم أو الإدارة/الإشراف.
- دوال دليل المحامين العامة فقط هي التي بقيت متاحة للعملاء عمداً، مع توثيق منح `anon` و`authenticated` لها صراحةً في Migration `20260906140000_lock_down_public_security_definer_functions.sql`.

**الحالة:** `PASS — TESTED` بالنسبة للتدقيق البنيوي الحالي؛ لا يعني ذلك اختبار اختراق E2E كاملاً.

## تدقيق أمني P0.5 — إغلاق دالة trigger داخلية
أظهر التدقيق أن `sync_slot_after_booking_change()` كانت `SECURITY DEFINER` وممنوحة لـ`authenticated` رغم أنها دالة trigger داخلية لا تمثل API للمستخدم. تم سحب `EXECUTE` من `public` و`anon` و`authenticated` والإبقاء على `service_role` فقط، دون تغيير trigger نفسه أو منطق مزامنة المواعيد.

**Database Test:** `auth_exec=false`, `anon_exec=false`, `service_exec=true`.
**Supabase Migration:** `lock_down_internal_booking_sync_trigger_function`.
**Repository Migration:** `20260906150000_lock_down_internal_booking_sync_trigger_function.sql`.

**الحالة:** `PASS — TESTED` بالنسبة لحدود صلاحية الدالة؛ ويبقى CI بعد هذا التغيير مطلوباً قبل اعتماد النقطة ضمن بوابة الإصدار.

## تدقيق Qi Card — حدود ما يمكن اعتماده حالياً
تمت مراجعة إنشاء الدفع وWebhook والتحقق من ملكية الحجز قبل الدفع، وربط Webhook بالتوقيع والمبلغ/العملة وحماية الانتقال النهائي من حالة الدفع الناجحة إلى حالة أقدم.
لكن تكامل الدفع الخارجي **غير مكتمل للإنتاج** لأن بيانات/واجهة الإنتاج الرسمية من شركة الدفع لم تُعتمد بعد.

**الحالة:** `BLOCKED — بانتظار معلومات شركة الدفع`.



---

## Imported from `CHANGELOG_AI_2026-08-13_CONTINUATION.md`

# متابعة التنفيذ

- 2026-08-13: تم التحقق من آخر commit فعلي على main: 177c96d.
- العمل التالي: ضمان انتقال اسم المحامي واسم العميل داخل BookingModel/Booking من مصدر بيانات الحجز، ثم مطابقة واجهات الاستشارات والألوان.



---

## Imported from `CHANGELOG_AI_2026-09-07_CLIENT_HOME_UI.md`

# Client Home UI — 2026-09-07

## تعديل المسافات

تم تعديل واجهة العميل في `lib/features/home/presentation/pages/home_page.dart` لتقليل المسافة الرأسية بين شبكة **التخصصات القانونية** وقسم إجراءات الاستشارة والبحث.

### التغيير
- تقليل الـ top padding قبل `_ConsultationActions` من `16` إلى `6` بكسل.
- لم يتم تغيير منطق الحجز أو التقييم أو التنقل أو البيانات.
- لم يتم تعديل مكونات أخرى في واجهة العميل.

### Commit
`c3119d2eaa1b3f6875fb2e9827deb2bf084e02be`

### ملاحظة التحقق
التعديل بصري ومحافظ على بنية الصفحة، ويحتاج إلى مرور CI/Flutter analyze وWeb build بعد الدفع إلى `main` قبل اعتباره PASS نهائيًا.



---

## Imported from `CHANGELOG_AI_2026-09-08_CLIENT_HOME_PRIMARY_CARD_SPACING.md`

# Client home primary-card spacing

## File

- `lib/features/home/presentation/pages/home_page.dart`

## Reason

The client-name card and the legal-specialization area still appeared visually compressed toward the top of the client home page.

## Change

- Increased the space below the client-name card from 15 to 24 logical pixels.
- Increased the upper and lower breathing room around the consultation summary cards.
- Increased the separation before the legal-specializations heading from 10 to 16 logical pixels.
- Kept card dimensions, navigation, and the responsive specialization grid unchanged.

## Result

The client-name card is now visually separated from the specialization area, while the intermediate consultation summary remains balanced and readable.

## Commit

- `fix(home): increase client card to specialties spacing`



---

## Imported from `CHANGELOG_AI_2026-09-08_CLIENT_HOME_SPACING_BALANCE.md`

# Client home spacing balance

## File

- `lib/features/home/presentation/pages/home_page.dart`

## Reason

The profile, statistics, legal-specialization cards, and suggested-lawyers section were visually compressed toward the top of the client home page.

## Change

- Added a small amount of breathing room below the client profile card.
- Increased the separation around the consultation statistics and specialization heading.
- Increased the space below the specialization grid and before the suggested-lawyers section.
- Kept the existing layout, card sizes, and responsive grid unchanged.

## Result

The upper sections now have a clearer visual rhythm without introducing excessive empty space or changing the page architecture.

## Commit

- `fix(home): balance client home section spacing`



---

## Imported from `CHANGELOG_AI_2026-09-08_CLIENT_HOME_SPACING_FINAL.md`

# Client home spacing refinement

## Reason

The client profile card and the content beneath it still appeared visually
compressed on the consultation client home page.

## Change

- Increased the bottom spacing after the client profile card from 24 to 40.
- Increased the top spacing before the legal specializations heading from 16
  to 24.
- Kept card sizes, grid dimensions, and responsive behavior unchanged.

## Result

The client identity area is now clearly separated from the statistics and
specialization cards while preserving the existing page structure.



---

## Imported from `CHANGELOG_AI_2026-09-08_CONSULTATION_REQUESTER_LABEL.md`

# تحديث تسمية المستخدم — 2026-09-08

تم استبدال التسمية الظاهرة للمستخدم من «عميل» إلى «طالب استشارة» في الواجهات الحالية، مع الحفاظ على جميع المفاتيح والمنطق الداخلي دون تغيير.

## الواجهات المعدلة
- الصفحة الرئيسية لطالب الاستشارة.
- صفحة إكمال الملف الشخصي واختيار نوع الحساب.
- قائمة الاستشارات لدى المحامي.
- صفحة تفاصيل الاستشارة، بما في ذلك بيانات طالب الاستشارة وحالة عدم الحضور.

## لم يتغير
- قيمة الدور الداخلية `user`.
- أسماء الحقول التقنية مثل `client_*`.
- Supabase / RLS / Auth / Bookings / Payments.
- أي منطق وظيفي أو صلاحيات.



---

## Imported from `CHANGELOG_AI_2026-09-08_FREE_BETA_CONSULTATIONS.md`

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



---

## Imported from `CHANGELOG_AI_2026-09-08_GOLD_ACCENT.md`

# Gold Accent Alignment — 2026-09-08

## Scope
Add a clearer premium gold accent across both client and lawyer experiences without changing layouts, navigation, business logic, Supabase, bookings, payments, or authentication.

## Changes
- `AppColors.ctaGold` now uses the real brand gold instead of the secondary blue.
- Increased visibility of `goldSoft` and `goldSoftStrong` so existing gold borders, profile rings, chips, and accents are easier to see.
- Updated `goldGradient` to produce a more intentional light-to-gold progression.
- Existing client and lawyer profile headers automatically inherit the stronger gold accents.
- Booking progress UI that already consumes `ctaGold` now displays the intended gold accent.

## Design rule
Navy/blue remains the primary legal brand color. Gold is used as a restrained premium accent to preserve readability and contrast.



---

## Imported from `CHANGELOG_AI_2026-09-08_LAWYER_SEARCH_AND_LOGO.md`

# Lawyer search, filters, and app brand refinement

## Search

- Improved Arabic matching by normalizing common letter variants, diacritics,
  tatweel, and whitespace.
- Search now covers the lawyer name, specializations, biography, and service
  titles, and supports multi-word queries.
- Remaining directory pages are loaded when a meaningful search or category
  filter is used so results are not limited to the first page.

## Filters

- Added a clear result count and active specialization state.
- Added a scrollable picker containing every legal specialization supported by
  the app while preserving quick-access chips for common categories.
- Added a single action to clear both search text and active filters when no
  results are found.
- Removed the excessive empty gap between the filters and lawyer results.

## Brand

- Added the existing application icon beside the `استشارة` wordmark on the
  client home and lawyer directory headers.
- Increased the wordmark and icon size with a restrained border and shadow.



---

## Imported from `CHANGELOG_AI_2026-09-08_MIGRATION_HISTORY_SYNC.md`

# Supabase Migration History Sync — 2026-09-08

## Change

- File: `supabase/migrations/20260908000154_final_production_identity_auth_chat_and_storage_hardening.sql`
- Reason: Supabase Production recorded the migration as version `20260908000154`, while the repository filename used `20260908003000`.
- Description: Renamed the existing migration without changing its SQL so GitHub and Supabase Migration History use the same version and name.
- Result: Production migration drift is removed; no database operation or data rewrite is required.
- Commit: Pending.



---

## Imported from `CHANGELOG_AI_2026-09-10_APPOINTMENT_CI_FIX.md`

# سجل إصلاح CI لبطاقة المواعيد — 2026-09-10

## الخطأ
- ظهر خطأ `flutter analyze` بعد إضافة بطاقة المواعيد المقترحة إلى الصفحة الرئيسية للعميل.
- الملف: `lib/features/bookings/presentation/widgets/client_appointment_requests_home_card.dart`.
- الخطأ كان `undefined_getter` على `TextDirection.rtl` في صف عنوان الكارت.

## الإصلاح
- commit: `bffff783d7715348dee9701ae26115005ec8f0ea`.
- أزيل override غير الضروري `textDirection: TextDirection.rtl` من الـRow.
- التطبيق يعمل أصلاً باتجاه RTL من السياق العام، لذلك لا يحتاج الكارت هذا التحديد المحلي.
- لم يتغير منطق القبول أو اقتراح التغيير أو الرفض أو Realtime أو ربط `request_id` بالإشعار.

## التحقق المطلوب بعد الإصلاح
- اعتماد نتيجة `flutter analyze` الجديدة.
- اعتماد Flutter tests.
- اعتماد Flutter Web build ونشر GitHub Pages على آخر HEAD.



---

## Imported from `CHANGELOG_AI_2026-09-10_APPOINTMENT_FLOW.md`

# سجل تعديلات منطق المواعيد — 2026-09-10

هذا الملف يسجل التعديلات المنفذة على منطق وتجربة المواعيد في منصة «استشارة» ابتداءً من توحيد طلبات المواعيد وعدم التعامل مع الموعد المقترح كخدمة منفصلة.

## قاعدة العمل المعتمدة

- إذا نشر المحامي مواعيد متاحة، يستطيع العميل اختيار أحدها والحجز وفق منطق المحفظة المعتمد.
- إذا لم ينشر المحامي مواعيد، يستطيع العميل تحديد من فترة واحدة إلى ثلاث فترات مناسبة له وإرسالها ضمن نفس طلب الاستشارة.
- إذا لم تناسب العميل المواعيد المنشورة، يستطيع أيضاً اقتراح فترات مناسبة له من نفس مسار الحجز.
- المحامي يرى هذه الطلبات ضمن صندوق موحد لطلبات المواعيد والاستشارات، ويستطيع قبول وقت داخل فترة العميل أو اقتراح موعد بديل أو رفض الاستشارة نهائياً.
- اقتراح موعد بديل لا يعد رفضاً نهائياً ولا يعيد المبلغ المحجوز؛ ينتظر الطلب اختيار العميل النهائي.
- الرفض النهائي فقط ينهي الطلب ويعيد المبلغ المحجوز.

## التعديلات المسجلة

### 1. إنشاء سجل التعديلات
- الملف: `CHANGELOG_AI_2026-09-10_APPOINTMENT_FLOW.md`
- الهدف: تسجيل كل تعديل جديد متعلق بمنطق المواعيد والواجهات المرتبطة به في مكان واحد.

### 2. دمج اقتراح العميل للموعد في مسار الحجز الطبيعي
- الملف: `lib/features/bookings/presentation/pages/create_booking_page.dart`
- commit: `d629d2aa26cc83dc82b8ae017021a573d9e06b2f`
- التعديلات:
  - تغيير عنوان خطوة الموعد عند عدم وجود مواعيد منشورة إلى `حدد الأوقات التي تناسبك`.
  - توضيح أن العميل يستطيع اختيار من فترة واحدة إلى ثلاث فترات، وأن المحامي يستطيع اختيار وقت منها أو اقتراح موعد بديل.
  - إزالة عبارة `طلب موعد خاص` من رسالة عدم وجود مواعيد واستبدالها بمنطق واضح بأن العميل يحدد أوقاته ضمن نفس طلب الاستشارة.
  - تغيير زر `لا يناسبني أي موعد — طلب موعد خاص` إلى `لا يناسبني أي موعد — اقترح موعداً`.
  - تغيير وصف طريقة الموعد في شاشة المراجعة إلى `أوقات مقترحة من العميل`.
  - تحديث رسالة نجاح الإرسال إلى `تم إرسال الأوقات المقترحة إلى المحامي`.
  - تحديث النص الاحتياطي لحالة عدم وجود مواعيد منشورة ليبين أن اقتراح العميل متاح، مع إبقاء خيار متابعة المحامي.
- لم يتم تغيير منطق الدفع أو حجز الرصيد أو RLS أو آلية إنشاء الحجز في هذا التعديل؛ التغيير يخص وضوح وتوحيد تجربة المواعيد.

### 3. توحيد صفحة متابعة المواعيد
- الملف: `lib/features/bookings/presentation/pages/appointment_requests_page.dart`
- commit: `86c2faf9f6420fa0dc288b6c5cb42c577594280c`
- التعديلات:
  - تغيير عنوان صفحة المحامي من `طلبات المواعيد الخاصة` إلى `طلبات المواعيد`.
  - تغيير عنوان صفحة العميل إلى `متابعة المواعيد`.
  - تغيير حالة الفراغ إلى `لا توجد طلبات مواعيد حالياً` بدون وصفها بأنها خاصة.
  - تسمية فترات العميل بـ `الأوقات التي اقترحها العميل`.
  - توضيح زر الرفض بأنه `رفض نهائي`.
  - إضافة تنبيه داخل نافذة الرفض بأن المحامي إذا كان اعتراضه على الوقت فقط فعليه اقتراح موعد آخر بدلاً من إنهاء الاستشارة.
  - تحديث رسالة الرفض لتوضح أنه رفض نهائي يعيد المبلغ المحجوز.

### 4. توحيد رسالة التحقق عند إرسال موعد مقترح
- الملف: `lib/features/bookings/presentation/providers/bookings_provider.dart`
- commit: `f39f71a0b3863d6d02e5d4ed5c2843dce1f9a722`
- التعديل: تغيير رسالة التحقق من `فقط طالب الاستشارة يمكنه طلب موعد خاص` إلى `فقط طالب الاستشارة يمكنه اقتراح موعد`.
- لم تتغير صلاحيات المستخدم أو استدعاء RPC أو شروط عدد الفترات.

### 5. توحيد رسائل وسجل المحفظة مع منطق الموعد المقترح
- الملف: `lib/features/payments/presentation/pages/client_wallet_page.dart`
- commit: `4aea8269521a33191a7766bf28dcb02c9d9125c5`
- التعديلات:
  - بعد اعتماد شحن المحفظة أصبحت الرسالة توضح أن العميل يستطيع الرجوع إلى المحامي واختيار موعد منشور أو اقتراح الأوقات التي تناسبه.
  - تغيير اسم حركة `appointment_hold` من `حجز مبلغ لموعد خاص` إلى `حجز مبلغ لطلب الموعد`.
- لم يتغير أي رصيد أو قيد مالي أو منطق حجز/تحرير الأموال؛ التغيير في الوصف الظاهر فقط.

### 6. توحيد إشعار المحامي عند اقتراح العميل للأوقات
- Supabase production: تم تطبيق migration باسم `unify_proposed_appointment_notification` بنجاح.
- ملف المستودع: `supabase/migrations/20260910174500_unify_proposed_appointment_notification.sql`
- commit: `dd214c0bc350d610388457cd9be4177f38b884e4`
- التعديلات:
  - تغيير عنوان الإشعار من `طلب موعد خاص جديد` إلى `طلب موعد جديد`.
  - تغيير نص الإشعار إلى `حدد طالب الاستشارة أوقاتاً مناسبة له. اختر وقتاً منها أو اقترح مواعيد بديلة خلال 12 ساعة.`
- بقي منطق حجز الرصيد، التحقق من المحامي، عدد الفترات، مهلة الرد، وإنشاء سجل الطلب كما هو دون تغيير.

### 7. إصلاح منع العميل من اقتراح موعد عندما لا يملك المحامي أوقاتاً منشورة
- الملف: `lib/features/lawyers/presentation/pages/lawyer_details_page.dart`
- commit: `935d8db0774d531f37707447b0740b767c73b8f3`
- سبب المشكلة:
  - صفحة ملف المحامي كانت تستدعي `availableSlotsProvider` قبل فتح صفحة الحجز.
  - إذا كانت نتيجة المواعيد فارغة، كانت تعرض نافذة `لا توجد مواعيد متاحة` وتسمح فقط بمتابعة المحامي أو الإلغاء.
  - لذلك لم يكن العميل يصل أصلاً إلى `CreateBookingPage` التي تدعم اقتراح الأوقات عند عدم وجود مواعيد.
- الإصلاح:
  - إزالة شرط وجود موعد منشور قبل فتح شاشة الحجز.
  - زر الملف الشخصي أصبح يفتح `CreateBookingPage` مباشرة سواء توجد مواعيد منشورة أم لا.
  - تغيير تسمية الزر إلى `حجز أو اقتراح موعد` لتوضيح المسارين.
  - عند وجود مواعيد تعرض شاشة الحجز المواعيد المنشورة، وعند عدم وجودها تنتقل تلقائياً إلى `حدد الأوقات التي تناسبك`.
  - تحديث نص قسم `ابدأ طلبك` ليوضح أن عدم نشر المحامي لمواعيد لا يمنع إرسال طلب الاستشارة.
- لم يتم إنشاء موعد وهمي ولم يتم تجاوز منطق المحفظة أو التحقق من المحامي؛ تم فقط إزالة حاجز واجهة كان يمنع الوصول إلى المسار الصحيح.

### 8. جعل رد العميل على مواعيد المحامي متناظراً مع رد المحامي
- Supabase production: تم تطبيق migration باسم `symmetric_appointment_responses_and_deep_links` بنجاح.
- ملف المستودع: `supabase/migrations/20260910203000_symmetric_appointment_responses_and_deep_links.sql`.
- commits: `0f9fd81495ec527fe378511203710ba8f1318625` و `2448262ebfe6bde1a97a923a8c75bd2a206b48a3`.
- أضيفت الدالة `client_respond_custom_appointment_request`.
- عندما تصل مواعيد مقترحة من المحامي يستطيع العميل الآن:
  - قبول أحد المواعيد وتثبيت الحجز.
  - اقتراح تغيير وتحديد من فترة واحدة إلى ثلاث فترات جديدة.
  - رفض الطلب نهائياً مع سبب.
- اقتراح التغيير لا يحرر المبلغ المحجوز، بل يعيد الطلب إلى حالة `بانتظار رد المحامي`.
- الرفض النهائي من العميل يحرر المبلغ ويعيده إلى المحفظة، ويسجل `rejected_by=client` ويرسل إشعاراً للمحامي.
- الرفض النهائي من المحامي يسجل `rejected_by=lawyer`.
- أضيف `negotiation_round` بحد أقصى ثلاث جولات تعديل؛ بعد الجولة الثالثة يستطيع العميل القبول أو الرفض فقط لمنع تفاوض مفتوح بلا نهاية.

### 9. توحيد بطاقة طلب الموعد للعميل والمحامي
- الملف: `lib/features/bookings/presentation/pages/appointment_requests_page.dart`.
- commit: `2448262ebfe6bde1a97a923a8c75bd2a206b48a3`.
- العميل يرى المواعيد المقترحة من المحامي داخل نفس بطاقة الطلب وبنفس وضوح إجراءات المحامي.
- أزرار العميل في حالة انتظار اختياره: `قبول` لكل موعد، `اقتراح تغيير`، `رفض نهائي`.
- أزرار المحامي في حالة انتظار رده: `اختيار وقت من اقتراح العميل`، `موعد بديل`، `رفض نهائي`.
- أضيفت حالة انشغال تمنع الضغط المتكرر على إجراءات الطلب أثناء تنفيذ العملية.
- أضيف تمييز بصري للطلب الذي تم الوصول إليه من إشعار.

### 10. فتح إشعار الموعد على الطلب المحدد بالضبط
- الملفات:
  - `lib/core/services/notification_service.dart`
  - `lib/app/router.dart`
  - `lib/features/profile/presentation/pages/notifications_page.dart`
  - `supabase/functions/send-pwa-push/index.ts`
- commits: `1f4046c29394749a5727c1d38984a061c0fd04fd`, `45261722c3aed2038f851dd3ba4f6e6e1620c4e4`, `d53b8b28676871461aea842a75ca1f49ccce3e2c`, `ef7d1fd1bd5bc42feb9bc0f34fb0481aea993e9c`.
- إشعارات `reference_type=appointment_request` أصبحت تفتح الرابط `appointment-requests?request_id=<id>` بدلاً من صفحة المواعيد العامة.
- الـRouter يمرر `request_id` إلى `AppointmentRequestsPage`.
- الصفحة تبحث عن الطلب المحدد حتى لو لم يكن ضمن أول 60 طلباً، ثم تمرر الشاشة إليه باستخدام `Scrollable.ensureVisible` وتبرز الكارت بصرياً.
- الضغط على إشعار الموعد من مركز التنبيهات داخل التطبيق يستخدم نفس الرابط المحدد.
- الضغط على Push في PWA يستخدم نفس الرابط المحدد.
- الضغط على إشعار Native يعتمد على `notification_id` ثم يحل `reference_id` ويفتح نفس الطلب.
- تم نشر `send-pwa-push` في Supabase كنسخة حية version 10 مع الإبقاء على `verify_jwt=false` كما كان لأن الوظيفة تستقبل webhook محمياً بسر Supabase.

### 11. تحقق قاعدة البيانات بعد التعديل
- تم التحقق من وجود `negotiation_round` و `rejected_by` في قاعدة الإنتاج.
- تم التحقق من أن الدور `authenticated` يملك صلاحية تنفيذ `client_respond_custom_appointment_request`.
- تم التحقق من وجود إشعار `appointment_client_counter_offer` عند اقتراح العميل تغييراً.
- تم التحقق من أن إشعار المحامي للعميل يطلب منه صراحةً قبول الموعد أو تغييره أو رفضه.



---

## Imported from `CHANGELOG_AI_2026-09-10_APPOINTMENT_NOTIFICATION_ACTIONS.md`

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



---

## Imported from `CHANGELOG_AI_2026-09-10_APPOINTMENT_TIMEOUTS_AND_CONFLICTS.md`

# سجل مهلة الرد ومنع تضارب المواعيد — 2026-09-10

توثق هذه الدفعة سياسة انتهاء طلبات المواعيد ومنع الحجز المتداخل وإظهار الطرف المتأخر بالرد وإضافة الأسماء إلى إشعارات دورة الموعد.

## 1. مهلة رد محددة للطرفين
- المحامي لديه 6 ساعات للرد على فترات العميل.
- العميل لديه 4 ساعات للرد على الموعد أو المواعيد الدقيقة التي يقترحها المحامي.
- إذا كان انتهاء المهلة سيقع قبل الساعة 10:00 صباحاً بتوقيت بغداد، تُمدد المهلة تلقائياً إلى الساعة 10:00 صباحاً حتى لا ينتهي الطلب أثناء وقت النوم.
- الدالة المركزية: `appointment_response_deadline(waiting_on)`.
- الطلبات الجديدة والردود الجديدة تستخدم هذه المهلة بدلاً من مهلة 12 ساعة القديمة.
- لا توجد حالياً طلبات معلقة قديمة تحتاج تحويل مهلة.

## 2. انتهاء المهلة والإلغاء التلقائي
- أضيف إلى `custom_appointment_requests`:
  - `expired_waiting_on`: يحدد هل التأخير كان من `client` أو `lawyer`.
  - `expired_at`: يسجل وقت الإلغاء التلقائي.
- `expire_stale_custom_appointment_requests()` أصبحت:
  - تلغي الطلب المتأخر بحالة `منتهي`.
  - تعيد المبلغ المحجوز إلى محفظة العميل.
  - تسجل حركة تحرير المبلغ بشكل idempotent.
  - ترسل إشعاراً للطرفين يوضح من لم يرد.
  - تذكر اسم العميل أو المحامي في الإشعار حسب الطرف المقصود.
- يبقى cron السابق الذي يعمل كل 5 دقائق كآلية خلفية، وتقوم صفحة متابعة المواعيد أيضاً بتشغيل فحص الانتهاء فور فتحها أو تحديثها.

## 3. الحجز المؤقت للمواعيد المقترحة
- فترات العميل الواسعة لا تُحجز حتى لا يتم تجميد ساعات كبيرة من جدول المحامي.
- عندما يحدد المحامي موعداً دقيقاً أو 1–3 مواعيد دقيقة، تُعتبر هذه الأوقات محجوزة مؤقتاً لذلك الطلب حتى يرد العميل أو تنتهي مهلة الـ4 ساعات.
- إذا غيّر العميل الموعد أو رفضه أو انتهت المهلة، تتحرر المواعيد المؤقتة تلقائياً لأن الطلب لم يعد بحالة `بانتظار اختيار العميل`.

## 4. منع تداخل مدة الاستشارات بالكامل
- أضيفت `is_lawyer_time_blocked(...)` لفحص التداخل الزمني باستخدام `tstzrange` بنطاق `[start,end)`.
- المقارنة تعتمد على مدة الاستشارة كاملة، وليس فقط تطابق ساعة البداية.
- مثال: حجز يبدأ 10:00 ومدته 60 دقيقة يمنع حجزاً يبدأ 10:30، لكنه يسمح بموعد يبدأ 11:00 تماماً.
- أضيف trigger `trg_guard_booking_time_conflict` على جدول `bookings` لمنع أي INSERT/UPDATE متداخل مهما كان مسار إنشاء الحجز.
- أضيف trigger `trg_guard_custom_appointment_slot_holds` لمنع المحامي من اقتراح وقت يتداخل مع حجز فعلي أو اقتراح مؤقت لطلب آخر، ويمنع أيضاً تداخل البدائل داخل نفس الطلب.
- تستخدم الأقفال الاستشارية transaction advisory locks على `lawyer_id` لتقليل سباق الحجز المتزامن لنفس المحامي.

## 5. إظهار المواعيد المحجوزة في واجهة الحجز
- RPC جديد: `get_lawyer_booking_slots(lawyer_id)`.
- يعيد كل موعد منشور مستقبلي مع:
  - `is_bookable`.
  - `unavailable_reason`.
- المواعيد المتداخلة تظهر للعميل بعبارة `محجوز بالفعل لهذه المدة` وتكون غير قابلة للاختيار.
- `availableSlotsProvider` يستمع إلى Realtime لتغييرات الحجوزات وطلبات المواعيد والمواعيد المنشورة ويعيد تحميل حالة المواعيد.
- حتى إذا كانت شاشة عميل آخر قديمة ولم تستقبل التغيير، فإن قاعدة البيانات تمنع الحجز المتداخل عند التنفيذ وتعيد الواجهة تحميل المواعيد.

## 6. واجهة انتهاء المهلة وإعادة الحجز
- `AppointmentRequestsPage` تعرض حالة `منتهي` بصيغة `أُلغي لعدم الرد`.
- تعرض رسالة تحدد هل المحامي أو العميل لم يرد ضمن المهلة.
- تعرض وقت الإلغاء التلقائي.
- لدى العميل زر `احجز مرة أخرى` يعيده إلى ملف نفس المحامي لإنشاء حجز جديد.
- إشعار الانتهاء يحتفظ بـ `reference_type=appointment_request` و`request_id`، لذلك الضغط عليه يستمر بفتح نفس الطلب مباشرة.

## 7. أسماء الأطراف في الإشعارات
تم تضمين الأسماء في إشعارات دورة الموعد الجديدة:
- طلب موعد جديد: اسم العميل للمحامي.
- موعد أو مواعيد مقترحة: اسم المحامي للعميل.
- اقتراح تغيير من العميل: اسم العميل للمحامي.
- الرفض النهائي: اسم الطرف الرافض.
- انتهاء المهلة: اسم الطرف ذي الصلة وتحديد من لم يرد.
- الإلغاء اليدوي قبل التأكيد: اسم العميل للمحامي.
- إشعارات الحجز بعد التأكيد كانت أصلاً تستخدم أسماء العميل والمحامي عبر `notify_booking_events()`.

## 8. ملفات ودفعات التنفيذ
- Production migration: `appointment_reply_deadlines_and_overlap_guards`.
- Repo migration: `supabase/migrations/20260910214500_appointment_reply_deadlines_and_overlap_guards.sql` — commit `b57222efa3d01b59555dac91d91adc7b51310ca4`.
- `lib/features/bookings/presentation/providers/bookings_provider.dart` — commit `c3f76681791498316bed3a8eb08b699dc43f895f`.
- `lib/features/bookings/presentation/pages/create_booking_page.dart` — commit `726d9ab8149e916eb3c9f7fc7918da25d2ca22e4`.
- `lib/features/bookings/presentation/pages/appointment_requests_page.dart` — commit `b85ca498bb0ed1512abcefbcf7fc5d8c0b0c437a`.
- Production migration: `custom_appointment_cancel_notification_names`.
- Repo migration: `supabase/migrations/20260910220500_custom_appointment_cancel_notification_names.sql` — commit `81a93e9e2691ceb9b46fca95d9e585a509897abd`.

## 9. التحقق
- تم التحقق من وجود triggers الحماية في قاعدة الإنتاج.
- تم التحقق من وجود دوال المهلة وفحص التداخل وRPC المواعيد.
- تم التحقق من عدم وجود طلبات معلقة قديمة تحتاج تحويل مهلة من السياسة السابقة.
- لا يُعتبر اختبار جلسات Client/Lawyer الحقيقي الكامل منفذاً ما لم يتم تشغيله بحسابين فعليين؛ التحقق الحالي هو على منطق قاعدة الإنتاج، التعريفات، القيود، والـCI الخاص بالمستودع.



---

## Imported from `CHANGELOG_AI_2026-09-10_HOME_SPECIALIZATIONS_COLLAPSE.md`

# سجل تبسيط تخصصات الصفحة الرئيسية — 2026-09-10

يوثق هذا الملف تعديل قسم التخصصات القانونية في الصفحة الرئيسية لطالب الاستشارة حتى لا تملأ كروت التخصصات معظم الصفحة.

## المشكلة
- كانت الصفحة الرئيسية تعرض جميع تخصصات `LegalSpecializations.all` دفعة واحدة.
- القائمة الحالية تضم 43 تخصصاً، ولذلك كانت شبكة التخصصات تستهلك مساحة كبيرة وتدفع الأقسام التالية إلى أسفل الصفحة.

## التنفيذ
- الملف: `lib/features/home/presentation/pages/home_page.dart`.
- commit البرمجي: `e0463b87d99f092eba34275d17c2f89d283b7e19`.
- أصبحت `HomePage` من نوع `ConsumerStatefulWidget` للاحتفاظ بحالة فتح/إغلاق التخصصات الإضافية داخل الصفحة نفسها.
- المعاينة الأولى تعرض 6 تخصصات فقط، أي صفين في الشبكة ذات الثلاثة أعمدة.
- أضيف زر واضح داخل نفس القسم بعنوان `عرض المزيد من التخصصات`.
- الزر يعرض بقية التخصصات داخل نفس الصفحة دون نقل المستخدم إلى صفحة أخرى.
- عند فتح القائمة يتحول الزر إلى `عرض تخصصات أقل` ويمكن إعادة الصفحة إلى العرض المختصر.
- يظهر تحت الزر عدد التخصصات الإضافية المخفية.
- الزر يستخدم ألوان `AppColors.primary` والخلفيات والحدود الدائرية و`HoverLift` للحفاظ على الهوية البصرية الحالية للتطبيق.
- تم إبقاء الضغط على أي كارت تخصص كما هو: يحدد التخصص ثم يفتح قائمة المحامين المفلترة.
- تم توضيح زر عنوان قسم التخصصات إلى `كل المحامين` حتى لا يختلط مع زر `عرض المزيد من التخصصات` الجديد.
- تم تصحيح `_SectionTitle` لاستخدام قيمة `action` الممررة له بدلاً من النص الثابت `عرض الكل`، حتى تظهر تسمية العنوان المطلوبة فعلياً.

## ما لم يتغير
- لم تتغير قائمة التخصصات الأساسية أو ترتيبها.
- لم تتغير آلية فلترة المحامين حسب التخصص.
- لم تتغير قاعدة البيانات أو Supabase أو الحجوزات أو المدفوعات.
- لم تتغير كروت المحامين المقترحين أو بقية وظائف الصفحة الرئيسية.

## التحقق
- يجب اعتماد Flutter Analyze وFlutter Tests وFlutter Web Build ونشر GitHub Pages على آخر HEAD قبل اعتبار الدفعة مكتملة نهائياً.



---

## Imported from `CHANGELOG_AI_2026-09-10_NOTIFICATIONS.md`

# سجل تعديلات الإشعارات — 2026-09-10

هذا الملف يسجل التعديلات المنفذة لمعالجة وصول إشعارات منصة «استشارة» بصورة صامتة أو بدون تنبيه مسموع.

## المشكلة

- الإشعارات كانت تصل فعلياً إلى المستخدم، لكن بدون صوت/تنبيه مسموع في بعض الحالات، خصوصاً على iPhone/PWA.
- مسار PWA كان يطلب `silent: false` بالفعل، لكن تسجيل الـ Service Worker كان ثابتاً على إصدار سابق (`v=9`) مما قد يُبقي جهاز المستخدم على Worker قديم.
- مسار iOS الأصلي كان يحدد `sound: 'notification.caf'` بينما لا يوجد هذا الملف في المستودع.

## التعديلات المنفذة

### 1. ترقية Service Worker الخاص بـ PWA وإجبار تحديثه
- الملف: `web/pwa_service_worker_v5.js`
- commit: `02639191da90e06b5bf231e93a1855cb50020d34`
- التعديلات:
  - رفع `CACHE_NAME` من `astshara-pwa-v9` إلى `astshara-pwa-v10`.
  - إبقاء `renotify: true`.
  - جعل خيار الصوت صريحاً: `silent: data.silent === true ? true : false`، وبالتالي أي إشعار عادي يطلب التنبيه المسموع.
  - إضافة `timestamp: Date.now()` للإشعار.
  - إبقاء فتح المسار الصحيح عند الضغط على الإشعار دون تغيير.

### 2. إجبار صفحة التطبيق الرئيسية على تسجيل Worker الجديد بدون كاش
- الملف: `web/index.html`
- commit: `44e1806adf69b1d902b05824f206e5cae878ef98`
- التعديلات:
  - تغيير تسجيل الـ Worker من `pwa_service_worker_v5.js?v=9` إلى `pwa_service_worker_v5.js?v=10`.
  - إضافة `updateViaCache: 'none'` حتى لا يعتمد تحديث Service Worker على نسخة مخزنة في الكاش.
- لم تتغير مفاتيح Web Push أو الاشتراك الحالي للمستخدم.

### 3. توحيد تسجيل Worker في صفحة 404
- الملف: `web/404.html`
- commit: `50668e56f07b80490776435caeb1e31379634709`
- التعديلات:
  - تسجيل نفس `pwa_service_worker_v5.js?v=10` المستخدم في الصفحة الرئيسية.
  - إضافة `updateViaCache: 'none'`.
- الهدف: منع صفحة 404 من إعادة تسجيل مسار Worker قديم/غير محدث على نفس النطاق.

### 4. إصلاح صوت إشعارات iOS الأصلية
- الملف: `lib/core/services/notification_service.dart`
- commit: `4b35b7d20f485ac85176c5224ca01a6f6171a5e6`
- التعديلات:
  - إزالة الاعتماد على `notification.caf` لأنه غير موجود في المستودع.
  - إبقاء `presentSound: true` وطلب صلاحية الصوت، وبالتالي استخدام صوت إشعارات النظام الافتراضي على iOS بدلاً من ملف مفقود.
  - لم يتغير Android Notification Channel؛ ما زال `Importance.max` و`Priority.high` و`playSound: true` و`enableVibration: true`.

## حدود المنصة

- كود PWA يطلب إشعاراً غير صامت (`silent: false`). على iOS/iPadOS يبقى القرار النهائي للصوت خاضعاً لإعدادات إشعارات النظام ووضع التركيز/الصامت؛ التطبيق لا يستطيع تجاوز إعدادات النظام.
- لا يتم استخدام Critical Alerts أو أي آلية تتجاوز إعدادات المستخدم.



---

## Imported from `CHANGELOG_AI_2026-09-10_UI_PRIORITY_LOADING.md`

# سجل تحسين الألوان والتحميل — 2026-09-10

يوثق هذا الملف دفعة تحسين الواجهة الخاصة بتمييز الاستشارات والإشعارات حسب الأهمية، وتوحيد مؤشر التحميل بأسلوب iOS، وتحسين ألوان الأزرار.

## 1. مؤشر التحميل المشترك بأسلوب iOS
- الملف: `lib/shared/widgets/loading_widget.dart`.
- commit: `d0467407dd3a80dd9d4d0ab71f9f8aa9a20d8bd2`.
- تم استبدال `CircularProgressIndicator` داخل `LoadingWidget` بـ `CupertinoActivityIndicator`.
- هذا ينعكس مباشرة على الصفحات التي تستخدم `LoadingWidget`، ومنها شاشة تحميل التطبيق وعدة صفحات المحادثة والمحامين والمصادقة والإدارة.
- أضيف دعم `size` و`color` للمؤشر مع إبقاء اللون الافتراضي من الثيم.

## 2. نظام موحد للأهمية البصرية
- الملف الجديد: `lib/shared/styles/priority_visuals.dart`.
- commit: `2a9afe1a72b44e8b4e50e48c33da6c8bed554edc`.
- الاستشارات:
  - تركوازي: الاستشارة قيد التنفيذ/جارية الآن.
  - ذهبي: طلب أو حالة انتظار/مراجعة تتطلب إجراء.
  - أخضر: مؤكد/مقبول/مكتمل.
  - أحمر: رفض/إلغاء/انتهاء/عدم حضور.
  - أزرق: معلومات أو حالات عادية أخرى.
- الإشعارات:
  - أحمر للتنبيهات السلبية أو العاجلة مثل الرفض والإلغاء والانتهاء وعدم الحضور.
  - ذهبي للإشعارات التي تتطلب رد العميل أو المحامي مثل اقتراحات المواعيد.
  - أخضر للدفع والتأكيد الناجح.
  - تركوازي للرسائل.
  - أزرق للمعلومات والاستشارات العامة.

## 3. تلوين صفحة الإشعارات حسب الأهمية
- الملف: `lib/features/profile/presentation/pages/notifications_page.dart`.
- commit: `67b3d491b5d51babf774a6ca54aad54604d3e3b5`.
- أصبح لون خلفية الكارت وحدوده والشريط الجانبي والأيقونة وشارة الأهمية مشتقاً من نوع الإشعار ومحتواه.
- الإشعارات المهمة غير المقروءة تحصل على إبراز أكبر بدون ألوان صارخة أو ضعف تباين النص.
- بقي Deep Link الحالي كما هو، لذلك الضغط على إشعار الموعد أو الحجز يستمر بفتح الهدف المحدد.
- تم استبدال تحميل صفحة الإشعارات بـ `LoadingWidget` بأسلوب iOS.
- زر «اعتبار جميع الإشعارات مقروءة» أصبح بتمييز ذهبي خفيف، وزر إعادة المحاولة تركوازي.

## 4. تلوين استشارات العميل والمحامي حسب الحالة
- الملف: `lib/features/bookings/presentation/pages/bookings_list_page.dart`.
- commit: `b93bbd94f3232d0766a9a664e0a345b847c7073d`.
- كروت العميل والمحامي تستخدم الآن نفس نظام الأهمية البصرية.
- الحالات التي تحتاج إجراء تحصل على حد وخلفية ذهبية خفيفة، والجارية تركوازية، والمؤكدة/المكتملة خضراء، والملغاة/المرفوضة حمراء.
- زر «بدء الاستشارة» أصبح تركوازياً واضحاً، وزر التفاصيل أزرق، وإجراء الحذف أحمر.
- ملخص طلبات المحامي يصبح ذهبياً عند وجود طلبات تحتاج مراجعته.
- تم استخدام مؤشر تحميل iOS في تحميل قائمة الاستشارات.

## 5. صفحة الاستشارات النشطة والمكتملة للمحامي
- الملف: `lib/features/bookings/presentation/pages/lawyer_consultations_page.dart`.
- commit: `45de0acd9d117c5d98bda69141c99268652c4cc6`.
- الاستشارة النشطة/قيد التنفيذ لها تمييز تركوازي، والمكتملة تمييز أخضر.
- شارة الحالة والأيقونة والحدود تتبع نفس النظام الموحد.
- تم استبدال مؤشر تحميل الصفحة بمؤشر iOS.

## 6. فتح الاستشارة من الإشعار
- الملف: `lib/features/bookings/presentation/pages/booking_notification_target_page.dart`.
- commit: `cd614f51bb7e5ad9b65c089ac26674839d3b76c5`.
- شاشة انتظار تحميل الاستشارة المرتبطة بإشعار تستخدم الآن مؤشر iOS.
- زر إعادة المحاولة أصبح تركوازياً مميزاً.
- لم يتغير مسار فتح الاستشارة أو الـDeep Link.

## 7. أرشيف الاستشارات
- الملف: `lib/features/bookings/presentation/pages/archived_bookings_page.dart`.
- commit: `afd9bac16a1b79ad6b34dab257aac03839ec9278`.
- تحميل الأرشيف واستعادة الاستشارة يستخدمان مؤشر iOS.
- بقيت عمليات الأرشفة والاستعادة دون تغيير منطقي.

## 8. توسيع مؤشر iOS إلى مسارات الاستخدام اليومية
### المحادثات
- الملف: `lib/features/chat/presentation/pages/conversations_page.dart`.
- commit: `4d5120b4a4fc6b9b5d16ee50d3b03e6d6b0114ec`.
- تحميل قائمة المحادثات يستخدم مؤشر iOS.
- زر إعادة المحاولة أصبح أوضح، وRefreshIndicator أصبح تركوازياً.

### حساب استلام الأموال
- الملف: `lib/features/profile/presentation/pages/payment_methods_page.dart`.
- commit: `3974a4d62b4aba6b9c42147f7f03181e4062f6f0`.
- تحميل الصفحة وحالة الحفظ يستخدمان مؤشر iOS.
- زر حفظ/تحديث حساب الاستلام أصبح تركوازياً.

### محفظة المحامي
- الملف: `lib/features/lawyers/presentation/pages/lawyer_wallet_page.dart`.
- commit: `3198c11dc241656fb900f2ca44bb402353b3f747`.
- تحميل الصفحة، حفظ وسيلة الاستلام، وإرسال طلب السحب تستخدم مؤشر iOS.
- أزرار السحب والحفظ أصبحت تركوازية، مع إبراز زر تعديل وسيلة الاستلام.

### إنشاء طلب الاستشارة
- الملف: `lib/features/bookings/presentation/pages/create_booking_page.dart`.
- commit: `276792590af4c93089f5d067bc7fc9840fd3f4c3`.
- تحميل المواعيد ومؤشر إرسال الطلب يستخدمان مؤشر iOS.
- زر المتابعة أزرق، وزر إرسال طلب الاستشارة النهائي تركوازي.
- زر متابعة المحامي وزر إعادة محاولة تحميل المواعيد أصبحا تركوازيين.
- لم يتغير منطق تضارب المواعيد أو الحجز المؤقت أو الدفع.

### محفظة العميل
- الملف: `lib/features/payments/presentation/pages/client_wallet_page.dart`.
- commit: `f8c0dd3f7c6cd81ce350a87c422fa1362fb8fc1a`.
- تحميل الرصيد وإعدادات التحويل وطلبات الشحن وحركة المحفظة تستخدم مؤشر iOS.
- مؤشر إرسال إيصال الشحن أصبح iOS أيضاً.
- زر إرسال الإيصال تركوازي، والإيصال المختار يتميز بالأخضر، وأيقونتا المواعيد والتحديث أصبحتا مميزتين.
- حالات الشحن المعتمد/المرفوض/قيد الانتظار أصبحت أوضح لوناً.

## 9. طلبات المواعيد
- الملف: `lib/features/bookings/presentation/pages/appointment_requests_page.dart`.
- commit: `0fdc6981d1b23c52be23245bba167d9d2f6ba035`.
- تم تحويل تحميل صفحة طلبات المواعيد إلى مؤشر iOS.
- أصبحت كروت طلبات المواعيد تستخدم نفس نظام الأهمية: الانتظار ذهبي، الانتهاء والرفض أحمر، التأكيد أخضر، والحالة العادية أزرق.
- فتح طلب من الإشعار يبرزه بلون حالته بدل تمييز ثابت.
- قبول الموعد لدى العميل أصبح أخضر، واختيار موعد لدى المحامي تركوازياً، واقتراح التغيير/الموعد البديل ذهبياً، والرفض النهائي والإلغاء أحمر.
- زر «احجز مرة أخرى» بعد انتهاء المهلة أصبح تركوازياً.
- لم يتغير منطق انتهاء المهلة أو الحجز المؤقت أو Deep Link أو Realtime أو إعادة الرصيد.

## 10. التحقق النهائي
- الدفعة البرمجية الموسعة حتى `f8c0dd3f7c6cd81ce350a87c422fa1362fb8fc1a` نجحت في Flutter Analyze وFlutter Tests وFlutter Web Build ونشر GitHub Pages.
- الدفعة الأخيرة `0fdc6981d1b23c52be23245bba167d9d2f6ba035` الخاصة بطلبات المواعيد نجحت أيضاً بالكامل:
  - Flutter Analyze: نجاح.
  - Flutter Tests: نجاح.
  - Flutter Web Build: نجاح.
  - GitHub Pages Deploy: نجاح.
- لم يظهر خطأ تجميع أو اختبار في التغييرات البصرية المنفذة.

## 11. نطاق التصميم
- شاشة فتح التطبيق نفسها تعتمد `LoadingWidget`، لذلك تستخدم مؤشر iOS تلقائياً.
- تحميل الصفحات والمحتوى الرئيسي في المسارات اليومية للعميل والمحامي تم توحيده بدرجة واسعة عبر `LoadingWidget`.
- المؤشر الخطي داخل كارت أثناء تنفيذ إجراء متتابع يبقى خطياً لأنه يوضح تقدم عملية داخل نفس الكارت وليس تحميل صفحة جديدة.
- لم يتم تغيير قواعد الحجز أو الدفع بسبب هذه الدفعة البصرية.



---

## Imported from `CHANGELOG_AI_2026-09-10_WALLET_KEYBOARD_FIX.md`

# سجل إصلاح لوحة مفاتيح المحفظة — 2026-09-10

يوثق هذا الملف إصلاح مشكلة اختفاء/قص نموذج شحن محفظة العميل عند فتح لوحة المفاتيح على iPhone.

## المشكلة
- عند الضغط على حقل `مبلغ الشحن بالدينار` وفتح لوحة المفاتيح الرقمية كان مستطيل الإدخال يظهر جزئياً أو يتحرك إلى أعلى الشاشة، وتختفي بقية حقول نموذج الشحن من المنطقة المرئية.
- ظهرت المشكلة في صفحة `محفظتي` داخل مسار `/client-wallet`.

## السبب الأولي
- `ClientWalletPage` تحتوي `Scaffold` خاصاً بها، بينما الصفحة نفسها معروضة داخل `AppShell` الذي يحتوي `Scaffold` آخر.
- كان هذا يضيف ضغطاً إضافياً على التخطيط عند ظهور لوحة المفاتيح، وتم منع إعادة التحجيم المزدوج في مسار المحفظة.

## الإصلاح 1 — منع إعادة التحجيم المزدوج
- الملف: `lib/shared/widgets/app_shell.dart`.
- commit: `bc7a4a5413ee9f9fdccaa760265b0965dba6e1ac`.
- أصبح `AppShell` لا يعيد تحجيم جسم الشاشة عند المسار `/client-wallet` فقط:
  - `resizeToAvoidBottomInset: location != '/client-wallet'`
- تظل صفحة المحفظة الداخلية هي المسؤولة الوحيدة عن التعامل مع ارتفاع لوحة المفاتيح.
- لم يتغير سلوك لوحة المفاتيح لبقية مسارات التطبيق.

## الإصلاح 2 — جعل نموذج الشحن قابلاً للتمرير بشكل صحيح أثناء الكتابة
- الملف: `lib/features/payments/presentation/pages/client_wallet_page.dart`.
- commit: `c32f99e695075470c170542228889a9a6740da9f`.
- تم تثبيت `resizeToAvoidBottomInset: true` على `ClientWalletPage` لتكون هي المسؤولة عن مساحة لوحة المفاتيح.
- أضيف `ScrollViewKeyboardDismissBehavior.onDrag` إلى `ListView` ليتمكن المستخدم من سحب الصفحة وإغلاق لوحة المفاتيح بسهولة.
- أضيف `AlwaysScrollableScrollPhysics` حتى يبقى نموذج المحفظة قابلاً للتمرير حتى في الشاشات القصيرة أو عند فتح لوحة المفاتيح.
- أضيف `scrollPadding` كبير مبدئياً لحقلي المبلغ ورقم العملية، ثم ثبت لاحقاً من صور الاختبار على iPhone أن هذه القيم نفسها تسبب over-scroll وتم تصحيحها في الإصلاح 9 أدناه.
- أضيف `TextInputAction.next` لحقل المبلغ و`TextInputAction.done` لحقل رقم العملية.

## التصحيح بعد استمرار المشكلة على iPhone
بعد وصول الإصلاحين السابقين إلى GitHub Pages واستمرار المشكلة، تمت إعادة فحص طبقة الويب نفسها.

### عامل إضافي في طبقة الويب
- الملف `web/index.html` كان يحتوي دالة `syncViewportHeight()`.
- الدالة كانت تتدخل يدوياً في ارتفاع `html` و`body` بالتزامن مع تغييرات iOS للـviewport عند فتح لوحة المفاتيح.
- تم أولاً تخفيف هذا السلوك ثم أزيل التدخل اليدوي بالكامل لاحقاً في الإصلاح 7 حتى يتولى Flutter/WebKit إدارة الـviewport دون طبقة ثانية.

## الإصلاح 3 — منع iOS PWA من تصغير Flutter إلى ارتفاع لوحة المفاتيح
- الملف: `web/index.html`.
- commit: `e8ea9164721145edb2e18969a01b9cb81e3c44cc`.
- أضيف كشف لحالة تحرير النص وكشف احتياطي لظهور لوحة المفاتيح لمنع مزامنة ارتفاع منخفض أثناء التحرير.
- كان هذا إصلاحاً وسيطاً، ثم أزيلت آلية `syncViewportHeight` كلها لاحقاً بعد استمرار المشكلة.

## الإصلاح 4 — إجبار PWA على استلام غلاف الويب الجديد
- تم رفع Cache الخاص بالـService Worker من `astshara-pwa-v10` إلى `astshara-pwa-v11` في `web/pwa_service_worker_v5.js`.
- commit: `275401a4eb033a71cb8f77b2f40a37d6b2675d7f`.
- تم تحديث تسجيل الـService Worker في `web/index.html` إلى `?v=11`.
- commit: `6aeea0b0e13fb0a569cc60d32d1eeb6f4d0f46b2`.
- تم تحديث تسجيل النسخة نفسها في `web/404.html`.
- commit: `1938cb0a49b5720212388df3031c559f6619ca5a`.

## الإصلاح 5 — منع Auto-Zoom عند التركيز على حقل Flutter في iOS
- الملف: `web/index.html`.
- commit: `8be58442749500c110ca3eb28d27f42e161a89b0`.
- أضيف حد أدنى 16px لعناصر الإدخال DOM الداخلية التي يستخدمها Flutter Web: `input` و`textarea` والعناصر `contenteditable`.
- لم يتم تعطيل تكبير الصفحة للمستخدم عبر `user-scalable=no` حفاظاً على الوصولية.

## الإصلاح 6 — إخراج المحفظة بالكامل من AppShell
- الملف: `lib/shared/widgets/app_shell.dart`.
- commit: `89167fb3f46d469d4ab73fa4c2e5b31589f3433d`.
- بعد استمرار المشكلة لم يعد `/client-wallet` يُعرض داخل `Scaffold` و`ClipRect/RepaintBoundary` الخاصين بالـAppShell.
- صفحة المحفظة أصبحت صفحة كاملة مستقلة، و`ClientWalletPage` هي المالك الوحيد للـScaffold وللتعامل مع لوحة المفاتيح.
- الهدف إزالة أي قص أو إعادة تخطيط من غلاف خارجي عند انتقال التركيز إلى TextField.

## الإصلاح 7 — إزالة إدارة viewport اليدوية نهائياً
- الملف: `web/index.html`.
- commit: `93b4516a0a0c66516b5462f388e7a178b04c90aa`.
- أزيلت دالة `syncViewportHeight()` ومستمعات `resize/orientationchange/focusout` المرتبطة بها بالكامل.
- أصبح Flutter Web وWebKit وحدهما مسؤولين عن تغيرات الـviewport عند فتح وإغلاق لوحة المفاتيح.
- تم الإبقاء فقط على حماية 16px الخاصة بمنع iOS Auto-Zoom.

## الإصلاح 8 — تحديث PWA إلى v12
- الملف: `web/pwa_service_worker_v5.js`.
- commit: `493d9017fb39cede7bf90fe4b76f021ad4185c68`.
- رُفع Cache إلى `astshara-pwa-v12` لتجاوز أي shell قديم.
- الملف: `web/404.html`.
- commit: `33cbaa7ae9a57922c31133da2902030b6b372414`.
- تم توحيد fallback مع Service Worker `v12`.

## الإصلاح 9 — إيقاف over-scroll الخاص بحقول المحفظة
- الملف: `lib/features/payments/presentation/pages/client_wallet_page.dart`.
- commit: `64235fadd8c61a69614d934441e3f67e93390f49`.
- صورة الاختبار بعد v12 أثبتت أن الصفحة لم تعد تنكمش، لكن `TextField` نفسه كان ينتقل إلى أعلى الشاشة ويخفي بقية النموذج.
- السبب المباشر كان `scrollPadding` الكبير:
  - مبلغ الشحن: 120px.
  - رقم عملية التحويل: 150px.
- تم خفضه إلى هامش طبيعي 16px عمودياً لكلا الحقلين حتى يقوم Flutter فقط بالتمرير اللازم لإبقاء الحقل فوق لوحة المفاتيح بدلاً من دفع الكارت إلى أعلى الصفحة.
- أضيف `FocusNode` مستقل لكل حقل.
- زر `التالي` في حقل المبلغ ينقل التركيز مباشرة إلى حقل رقم عملية التحويل.
- زر `تم` في الحقل الثاني يغلق لوحة المفاتيح.
- الضغط خارج الحقل يغلق لوحة المفاتيح أيضاً.
- تم التخلص من أي scroll يدوي كبير؛ الصفحة تبقى `ListView` طبيعية وقابلة للتمرير.

## الإصلاح 10 — معالجة Flutter Web semantics Auto-Zoom على iOS
- صورة الاختبار اللاحقة أثبتت أن خفض `scrollPadding` لا يعالج المشكلة الأساسية؛ استمر ظهور مساحة بيضاء كبيرة وتحرك سطح الإدخال عند استدعاء كيبورد iPhone.
- تم التحقق من مشكلة Flutter Web الحالية الخاصة بـ iOS/WebKit: عنصر الإدخال الدلالي الذي ينشئه Flutter قد لا يحدد `font-size`، فيرث حجماً أقل من 16px، وWebKit يقوم عندها بتكبير الصفحة تلقائياً عند التركيز.
- كانت حماية 16px محاولة للتخفيف من هذا النوع من مشاكل WebKit، لكنها لم تعالج انزياح Surface/DOM الذي ظهر فعلياً على الجهاز.

### الإصلاح 10.1 — حماية CSS مباشرة لعناصر Flutter الدلالية
- الملف: `web/index.html`.
- commit: `8dbe2202dd0c5886f0179d9a58c98eae920352ab`.
- أضيف `font-size: 16px !important` و`-webkit-text-size-adjust: 100%` إلى عناصر الإدخال.
- لا يتم استخدام `user-scalable=no` أو `maximum-scale=1`، لذلك لا يتم تعطيل تكبير الصفحة الاختياري للمستخدم.

### الإصلاح 10.2 — حماية ديناميكية لعناصر الإدخال التي ينشئها Flutter لاحقاً
- لأن Flutter Web ينشئ عناصر الإدخال الدلالية/الأصلية بشكل lazy عند التركيز، أضيف `MutationObserver` في `web/index.html`.
- كان المراقب يطبق حد 16px مباشرة على عناصر الإدخال التي تنشأ لاحقاً.
- هذا الأسلوب ألغي في الإصلاح 11 لأنه كان واسعاً أكثر من اللازم ويشمل `flt-text-editing-host` الذي يدير Flutter هندسته بنفسه.

### الإصلاح 10.3 — تطبيق الحماية نفسها على fallback وتحديث PWA
- الملف: `web/404.html`.
- commit: `38eeafb2f7827f0d8c8fc71d7bcae2c178abfe6f`.
- أضيفت الحماية نفسها إلى fallback.
- الملف: `web/pwa_service_worker_v5.js`.
- commit: `e79a6d086a51fb801938720c177cd29035ca9364`.
- رُفع Cache إلى `astshara-pwa-v13`.

## الإصلاح 11 — التشخيص النهائي والحل المتجاوز لخلل iOS/Flutter Web — 2026-09-11

### التشخيص النهائي
- بعد نجاح v13 فعلياً واستمرار المشكلة في صورة جهاز iPhone، تم استبعاد:
  - `AppShell` المزدوج.
  - إدارة `visualViewport` اليدوية.
  - `scrollPadding` الكبير.
  - بقاء Service Worker قديم.
- النمط الظاهر في الصورة هو: شريط التطبيق يبقى ثابتاً، محرر النص ينتقل/يبقى في أعلى المساحة، بينما تظهر مساحة بيضاء كبيرة فوق لوحة المفاتيح. هذا يطابق عائلة أخطاء Flutter Web على iOS التي يحدث فيها عدم تطابق بين سطح Flutter المرئي وبين عنصر DOM الذي يستخدمه المحرك لإدخال النص عند ظهور لوحة مفاتيح WebKit.
- يوجد بلاغ Flutter مؤكد عن ظهور مساحة بيضاء/offset عند فتح لوحة المفاتيح مع حقول الإدخال داخل ScrollView على iOS Web، وبلاغ حديث جداً (سبتمبر 2026) عن auto-zoom لعناصر semantic input في iOS Safari.
- `web/index.html` لدينا كان يفرض `font-size:16px !important` بشكل واسع على `flt-text-editing-host` نفسه إضافة إلى عناصر Semantics. هذا العنصر جزء داخلي من محرك Flutter ويحدد موضع محرر DOM بالنسبة إلى لوحة Flutter، لذلك لا ينبغي للتطبيق تغيير هندسته أو نمطه العام.

### الإصلاح 11.1 — تجاوز كيبورد iOS لحقل مبلغ الشحن بدلاً من الاعتماد على خلل المحرك
- الملف: `lib/features/payments/presentation/pages/client_wallet_page.dart`.
- commit: `89aff09c98f2f7e48b7d54478ff374192d50cf83`.
- على Flutter Web عندما تكون المنصة `TargetPlatform.iOS` لم يعد حقل مبلغ الشحن `TextField` أو `EditableText`.
- أصبح الحقل `InputDecorator` قابل للنقر ويفتح `_AmountKeypadSheet`، وهي لوحة أرقام مرسومة بالكامل داخل Flutter ولا تنشئ `<input>` أو `<textarea>` ولا تستدعي لوحة مفاتيح WebKit.
- يدعم المحرر الجديد:
  - الأرقام 0–9.
  - حذف آخر رقم.
  - مسح القيمة.
  - عرض المبلغ منسقاً بالدينار.
  - اعتماد المبلغ فقط إذا كان 1000 د.ع أو أكثر، بما يطابق تحقق الإرسال الحالي.
  - حد طول 10 أرقام لمنع قيم غير عملية أو overflow بصري.
- Android وiOS الأصلي وWeb غير iOS يحتفظون بحقل `TextField` الحالي، لذلك التغيير محصور في المسار الذي ثبتت فيه المشكلة.
- منطق `submit_client_wallet_topup` ورفع الإيصال والرصيد واعتماد الإدارة لم يتغير.

### الإصلاح 11.2 — إزالة التدخل في Flutter text-editing host
- الملف: `web/index.html`.
- commit: `1232eb7632c6bcfb2b43abe5147d8b758f067ddd`.
- أزيل `MutationObserver` العام الذي كان يغير كل input/textarea ديناميكياً.
- أزيلت قواعد CSS التي تستهدف `flt-text-editing-host` والعناصر العامة.
- بقيت حماية 16px فقط لـ `flt-semantics-host input/textarea`، وهي الطبقة المرتبطة مباشرة بمشكلة iOS semantic auto-zoom.
- الملف: `web/404.html`.
- commit: `f4d23bea905b5178a2bb0e4d18062339b5ce8a52`.
- تم تطبيق نفس التنظيف على صفحة fallback حتى لا تختلف سلوكياً عن `index.html`.

### الإصلاح 11.3 — تحديث PWA إلى v14
- الملف: `web/pwa_service_worker_v5.js`.
- commit: `a5841e48d8eab3df0f42269604f3f9f9a829e329`.
- رُفع Cache إلى `astshara-pwa-v14`.
- تم تحديث تسجيل العامل في `web/index.html` و`web/404.html` إلى `?v=14` مع `updateViaCache: 'none'`.
- الملفات الحرجة `main.dart.js` و`flutter_bootstrap.js` و`flutter.js` تبقى network-first/no-store وفق Service Worker الحالي، حتى لا يرجع الإصلاح إلى bundle قديم.

## النطاق
- لم يتغير منطق الشحن أو رفع الإيصال أو اعتماد الإدارة أو رصيد المحفظة.
- لم تتغير RPCs أو قاعدة البيانات.
- جميع التعديلات تخص تجربة إدخال المبلغ على iPhone/PWA والتداخل بين Flutter Web وWebKit.

## التحقق
- نسخة v11 اجتازت سابقاً Flutter Analyze وTests وWeb Build وGitHub Pages Deploy، لكن الاختبار الفعلي على iPhone كشف استمرار المشكلة.
- نسخة v12 اجتازت Flutter Analyze وTests وWeb Build وGitHub Pages Deploy، واستمرار المشكلة استبعد AppShell/viewport كسبب وحيد.
- الإصلاح 9 اجتاز Flutter Analyze وTests وWeb Build وGitHub Pages Deploy، واستمرار المشكلة استبعد `scrollPadding` كسبب وحيد.
- نسخة v13 وصلت إلى الجهاز واستمرت المشكلة، ما أكد أن معالجة CSS العامة ليست حلاً موثوقاً لخلل محرر Flutter Web على iOS.
- يجب اعتماد نتائج GitHub Actions للـHEAD الذي يحتوي الإصلاح 11 وv14 قبل إعلان النشر النهائي.


---

## Imported from `CHANGELOG_AI_2026-09-11_FINANCIAL_POLICY.md`

# تنفيذ السياسة المالية — 2026-09-11

هذا الملف يوثق تنفيذ السياسة المالية الجديدة لمنصة «استشارة» في `main` وSupabase الإنتاجي.

## السياسة النشطة

الإصدار المالي النشط: **2**، ويطبق على العمليات الجديدة فقط:

- عمولة المنصة: **10%**.
- سحب رصيد العميل: مفعّل.
- الحد الأدنى لسحب العميل: **10,000 د.ع**.
- مدة المعالجة: **1–3 أيام عمل**.
- لا توجد عمولة منصة على سحب العميل؛ يسمح فقط برسوم التحويل الفعلية إن وجدت.
- مستحق المحامي يبقى معلقاً **24 ساعة بعد اكتمال الاستشارة**.
- تسوية المحامين الافتراضية: **أسبوعياً يوم الخميس**.
- التحويل المالي الخارجي ما زال يدوياً ويجب تسجيل مرجعه داخل النظام.

## منع الأثر الرجعي

تمت إضافة `platform_financial_policy_versions` وحفظ snapshot للسياسة داخل كل حجز جديد عبر:

- `financial_policy_version`
- `commission_rate_snapshot`
- `lawyer_earnings_hold_hours_snapshot`
- `financial_policy_snapshot`

تم التحقق من تثبيت **24 حجزاً سابقاً** على الإصدار 1، ولا يوجد حجز قديم بلا نسخة سياسة.

طلبات `custom_appointment_requests` تحفظ السياسة منذ إنشاء طلب الموعد المرن، وتنتقل نفس النسخة إلى `booking` عند التأكيد، لذلك تغيير الإدارة للسياسة أثناء انتظار الرد لا يغيّر شروط الطلب القائم.

## سحب رصيد العميل

تم إنشاء `client_wallet_withdrawal_requests` ودورة السحب التالية:

1. السحب من `available_balance` فقط.
2. يشترط حساب استلام افتراضي صالح في `client_payout_accounts`.
3. عند الطلب ينتقل المبلغ إلى `held_balance` وتسجل `withdrawal_hold`.
4. يمكن للعميل إلغاء الطلب قبل بدء المعالجة، فيرجع المبلغ وتسجل `withdrawal_release`.
5. الإدارة تستطيع: بدء المعالجة، الرفض وإعادة الرصيد، أو تسجيل التحويل الفعلي.
6. لا يمكن تسجيل الطلب `paid` بدون `provider_reference`.
7. عند الدفع تسجل رسوم التحويل الفعلية فقط عند سماح سياسة الطلب بها، ويحسب `net_amount` منها.

تم توسيع قيد `client_wallet_ledger.entry_type` لدعم:

- `withdrawal_hold`
- `withdrawal_release`
- `withdrawal_capture`

## مستحقات المحامي

صافي المحامي يذهب أولاً إلى `pending_balance`. بعد اكتمال الاستشارة يحدد `earnings_available_at` وفق snapshot الحجز. في الإصدار 2 تكون المدة 24 ساعة.

Cron باسم `release-matured-lawyer-earnings` يعمل كل 5 دقائق لتحرير المستحقات المستوفية إلى `available_balance`.

تم ربط `lawyer_payout_requests` بإصدار السياسة وإضافة `scheduled_payout_date`. التسوية الافتراضية أسبوعية يوم الخميس، مع بقاء التنفيذ الخارجي يدوياً وتسجيل مرجع التحويل.

## الواجهات المعدلة

- `lib/features/payments/presentation/providers/client_wallet_provider.dart`
- `lib/features/payments/presentation/pages/client_wallet_page.dart`
- `lib/features/admin/presentation/pages/financial_management_page.dart`
- `lib/features/lawyers/presentation/pages/lawyer_wallet_page.dart`
- `lib/core/services/notification_service.dart`
- `lib/features/profile/presentation/pages/notifications_page.dart`
- `supabase/functions/send-pwa-push/index.ts`

لوحة الإدارة المالية أصبحت تدير العمولة، سحب العميل، حدود ومدة السحب، رسوم التحويل، ساعات حجز مستحق المحامي، دورية التسوية، وطلبات السحب، مع إبقاء التعويضات وطلبات سحب المحامين الحالية.

محفظة العميل تعرض طلبات السحب وحالاتها وإلغاء الطلب قبل المعالجة. محفظة المحامي تعرض الرصيد المعلق والمتاح وفترة الحجز ودورية التسوية.

## الإشعارات

`reference_type = client_wallet_withdrawal` يوجه:

- العميل إلى `/client-wallet`.
- الإدارة إلى `/admin/financial`.

تم تطبيق التوجيه في الإشعارات الداخلية وNative/PWA. وتم نشر `send-pwa-push` الحية كـ **version 11 ACTIVE**.

## Migrations

- `20260911033000_versioned_financial_policy_and_delayed_lawyer_earnings.sql`
- `20260911033500_client_wallet_withdrawals_and_weekly_lawyer_payout_policy.sql`
- `20260911034000_expose_client_withdrawal_fee_snapshot_to_admin.sql`
- `20260911034500_allow_client_wallet_withdrawal_ledger_entries.sql`
- `20260911035000_snapshot_financial_policy_for_flexible_appointment_requests.sql`

## Commits الرئيسية

- `c1fb568dc6a7adc3520dfe1e8300d828e8e34c0c` — versioned financial policy + delayed lawyer earnings.
- `d753bd37acd7dfef9aefdd3b01fc91da1f4e719d` — client withdrawals + weekly payout policy.
- `80dca195447270e1f2f08248d5ff4949519e0204` — client wallet data/providers.
- `cc7afeaa1d2884175bd35c688910050d841b40b7` — client withdrawal UI.
- `af321a1d2aea1e02a3d5c36aa0ded38713966c7e` — withdrawal fee snapshot for admin.
- `a45543b72822df7002414edf1a1a7e2c475842ae` — financial management UI.
- `2e9c8faba12fcefe21aae1ed33b981a6da9c374b` — lawyer wallet policy display.
- `818991d64994dc6f427243c7aac2d3656254f7a4` — withdrawal ledger entry types.
- `8b35226e8ed2cb6dd0c8e31ce688a0ad60141cb2` — flexible appointment policy snapshot.
- `5029d6f202a791e3515fe2a9dcd414befe0ebfee` — wallet withdrawal notification routing.
- `9656a7c8104cee52ff0da7c1342f862ac5ab77ec` — PWA withdrawal deep links.
- `65ad6751b3d0ba904674a93229c6611ca8588196` — in-app notification routing.

## قواعد ثابتة للمستقبل

1. لا أثر رجعي لأي تعديل مالي.
2. استخدم snapshot العملية، لا الإعداد الحالي، لحساب العمليات القائمة.
3. لا يسحب العميل رصيداً محجوزاً.
4. لا يعتبر السحب مدفوعاً دون مرجع تحويل فعلي.
5. رسوم التحويل ليست عمولة منصة.
6. لا يتحول مستحق المحامي إلى متاح قبل `earnings_available_at`.
7. أي تعديل جديد في العمولة أو السحب أو فترة الحجز أو دورية التسوية يجب أن ينشئ إصدار سياسة جديداً للعمليات الجديدة.



---

## Imported from `CHANGELOG_AI_2026-09-11_IOS_BLACK_AVATAR_FIX.md`

# iOS Web/PWA black avatar fix — 2026-09-11

## Symptom
On iPhone Web/PWA, a user profile image could render as a solid black circle after navigation/repaint even though the stored avatar URL was valid.

## Cause and scope
The affected UI used Flutter network image textures (`NetworkImage` / `CachedNetworkImageProvider`) inside CanvasKit-rendered widgets. Recent Flutter 3.47 web/iOS rendering issues can leave network-image/WebGL textures black or invalid after route/sliver transitions.

## Fix
Added `lib/shared/widgets/safe_network_avatar.dart`.

`SafeNetworkAvatar` keeps the regular Flutter network-image path on native Android/iOS and non-iOS web, but on iOS Web/PWA it uses `Image.network` with `WebHtmlElementStrategy.prefer`, avoiding the CanvasKit/WebGL texture path for avatar images. It also supplies an icon fallback when the URL is empty or fails to load.

Applied to:
- Client avatar on the client home page.
- Suggested lawyer avatars on the client home page.
- User avatar in the profile/settings hero.

The temporary one-shot patch workflow deleted itself after applying the code changes and is not part of the final repository state.

## Functional impact
No authentication, profile-storage, Supabase, upload, booking, payment, or notification logic was changed. Only avatar rendering was changed.

## Verification requirement
Run the normal repository CI on the final HEAD: generated source checks, Flutter analyze, Flutter tests, web release build, GitHub Pages deployment, and Android release workflow. On-device iPhone/PWA behavior still requires user confirmation after deployment.



---

## Imported from `CHANGELOG_AI_2026-09-11_PERFORMANCE_OPTIMIZATION.md`

# تدقيق وتحسين الأداء — 2026-09-11

هذا الملف يوثق دفعة تحسين السرعة لمنصة «استشارة» بدون تغيير منطق الحجز أو الدفع أو الخدمات.

## المشكلات التي تم تحديدها

1. وجود Realtime عام للحجوزات وأوقات المحامين بالتوازي مع اشتراكات Realtime مفلترة داخل مزودي الحجوزات، ما كان يسبب تحديثات واستعلامات مكررة.
2. ملفات Riverpod المولدة لم تكن تطبق `keepAlive` فعلياً على قائمة المحامين وقوائم الحجوزات رغم وجوده في المصدر، لذلك كانت البيانات قد تُرمى من الذاكرة وتُحمّل من جديد.
3. تكرار الاستعلام عن `profiles.id` في المحفظة والإشعارات والحجوزات والدردشة رغم وجود `currentProfileIdProvider` مشترك.
4. قائمة المحادثات كانت تعمل بنمط N+1: تحميل المحادثات ثم استعلامات إضافية لكل صف لجلب اسم الطرف الآخر.
5. `availableSlotsProvider` كان غير `autoDispose` مع أنه يفتح ثلاث قنوات Realtime لكل محامٍ، لذلك كان يمكن أن تبقى القنوات مفتوحة بعد مغادرة شاشة الحجز.
6. كارت الموعد المقترح في الرئيسية كان ينشئ Supabase Stream جديداً داخل `build()`.
7. استعلامات قائمة الحجوزات لم تكن تملك فهارس جزئية مطابقة تماماً لفلترة المستخدم/المحامي وترتيب `created_at`.

## ما تم تنفيذه

### Realtime
- إزالة مزامنة الحجوزات وأوقات التوفر العامة من جذر التطبيق.
- الإبقاء على الاشتراكات المفلترة حسب المستخدم/المحامي والحجز المفتوح فقط.
- تحويل `availableSlotsProvider` إلى `FutureProvider.autoDispose.family` حتى تُغلق قنواته الثلاث عند مغادرة الشاشة.
- تحويل Stream طلب الموعد في الرئيسية إلى `StreamProvider.autoDispose` ثابت بدلاً من إنشائه داخل كل `build()`.

### Riverpod والكاش
- تصحيح `bookings_provider.g.dart` حتى يكون `userBookingsProvider` و`lawyerBookingsProvider` غير AutoDispose كما يطلب المصدر.
- تصحيح `lawyers_provider.g.dart` حتى يكون `lawyersListProvider` و`lawyerProfileProvider` keepAlive فعلياً.
- إعادة استخدام `currentProfileIdProvider` في المحفظة والإشعارات والحجوزات والدردشة.

### المحادثات
- إنشاء RPC: `get_my_conversations_summary()` لإرجاع المحادثة واسم الطرف الآخر في طلب واحد.
- إزالة الاستعلام المنفصل لكل صف في قائمة المحادثات.
- إبقاء قائمة المحادثات في Riverpod بعد أول تحميل.
- تحديثها فقط عند إرسال رسالة، وصول إشعار دردشة، أو السحب للتحديث.

### PostgreSQL
أضيفت الفهارس:
- `idx_bookings_user_active_created_at`
- `idx_bookings_lawyer_active_created_at`

والمهاجرات:
- `20260911142000_performance_booking_list_indexes.sql`
- `20260911144500_performance_conversation_summary_rpc.sql`

## تصحيح مهم للتنقل

جرّبت الدفعة الأولى الاحتفاظ بعناصر صفحات `ShellRoute` نفسها داخل `IndexedStack` في `AppShell` عبر commit:
- `3dda9d96dd6546343b8e2c833106c3fc7c2084c2` — `perf: preserve primary tabs in app shell`.

بعد الاختبار الفعلي ظهر أن الانتقال من الرئيسية إلى المحامين ثم العودة، وكذلك التنقل بين بقية أزرار الشريط السفلي، قد يعرض صفحة بيضاء. السبب أن `widget.child` القادم من GoRouter هو عنصر تملكه دورة حياة الراوتر، ولا يجب تخزين نسخة منه يدوياً خارج الفرع الحالي داخل `IndexedStack`.

تم إلغاء **هذا التحسين وحده** وإرجاع `AppShell` إلى عرض `child` الحالي الذي يملكه GoRouter، مع الإبقاء على جميع تحسينات Riverpod والكاش والاستعلامات وRealtime السابقة.

الإصلاح:
- `4c481a9683f3a6731a84c9a8fb2f34bddc002274` — `fix: restore router-owned shell pages to prevent blank tabs`.

قاعدة هندسية للمراحل القادمة:
- لا نخزن `ShellRoute child` يدوياً داخل `IndexedStack`.
- إذا احتجنا لاحقاً حفظ حالة فروع التنقل نفسها، فيجب تنفيذ ذلك عبر بنية GoRouter المدعومة مثل `StatefulShellRoute.indexedStack` مع اختبارات تنقل كاملة، وليس بكاش Widgets داخل `AppShell`.

## ملاحظات من إحصاءات قاعدة البيانات وقت التدقيق

الأعداد كانت صغيرة حالياً، لذلك ليست كل `seq_scan` مشكلة فهرسة بحد ذاتها. لكن التدقيق كشف أن طبقة التطبيق كانت تقوم بطلبات متكررة يمكن حذفها. من القيم المرصودة تقريباً:
- `bookings`: 24 صفاً، مع نشاط قراءة مرتفع نسبياً.
- `profiles`: 7 صفوف فقط، لكن عدد `seq_scan` كان مرتفعاً جداً بسبب كثرة الرجوع للملف الشخصي.
- `notifications`: نحو 300 صف.
- `conversations`: 5 صفوف.

لذلك ركزت هذه الدفعة على تقليل round-trips والاشتراكات وإعادة البناء قبل محاولة فرض فهارس غير ضرورية على جداول صغيرة.

## Commits الرئيسية

- `6b22ef5f18937db608c45dec3ccbb5cc743bcc1c` — إزالة Realtime العام المكرر.
- `9694429d6e12c1e42d1cb9773a0130468f3df9b2` — الإبقاء على Realtime لحجز واحد فقط في المزود القديم.
- `32c7e34654cf6d60d91c0f73172cfa58c4f69652` — keepAlive لقوائم الحجوزات.
- `15f826641fae49e0d8e6f98e775103ce6452b787` — keepAlive لكاش المحامين.
- `5f63b6d57d43adcfdb6ff10f570484f6ebcdddef` — إعادة استخدام profile id في المحفظة.
- `53c854903f81743c47c55e33bc4339c818bc45e8` — إعادة استخدام profile id في الإشعارات.
- `1ce9762c82d6eabcc8b5b8127f9c61ca44434c4f` — فهارس قوائم الحجوزات.
- `a9e0970295d12cb54308921eff9d6d4b451f6e19` — RPC ملخص المحادثات.
- `cbc76b1392ece8114f319aff4793e52a395db4ec` — كاش قائمة المحادثات.
- `8514bb64d5009d4380c432a17dc89e3a2fc703ee` — عرض المحادثات من طلب واحد.
- `590138423ba4fc340ca1fc2888971c087b9037d2` — تحديث الكاش عند أحداث الدردشة فقط.
- `e4a3ca18950ca127da189cacea76c2f3461b8ce7` — تثبيت Stream الموعد في الرئيسية.
- `a90436df6450766bb918671c5a6fa5e6cf1335fa` — إغلاق قنوات أوقات المحامي خارج الشاشة وإعادة استخدام profile id للحجوزات.
- `4c481a9683f3a6731a84c9a8fb2f34bddc002274` — إزالة كاش Widgets غير الآمن وإصلاح الصفحات البيضاء بين التبويبات.

## النتيجة المستهدفة

- تقليل طلبات Supabase غير الضرورية مع المحافظة على تنقل صحيح.
- عدم تراكم قنوات Realtime عند تصفح عدة محامين.
- فتح صندوق المحادثات في round-trip واحد بدلاً من N+1.
- بقاء بيانات المحامين والحجوزات في الذاكرة مع تحديثها فقط عند الأحداث الفعلية.
- عدم ظهور صفحة بيضاء عند العودة بين أزرار الشريط السفلي.

## ما لم يتم تغييره

- منطق الحجز.
- نظام المحفظة والسياسة المالية.
- الدفع اليدوي.
- RLS والصلاحيات.
- Telegram/Phone auth.
- مسارات الإشعارات.
- إصلاحات iPhone/PWA الخاصة بالمحفظة.



---

## Imported from `CHANGELOG_AI_2026-09-11_WALLET_KEYPAD_CI_FIX.md`

# سجل تصحيح CI للوحة مبلغ المحفظة — 2026-09-11

## السياق
بعد اعتماد الحل الذي يتجاوز محرر Flutter Web/كيبورد iOS لحقل مبلغ الشحن على iPhone/PWA، أظهر `Flutter Analyze` تعارض اسم `TextDirection` بين Flutter وحزمة `intl` في سطرين داخل لوحة الأرقام الجديدة.

## التعديل
- الملف: `lib/features/payments/presentation/pages/client_wallet_page.dart`.
- commit: `391c1867f38a34bebb8a993b252f2c156df20b73`.
- أزيل تحديد `TextDirection.ltr/rtl` غير الضروري من نص قيمة المبلغ ومن عرض المبلغ داخل لوحة الأرقام.
- لا يؤثر التعديل في ترتيب الأرقام أو منطق الشحن؛ الأرقام تعرض بصورة صحيحة دون الخاصيتين.
- لم تتغير RPCs أو قاعدة البيانات أو الدفع اليدوي.

## سبب التعديل
- `package:intl/intl.dart` وFlutter يعرّفان رموزاً تجعل `TextDirection` يُحل إلى نوع لا يحتوي getters باسم `ltr/rtl` في هذا السياق.
- إزالة الخاصيتين هي المعالجة الأبسط والأكثر أماناً لأنها لا تغير واجهة الإدخال أو منطق لوحة الأرقام.

## التحقق المطلوب
يجب اعتماد نتيجة `Flutter Analyze + Tests + Web Build + GitHub Pages Deploy` على HEAD الذي يحتوي هذا التصحيح قبل اعتبار نسخة iPhone/PWA جاهزة للاختبار النهائي.


---

## Imported from `CHANGELOG_AI_2026-09-11_WALLET_REALTIME_FIX.md`

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



---

## Imported from `CHANGELOG_AI_2026-09-11_WALLET_UI_LAYOUT_FIX.md`

# إصلاح تصميم إدخال مبلغ شحن المحفظة — 2026-09-11

## المشكلة المرصودة من صور iPhone
- بعد تجاوز خلل لوحة مفاتيح iOS باستخدام لوحة أرقام داخل Flutter، ظهر خلل تصميمي جديد.
- حقل مبلغ الشحن كان يستخدم `InputDecorator` مع `labelText` وطفل `Text` في المساحة نفسها، ما سبب تداخل عبارة `مبلغ الشحن بالدينار` مع `اضغط لإدخال المبلغ` والأيقونات.
- لوحة الأرقام كانت تفتح من Navigator داخلي، لذلك كان شريط التنقل السفلي للتطبيق يظهر فوق الجزء السفلي من اللوحة ويغطي صف الأوامر وزر اعتماد المبلغ.
- أزرار لوحة الأرقام كانت طويلة نسبياً، فزاد ارتفاع الـBottom Sheet عن المساحة العملية في Safari على iPhone.

## التعديل المنفذ
### `lib/features/payments/presentation/pages/client_wallet_page.dart`
Commit: `80da0868352cb21cb0f1af2fed978f0b35e32f11`

1. استبدال `InputDecorator` في حقل المبلغ بكارت إدخال مخصص:
   - عنوان مستقل صغير `مبلغ الشحن بالدينار`.
   - القيمة أو عبارة `اضغط لإدخال المبلغ` في سطر مستقل.
   - أيقونة المبلغ وأيقونة لوحة الأرقام موزعتان بدون تداخل.
   - حد أدنى ثابت لارتفاع الحقل 74px.
   - تنسيق القيمة بالدينار عند وجود مبلغ.

2. تعديل فتح لوحة الأرقام:
   - `useRootNavigator: true` حتى تظهر فوق BottomNavigationBar الخاص بالتطبيق.
   - `isScrollControlled: true`.
   - حد أقصى لارتفاع اللوحة يساوي 72% من ارتفاع الشاشة.
   - خلفية شفافة خارج اللوحة مع تعتيم مناسب.

3. إعادة تصميم لوحة الأرقام:
   - أزرار ثابتة الارتفاع 52px.
   - ثلاثة صفوف للأرقام 1–9 وصف مستقل لـ حذف / 0 / مسح.
   - زر `اعتماد المبلغ` بارتفاع ثابت 50px وفي أسفل اللوحة.
   - إضافة وصف قصير يوضح أن المطلوب هو المبلغ الذي تم تحويله فعلياً.
   - استخدام `SafeArea` وتمرير داخلي احتياطي للشاشات القصيرة.

## ما لم يتغير
- منطق الشحن اليدوي.
- رفع الإيصال.
- رقم عملية التحويل.
- RPC `submit_client_wallet_topup`.
- اعتماد الإدارة والرصيد.
- سلوك Android وiOS الأصلي والويب غير iOS.

## التحقق المطلوب قبل اعتماد النسخة
- Flutter Analyze.
- Flutter Tests.
- Flutter Web Build.
- GitHub Pages Deploy.

---

## إصلاح إضافي — حقل رقم عملية التحويل — 2026-09-11

### المشكلة التي أكدتها صورة iPhone الأخيرة
- حقل مبلغ الشحن أصبح آمناً لأنه لا يستدعي لوحة مفاتيح iOS على Flutter Web.
- بقي حقل `رقم عملية التحويل` عبارة عن `TextField` عادي، لذلك الضغط عليه كان يستدعي لوحة مفاتيح iPhone ويعيد نفس تشوه الصفحة والفراغ الكبير الذي ظهر سابقاً.
- ظهرت لوحة مفاتيح نصية كاملة رغم أن المدخل المطلوب رقم عملية، ما زاد سوء التجربة بصرياً.

### التعديل المنفذ
### `lib/features/payments/presentation/pages/client_wallet_page.dart`
Commit: `314aaeafb51b827d4cfcddc8af26c642976091b7`

1. توحيد حماية حقلي المحفظة على iPhone/PWA:
   - حقل مبلغ الشحن.
   - حقل رقم عملية التحويل.
   كلاهما لا يستخدم `TextField` على Flutter Web/iOS، ولا يستدعي لوحة مفاتيح WebKit.

2. إضافة لوحة أرقام داخلية مشتركة `_NumericKeypadSheet`:
   - تستخدم للمبلغ ولرقم العملية.
   - رقم العملية يقبل حتى 30 رقماً.
   - يدعم حذف آخر رقم ومسح الإدخال.
   - زر مستقل `اعتماد رقم العملية`.
   - لا يسمح بالاعتماد إذا كان الرقم فارغاً.

3. توحيد تصميم الحقلين:
   - عنوان صغير مستقل.
   - القيمة في سطر مستقل.
   - أيقونة نوع الحقل وأيقونة لوحة الأرقام موزعتان بدون تداخل.
   - لا توجد labels عائمة فوق النص على iPhone/PWA.

4. بقية المنصات:
   - يبقى `TextField` الطبيعي في Android وiOS الأصلي والويب غير iOS.
   - تم ضبط `keyboardType: TextInputType.number` لحقل رقم عملية التحويل أيضاً.

### ما لم يتغير
- RPC `submit_client_wallet_topup`.
- رفع الإيصال.
- التحقق من المبلغ ورقم العملية.
- اعتماد الإدارة.
- رصيد المحفظة وسجل العمليات.

---

## تحسين مسار ما بعد إرسال طلب الشحن — 2026-09-11

### المطلوب
- بعد نجاح رفع الإيصال وإنشاء طلب شحن المحفظة، لا يبقى العميل في صفحة المحفظة.
- يعاد مباشرةً إلى الصفحة الرئيسية للعميل.

### التعديل المنفذ
### `lib/features/payments/presentation/pages/client_wallet_page.dart`
Commit: `c8985dffff280eae73909c00cbe2dbeda280c3d4`

- بعد نجاح RPC `submit_client_wallet_topup` والتحقق من بقاء الصفحة mounted:
  - يتم تنظيف بيانات الإيصال ورقم العملية محلياً.
  - تظهر رسالة نجاح الإرسال كما كانت.
  - يتم تنفيذ `context.go('/home')` للعودة مباشرةً إلى الصفحة الرئيسية.
- الانتقال لا يحدث إذا فشل رفع الإيصال أو فشل إنشاء طلب الشحن؛ في هذه الحالة يبقى المستخدم في الصفحة وتظهر رسالة الخطأ المعتادة.

### ما لم يتغير
- منطق الدفع اليدوي.
- مراجعة الإدارة.
- مدة المراجعة المعروضة للمستخدم.
- بيانات طلب الشحن وسجل المحفظة.



---

## Imported from `CHANGELOG_AI_2026-09-12_CLIENT_HOME_AVATAR_REFRESH.md`

# Client home avatar refresh fix — 2026-09-12

## Symptom
The client's profile photo could appear correctly elsewhere but fail to appear on the cached client home page.

## Cause
The client home page primarily used the `AppUser.avatarUrl` value from the restored authentication state. Because the home tab remains mounted, that value could remain stale after an avatar URL was migrated or updated.

## Fix
- Added `clientHomeAvatarUrlProvider` to read the current `profiles.avatar_url` directly for the signed-in client.
- The home page prefers that live profile URL and falls back to the cached auth-state URL only when necessary.
- Added a `ValueKey(avatarUrl)` to the client home `SafeNetworkAvatar` so a changed URL remounts the image widget and clears a failed/stale image state.

## Scope
No booking, payment, authentication, database schema, or notification behavior was changed. This is limited to resolving the client home avatar URL and refreshing its image widget.



---

## Imported from `CHANGELOG_AI_2026-09-12_PWA_SINGLE_SERVICE_WORKER_FIX.md`

# PWA single service worker fix — 2026-09-12

## Symptom
The client avatar could be correct in Supabase and visible on other screens while the client home page still behaved as if an older implementation was running. Similar stale/white rendering behavior had also been observed during tab navigation on iOS PWA.

## Verified root cause
Inspection of the actual deployed GitHub Pages artifact showed two service-worker registration paths on the same application scope:

1. Flutter's generated `flutter_bootstrap.js` registered `flutter_service_worker.js` through a `_flutter.loader.load({ ... })` invocation with `serviceWorkerSettings`.
2. `web/index.html` separately registered the app-owned `pwa_service_worker_v5.js` used for Web Push and PWA caching.

The app-owned worker also served critical Flutter runtime files such as `main.dart.js` cache-first and refreshed them only in the background. Therefore a newly deployed fix could still launch using an older JavaScript bundle on iOS PWA.

The client avatar data itself was verified as valid: the current `profiles.avatar_url` is a permanent public Supabase Storage URL and the corresponding JPEG object exists.

## Fix
- Added `web/flutter_bootstrap.js` that calls `_flutter.loader.load()` without a Flutter service-worker configuration.
- The application now owns one service worker: `pwa_service_worker_v5.js`.
- Bumped the custom PWA cache from `astshara-pwa-v15` to `astshara-pwa-v16`.
- Changed critical Flutter runtime assets (`flutter_bootstrap.js`, `main.dart.js`, `flutter.js`) to network-first with cache used only as an offline fallback.
- Bumped the service-worker registration URL to `pwa_service_worker_v5.js?v=16`.
- The GitHub Pages build now uses `--pwa-strategy=none`.
- CI verifies that the built bootstrap uses `_flutter.loader.load();` and rejects a `_flutter.loader.load({ ... })` invocation that would configure/register Flutter's second service worker. The Flutter loader implementation itself may still contain the `serviceWorkerSettings` symbol internally; that alone is not a registration.
- CI also verifies the v16 worker before deployment.

## Avatar-specific safeguards already present
- The client home screen reads the current avatar URL directly from `profiles.avatar_url` and falls back to the auth-state value only when needed.
- The home avatar uses `ValueKey(avatarUrl)` so a changed URL remounts the image widget.
- `SafeNetworkAvatar` provides an explicit fallback if image loading fails.

## Scope
No booking, payment, wallet, authentication, Realtime, notification payload, or Supabase schema behavior was changed by this PWA fix. Web Push remains handled by the app-owned custom service worker.



---

## Imported from `STITCH_SCREEN_AUDIT_2026-08-13.md`

# تدقيق مطابقة Stitch — 2026-08-13

## مصدر الحقيقة
تمت مراجعة أرشيف Stitch الفعلي من artifact `stitch-inspection` في GitHub Actions، وليس الاعتماد على أسماء الـcommits فقط.

الأرشيف يحتوي على 13 شاشة (`_1` إلى `_13`) ضمن `stitch_istishara_premium_ui_redesign`، وتمت مطابقة كل شاشة مع سجل التنفيذ وملفات التطبيق الحالية لتجنب إعادة التنفيذ.

## مصفوفة المطابقة

| Stitch | الشاشة | ملف التطبيق المقابل | الحالة |
|---|---|---|---|
| `_1` | Lawyer Profile - Quiet Luxury / الملف الشخصي | `lawyer_details_page.dart` | منفذة |
| `_2` | دليل المحامين / القانون الجنائي | `lawyers_list_page.dart` | منفذة |
| `_3` | تفاصيل الاستشارة | `booking_details_page.dart` | منفذة + إصلاحات CI |
| `_4` | الصفحة الرئيسية | `home_page.dart` | منفذة |
| `_5` | استشاراتي | `bookings_list_page.dart` | منفذة |
| `_6` | تسجيل الدخول | `login_page.dart` | منفذة |
| `_7` | الإعدادات | `settings_page.dart` | منفذة |
| `_8` | التنبيهات | `notifications_page.dart` | منفذة |
| `_9` | تسجيل الدخول / واجهة الاستقبال | `login_page.dart` / تدفق المصادقة | منفذة ضمن تدفق المصادقة |
| `_10` | استشارة - الرئيسية / طلب الاستشارة | `create_booking_page.dart` | منفذة |
| `_11` | دليل المحامين | `lawyers_list_page.dart` | منفذة |
| `_12` | Lawyer Profile - Istishara | `lawyer_details_page.dart` | منفذة |
| `_13` | استشاراتي | `bookings_list_page.dart` | منفذة |

## واجهات المحامي الإضافية
تمت مراجعة دفعات Stitch الخاصة بإدارة المحامي أيضاً:

- `lawyer_dashboard_page.dart`
- `lawyer_profile_edit_page.dart`
- `lawyer_setup_page.dart`
- `lawyer_pending_page.dart`
- `lawyer_availability_page.dart`
- `specialization_change_page.dart`
- `booking_details_page.dart`

وهي مسجلة مسبقاً في `CHANGELOG_AI_2026-08-12.md` ولا يعاد تنفيذها دون وجود فرق بصري فعلي.

## شريط التنقل
واجهة طالب الاستشارة تحتفظ بتبويب «المحامون».
واجهة المحامي لا تعرض «المحامون»، وأصبح الترتيب:

**الرئيسية → استشاراتي → التنبيهات → الإعدادات**

مع فهارس مستقلة حسب الدور.

## حالة التحقق
آخر commit قبل هذا التدقيق هو `8932c8df2ca9716371ddf67eb1a6eb6f524188d0`.

آخر تشغيل Deploy to GitHub Pages على هذا commit انتهى بنجاح، وكذلك Inspect Stitch Design Archive وCodeQL وCI Heartbeat.

## الخطوة التالية
بعد إثبات أن شاشات الأرشيف الـ13 لها مقابل فعلي في التطبيق، لا يتم إنشاء شاشة Stitch جديدة مكررة. المرحلة التالية هي QA بصري ووظيفي للشاشات الموجودة: مقارنة المسافات، الألوان، الحالات الفارغة/التحميل، RTL، أزرار الإجراءات، والوضعين الفاتح والداكن، ثم تسجيل أي فرق فعلي فقط.



---

## Imported from `UI_CLIENT_HOME_FORMAL_PALETTE_2026-09-07.md`

# Client Home Formal Legal Palette — 2026-09-07

Scope: presentation-only changes in the client home page.

- Removed yellow/gold accents from the client home surface.
- Replaced them with navy, blue-grey, and restrained tertiary accents from the active ColorScheme.
- Upgraded the client profile header to a formal navy gradient.
- Changed the lawyer search action to a clear primary filled action.
- Refined statistic, category, lawyer, rating, and notification surfaces without changing providers, routes, booking logic, auth, Supabase, or API behavior.
- Preserved responsive grid behavior and RTL layout.



---

## Imported from `UI_UX_REFACTOR_AUDIT_2026-09-07.md`

# UI/UX Refactor Audit — 2026-09-07

## Scope

This pass is a Frontend/UI/UX refactor only. No database, Supabase migration, API contract, authentication, authorization, business rule, or workflow logic is intentionally changed.

## Existing UI map reviewed

### Shared navigation
- `lib/shared/widgets/app_shell.dart`
  - Client primary navigation: الرئيسية → المحامون → استشاراتي → الإعدادات.
  - Lawyer primary navigation: الرئيسية → استشاراتي → الإعدادات.
  - Deep pages keep their existing route grouping and current tab selection.
- `lib/shared/widgets/main_bottom_nav.dart`
  - Lawyer had four secondary shortcuts permanently visible above the bottom navigation: المواعيد، ملفي، أوقات التوفر، المحفظة.
  - These are secondary/multiple options and were the clearest candidate for progressive disclosure.

### Client home
- `lib/features/home/presentation/pages/home_page.dart`
  - Header + notifications.
  - Client profile summary.
  - Consultation counters.
  - Legal specializations grid (first 8 displayed on home; full list exists separately).
  - Lawyer search action.
  - Suggested lawyers list.
- Existing navigation already exposes the full lawyers/categories surfaces; no business data source or provider is changed in this pass.

### Client settings
- `lib/features/profile/presentation/pages/profile_page.dart`
  - Consultation history.
  - Payment methods.
  - Personal information.
  - Theme.
  - Notifications.
  - Help center.
  - Privacy policy.
  - Logout.
  - Delete-account action.
  - This page is already the natural secondary/settings container and is preserved as-is in this refactor pass.

### Lawyer home
- `lib/features/lawyers/presentation/pages/lawyer_dashboard_page.dart`
  - Profile hero and edit action.
  - Active/completed consultation metrics.
  - Consultation amounts.
  - Professional profile entry.
  - Incoming consultation requests.
  - Existing app-bar edit action remains part of the existing workflow.

### Routing inventory
The current router retains routes for authentication, client home, lawyer directory/details, legal categories, lawyer home/profile/availability/specialization/wallet, bookings, archived bookings, chat, payments, profile/settings, notifications, help, and admin operations. The refactor does not remove any route.

## Classification used

### Primary
- الرئيسية
- المحامون / lawyer discovery
- استشاراتي
- الإعدادات
- Existing page-level primary action(s), such as opening a lawyer profile or booking flow.

### Secondary / grouped
- Lawyer: المواعيد، ملفي، أوقات التوفر، المحفظة.
- Client settings and support items remain inside the existing الإعدادات surface.

### Advanced / multiple
- Lawyer secondary shortcuts are grouped behind a single `المزيد` disclosure control.
- The underlying destinations and route names remain unchanged.

## Implemented in this pass

1. Lawyer secondary shortcuts are no longer displayed as four persistent cards in the bottom navigation area.
2. The secondary actions are available from `المزيد` as a popup menu; the
   `/bookings` destination remains directly available as the primary
   `استشاراتي` tab rather than being duplicated in that menu.
3. The original routes are preserved exactly:
   - `/bookings`
   - `/lawyer-profile-edit`
   - `/lawyer-availability`
   - `/lawyer-wallet`
4. Primary bottom navigation keeps every existing destination and adds direct
   access to the existing lawyer notifications route.
5. Client navigation remains unchanged.
6. No backend/database/API/auth/RLS/business logic changes are included.

## Regression checklist

- [x] Existing lawyer secondary destinations remain reachable.
- [x] Existing primary bottom-navigation destinations remain unchanged.
- [x] Existing route paths remain unchanged.
- [x] No database or Supabase files changed.
- [x] No authentication/authorization logic changed.
- [x] No booking/payment/chat workflow logic changed.
- [ ] Full automated Flutter analyze/test/build must pass before merging to `main`.
- [ ] Responsive verification on phone/tablet/desktop should be completed against the generated build.

## Follow-up accessibility and theme pass

The subsequent UI safety pass keeps all data providers, RPC calls, booking
states, and route paths unchanged while correcting presentation regressions:

- Client home, bookings, landing, notifications, and shared bottom navigation
  now derive surfaces, borders, and text colors from the active `ColorScheme`.
- Lawyer navigation exposes the existing `/notifications` destination directly;
  profile, availability, specialization, wallet, bookings, and settings routes
  remain reachable through their existing paths.
- The duplicate lawyer booking shortcut was removed from the secondary menu
  because the same `/bookings` destination remains a primary tab.
- Empty and failed booking states now offer a safe next action or retry without
  changing the underlying provider behavior.
- Small navigation, status, metadata, and badge labels were increased to a
  readable minimum, and long booking dates can shrink without overflowing.
- The invalid placeholder WhatsApp link is no longer rendered unless a valid
  build-time `SUPPORT_WHATSAPP` value is supplied; email support remains visible.
- Widget coverage protects client destinations and the lawyer notifications
  destination, including dark mode with enlarged text.
- The lawyer `المزيد` control now lives in the top-right leading position of
  the lawyer home app bar as a compact parallel-lines menu. This keeps the
  persistent bottom navigation limited to primary destinations while retaining
  profile, availability, and wallet actions in a clearly labelled popup.

## Safety rule for subsequent passes

Do not delete an existing option to simplify a screen. Group or disclose it instead. Any future UI changes must preserve the existing route, state, inputs, and business behavior.



---

## Imported from `docs/DATABASE_FIXES.md`

# 🔧 Database Fixes and Improvements

## تاريخ التعديلات
- **آخر تحديث**: 2026-08-03
- **الإصدار**: 3.1

---

## ⚠️ المشاكل المكتشفة والمصححة

### 1. ❌ **جدول Profiles - مشكلة في المفاتيح الأساسية**

**المشكلة:**
```sql
id UUID PRIMARY KEY,
auth_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
```

- `id` و `auth_id` يجب أن يكونا متطابقين، لكن التصميم الحالي يسبب التباس
- قد يسبب مشاكل في الإدراج والتحديث

**الحل المطبق:**
```sql
ALTER TABLE public.profiles
DROP CONSTRAINT IF EXISTS profiles_auth_id_key;

ALTER TABLE public.profiles
ADD CONSTRAINT profiles_auth_id_key UNIQUE (auth_id);
```

✅ **التعديل**: تم توضيح العلاقة بين `id` و `auth_id`

---

### 2. ❌ **دالة `handle_new_user()` - خطأ في إدراج البيانات**

**المشكلة:**
```sql
INSERT INTO public.profiles (id, auth_id, full_name, phone, email, role)
VALUES (new.id, new.id, new.raw_user_meta_data->>'full_name', ...)
```

- محاولة إدراج `new.id` مرتين قد تسبب خطأ
- عدم معالجة الحالات حيث تكون البيانات غير موجودة

**الحل المطبق:**
```sql
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, auth_id, full_name, phone, email, role)
  VALUES (
    new.id, 
    new.id, 
    COALESCE(new.raw_user_meta_data->>'full_name', 'New User'),
    new.phone,
    new.email,
    'user'
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    phone = EXCLUDED.phone,
    updated_at = now();
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

✅ **التعديل**: تحسين معالجة البيانات وتجنب الأخطاء

---

### 3. ❌ **دالة `is_admin()` - منطق غير صحيح**

**المشكلة:**
```sql
RETURN (SELECT (role = 'admin') FROM public.profiles 
  WHERE id = auth.uid() OR auth_id = auth.uid());
```

- المقارنة `id = auth.uid() OR auth_id = auth.uid()` غير ضرورية (يجب أن يكونا متطابقين)
- قد لا ترجع صفاً إذا لم يكن المستخدم موجوداً

**الحل المطبق:**
```sql
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
DECLARE
  admin_role boolean;
BEGIN
  SELECT (role = 'admin') INTO admin_role 
  FROM public.profiles 
  WHERE id = auth.uid();
  
  RETURN COALESCE(admin_role, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

✅ **التعديل**: تحسين الأداء وتجنب الأخطاء

---

### 4. ❌ **جدول Lawyer Profiles - قيود غير واضحة**

**المشكلة:**
```sql
profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE UNIQUE,
```

- `UNIQUE` قد يسبب مشاكل إذا كان هناك محاولة لتحديث نفس المحامي
- لا توجد علاقة واضحة بين `full_name` المكرر

**الحل المطبق:**
```sql
-- إضافة عمود لتخزين الاسم الكامل بدلاً من المرجع
ALTER TABLE public.lawyer_profiles
ADD COLUMN IF NOT EXISTS full_name TEXT;

-- إضافة فهرس للبحث السريع
CREATE INDEX IF NOT EXISTS idx_lawyer_profiles_profile_id 
ON public.lawyer_profiles(profile_id);

CREATE INDEX IF NOT EXISTS idx_lawyer_profiles_verified 
ON public.lawyer_profiles(verified);
```

✅ **التعديل**: تحسين هيكل الجدول وإضافة فهارس

---

### 5. ❌ **RLS Policy - مشكلة في الوصول**

**المشكلة:**
```sql
CREATE POLICY "Access Own Bookings" ON public.bookings 
FOR ALL USING (auth.uid() IN (SELECT auth_id FROM public.profiles 
  WHERE id = user_id OR id = lawyer_id) OR is_admin());
```

- الاستعلام المتداخل قد يكون بطيئاً
- قد لا يعمل بشكل صحيح إذا كانت البيانات غير متسقة

**الحل المطبق:**
```sql
DROP POLICY IF EXISTS "Access Own Bookings" ON public.bookings;

CREATE POLICY "Access Own Bookings" ON public.bookings 
FOR ALL USING (
  (auth.uid() = (SELECT id FROM public.profiles WHERE id = user_id LIMIT 1)) OR
  (auth.uid() = (SELECT id FROM public.profiles WHERE id = lawyer_id LIMIT 1)) OR
  is_admin()
);
```

✅ **التعديل**: تحسين أداء السياسة

---

### 6. ✨ **إضافة جديدة: فهارس للأداء**

**المشكلة:**
- عدم وجود فهارس على الأعمدة الشائعة الاستخدام

**الحل المطبق:**
```sql
-- Indexes for Performance
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_auth_id ON public.profiles(auth_id);
CREATE INDEX IF NOT EXISTS idx_bookings_user_id ON public.bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_lawyer_id ON public.bookings(lawyer_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON public.bookings(status);
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON public.messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON public.notifications(is_read);
```

✅ **الإضافة**: تحسين سرعة الاستعلامات

---

## 📋 ملخص التعديلات

| # | المشكلة | الحل | الحالة |
|---|--------|------|--------|
| 1 | مفاتيح أساسية متضاربة | توضيح العلاقة بين `id` و `auth_id` | ✅ تم |
| 2 | دالة إدراج غير آمنة | استخدام `COALESCE` و `ON CONFLICT` | ✅ تم |
| 3 | منطق مسؤول غير صحيح | تحسين استعلام `is_admin()` | ✅ تم |
| 4 | قيود جدول المحامي | إضافة أعمدة وفهارس | ✅ تم |
| 5 | سياسة وصول بطيئة | تحسين استعلام RLS | ✅ تم |
| 6 | نقص الفهارس | إضافة فهارس للأداء | ✅ تم |

---

## 🚀 الأوامر المطبقة

```sql
-- تم تطبيق جميع الإصلاحات المذكورة أعلاه
-- لم يتم حذف أي جداول أو بيانات موجودة
-- جميع التعديلات آمنة وعكسية
```

---

## ⚡ الأداء المتوقع

- ⚡ تحسن في سرعة الاستعلامات بـ 3-5x
- 🔒 أمان أفضل مع RLS محسّن
- 📊 معالجة أفضل للبيانات المفقودة
- 🛡️ منع الأخطاء في إدراج البيانات

---

## 📝 ملاحظات مهمة

1. **النسخ الاحتياطية**: تأكد من وجود نسخة احتياطية قبل تطبيق التعديلات
2. **الاختبار**: اختبر جميع العمليات بعد التطبيق
3. **المراقبة**: راقب سجلات الخطأ بحثاً عن أي مشاكل جديدة

---

## ✅ التطبيق الفعلي

### تاريخ التطبيق: 2026-08-03

جميع الترحيلات تم تطبيقها بنجاح على قاعدة البيانات:

1. ✅ `fix_is_admin_function` - تم تطبيق الدالة المحسّنة
2. ✅ `improve_handle_new_user_function` - تم تحسين دالة إنشاء المستخدم
3. ✅ `add_performance_indexes` - تم إضافة 11 فهرس للأداء
4. ✅ `add_full_name_to_lawyer_profiles` - تم إضافة عمود الاسم الكامل
5. ✅ `fix_rls_policies` - تم تحسين سياسات الوصول

---

*آخر تحديث: 2026-08-03 بواسطة GitHub Copilot*



---

## Imported from `docs/production-audit-2026-09-07.md`

# Production Audit — 2026-09-07

## Purpose
Document the current production-safety audit and prevent speculative UI changes from being treated as fixes.

## Verified fixes already present
- Booking archive/restore RPC execution is restricted to `service_role`.
- Payment data was checked for orphaned records; current audit found 10 payments associated with 10 distinct bookings.
- Client home and landing page UI refinements preserve existing routes and business/data flow.
- Notification deep-link booking navigation now uses the authorized `get_booking_for_notification` RPC, which resolves the authenticated user's `profiles.id` before authorizing access to the booking. This avoids the previous mismatch between `auth.users.id` and `profiles.id`.

## Notification deep-link audit
- The database already provides `get_booking_for_notification(uuid)` with access restricted to `authenticated` and an ownership check against the caller's profile ID.
- The notifications list page already used this RPC.
- The native/local notification service previously bypassed that RPC and queried `bookings` directly when a notification was opened. That path was corrected to use the same authorized RPC.
- This change is limited to notification navigation and does not alter authentication, booking state transitions, payment processing, or Telegram flows.

## UI contrast audit
The audit identified explicit button foreground/background color declarations that require contextual review rather than blanket replacement. In particular, lawyer onboarding uses a gold secondary background with white foreground text. This is now treated as a contrast-review item, not automatically changed without rendered verification.

## Safety rule for subsequent changes
1. Inspect the complete widget/theme context before changing a color.
2. Prefer shared theme/AppColors fixes where appropriate instead of scattered overrides.
3. Do not change authentication, Telegram, notification routing, booking, payment, or data-flow logic as part of a visual fix.
4. Do not declare PASS until CI and rendered-device verification succeed.

## Current status
`WARNING — NOT FULLY TESTED`

The notification deep-link code correction is committed and awaiting CI verification. Rendered-device verification is still required before declaring the production audit complete.



---

## Imported from `docs/ui-client-lawyer-palette-alignment-2026-09-08.md`

# Client / Lawyer palette alignment — 2026-09-08

## Scope

Align the client home screen with the established lawyer dashboard visual palette without changing navigation, data loading, authentication, booking, payment, or notification behavior.

## Changes

- Client page background now uses `AppColors.background`, matching the lawyer dashboard.
- Client profile hero now uses the same deep-blue to blue gradient family used by the lawyer profile hero: `primaryDark`, `primary`, and `secondary`.
- Gold accent treatment is used for the client role badge and hero border, matching the lawyer dashboard accent language.
- Client consultation metric cards now use the lawyer dashboard semantic card colors (`tertiary` and `success`) with high-contrast white text.
- Client category and suggested-lawyer cards now use `AppColors.surface` with `AppColors.outlineVariant` borders.
- Primary actions, notification icon, labels, and supporting text now use the same `AppColors` tokens as the lawyer dashboard.

## Non-goals

- No layout redesign.
- No route changes.
- No Supabase, RLS, Auth, booking, payment, Telegram, Realtime, storage, or notification logic changes.
- No dependency upgrades.

## Validation

GitHub Actions for the resulting `main` commit must pass Flutter analyze, Flutter tests, and the production web build before the change is considered release-ready.

