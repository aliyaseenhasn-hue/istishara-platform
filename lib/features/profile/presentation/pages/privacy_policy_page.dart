import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('سياسة الخصوصية'),
        leading: IconButton(
          tooltip: 'رجوع',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _section(context, 'مقدمة', 'نحترم خصوصية مستخدمي منصة استشارة ونستخدم البيانات بالقدر اللازم لتقديم خدمات التسجيل، الاستشارات، الحجوزات، الدفع والتواصل وحماية المنصة.'),
          _section(context, 'البيانات التي قد نجمعها', 'قد تشمل البيانات الاسم ورقم الهاتف والبريد الإلكتروني عند استخدامه ورقم واتساب والمدينة وبيانات الحساب وصورة الملف الشخصي وبيانات الحجز والرسائل والمستندات التي يختار المستخدم إرفاقها، إضافة إلى بيانات تقنية لازمة للإشعارات وتشغيل التطبيق.'),
          _section(context, 'بيانات المحامين', 'قد تتضمن بيانات الملف المهني والتخصص والخبرة وبيانات الترخيص أو النقابة ومستندات التحقق التي يرفعها المحامي للمراجعة. لا تُعامل مستندات التحقق كمحتوى عام.'),
          _section(context, 'استخدام البيانات', 'تستخدم البيانات لإنشاء الحساب وإدارته، تنظيم الاستشارات والمواعيد، إدارة المدفوعات والاستحقاقات، تنفيذ التواصل المرتبط بالخدمة، إرسال الإشعارات، دعم المستخدمين ومنع إساءة استخدام المنصة.'),
          _section(context, 'مشاركة البيانات', 'تظهر فقط المعلومات التي تسمح بها حالة الحجز والصلاحيات المعتمدة. وقد تُعالج البيانات اللازمة لدى مزودي الخدمات التقنية الذين تعتمد عليهم المنصة مثل خدمات الاستضافة والمصادقة والإشعارات وتسجيل الدخول والدفع عند استخدامه.'),
          _section(context, 'المستندات والملفات', 'تُحمى المستندات الخاصة وصور التحقق والإيصالات بصلاحيات الوصول المناسبة لطبيعتها. ينبغي عدم رفع معلومات غير لازمة لتقديم الخدمة.'),
          _section(context, 'الأمان', 'نستخدم ضوابط تقنية وصلاحيات وصول لحماية بيانات الحسابات. ومع ذلك، لا توجد وسيلة نقل أو تخزين إلكترونية يمكن ضمان أمانها بشكل مطلق.'),
          _section(context, 'حذف الحساب والبيانات', 'يمكن للمستخدم طلب حذف حسابه من داخل التطبيق. عند اكتمال الحذف تُزال بيانات التعريف المباشر وهوية تسجيل الدخول والملفات الشخصية التي لا يلزم الاحتفاظ بها. قد تبقى سجلات محدودة مرتبطة بالحجوزات أو المدفوعات أو النزاعات أو متطلبات أمنية وقانونية مشروعة، وتُفصل عن الملف العام كلما أمكن.'),
          _section(context, 'الاستشارات النشطة', 'قد يلزم إنهاء أو إلغاء الاستشارات النشطة قبل إكمال حذف الحساب حتى لا يؤدي الحذف إلى الإخلال بخدمة جارية أو بحقوق الأطراف المرتبطة بها.'),
          _section(context, 'التحديثات', 'قد يتم تحديث هذه السياسة عند إضافة وظائف أو مزودي خدمات أو متطلبات تنظيمية جديدة. تنشر النسخة المحدثة مع تاريخ سريان واضح.'),
          const SizedBox(height: 12),
          Text('آخر تحديث: 12 سبتمبر 2026. النسخة الكاملة من سياسة الخصوصية منشورة في الموقع الرسمي لمنصة استشارة.', textAlign: TextAlign.right, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12, height: 1.6)),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, String body) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(title, textAlign: TextAlign.right, style: TextStyle(color: scheme.primary, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          Text(body, textAlign: TextAlign.right, style: TextStyle(color: scheme.onSurface, fontSize: 13, height: 1.65)),
        ],
      ),
    );
  }
}
