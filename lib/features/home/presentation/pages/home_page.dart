import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/legal_specializations.dart';
import '../../../../shared/widgets/hover_lift.dart';
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
    final name = registeredName != null && registeredName.isNotEmpty ? registeredName : 'طالب استشارة';
    final avatarUrl = user?.avatarUrl;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Expanded(
                      child: Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.primary.withValues(alpha: .25)),
                              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .12), blurRadius: 10, offset: const Offset(0, 3))],
                            ),
                            child: ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.asset('assets/icons/app_icon.png', fit: BoxFit.cover)),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('استشارة', style: TextStyle(color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.w900)),
                                Text('مساحتك للاستشارات القانونية', style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _NotificationBell(unreadCount: unread, onTap: () => context.push('/notifications')),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
              sliver: SliverToBoxAdapter(child: _ClientProfileHeader(name: name, avatarUrl: avatarUrl)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
              sliver: SliverToBoxAdapter(
                child: bookings.when(
                  loading: () => const _StatsLoading(),
                  error: (_, __) => const _ClientStats(total: '—', completed: '—'),
                  data: (items) => _ClientStats(total: '${items.length}', completed: '${items.where((b) => b.status == 'مكتمل').length}'),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 3),
              sliver: SliverToBoxAdapter(child: _SectionTitle(title: 'التخصصات القانونية', action: 'عرض الكل', onTap: () => context.push('/lawyers'))),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 9),
              sliver: SliverToBoxAdapter(child: _LawyerSearchButton(onTap: () => context.push('/lawyers'))),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
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
                  crossAxisCount: 4,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 18,
                  childAspectRatio: .74,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 5),
              sliver: SliverToBoxAdapter(child: _SectionTitle(title: 'محامون مقترحون', action: 'عرض الكل', onTap: () => context.push('/lawyers'))),
            ),
            lawyers.when(
              loading: () => const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))),
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
    return HoverLift(
      borderRadius: 26,
      child: Container(
        constraints: const BoxConstraints(minHeight: 148),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [AppColors.primaryDark, AppColors.primary, AppColors.secondary]),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.goldTransparentStrong),
          boxShadow: [
            BoxShadow(color: AppColors.primaryDark.withValues(alpha: .14), blurRadius: 18, offset: const Offset(0, 7)),
          ],
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.goldTransparent, border: Border.all(color: AppColors.goldSoft, width: 1.7)),
              child: CircleAvatar(
                backgroundColor: AppColors.surfaceContainerHighest,
                backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty ? NetworkImage(avatarUrl!) : null,
                child: avatarUrl == null || avatarUrl!.isEmpty ? const Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 40) : null,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.goldTransparent, borderRadius: BorderRadius.circular(99)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.person_pin_circle_outlined, color: Colors.white, size: 15),
                      SizedBox(width: 5),
                      Text('طالب استشارة', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Text(name, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900, height: 1.2)),
                  const SizedBox(height: 7),
                  Text('اطلب استشارتك القانونية بسهولة وأمان', textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: .94), fontSize: 13, fontWeight: FontWeight.w600, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
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
    return Row(children: [
      Expanded(child: _ClientStatCard(value: total, label: 'الاستشارات', icon: Icons.forum_outlined, background: AppColors.tertiary, foreground: Colors.white)),
      const SizedBox(width: 9),
      Expanded(child: _ClientStatCard(value: completed, label: 'مكتملة', icon: Icons.verified_outlined, background: AppColors.success, foreground: Colors.white)),
    ]);
  }
}

class _ClientStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  const _ClientStatCard({required this.value, required this.label, required this.icon, required this.background, required this.foreground});

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      lift: 2,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(15)),
        child: Row(textDirection: TextDirection.rtl, children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: foreground.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: Icon(icon, color: foreground, size: 18)),
          const SizedBox(width: 7),
          Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(value, style: TextStyle(color: foreground, fontSize: 17, fontWeight: FontWeight.w900, height: 1.05)),
            Text(label, textAlign: TextAlign.right, style: TextStyle(color: foreground.withValues(alpha: .92), fontSize: 10.5, fontWeight: FontWeight.w700, height: 1.15)),
          ])),
        ]),
      ),
    );
  }
}

class _StatsLoading extends StatelessWidget {
  const _StatsLoading();
  @override
  Widget build(BuildContext context) => const _ClientStats(total: '—', completed: '—');
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback onTap;
  const _SectionTitle({required this.title, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(textDirection: TextDirection.rtl, children: [
        Expanded(child: Text(title, textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w900))),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 6), tapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact),
          child: const Text('عرض الكل', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 11.5)),
        ),
      ]),
    );
  }
}

class _LawyerSearchButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LawyerSearchButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.manage_search_rounded, size: 18),
        label: const Text('ابحث عن محامٍ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused) || states.contains(WidgetState.pressed)) return AppColors.primaryLight;
            return AppColors.primary;
          }),
          overlayColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: .08)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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

  IconData _iconFor(String value) {
    if (value.contains('إداري')) return Icons.account_balance_rounded;
    if (value.contains('الأمن')) return Icons.shield_outlined;
    if (value.contains('شركات')) return Icons.business_center_outlined;
    if (value.contains('عقاري')) return Icons.home_work_outlined;
    if (value.contains('الشهداء')) return Icons.workspace_premium_outlined;
    if (value.contains('أحوال')) return Icons.family_restroom_rounded;
    if (value.contains('مدني')) return Icons.balance_outlined;
    if (value.contains('جنائي')) return Icons.gavel_rounded;
    return Icons.account_balance_outlined;
  }

  Color _accentColor() {
    const colors = <Color>[Color(0xFF8E24AA), Color(0xFF43A047), Color(0xFF1E88E5), Color(0xFFFB8C00), Color(0xFFE53935), Color(0xFF795548), Color(0xFFFF9800), Color(0xFFD81B60)];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor();
    return TweenAnimationBuilder<double>(
      key: ValueKey(title),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 40)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(opacity: value, child: Transform.translate(offset: Offset(0, 8 * (1 - value)), child: child)),
      child: HoverLift(
        lift: 3,
        borderRadius: 18,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            splashColor: accent.withValues(alpha: .08),
            hoverColor: accent.withValues(alpha: .035),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Expanded(child: Container(width: double.infinity, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .075), blurRadius: 18, offset: const Offset(0, 7))]), alignment: Alignment.center, child: Icon(_iconFor(title), color: accent, size: 34))),
              const SizedBox(height: 8),
              SizedBox(height: 30, child: Text(title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w700, height: 1.2))),
            ]),
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
    final name = lawyer.fullName?.trim().isNotEmpty == true ? lawyer.fullName!.trim() : 'محامٍ';
    final specialization = lawyer.specializations.isNotEmpty ? lawyer.specializations.take(2).join('، ') : 'استشارات قانونية';
    final hasAvatar = lawyer.avatarUrl?.isNotEmpty == true;
    return HoverLift(
      borderRadius: 16,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            final id = lawyer.profileId.trim();
            if (id.isEmpty) return;
            context.push('/lawyers/$id');
          },
          hoverColor: AppColors.primary.withValues(alpha: .05),
          focusColor: AppColors.primary.withValues(alpha: .07),
          splashColor: AppColors.primary.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.outlineVariant)),
            child: Row(textDirection: TextDirection.rtl, children: [
              CircleAvatar(radius: 22, backgroundColor: AppColors.primary.withValues(alpha: .10), backgroundImage: hasAvatar ? NetworkImage(lawyer.avatarUrl!) : null, child: hasAvatar ? null : const Icon(Icons.person_outline_rounded, color: AppColors.primary)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  const Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 14),
                  const SizedBox(width: 4),
                  Flexible(child: Text(name, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w900))),
                ]),
                const SizedBox(height: 3),
                Text(specialization, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  const Icon(Icons.star_rounded, color: AppColors.tertiary, size: 14),
                  const SizedBox(width: 3),
                  Text(lawyer.rating.toStringAsFixed(1), style: const TextStyle(color: AppColors.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 7),
                  Text('${lawyer.reviewCount} تقييم', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
                ]),
              ])),
              const SizedBox(width: 7),
              const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary, size: 21),
            ]),
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
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: const Center(
                  child: Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.primary,
                    size: 27,
                  ),
                ),
              ),
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              top: 1,
              right: 1,
              child: IgnorePointer(
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.tertiary,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
        ],
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
    return Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Column(children: [Icon(icon, color: AppColors.textSecondary, size: 32), const SizedBox(height: 6), Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700))]));
  }
}
