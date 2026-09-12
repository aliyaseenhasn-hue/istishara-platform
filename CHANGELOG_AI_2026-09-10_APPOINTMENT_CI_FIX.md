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
