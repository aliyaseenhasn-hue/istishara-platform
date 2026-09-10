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
- صورة الاختبار اللاحقة أظهرت أن المشكلة تحدث أيضاً عند حقل `رقم عملية التحويل` وأن Safari يعرض الصفحة مكبرة أثناء التركيز، ما أثبت أن المشكلة لم تعد مرتبطة بحقل بعينه أو بقيمة `scrollPadding` وحدها.
- تم التحقق من مشكلة Flutter Web الحالية الخاصة بـ iOS/WebKit: عنصر الإدخال الدلالي الذي ينشئه Flutter قد لا يحدد `font-size`، فيرث حجماً أقل من 16px، وWebKit يقوم عندها بتكبير الصفحة تلقائياً عند التركيز.
- أثناء مراجعة `web/index.html` الحالي وُجد أن حماية 16px السابقة لم تعد موجودة بعد تعديلات إزالة `visualViewport`، لذلك عادت المشكلة.

### الإصلاح 10.1 — حماية CSS مباشرة لعناصر Flutter الدلالية
- الملف: `web/index.html`.
- commit: `8dbe2202dd0c5886f0179d9a58c98eae920352ab`.
- أضيف `font-size: 16px !important` و`-webkit-text-size-adjust: 100%` إلى:
  - `input` و`textarea` و`contenteditable` العامة.
  - `flt-semantics-host` وعناصر الإدخال التابعة له.
  - `flt-semantics` وعناصر الإدخال التابعة له.
  - `flt-text-editing-host` وعناصر الإدخال التابعة له.
- لا يتم استخدام `user-scalable=no` أو `maximum-scale=1`، لذلك لا يتم تعطيل تكبير الصفحة الاختياري للمستخدم.

### الإصلاح 10.2 — حماية ديناميكية لعناصر الإدخال التي ينشئها Flutter لاحقاً
- لأن Flutter Web ينشئ عناصر الإدخال الدلالية/الأصلية بشكل lazy عند التركيز، أضيف `MutationObserver` في `web/index.html`.
- المراقب يطبق حد 16px مباشرة على أي `input` أو `textarea` أو `contenteditable` ينشأ لاحقاً.
- هذه طبقة دفاع إضافية فوق CSS لمنع فقدان الحماية بسبب طريقة إنشاء Flutter لعناصر الإدخال.

### الإصلاح 10.3 — تطبيق الحماية نفسها على fallback وتحديث PWA
- الملف: `web/404.html`.
- commit: `38eeafb2f7827f0d8c8fc71d7bcae2c178abfe6f`.
- أضيفت حماية CSS وMutationObserver نفسها حتى تعمل الروابط المباشرة/fallback بنفس السلوك.
- الملف: `web/pwa_service_worker_v5.js`.
- commit: `e79a6d086a51fb801938720c177cd29035ca9364`.
- رُفع Cache إلى `astshara-pwa-v13`، وتم تحديث تسجيل العامل في `index.html` و`404.html` إلى `?v=13` لإزالة أي shell قديم لا يحتوي حماية الـAuto-Zoom.

## النطاق
- لم يتغير منطق الشحن أو رفع الإيصال أو اعتماد الإدارة أو رصيد المحفظة.
- لم تتغير RPCs أو قاعدة البيانات.
- جميع التعديلات تخص تجربة لوحة المفاتيح والتخطيط على iPhone/PWA وSafari/WebKit.

## التحقق
- نسخة v11 اجتازت سابقاً Flutter Analyze وTests وWeb Build وGitHub Pages Deploy، لكن الاختبار الفعلي على iPhone كشف استمرار over-scroll.
- نسخة v12 التي أخرجت المحفظة من AppShell وأزالت إدارة viewport اليدوية اجتازت Flutter Analyze وTests وWeb Build وGitHub Pages Deploy.
- الإصلاح 9 اجتاز Flutter Analyze وTests وWeb Build وGitHub Pages Deploy، لكن الصورة الفعلية على iPhone كشفت استمرار Auto-Zoom من طبقة Flutter semantics/WebKit.
- يجب اعتماد GitHub Actions ونشر نسخة v13 التي تحتوي الإصلاح 10 قبل الاختبار النهائي التالي على iPhone.
