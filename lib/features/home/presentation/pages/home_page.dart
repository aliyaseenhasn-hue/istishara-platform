import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/legal_specializations.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../bookings/presentation/providers/bookings_provider.dart';
import '../../../lawyers/domain/entities/lawyer_profile.dart';
import '../../../lawyers/presentation/providers/lawyers_provider.dart';
import '../../../profile/presentation/providers/notifications_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateChangesProvider).value;
    final bookings = ref.watch(userBookingsProvider);
    final lawyers = ref.watch(lawyersListProvider);
    final unread = ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;
    final categories = LegalSpecializations.all.take(8).toList();
    final registeredName = user?.fullName?.trim();
    final name = registeredName != null && registeredName.isNotEmpty ? registeredName : 'عميل استشارة';
    final avatarUrl = user?.avatarUrl;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('استشارة', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 20, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text('مساحتك للاستشارات القانونية', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _NotificationBell(unreadCount: unread, onTap: () => context.push('/notifications')),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              sliver: SliverToBoxAdapter(
                child: _ClientProfileHeader(name: name, avatarUrl: avatarUrl),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              sliver: SliverToBoxAdapter(
                child: bookings.when(
                  loading: () => const _StatsLoading(),
                  error: (_, __) => const _ClientStats(total: 0, completed: 0),
                  data: (items) => _ClientStats(
                    total: items.length,
                    completed: items.where((b) => b.status == 'مكتمل').length,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 9),
              sliver: SliverToBoxAdapter(
                child: _SectionTitle(title: 'التخصصات القانونية', action: 'عرض الكل', onTap: () => context.push('/lawyers')),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _AnimatedCategoryCard(
                    index: index,
                    title: categories[index],
                    onTap: () {
                      ref.read(selectedCategoryProvider.notifier).setCategory(categories[index]);
                      context.push('/lawyers');
                    },
                  ),
                  childCount: categories.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.42,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              sliver: SliverToBoxAdapter(
                child: _ConsultationActions(
                  onConsult: () => context.push('/lawyers'),
                  onSearch: () => context.push('/lawyers'),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 8),
              sliver: SliverToBoxAdapter(
                child: _SectionTitle(title: 'محامون مقترحون', action: 'عرض الكل', onTap: () => context.push('/lawyers')),
              ),
            ),
            lawyers.when(
              loading: () => const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()))),
              error: (_, __) => const SliverToBoxAdapter(child: _EmptyState(icon: Icons.cloud_off_rounded, text: 'تعذر تحميل المحامين حالياً')),
              data: (items) => items.isEmpty
                  ? const SliverToBoxAdapter(child: _EmptyState(icon: Icons.person_search_outlined, text: 'لا يوجد محامون موثقون حالياً'))
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                          child: _SuggestedLawyerCard(lawyer: items[index] as LawyerProfile),
                        ),
                        childCount: items.length > 6 ? 6 : items.length,
                      ),
                    ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ),
      ),
    );
  }
}

class _ClientProfileHeader extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  const _ClientProfileHeader({required this.name, required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: const [BoxShadow(color: Color(0x0D082B49), blurRadius: 18, offset: Offset(0, 7))],
      ),
      child: Column(
        children: [
          Container(
            width: 94,
            height: 94,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.secondaryContainer, border: Border.all(color: AppColors.ctaGold, width: 2)),
            child: CircleAvatar(
              backgroundColor: AppColors.surfaceContainerHighest,
              backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty ? NetworkImage(avatarUrl!) : null,
              child: avatarUrl == null || avatarUrl!.isEmpty ? const Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 43) : null,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.primaryContainer.withValues(alpha: .10), borderRadius: BorderRadius.circular(99)),
            child: const Text('عميل', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 5),
          Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontSize: 21, fontWeight: FontWeight.w900, height: 1.2)),
          const SizedBox(height: 3),
          const Text('اطلب استشارتك القانونية بسهولة وأمان', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ClientStats extends StatelessWidget {
  final int total;
  final int completed;
  const _ClientStats({required this.total, required this.completed});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _ClientStatCard(value: '$total', label: 'الاستشارات', icon: Icons.forum_outlined, iconBackground: AppColors.primaryContainer.withValues(alpha: .10), iconColor: AppColors.primary)),
        const SizedBox(width: 10),
        Expanded(child: _ClientStatCard(value: '$completed', label: 'مكتملة', icon: Icons.star_outline_rounded, iconBackground: AppColors.secondaryContainer, iconColor: AppColors.onSecondaryContainer)),
      ],
    );
  }
}

class _ClientStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  const _ClientStatCard({required this.value, required this.label, required this.icon, required this.iconBackground, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.outlineVariant)),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: iconBackground, borderRadius: BorderRadius.circular(13)), alignment: Alignment.center, child: Icon(icon, color: iconColor, size: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 1),
              Text(label, textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _StatsLoading extends StatelessWidget {
  const _StatsLoading();
  @override
  Widget build(BuildContext context) => Row(children: [Expanded(child: _ClientStatCard(value: '—', label: 'الاستشارات', icon: Icons.forum_outlined, iconBackground: AppColors.primaryContainer.withValues(alpha: .10), iconColor: AppColors.primary)), const SizedBox(width: 10), Expanded(child: _ClientStatCard(value: '—', label: 'مكتملة', icon: Icons.star_outline_rounded, iconBackground: AppColors.secondaryContainer, iconColor: AppColors.onSecondaryContainer))]);
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback onTap;
  const _SectionTitle({required this.title, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        Expanded(child: Text(title, textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w900))),
        TextButton(onPressed: onTap, child: const Text('عرض الكل', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 12))),
      ],
    );
  }
}

class _AnimatedCategoryCard extends StatelessWidget {
  final int index;
  final String title;
  final VoidCallback onTap;
  const _AnimatedCategoryCard({required this.index, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(title),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + (index * 45)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(opacity: value, child: Transform.translate(offset: Offset(0, 12 * (1 - value)), child: child)),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.outlineVariant)),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Container(width: 38, height: 38, decoration: BoxDecoration(color: AppColors.secondaryContainer.withValues(alpha: .72), borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: const Icon(Icons.gavel_rounded, color: AppColors.onSecondaryContainer, size: 20)),
                const SizedBox(width: 8),
                Expanded(child: Text(title, textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w800, height: 1.25))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsultationActions extends StatelessWidget {
  final VoidCallback onConsult;
  final VoidCallback onSearch;
  const _ConsultationActions({required this.onConsult, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.primaryContainer.withValues(alpha: .07), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primaryContainer.withValues(alpha: .14))),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: FilledButton.icon(
                onPressed: onConsult,
                icon: const Icon(Icons.forum_outlined, size: 18),
                label: const Text('استشر محامياً', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.textOnPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: onSearch,
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('ابحث عن محامٍ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.outline), backgroundColor: AppColors.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestedLawyerCard extends StatelessWidget {
  final LawyerProfile lawyer;
  const _SuggestedLawyerCard({required this.lawyer});

  @override
  Widget build(BuildContext context) {
    final name = lawyer.fullName?.trim().isNotEmpty == true ? lawyer.fullName!.trim() : 'محامٍ';
    final specialization = lawyer.specializations.isNotEmpty ? lawyer.specializations.take(2).join('، ') : 'استشارات قانونية';
    final hasAvatar = lawyer.avatarUrl?.isNotEmpty == true;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          final id = lawyer.profileId.trim();
          if (id.isEmpty) return;
          context.push('/lawyers/$id');
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.outlineVariant)),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              CircleAvatar(radius: 25, backgroundColor: AppColors.primaryContainer, backgroundImage: hasAvatar ? NetworkImage(lawyer.avatarUrl!) : null, child: hasAvatar ? null : const Icon(Icons.person_outline_rounded, color: AppColors.onPrimaryContainer)),
              const SizedBox(width: 11),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(name, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(specialization, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5)),
                  const SizedBox(height: 5),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [const Icon(Icons.star_rounded, color: AppColors.gold, size: 14), const SizedBox(width: 3), Text(lawyer.rating.toStringAsFixed(1), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 10.5)), const SizedBox(width: 6), const Text('التقييم', style: TextStyle(color: AppColors.textSecondary, fontSize: 9.5))]),
                ]),
              ),
              const SizedBox(width: 7),
              const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.outlineVariant)),
        child: Column(children: [Icon(icon, color: AppColors.textSecondary, size: 28), const SizedBox(height: 7), Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary))]),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;
  const _NotificationBell({required this.unreadCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'التنبيهات',
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary, size: 24),
                if (unreadCount > 0)
                  Positioned(
                    top: 2,
                    right: 1,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(99), border: Border.all(color: AppColors.surface, width: 1.5)),
                      child: Text(unreadCount > 99 ? '99+' : '$unreadCount', style: const TextStyle(color: AppColors.textOnPrimary, fontSize: 8, fontWeight: FontWeight.w900)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
