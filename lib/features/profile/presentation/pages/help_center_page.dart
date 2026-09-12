import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_sizes.dart';

const _supportWhatsApp = String.fromEnvironment('SUPPORT_WHATSAPP');

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  Future<void> _launchUrl(BuildContext context, String url) async {
    final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح الرابط')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('مركز المساعدة', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSizes.p20, 8, AppSizes.p20, 36),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: dark
                      ? [scheme.primary.withValues(alpha: .28), scheme.tertiary.withValues(alpha: .20)]
                      : [scheme.primary.withValues(alpha: .16), scheme.tertiary.withValues(alpha: .10)],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: scheme.primary.withValues(alpha: dark ? .42 : .22)),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: dark ? .16 : .10),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(children: [
                Container(
                  width: 66,
                  height: 66,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [scheme.primary, scheme.tertiary],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: .22),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(Icons.support_agent_rounded, size: 35, color: scheme.onPrimary),
                ),
                const SizedBox(height: 15),
                Text('كيف يمكننا مساعدتك؟', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: scheme.onSurface)),
                const SizedBox(height: 7),
                Text('اختر الطريقة الأنسب للتواصل مع فريق استشارة.', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5)),
              ]),
            ),
            const SizedBox(height: 22),
            Text('تواصل معنا', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: scheme.onSurface)),
            const SizedBox(height: 11),
            if (_supportWhatsApp.isNotEmpty) ...[
              _ContactCard(icon: Icons.chat_rounded, title: 'تحدث مع الدعم الفني', subtitle: 'مساعدة مباشرة عبر واتساب', color: scheme.primary, onTap: () => _launchUrl(context, 'https://wa.me/${_supportWhatsApp.replaceAll(RegExp(r'[^0-9]'), '')}')),
              const SizedBox(height: 10),
            ],
            _ContactCard(icon: Icons.mail_outline_rounded, title: 'راسلنا عبر البريد', subtitle: 'support@astshara.iq', color: scheme.primary, onTap: () => _launchUrl(context, 'mailto:support@astshara.iq')),
            const SizedBox(height: 26),
            Text('الأسئلة الشائعة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: scheme.onSurface)),
            const SizedBox(height: 10),
            _FaqItem(question: 'كيف يتم توثيق حساب المحامي؟', answer: 'يتم رفع هوية النقابة والبيانات المهنية، ثم تتم مراجعتها من قبل الإدارة قبل تفعيل الحساب.', scheme: scheme),
            _FaqItem(question: 'ما هي طرق الدفع المتاحة؟', answer: 'تتوفر طرق الدفع التي يدعمها التطبيق حالياً، وتظهر لك الخيارات المتاحة عند إكمال الحجز.', scheme: scheme),
            _FaqItem(question: 'متى تظهر معلومات التواصل؟', answer: 'لا تظهر معلومات التواصل قبل تأكيد الحجز والدفع وفق حالة الحجز المعتمدة.', scheme: scheme),
            _FaqItem(question: 'ماذا أفعل إذا واجهت مشكلة في الحجز؟', answer: 'تحقق من حالة الحجز أولاً، وإذا استمرت المشكلة تواصل مع الدعم الفني من الخيارات أعلاه.', scheme: scheme),
          ]),
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ContactCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: scheme.outlineVariant.withValues(alpha: .8))),
          child: Row(children: [
            Container(width: 50, height: 50, alignment: Alignment.center, decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: color, size: 25)),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurface)), const SizedBox(height: 4), Text(subtitle, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant))])),
            Icon(Icons.arrow_forward_ios_rounded, size: 15, color: scheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String question;
  final String answer;
  final ColorScheme scheme;
  const _FaqItem({required this.question, required this.answer, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(color: scheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(18), border: Border.all(color: scheme.outlineVariant.withValues(alpha: .75))),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: scheme.primary,
          collapsedIconColor: scheme.onSurfaceVariant,
          title: Text(question, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: scheme.onSurface)),
          children: [Text(answer, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, height: 1.6))],
        ),
      ),
    );
  }
}
