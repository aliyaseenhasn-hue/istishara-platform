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
      body: SafeArea(child: CustomScrollView(slivers: [
        SliverPadding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 0), sliver: SliverToBoxAdapter(child: Row(textDirection: TextDirection.rtl, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('استشارة', style: TextStyle(color: scheme.primary, fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text('منصة الاستشارات القانونية', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
          ])),
          _NotificationBell(unreadCount: unread, onTap: () => context.push('/notifications')),
        ]))),
        SliverPadding(padding: const EdgeInsets.fromLTRB(20, 22, 20, 0), sliver: SliverToBoxAdapter(child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('كيف يمكننا مساعدتك؟', textAlign: TextAlign.right, style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 24, fontWeight: FontWeight.w900, height: 1.25)),
            const SizedBox(height: 7),
            Text('ابحث عن محامٍ مناسب لتخصصك وابدأ استشارتك.', textAlign: TextAlign.right, style: TextStyle(color: scheme.onPrimaryContainer.withValues(alpha: .78), fontSize: 13, height: 1.5)),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, height: 46, child: FilledButton.icon(onPressed: () => context.push('/lawyers'), icon: const Icon(Icons.search_rounded, size: 19), label: const Text('ابحث عن محامٍ', style: TextStyle(fontWeight: FontWeight.w800)))),
          ]),
        ))),
        SliverPadding(padding: const EdgeInsets.fromLTRB(20, 25, 20, 10), sliver: SliverToBoxAdapter(child: _SectionTitle(title: 'التخصصات القانونية', action: 'عرض الكل', onTap: () => context.push('/lawyers')))),
        SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 20), sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate((context, index) {
            final category = categories[index];
            return _CategoryCard(title: category, onTap: () {
              ref.read(selectedCategoryProvider.notifier).setCategory(category);
              context.push('/lawyers');
            });
          }, childCount: categories.length),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.65),
        )),
        SliverPadding(padding: const EdgeInsets.fromLTRB(20, 25, 20, 8), sliver: SliverToBoxAdapter(child: _SectionTitle(title: 'محامون مقترحون', action: 'عرض الكل', onTap: () => context.push('/lawyers')))),
        lawyers.when(
          loading: () => const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))),
          error: (_, __) => const SliverToBoxAdapter(child: _EmptyState(icon: Icons.cloud_off_rounded, text: 'تعذر تحميل المحامين حالياً')),
          data: (items) => items.isEmpty
            ? const SliverToBoxAdapter(child: _EmptyState(icon: Icons.person_search_outlined, text: 'لا يوجد محامون موثقون حالياً'))
            : SliverList(delegate: SliverChildBuilderDelegate((context, index) => Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4), child: _SuggestedLawyerCard(lawyer: items[index] as LawyerProfile)), childCount: items.length > 6 ? 6 : items.length)),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ])),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title; final String action; final VoidCallback onTap;
  const _SectionTitle({required this.title, required this.action, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(textDirection: TextDirection.rtl, children: [
      Expanded(child: Text(title, textAlign: TextAlign.right, style: TextStyle(color: scheme.onSurface, fontSize: 18, fontWeight: FontWeight.w900))),
      TextButton(onPressed: onTap, child: Text(action, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700))),
    ]);
  }
}

class _CategoryCard extends StatelessWidget {
  final String title; final VoidCallback onTap;
  const _CategoryCard({required this.title, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(color: scheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(16), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: scheme.outlineVariant)),
      child: Row(textDirection: TextDirection.rtl, children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(color: AppColors.goldLight.withValues(alpha: .30), borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: const Icon(Icons.gavel_rounded, color: AppColors.gold, size: 19)),
        const SizedBox(width: 8),
        Expanded(child: Text(title, textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurface, fontSize: 11.5, fontWeight: FontWeight.w800, height: 1.2))),
      ]),
    )));
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
    return Material(color: scheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(16), child: InkWell(onTap: () { final id = lawyer.profileId.trim(); if (id.isEmpty) return; context.push('/lawyers/$id'); }, borderRadius: BorderRadius.circular(16), child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: scheme.outlineVariant)),
      child: Row(textDirection: TextDirection.rtl, children: [
        CircleAvatar(radius: 25, backgroundColor: scheme.primaryContainer, backgroundImage: hasAvatar ? NetworkImage(lawyer.avatarUrl!) : null, child: hasAvatar ? null : Icon(Icons.person_outline_rounded, color: scheme.primary)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(name, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 3),
          Text(specialization, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10.5)),
          const SizedBox(height: 5),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [const Icon(Icons.star_rounded, color: AppColors.gold, size: 14), const SizedBox(width: 3), Text(lawyer.rating.toStringAsFixed(1), style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700, fontSize: 10.5)), const SizedBox(width: 6), Text('التقييم', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 9.5))]),
        ])),
        const SizedBox(width: 7),
        Icon(Icons.chevron_left_rounded, color: scheme.onSurfaceVariant),
      ]),
    )));
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon; final String text;
  const _EmptyState({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 20), child: Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: scheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(16), border: Border.all(color: scheme.outlineVariant)), child: Column(children: [Icon(icon, color: scheme.onSurfaceVariant, size: 28), const SizedBox(height: 7), Text(text, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant))])));
  }
}

class _NotificationBell extends StatelessWidget {
  final int unreadCount; final VoidCallback onTap;
  const _NotificationBell({required this.unreadCount, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(button: true, label: 'التنبيهات', child: Material(color: scheme.surfaceContainerLowest, shape: const CircleBorder(), child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: SizedBox(width: 44, height: 44, child: Stack(alignment: Alignment.center, children: [
      Icon(Icons.notifications_none_rounded, color: scheme.onSurface, size: 24),
      if (unreadCount > 0) Positioned(top: 2, right: 1, child: Container(constraints: const BoxConstraints(minWidth: 18, minHeight: 18), padding: const EdgeInsets.symmetric(horizontal: 4), alignment: Alignment.center, decoration: BoxDecoration(color: scheme.error, borderRadius: BorderRadius.circular(99), border: Border.all(color: scheme.surfaceContainerLowest, width: 1.5)), child: Text(unreadCount > 99 ? '99+' : '$unreadCount', style: TextStyle(color: scheme.onError, fontSize: 8, fontWeight: FontWeight.w900)))),
    ])))));
  }
}
