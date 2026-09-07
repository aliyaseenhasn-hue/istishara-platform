import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/hover_lift.dart';
import '../../../../shared/widgets/lawyer_more_menu_button.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../bookings/domain/entities/booking.dart';
import '../../../bookings/presentation/providers/bookings_provider.dart';
import '../../domain/entities/lawyer_profile.dart';
import '../providers/lawyers_provider.dart';

class LawyerDashboardPage extends ConsumerWidget {
  const LawyerDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateChangesProvider).value;
    final bookings = ref.watch(lawyerBookingsProvider);
    final profileIdAsync = ref.watch(currentProfileIdProvider);
    final profileAsync = profileIdAsync.when(
      data: (id) => id == null ? const AsyncValue<LawyerProfile?>.data(null) : ref.watch(ownLawyerProfileProvider(id)),
      loading: () => const AsyncValue.loading(),
      error: (e, st) => AsyncValue.error(e, st),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 66,
        leading: const Padding(padding: EdgeInsetsDirectional.only(start: 14), child: LawyerMoreMenuButton()),
        title: const Text('الرئيسية', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        actions: [IconButton(tooltip: 'تعديل الملف المهني', onPressed: () => context.push('/lawyer-profile-edit'), icon: const Icon(Icons.edit_outlined))],
      ),
      body: bookings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('تعذر تحميل البيانات')),
        data: (items) {
          final completed = items.where((b) => b.status == 'مكتمل').length;
          final active = items.where((b) => b.status == 'مؤكد' || b.status == 'قيد التنفيذ').length;
          final total = items.fold<double>(0, (sum, booking) => sum + booking.price);
          final profile = profileAsync.value;
          final registeredName = user?.fullName?.trim();
          final profileName = profile?.fullName?.trim();
          final name = registeredName != null && registeredName.isNotEmpty ? registeredName : (profileName != null && profileName.isNotEmpty ? profileName : 'أستاذ قانون');
          final specialization = profile?.specializations.isNotEmpty == true ? profile!.specializations.join('، ') : 'محامي ومستشار قانوني';
          final license = profile?.practiceLicenseClass;
          final avatar = user?.avatarUrl;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(lawyerBookingsProvider);
              if (profileIdAsync.value != null) ref.invalidate(ownLawyerProfileProvider(profileIdAsync.value!));
              await Future<void>.delayed(const Duration(milliseconds: 250));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
              children: [
                _ProfileHero(name: name, specialization: specialization, license: license, avatarUrl: avatar, onTap: () => context.push('/lawyer-profile-edit')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _MetricCard(value: '$active', label: 'استشارات نشطة', icon: Icons.forum_rounded, background: AppColors.tertiary, foreground: Colors.white)),
                  const SizedBox(width: 9),
                  Expanded(child: _MetricCard(value: '$completed', label: 'استشارات مكتملة', icon: Icons.task_alt_rounded, background: AppColors.success, foreground: Colors.white)),
                ]),
                const SizedBox(height: 9),
                _MoneyCard(total: total),
                const SizedBox(height: 14),
                _ProfessionalProfileCard(onTap: () => context.push('/lawyer-profile-edit')),
                const SizedBox(height: 16),
                Row(children: [
                  const Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Icon(Icons.inbox_outlined, color: AppColors.primary, size: 21),
                    SizedBox(width: 7),
                    Text('طلبات الاستشارة الواردة', textAlign: TextAlign.right, style: TextStyle(color: AppColors.textPrimary, fontSize: 19, fontWeight: FontWeight.w900)),
                  ])),
                  Text('${items.length} طلب', style: const TextStyle(color: AppColors.tertiary, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 8),
                if (items.isEmpty) const _EmptyState() else ...items.take(5).map((b) => _BookingCard(booking: b)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final String name;
  final String specialization;
  final String? license;
  final String? avatarUrl;
  final VoidCallback onTap;
  const _ProfileHero({required this.name, required this.specialization, required this.license, required this.avatarUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      borderRadius: 24,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [AppColors.primary, AppColors.primaryContainer]),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primaryLight.withValues(alpha: .32)),
        ),
        child: Column(children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 92,
              height: 92,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .12), border: Border.all(color: Colors.white.withValues(alpha: .70), width: 2)),
              child: CircleAvatar(
                backgroundColor: AppColors.surfaceContainerHighest,
                backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty ? NetworkImage(avatarUrl!) : null,
                child: avatarUrl == null || avatarUrl!.isEmpty ? Text(name.substring(0, 1), style: const TextStyle(color: AppColors.primary, fontSize: 34, fontWeight: FontWeight.w900)) : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(99)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.gavel_rounded, color: Colors.white, size: 15),
              SizedBox(width: 5),
              Text('محامي', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
            ]),
          ),
          const SizedBox(height: 5),
          Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900, height: 1.2)),
          const SizedBox(height: 4),
          Text(specialization, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: .84), fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.4)),
          if (license != null && license!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.tertiary.withValues(alpha: .76), borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.verified_user_outlined, color: Colors.white, size: 15),
                const SizedBox(width: 5),
                Text('الصلاحية: ${license == 'مطلقة' ? 'مطلقة' : 'الفئة $license'}', style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900)),
              ]),
            ),
          ],
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: onTap,
            style: ButtonStyle(
              foregroundColor: const WidgetStatePropertyAll(Colors.white),
              overlayColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: .10)),
            ),
            icon: const Icon(Icons.edit_rounded, size: 17),
            label: const Text('عرض وتعديل الملف', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  const _MetricCard({required this.value, required this.label, required this.icon, required this.background, required this.foreground});

  @override
  Widget build(BuildContext context) => HoverLift(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(18)),
          child: Column(children: [
            Icon(icon, color: foreground, size: 23),
            const SizedBox(height: 5),
            Text(value, style: TextStyle(color: foreground, fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: TextStyle(color: foreground.withValues(alpha: .92), fontSize: 10.5, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

class _MoneyCard extends StatelessWidget {
  final double total;
  const _MoneyCard({required this.total});

  @override
  Widget build(BuildContext context) => HoverLift(
        borderRadius: 20,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.outlineVariant)),
          child: Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 25)),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('إجمالي مبالغ الاستشارات', textAlign: TextAlign.right, style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text('${total.toStringAsFixed(0)} د.ع', textAlign: TextAlign.right, style: const TextStyle(color: AppColors.primary, fontSize: 23, fontWeight: FontWeight.w900)),
            ])),
          ]),
        ),
      );
}

class _ProfessionalProfileCard extends StatelessWidget {
  final VoidCallback onTap;
  const _ProfessionalProfileCard({required this.onTap});

  @override
  Widget build(BuildContext context) => HoverLift(
        borderRadius: 20,
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            hoverColor: AppColors.primary.withValues(alpha: .05),
            focusColor: AppColors.primary.withValues(alpha: .07),
            splashColor: AppColors.primary.withValues(alpha: .10),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.outlineVariant)),
              child: Row(children: [
                Container(width: 46, height: 46, decoration: BoxDecoration(color: AppColors.secondaryContainer, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.badge_outlined, color: AppColors.primary)),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('ملفي المهني', textAlign: TextAlign.right, style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
                  SizedBox(height: 4),
                  Text('تعديل البيانات والتخصص والباقات وأوقات التوفر', textAlign: TextAlign.right, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ])),
                const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
              ]),
            ),
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => HoverLift(
        child: Container(
          padding: const EdgeInsets.all(23),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.outlineVariant)),
          child: const Column(children: [
            Icon(Icons.event_available_rounded, color: AppColors.tertiary, size: 34),
            SizedBox(height: 8),
            Text('لا توجد طلبات استشارة حالياً', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

class _BookingCard extends ConsumerWidget {
  final Booking booking;
  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientNameAsync = ref.watch(bookingClientNameProvider(booking.id));
    final clientName = clientNameAsync.value?.trim();
    final title = clientName != null && clientName.isNotEmpty ? clientName : 'اسم طالب الاستشارة غير متوفر';

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: HoverLift(
        borderRadius: 16,
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            hoverColor: AppColors.primary.withValues(alpha: .05),
            focusColor: AppColors.primary.withValues(alpha: .07),
            splashColor: AppColors.primary.withValues(alpha: .10),
            onTap: () => context.push('/booking-details', extra: booking),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.outlineVariant)),
              child: Row(children: [
                Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .09), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.description_outlined, color: AppColors.primary, size: 21)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(title, textDirection: TextDirection.rtl, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.textSecondary, size: 14),
                    const SizedBox(width: 4),
                    Text(booking.status, textDirection: TextDirection.rtl, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ]),
                ])),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
