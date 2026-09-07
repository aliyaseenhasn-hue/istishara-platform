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
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authStateChangesProvider).value;
    final bookings = ref.watch(userBookingsProvider);
    final lawyers = ref.watch(lawyersListProvider);
    final unread = ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;
    final categories = LegalSpecializations.all.take(8).toList();
    final registeredName = user?.fullName?.trim();
    final name = registeredName != null && registeredName.isNotEmpty ? registeredName : 'عميل استشارة';
    final avatarUrl = user?.avatarUrl;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLow,
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
                          Text('استشارة', style: TextStyle(color: scheme.primary, fontSize: 20, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text('مساحتك للاستشارات القانونية', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
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
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              sliver: SliverToBoxAdapter(child: _ClientProfileHeader(name: name, avatarUrl: avatarUrl)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              sliver: SliverToBoxAdapter(
                child: bookings.when(
                  loading: () => const _StatsLoading(),
                  error: (_, __) => const _ClientStats(total: '—', completed: '—'),
                  data: (items) => _ClientStats(total: '${items.length}', completed: '${items.where((b) => b.status == 'مكتمل').length}'),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 7),
              sliver: SliverToBoxAdapter(child: _SectionTitle(title: 'التخصصات القانونية', action: 'عرض الكل', onTap: () => context.push('/lawyers'))),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              sliver: SliverToBoxAdapter(child: _LawyerSearchButton(onTap: () => context.push('/lawyers'))),
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
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 250,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.42,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
              sliver: SliverToBoxAdapter(child: _SectionTitle(title: 'محامون مقترحون', action: 'عرض الكل', onTap: () => context.push('/lawyers'))),
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [scheme.primary, AppColors.primaryContainer],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.primary.withValues(alpha: .18)),
        boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: .16), blurRadius: 24, offset: const Offset(0, 9))],
      ),
      child: Column(
        children: [
          Container(
            width: 94,
            height: 94,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.onPrimary.withValues(alpha: .12),
              border: Border.all(color: scheme.onPrimary.withValues(alpha: .72), width: 2),
            ),
            child: CircleAvatar(
              backgroundColor: scheme.surfaceContainerHighest,
              backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty ? NetworkImage(avatarUrl!) : null,
              child: avatarUrl == null || avatarUrl!.isEmpty ? Icon(Icons.person_outline_rounded, color: scheme.primary, size: 43) : null,
            ),
          ),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
            decoration: BoxDecoration(color: scheme.onPrimary.withValues(alpha: .12), borderRadius: BorderRadius.circular(99)),
            child: Text('عميل', style: TextStyle(color: scheme.onPrimary, fontSize: 12, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 6),
          Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onPrimary, fontSize: 21, fontWeight: FontWeight.w900, height: 1.2)),
          const SizedBox(height: 4),
          Text('اطلب استشارتك القانونية بسهولة وأمان', textAlign: TextAlign.center, style: TextStyle(color: scheme.onPrimary.withValues(alpha: .82), fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ClientStats extends StatelessWidget {
  final String total;
  final String completed;
  const _ClientStats({required this.total, required this.completed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: _ClientStatCard(value: total, label: 'الاستشارات', icon: Icons.forum_outlined, iconBackground: scheme.primary.withValues(alpha: .10), iconColor: scheme.primary)),
        const SizedBox(width: 10),
        Expanded(child: _ClientStatCard(value: completed, label: 'مكتملة', icon: Icons.verified_outlined, iconBackground: scheme.tertiary.withValues(alpha: .10), iconColor: scheme.tertiary)),
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [BoxShadow(color: scheme.shadow.withValues(alpha: .035), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: iconBackground, borderRadius: BorderRadius.circular(13)), alignment: Alignment.center, child: Icon(icon, color: iconColor, size: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(value, style: TextStyle(color: scheme.onSurface, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 1),
              Text(label, textAlign: TextAlign.right, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700)),
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      Expanded(child: _ClientStatCard(value: '—', label: 'الاستشارات', icon: Icons.forum_outlined, iconBackground: scheme.primary.withValues(alpha: .10), iconColor: scheme.primary)),
      const SizedBox(width: 10),
      Expanded(child: _ClientStatCard(value: '—', label: 'مكتملة', icon: Icons.verified_outlined, iconBackground: scheme.tertiary.withValues(alpha: .10), iconColor: scheme.tertiary)),
    ]);
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback onTap;
  const _SectionTitle({required this.title, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        Expanded(child: Text(title, textAlign: TextAlign.right, style: TextStyle(color: scheme.onSurface, fontSize: 17, fontWeight: FontWeight.w900))),
        TextButton(onPressed: onTap, child: Text(action, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800, fontSize: 12))),
      ],
    );
  }
}

class _LawyerSearchButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LawyerSearchButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.search_rounded, size: 19),
        label: const Text('ابحث عن محامٍ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        style: FilledButton.styleFrom(
          foregroundColor: scheme.onPrimary,
          backgroundColor: scheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
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
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      key: ValueKey(title),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + (index * 45)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(opacity: value, child: Transform.translate(offset: Offset(0, 12 * (1 - value)), child: child)),
      child: Material(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: [BoxShadow(color: scheme.shadow.withValues(alpha: .025), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: scheme.primary.withValues(alpha: .09), borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: Icon(Icons.gavel_rounded, color: scheme.primary, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(title, textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurface, fontSize: 12, fontWeight: FontWeight.w800, height: 1.3))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestedLawyerCard extends StatelessWidget {
  final LawyerProfile lawyer;
  const _SuggestedLawyerCard({required this.lawyer});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = lawyer.fullName?.trim().isNotEmpty == true ? lawyer.fullName!.trim() : 'محامٍ';
    final specialization = lawyer.specializations.isNotEmpty ? lawyer.specializations.take(2).join('، ') : 'استشارات قانونية';
    final hasAvatar = lawyer.avatarUrl?.isNotEmpty == true;
    return Material(
      color: scheme.surfaceContainerLowest,
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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: [BoxShadow(color: scheme.shadow.withValues(alpha: .025), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: scheme.primary.withValues(alpha: .10),
                backgroundImage: hasAvatar ? NetworkImage(lawyer.avatarUrl!) : null,
                child: hasAvatar ? null : Icon(Icons.person_outline_rounded, color: scheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(name, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurface, fontSize: 14, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(specialization, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 5),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Icon(Icons.star_rounded, color: scheme.primary, size: 15),
                      const SizedBox(width: 3),
                      Text('${lawyer.rating.toStringAsFixed(1)}', style: TextStyle(color: scheme.onSurface, fontSize: 12, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 8),
                      Text('${lawyer.reviewCount} تقييم', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_left_rounded, color: scheme.onSurfaceVariant, size: 22),
            ],
          ),
        ),
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
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(onPressed: onTap, tooltip: 'الإشعارات', icon: Icon(Icons.notifications_none_rounded, color: scheme.primary)),
        if (unreadCount > 0)
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(color: scheme.tertiary, borderRadius: BorderRadius.circular(99)),
              child: Text(unreadCount > 99 ? '99+' : '$unreadCount', textAlign: TextAlign.center, style: TextStyle(color: scheme.onTertiary, fontSize: 11, fontWeight: FontWeight.w900)),
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, color: scheme.onSurfaceVariant, size: 34),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
