import 'package:flutter/material.dart';

class PublicInfoPage extends StatelessWidget {
  final String title;
  final String intro;
  final List<(String, String)> sections;

  const PublicInfoPage({super.key, required this.title, required this.intro, required this.sections});

  static PublicInfoPage howItWorks() => const PublicInfoPage(
    title: 'كيف تعمل استشارة؟',
    intro: 'منصة رقمية تساعدك على الوصول إلى خدمات واستشارات قانونية من خلال مسار واضح ومنظم.',
    sections: [
      ('1. استعرض', 'تصفح المحامين والتخصصات والخدمات المتاحة في المنصة.'),
      ('2. اختر الخدمة', 'اختر المحامي أو الخدمة المناسبة ثم أدخل تفاصيل موضوعك القانوني.'),
      ('3. أرسل الطلب', 'راجع بياناتك وأرسل الطلب وفق الخيارات المتاحة في المنصة.'),
      ('4. تابع طلبك', 'تابع حالة الطلب والتواصل المرتبط به من حسابك.'),
    ],
  );

  static PublicInfoPage privacy() => const PublicInfoPage(
    title: 'الخصوصية وحماية البيانات',
    intro: 'نلتزم بالتعامل مع بيانات المستخدمين وفق الصلاحيات والسياسات المطبقة على المنصة.',
    sections: [
      ('البيانات', 'تُستخدم البيانات اللازمة لتشغيل الحساب والخدمات والامتثال لمتطلبات المنصة.'),
      ('الوصول', 'تُعرض المعلومات العامة فقط في الواجهات العامة، بينما تُحمى البيانات الخاصة بصلاحيات الوصول.'),
      ('الأمان', 'تُدار المصادقة والوصول إلى البيانات عبر البنية الأمنية المعتمدة للمنصة.'),
      ('مسؤولية المستخدم', 'يجب المحافظة على بيانات الدخول وعدم مشاركة رموز التحقق أو معلومات الحساب مع الآخرين.'),
    ],
  );

  static PublicInfoPage terms() => const PublicInfoPage(
    title: 'الشروط والأحكام',
    intro: 'باستخدام منصة استشارة، يلتزم المستخدم بالأنظمة والتعليمات المعمول بها وبسياسات المنصة.',
    sections: [
      ('الاستخدام', 'تُستخدم المنصة للأغراض القانونية المشروعة، ولا يجوز إساءة استخدام الخدمات أو الحسابات.'),
      ('المعلومات', 'يتحمل المستخدم مسؤولية صحة البيانات والمعلومات التي يقدمها عبر المنصة.'),
      ('الخدمات القانونية', 'المنصة وسيلة تقنية لتنظيم الوصول إلى المحامين والخدمات، ولا تُعد بحد ذاتها بديلاً عن العلاقة المهنية مع المحامي.'),
      ('التحديثات', 'قد تتغير الخدمات والواجهات والسياسات عند تطوير المنصة، مع مراعاة المتطلبات النظامية ذات الصلة.'),
    ],
  );

  static PublicInfoPage contact() => const PublicInfoPage(
    title: 'تواصل معنا',
    intro: 'للاستفسارات المتعلقة بالمنصة أو الحساب أو الخدمات، استخدم قنوات التواصل المعتمدة داخل المنصة.',
    sections: [
      ('دعم المستخدمين', 'يمكن للمستخدم المسجل الوصول إلى مركز المساعدة من داخل المنصة.'),
      ('المشكلات التقنية', 'عند الإبلاغ عن مشكلة، أرفق وصفاً واضحاً للخطأ والخطوات التي أدت إليه دون إرسال كلمات المرور أو رموز التحقق.'),
      ('طلبات المحامين', 'يمكن للمحامي بدء التسجيل من صفحة إنشاء الحساب ثم استكمال متطلبات المراجعة والاعتماد.'),
    ],
  );

  static PublicInfoPage faq() => const PublicInfoPage(
    title: 'الأسئلة الشائعة',
    intro: 'إجابات مختصرة عن أكثر الأسئلة شيوعاً حول استخدام منصة استشارة.',
    sections: [
      ('هل أحتاج إلى حساب؟', 'يمكنك تصفح الصفحات العامة ودليل المحامين دون تسجيل، بينما تتطلب الخدمات التي تحفظ طلباتك أو بياناتك تسجيل الدخول.'),
      ('كيف أختار المحامي؟', 'يمكنك استعراض المحامين والتخصصات المتاحة ثم فتح الملف العام للمحامي ومراجعة المعلومات المنشورة قبل بدء الطلب.'),
      ('هل المنصة تقدم رأياً قانونياً بنفسها؟', 'المنصة أداة تقنية لتنظيم الوصول إلى المحامين والخدمات القانونية؛ الرأي أو الخدمة القانونية يقدمها المحامي ضمن العلاقة المهنية.'),
      ('ماذا أفعل إذا واجهت مشكلة؟', 'استخدم مركز المساعدة من داخل حسابك، واذكر رقم الطلب إن كان متاحاً، مع تجنب إرسال كلمات المرور أو رموز التحقق.'),
      ('كيف ينضم المحامي؟', 'يبدأ المحامي بإنشاء حساب ثم يستكمل بيانات ومتطلبات المراجعة، وتبقى حالة الاعتماد خاضعة لإجراءات المنصة.'),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SelectionArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Text(intro, style: const TextStyle(fontSize: 16, height: 1.8)),
                  ),
                  const SizedBox(height: 18),
                  ...sections.map((section) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(section.$1, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          Text(section.$2, style: const TextStyle(height: 1.7)),
                        ],
                      ),
                    ),
                  )),
                  const SizedBox(height: 12),
                  Text('ملاحظة: هذه الصفحة معلومات عامة وليست بديلاً عن مراجعة النصوص والسياسات الرسمية المعتمدة.', style: TextStyle(color: scheme.onSurfaceVariant, height: 1.6)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
