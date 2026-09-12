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
