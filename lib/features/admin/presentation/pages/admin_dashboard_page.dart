import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/notifications_provider.dart';
import '../providers/admin_provider.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);
    final unread = ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;

    ref.listen(realtimeNotificationsProvider, (previous, next) {
      if (next.hasValue) {
        ref.invalidate(unreadNotificationsCountProvider);
        ref.invalidate(notificationsProvider);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('لوحة الإدارة', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [
          _AdminNotificationButton(
            unreadCount: unread,
            onTap: () => context.push('/admin/notifications'),
          ),
          IconButton(
            onPressed: () => ref.read(adminStatsProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
          ),
          IconButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'تسجيل الخروج',
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _errorView(ref),
        data: (stats) => _dashboard(context, ref, stats, unread),
      ),
    );
  }

  Widget _errorView(WidgetRef ref) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
          const SizedBox(height: 14),
          const Text('تعذر تحميل لوحة الإدارة', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => ref.invalidate(adminStatsProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ]),
      );

  void _openSection(BuildContext context, WidgetRef ref, String route) {
    context.push(route).then((_) {
      ref.read(adminStatsProvider.notifier).refresh();
      ref.invalidate(unreadNotificationsCountProvider);
    });
  }

  Widget _dashboard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> stats,
    int unread,
  ) =>
      RefreshIndicator(
        onRefresh: () async {
          await ref.read(adminStatsProvider.notifier).refresh();
          ref.invalidate(unreadNotificationsCountProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSizes.p20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 22),
              _sectionHeading('نظرة عامة', Icons.dashboard_customize_outlined),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.38,
                children: [
                  _buildStatCard('إجمالي المستخدمين', stats['total_users'].toString(), Icons.people_alt_outlined, AppColors.primary),
                  _buildStatCard('إجمالي المحامين', stats['total_lawyers'].toString(), Icons.gavel_rounded, AppColors.secondaryDark),
                  _buildStatCard('طلبات التوثيق', stats['pending_verifications'].toString(), Icons.verified_user_outlined, AppColors.warning),
                  _buildStatCard('الحجوزات النشطة', stats['active_bookings'].toString(), Icons.calendar_month_outlined, AppColors.success),
                ],
              ),
              const SizedBox(height: 12),
              _buildRevenueCard((stats['total_revenue'] as num?)?.toDouble() ?? 0),
              const SizedBox(height: 24),
              _buildAdminSection(
                title: 'الحسابات والمحامون',
                icon: Icons.manage_accounts_outlined,
                children: [
                  _buildAdminActionCard(
                    'إدارة المستخدمين',
                    'البحث في الحسابات ومراجعة حالتها',
                    Icons.people_alt_outlined,
                    AppColors.primary,
                    () => _openSection(context, ref, '/admin/users'),
                  ),
                  _buildAdminActionCard(
                    'توثيق المحامين',
                    'مراجعة واعتماد بيانات المحامين',
                    Icons.verified_user_outlined,
                    AppColors.secondaryDark,
                    () => _openSection(context, ref, '/admin/lawyer-verifications'),
                  ),
                  _buildAdminActionCard(
                    'تغيير التخصصات',
                    'مراجعة طلبات تعديل تخصص المحامي',
                    Icons.category_outlined,
                    AppColors.teal,
                    () => _openSection(context, ref, '/admin/specialization-change-requests'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildAdminSection(
                title: 'المراجعات والطلبات',
                icon: Icons.fact_check_outlined,
                children: [
                  _buildAdminActionCard(
                    'مركز المراجعات',
                    'الطلبات التي تحتاج قراراً إدارياً',
                    Icons.fact_check_outlined,
                    AppColors.primary,
                    () => _openSection(context, ref, '/admin/reviews'),
                    emphasized: true,
                  ),
                  _buildAdminActionCard(
                    'مراجعة عدم الحضور',
                    'التحقق من البلاغات واتخاذ القرار',
                    Icons.person_off_outlined,
                    AppColors.error,
                    () => _openSection(context, ref, '/admin/no-show-reviews'),
                  ),
                  _buildAdminActionCard(
                    'إلغاء الحجوزات',
                    'الإلغاء والغرامات والتعويضات',
                    Icons.event_busy_outlined,
                    AppColors.warning,
                    () => _openSection(context, ref, '/admin/cancellation-requests'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildAdminSection(
                title: 'المدفوعات والمالية',
                icon: Icons.account_balance_wallet_outlined,
                children: [
                  _buildAdminActionCard(
                    'إدارة المدفوعات',
                    'حساب استلام الأموال ومراجعة الإيصالات',
                    Icons.payments_outlined,
                    AppColors.goldDark,
                    () => _openSection(context, ref, '/admin/payments'),
                    emphasized: true,
                  ),
                  _buildAdminActionCard(
                    'الإدارة المالية',
                    'العمولات والأرصدة والسحوبات وسجل العمليات',
                    Icons.account_balance_outlined,
                    AppColors.teal,
                    () => _openSection(context, ref, '/admin/financial'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildAdminSection(
                title: 'الإشعارات والمتابعة',
                icon: Icons.notifications_active_outlined,
                children: [
                  _buildAdminActionCard(
                    'إشعارات الإدارة',
                    unread == 0 ? 'لا توجد إشعارات غير مقروءة' : '$unread إشعار غير مقروء',
                    Icons.notifications_none_rounded,
                    AppColors.tertiary,
                    () => _openSection(context, ref, '/admin/notifications'),
                    badge: unread > 0 ? '$unread' : null,
                  ),
                ],
              ),
              const SizedBox(height: 22),
            ],
          ),
        ),
      );

  Widget _buildHeader() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryDark, AppColors.primary, AppColors.secondary],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.goldTransparentStrong),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.goldTransparent,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: AppColors.goldSoftStrong),
              ),
              child: const Icon(Icons.admin_panel_settings_outlined, color: AppColors.goldLight, size: 30),
            ),
            const SizedBox(width: 13),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('إدارة منصة استشارة', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                  SizedBox(height: 4),
                  Text('لوحة موحدة للحسابات والمراجعات والمدفوعات والعمليات المالية', textAlign: TextAlign.right, style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.45)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _sectionHeading(String title, IconData icon) => Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(title, textAlign: TextAlign.right, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(width: 8),
          Icon(icon, color: AppColors.primary, size: 21),
        ],
      );

  Widget _buildAdminSection({required String title, required IconData icon, required List<Widget> children}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionHeading(title, icon),
            const SizedBox(height: 12),
            GridView.extent(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              maxCrossAxisExtent: 420,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.35,
              children: children,
            ),
          ],
        ),
      );

  Widget _buildStatCard(String title, String value, IconData icon, Color accent) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.outlineVariant),
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .035), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: accent.withValues(alpha: .10), borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: accent, size: 23),
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        ]),
      );

  Widget _buildRevenueCard(double amount) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.goldSoftStrong),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: AppColors.goldLight, borderRadius: BorderRadius.circular(15)),
              child: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.goldDark, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('إجمالي الإيرادات المسجلة', textAlign: TextAlign.right, style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 5),
                  Text('${amount.toStringAsFixed(0)} د.ع', textAlign: TextAlign.right, style: const TextStyle(color: AppColors.goldDark, fontSize: 23, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildAdminActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool emphasized = false,
    String? badge,
  }) =>
      Material(
        color: emphasized ? AppColors.primaryFixed : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: emphasized ? color.withValues(alpha: .40) : AppColors.outlineVariant),
            ),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: color.withValues(alpha: .11), borderRadius: BorderRadius.circular(14)),
                      child: Icon(icon, color: color),
                    ),
                    if (badge != null)
                      PositionedDirectional(
                        top: -7,
                        start: -7,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 21),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white, width: 1.5)),
                          child: Text(badge, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(title, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary, fontSize: 13.5)),
                      const SizedBox(height: 4),
                      Text(subtitle, textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.35)),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary, size: 20),
              ],
            ),
          ),
        ),
      );
}

class _AdminNotificationButton extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;

  const _AdminNotificationButton({required this.unreadCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onTap,
          icon: const Icon(Icons.notifications_none_rounded),
          tooltip: 'إشعارات الإدارة',
        ),
        if (unreadCount > 0)
          PositionedDirectional(
            top: 4,
            end: 2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(99), border: Border.all(color: AppColors.primary, width: 1.2)),
              child: Text(unreadCount > 99 ? '99+' : '$unreadCount', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900)),
            ),
          ),
      ],
    );
  }
}
