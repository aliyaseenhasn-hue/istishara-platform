import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../providers/admin_provider.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('لوحة الإدارة'),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(onPressed: () => ref.read(adminStatsProvider.notifier).refresh(), icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث'),
          IconButton(onPressed: () => ref.read(authControllerProvider.notifier).logout(), icon: const Icon(Icons.logout_rounded), tooltip: 'تسجيل الخروج'),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _errorView(ref),
        data: (stats) => _dashboard(context, ref, stats),
      ),
    );
  }

  Widget _errorView(WidgetRef ref) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
          const SizedBox(height: 14),
          const Text('تعذر تحميل لوحة الإدارة', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: () => ref.invalidate(adminStatsProvider), icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
        ]),
      );

  void _openSection(BuildContext context, WidgetRef ref, String route) {
    context.push(route).then((_) => ref.read(adminStatsProvider.notifier).refresh());
  }

  Widget _dashboard(BuildContext context, WidgetRef ref, Map<String, dynamic> stats) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.p20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primaryDark, AppColors.primary], begin: Alignment.topRight, end: Alignment.bottomLeft),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Row(children: [
              Icon(Icons.admin_panel_settings_outlined, color: Colors.white, size: 34),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('إدارة منصة استشارة', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                  SizedBox(height: 4),
                  Text('المستخدمون، المراجعات، الحجوزات والعمليات المالية في مكان واحد', style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.45)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 22),
          const Text('نظرة عامة', textAlign: TextAlign.right, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
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
          const SizedBox(height: 20),
          _buildRevenueCard((stats['total_revenue'] as num?)?.toDouble() ?? 0),
          const SizedBox(height: 24),
          const Text('الإجراءات الإدارية', textAlign: TextAlign.right, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          _buildAdminActionCard('مركز المراجعات', 'كل الطلبات التي تحتاج قراراً إدارياً', Icons.fact_check_outlined, AppColors.primary, () => _openSection(context, ref, '/admin/reviews'), emphasized: true),
          _buildAdminActionCard('مراجعة عدم الحضور', 'التحقق من البلاغات وعرض تفاصيل الحجز قبل القرار', Icons.person_off_outlined, AppColors.error, () => _openSection(context, ref, '/admin/no-show-reviews')),
          _buildAdminActionCard('طلبات إلغاء الحجوزات', 'الإلغاء والغرامات والتعويضات', Icons.event_busy_outlined, AppColors.warning, () => _openSection(context, ref, '/admin/cancellation-requests')),
          _buildAdminActionCard('طلبات توثيق المحامين', 'مراجعة واعتماد بيانات المحامين', Icons.verified_user_outlined, AppColors.secondaryDark, () => _openSection(context, ref, '/admin/lawyer-verifications')),
          _buildAdminActionCard('إدارة المستخدمين', 'البحث في الحسابات ومراجعة حالتها', Icons.people_alt_outlined, AppColors.primary, () => _openSection(context, ref, '/admin/users')),
          _buildAdminActionCard('الإدارة المالية', 'العمولات والأرصدة والسحوبات وسجل العمليات', Icons.account_balance_wallet_outlined, AppColors.teal, () => _openSection(context, ref, '/admin/financial')),
        ]),
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(color: AppColors.acceptedBg, borderRadius: BorderRadius.circular(15)),
            child: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.success, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('إجمالي الإيرادات المسجلة', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text('${amount.toStringAsFixed(0)} د.ع', style: const TextStyle(color: AppColors.textPrimary, fontSize: 23, fontWeight: FontWeight.w900)),
            ]),
          ),
        ]),
      );

  Widget _buildAdminActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap, {bool emphasized = false}) => Container(
        margin: const EdgeInsets.only(bottom: 11),
        decoration: BoxDecoration(
          color: emphasized ? AppColors.primaryFixed : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: emphasized ? AppColors.primary.withValues(alpha: .26) : AppColors.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
                ]),
              ),
              const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
            ]),
          ),
        ),
      );
}
