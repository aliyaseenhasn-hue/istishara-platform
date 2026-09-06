import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/legal_specializations.dart';
import '../../../lawyers/domain/entities/lawyer_profile.dart';
import '../../../lawyers/presentation/providers/lawyers_provider.dart';
import '../../../profile/presentation/providers/notifications_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final lawyers = ref.watch(lawyersListProvider);
    final unread = ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;
    final categories = LegalSpecializations.all.take(8).toList();

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.balance_rounded, color: scheme.primary, size: 25),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('استشارة', style: TextStyle(color: scheme.primary, fontSize: 18, fontWeight: FontWeight.w900)),
                          Text('منصة الاستشارات القانونية', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10.5)),
                        ],
                      ),
                    ),
                    _NotificationBell(unreadCount: unread, onTap: () => context.push('/notifications')),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 21, 20, 20),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('استشر محامياً بثقة', textAlign: TextAlign.right, style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 27, fontWeight: FontWeight.w900, height: 1.2)),
                      const SizedBox(height: 7),
                      Text('اختر تخصصك وابحث عن المحامي المناسب لطلبك القانوني.', textAlign: TextAlign.right, style: TextStyle(color: scheme.onPrimaryContainer.withValues(alpha: .78), height: 1.5, fontSize: 13)),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () => context.push('/lawyers'),
                          icon: const Icon(Icons.search_rounded, size: 20),
                          label: const Text('ابحث عن محامٍ', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 9),
              sliver: SliverToBoxAdapter(
                child: _SectionTitle(title: 'التخصصات القانونية', action: 'عرض الكل', onTap: () => context.push('/lawyers')),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final category = categories[index];
                    return _CategoryCard(title: category, onTap: () {
                      ref.read(selectedCategoryProvider.notifier).setCategory(category);
                      context.push('/lawyers');
                    });
                  },
                  childCount: categories.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.4,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              sliver: SliverToBoxAdapter(
                child: _SectionTitle(title: 'محامون مقترحون', action: 'عرض الكل', onTap: () => context.push('/lawyers')),
              ),
            ),
            lawyers.when(
              loading: () => const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))),
              error: (_, __) => const SliverToBoxAdapter(child: _EmptyState(icon: Icons.cloud_off_rounded, text: 'تعذر تحميل المحامين حالياً')),
              data: (items) => items.isEmpty
                  ? const SliverToBoxAdapter(child: _EmptyState(icon: Icons.person_search_outlined, text: 'لا يوجد محامون موثقون حالياً'))
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                          child: _SuggestedLawyerCard(lawyer: items[index] as LawyerProfile),
                        ),
                        childCount: items.length > 6 ? 6 : items.length,
                      ),
                    ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 112)),
          ],
        ),
      ),
    );
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
        Expanded(child: Text(title, textAlign: TextAlign.right, style: TextStyle(color: scheme.onSurface, fontSize: 19, fontWeight: FontWeight.w900))),
        TextButton(onPressed: onTap, child: Text(action, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700))),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  const _CategoryCard({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: scheme.outlineVariant)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.goldLight.withValues(alpha: .38), borderRadius: BorderRadius.circular(13)), alignment: Alignment.center, child: const Icon(Icons.gavel_rounded, color: AppColors.gold, size: 22)),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurface, fontSize: 12, fontWeight: FontWeight.w800, height: 1.25)),
            ],
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
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () {
          final id = lawyer.profileId.trim();
          if (id.isEmpty) return;
          context.push('/lawyers/$id');
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: scheme.outlineVariant)),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              CircleAvatar(radius: 27, backgroundColor: scheme.primaryContainer, backgroundImage: hasAvatar ? NetworkImage(lawyer.avatarUrl!) : null, child: hasAvatar ? null : Icon(Icons.person_outline_rounded, color: scheme.primary)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(name, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w900, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(specialization, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
                  const SizedBox(height: 7),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [const Icon(Icons.star_rounded, color: AppColors.gold, size: 15), const SizedBox(width: 3), Text(lawyer.rating.toStringAsFixed(1), style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700, fontSize: 11)), const SizedBox(width: 7), Text('التقييم', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10))]),
                ]),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_left_rounded, color: scheme.onSurfaceVariant),
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
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: scheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(18), border: Border.all(color: scheme.outlineVariant)),
        child: Column(children: [Icon(icon, color: scheme.onSurfaceVariant, size: 30), const SizedBox(height: 8), Text(text, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant))]),
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
    return Semantics(
      button: true,
      label: 'التنبيهات',
      child: Material(
        color: scheme.surfaceContainerLowest,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.notifications_none_rounded, color: scheme.onSurface, size: 25),
                if (unreadCount > 0)
                  Positioned(
                    top: 3,
                    right: 2,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: scheme.error, borderRadius: BorderRadius.circular(99), border: Border.all(color: scheme.surfaceContainerLowest, width: 1.5)),
                      child: Text(unreadCount > 99 ? '99+' : '$unreadCount', style: TextStyle(color: scheme.onError, fontSize: 8, fontWeight: FontWeight.w900)),
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
