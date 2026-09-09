import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../lawyers/domain/entities/lawyer_profile.dart';
import '../../../lawyers/presentation/providers/lawyers_provider.dart';

const _navy = Color(0xFF18304F);
const _gold = Color(0xFFC9A84C);
const _goldSoft = Color(0xFFE8D9AD);

class LandingPage extends ConsumerWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final lawyersAsync = ref.watch(lawyersListProvider);
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: scheme.surface,
              surfaceTintColor: scheme.surface,
              elevation: 0,
              titleSpacing: 20,
              title: Text(
                'استشارة',
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 21,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => context.push('/login'),
                  child: Text(
                    'تسجيل الدخول',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: 14,
                    right: 4,
                    top: 8,
                    bottom: 8,
                  ),
                  child: FilledButton(
                    onPressed: () => context.push('/signup'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: _navy,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: const Text(
                      'إنشاء حساب',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 34),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _gold,
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'استشارتك القانونية تبدأ من هنا',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 29,
                          height: 1.25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'تواصل مع محامٍ موثوق واحصل على التوجيه القانوني الذي تحتاجه.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 22),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: SvgPicture.asset(
                          'assets/landing/lawyer_client.svg',
                          width: 300,
                          height: 190,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: () => context.push('/signup'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _navy,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text(
                            'اطلب استشارة الآن',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _sectionTitle(context, 'كيف تعمل استشارة؟')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        child: _Step(
                          number: '1',
                          title: 'اختر محاميًا',
                          icon: Icons.person_search_outlined,
                        ),
                      ),
                      Expanded(
                        child: _Step(
                          number: '2',
                          title: 'أرسل طلبك',
                          icon: Icons.edit_note_outlined,
                        ),
                      ),
                      Expanded(
                        child: _Step(
                          number: '3',
                          title: 'تابع استشارتك',
                          icon: Icons.chat_bubble_outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _sectionTitle(context, 'أضف استشارة إلى شاشة iPhone'),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF5FF),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.install_mobile_rounded,
                              color: _navy,
                              size: 23,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ثبّت التطبيق من Safari خلال أقل من دقيقة',
                                  style: TextStyle(
                                    color: scheme.onSurface,
                                    fontSize: 16,
                                    height: 1.4,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'بعد إضافته سيظهر تطبيق استشارة كأيقونة على الشاشة الرئيسية، ويمكن للعميل أو المحامي فتحه مباشرة ومشاركته مع الآخرين.',
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 13,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final cardWidth = constraints.maxWidth >= 760
                              ? (constraints.maxWidth - 36) / 4
                              : (constraints.maxWidth - 12) / 2;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _PwaInstallStep(
                                width: cardWidth,
                                number: '1',
                                title: 'اضغط زر المشاركة',
                                description:
                                    'افتح استشارة في Safari ثم اضغط أيقونة المشاركة في شريط المتصفح.',
                                asset: 'assets/landing/pwa_iphone_share.svg',
                                semanticsLabel: 'iPhone Safari share button guide',
                              ),
                              _PwaInstallStep(
                                width: cardWidth,
                                number: '2',
                                title: 'إضافة إلى الشاشة الرئيسية',
                                description:
                                    'من قائمة المشاركة اختر «إضافة إلى الشاشة الرئيسية».',
                                asset: 'assets/landing/pwa_iphone_add_home.svg',
                                semanticsLabel: 'iPhone Add to Home Screen guide',
                              ),
                              _PwaInstallStep(
                                width: cardWidth,
                                number: '3',
                                title: 'أكد الإضافة',
                                description:
                                    'اضغط «إضافة» ليظهر تطبيق استشارة كأيقونة مستقلة على شاشة iPhone.',
                                asset: 'assets/landing/pwa_iphone_confirm_add.svg',
                                semanticsLabel: 'iPhone confirm PWA add guide',
                              ),
                              _PwaInstallStep(
                                width: cardWidth,
                                number: '4',
                                title: 'شارك التطبيق',
                                description:
                                    'اضغط مطولًا على أيقونة استشارة ثم اختر «مشاركة التطبيق» لإرسال الرابط.',
                                asset: 'assets/landing/pwa_iphone_share_app.svg',
                                semanticsLabel: 'iPhone share installed app guide',
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF5FF).withValues(alpha: .65),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: _navy,
                              size: 20,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'على iPhone استخدم Safari لإظهار خيار «إضافة إلى الشاشة الرئيسية».',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 12.5,
                                  height: 1.45,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _sectionTitle(context, 'محامون موثوقون')),
            lawyersAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (_, __) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        'تعذر تحميل المحامين حالياً.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => ref.invalidate(lawyersListProvider),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (lawyers) {
                final verified = lawyers.where((lawyer) => lawyer.verified).take(6).toList();
                if (verified.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'سيظهر المحامون الموثوقون هنا قريبًا.',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      ...verified.map((lawyer) => _LawyerCard(lawyer: lawyer)),
                      const SizedBox(height: 4),
                      Center(
                        child: TextButton(
                          onPressed: () => context.push('/lawyers'),
                          child: const Text('عرض جميع المحامين'),
                        ),
                      ),
                    ]),
                  ),
                );
              },
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 42),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer.withValues(alpha: .28),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'لست مضطرًا للبحث وحدك',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ابدأ بخطوة بسيطة واختر المحامي المناسب لك.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Center(
                  child: Text(
                    'استشارة © جميع الحقوق محفوظة',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
        child: Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.icon});
  final String number;
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _goldSoft.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: _navy, size: 23),
          ),
          const SizedBox(height: 8),
          Text(
            '$number. $title',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _PwaInstallStep extends StatelessWidget {
  const _PwaInstallStep({
    required this.width,
    required this.number,
    required this.title,
    required this.description,
    required this.asset,
    required this.semanticsLabel,
  });

  final double width;
  final String number;
  final String title;
  final String description;
  final String asset;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: .82,
                child: SvgPicture.asset(
                  asset,
                  fit: BoxFit.contain,
                  semanticsLabel: semanticsLabel,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 27,
                  height: 27,
                  decoration: const BoxDecoration(
                    color: _gold,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 11.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LawyerCard extends StatelessWidget {
  const _LawyerCard({required this.lawyer});
  final LawyerProfile lawyer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/lawyers/${lawyer.id}'),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundImage: lawyer.avatarUrl != null && lawyer.avatarUrl!.isNotEmpty
                    ? NetworkImage(lawyer.avatarUrl!)
                    : null,
                child: lawyer.avatarUrl == null || lawyer.avatarUrl!.isEmpty
                    ? const Icon(Icons.person, color: _navy)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lawyer.fullName ?? 'محامٍ موثوق',
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.verified, color: _gold, size: 18),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lawyer.specializations.isNotEmpty
                          ? lawyer.specializations.join('، ')
                          : 'محامٍ',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
