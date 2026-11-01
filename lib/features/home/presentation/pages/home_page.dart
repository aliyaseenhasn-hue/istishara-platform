import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/legal_specializations.dart';
import '../../../../core/utils/app_time_format.dart';
import '../../../../core/utils/booking_status_text.dart';
import '../../../../shared/widgets/hover_lift.dart';
import '../../../../shared/widgets/safe_network_avatar.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../bookings/domain/entities/booking.dart';
import '../../../bookings/presentation/providers/bookings_provider.dart';
import '../../../bookings/presentation/widgets/consultation_fee_and_chat.dart';
import '../../../lawyers/domain/entities/lawyer_profile.dart';
import '../../../lawyers/presentation/providers/lawyers_provider.dart';
import '../../../payments/presentation/providers/client_wallet_provider.dart';
import '../../../profile/presentation/providers/notifications_provider.dart';
import '../providers/client_home_stats_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static const int _specializationsPreviewCount = 6;
  bool _showAllSpecializations = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateChangesProvider).value;
    final liveAvatar = ref.watch(clientHomeAvatarUrlProvider);
    final lawyers = ref.watch(lawyersListProvider);
    final unread = ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;
    final wallet = ref.watch(clientWalletProvider);
    final categories = LegalSpecializations.all;
    final visibleCategories = _showAllSpecializations
        ? categories
        : categories.take(_specializationsPreviewCount).toList(growable: false);
    final hiddenCategoriesCount =
        (categories.length - _specializationsPreviewCount).clamp(0, categories.length);
    final registeredName = user?.fullName?.trim();
    final name = registeredName != null && registeredName.isNotEmpty
        ? registeredName
        : 'طالب استشارة';
    final liveAvatarUrl = liveAvatar.valueOrNull?.trim();
    final cachedAvatarUrl = user?.avatarUrl?.trim();
    final avatarUrl = liveAvatarUrl != null && liveAvatarUrl.isNotEmpty
        ? liveAvatarUrl
        : cachedAvatarUrl;

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
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: .25),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: .12),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.asset(
                                'assets/icons/app_icon_v2.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'استشارة',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  'مساحتك للاستشارات القانونية',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _NotificationBell(
                      unreadCount: unread,
                      onTap: () => context.push('/notifications'),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              sliver: SliverToBoxAdapter(
                child: _ClientProfileHeader(name: name, avatarUrl: avatarUrl),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 10),
              sliver: SliverToBoxAdapter(
                child: _UpcomingConsultationCard(),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
              sliver: SliverToBoxAdapter(
                child: _ClientWalletCard(
                  wallet: wallet,
                  onTap: () => context.push('/client-wallet'),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 3),
              sliver: SliverToBoxAdapter(
                child: _SectionTitle(
                  title: 'التخصصات القانونية',
                  action: 'كل المحامين',
                  onTap: () => context.push('/lawyers'),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 9),
              sliver: SliverToBoxAdapter(
                child: _LawyerSearchButton(
                  onTap: () => context.push('/lawyers'),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final category = visibleCategories[index];
                    return _AnimatedCategoryCard(
                      index: index,
                      title: category,
                      onTap: () {
                        ref
                            .read(selectedCategoryProvider.notifier)
                            .setCategory(category);
                        context.push('/lawyers');
                      },
                    );
                  },
                  childCount: visibleCategories.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                  childAspectRatio: .88,
                ),
              ),
            ),
            if (categories.length > _specializationsPreviewCount)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                sliver: SliverToBoxAdapter(
                  child: _SpecializationsToggleButton(
                    expanded: _showAllSpecializations,
                    hiddenCount: hiddenCategoriesCount,
                    onTap: () {
                      setState(
                        () => _showAllSpecializations =
                            !_showAllSpecializations,
                      );
                    },
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 5),
              sliver: SliverToBoxAdapter(
                child: _SectionTitle(
                  title: 'محامون مقترحون',
                  action: 'عرض الكل',
                  onTap: () => context.push('/lawyers'),
                ),
              ),
            ),
            lawyers.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (_, __) => const SliverToBoxAdapter(
                child: _EmptyState(
                  icon: Icons.cloud_off_rounded,
                  text: 'تعذر تحميل المحامين حالياً',
                ),
              ),
              data: (items) => items.isEmpty
                  ? const SliverToBoxAdapter(
                      child: _EmptyState(
                        icon: Icons.person_search_outlined,
                        text: 'لا يوجد محامون موثقون حالياً',
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 4,
                          ),
                          child: _SuggestedLawyerCard(
                            lawyer: items[index] as LawyerProfile,
                          ),
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

class _ClientWalletCard extends StatelessWidget {
  final AsyncValue<ClientWalletSummary> wallet;
  final VoidCallback onTap;

  const _ClientWalletCard({
    required this.wallet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: HoverLift(
            borderRadius: 17,
            child: Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(17),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(17),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: wallet.when(
                          loading: () => const Text(
                            'المحفظة',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          error: (_, __) => const Text(
                            'فتح المحفظة',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          data: (value) => Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'الرصيد المتاح',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                '${value.availableBalance.toStringAsFixed(0)} د.ع',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_left_rounded,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ClientProfileHeader extends StatelessWidget {
  final String name;
  final String? avatarUrl;

  const _ClientProfileHeader({required this.name, required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        SafeNetworkAvatar(
          key: ValueKey(avatarUrl),
          imageUrl: avatarUrl,
          radius: 24,
          backgroundColor: AppColors.surfaceContainerHighest,
          iconColor: AppColors.primary,
          iconSize: 26,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'أهلاً، $name',
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'اطلب استشارتك القانونية بسهولة وأمان',
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The client's next consultation, or a short prompt to book one.
class _UpcomingConsultationCard extends ConsumerWidget {
  const _UpcomingConsultationCard();

  static Booking? _next(List<Booking> bookings) {
    final now = DateTime.now();
    final active = bookings.where((b) {
      if (!BookingStatusText.isActive(b.status)) return false;
      if (b.status.trim() == 'قيد التنفيذ') return true;
      final ends = b.scheduledAt
          .toLocal()
          .add(Duration(minutes: b.packageDurationMinutes < 1 ? 30 : b.packageDurationMinutes));
      return ends.isAfter(now);
    }).toList()
      ..sort((a, b) {
        final aLive = a.status.trim() == 'قيد التنفيذ' ? 0 : 1;
        final bLive = b.status.trim() == 'قيد التنفيذ' ? 0 : 1;
        if (aLive != bLive) return aLive.compareTo(bLive);
        return a.scheduledAt.compareTo(b.scheduledAt);
      });
    return active.isEmpty ? null : active.first;
  }

  static String _date(DateTime value) {
    final d = value.toLocal();
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} • ${AppTimeFormat.time12(d)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(userBookingsProvider);
    if (bookings.isLoading && !bookings.hasValue) return const SizedBox.shrink();
    final booking = _next(bookings.valueOrNull ?? const <Booking>[]);

    if (booking == null) {
      return Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/lawyers'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Row(
              textDirection: TextDirection.rtl,
              children: [
                Icon(Icons.event_available_outlined, color: AppColors.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'لا توجد استشارة قادمة. اختر محامياً واحجز موعدك.',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      );
    }

    final info = (booking.lawyerName?.trim().isNotEmpty ?? false)
        ? null
        : ref.watch(bookingLawyerInfoProvider(booking.id)).valueOrNull;
    final lawyerName = (booking.lawyerName?.trim().isNotEmpty ?? false)
        ? booking.lawyerName!.trim()
        : (info?['full_name']?.toString().trim().isNotEmpty ?? false)
            ? info!['full_name'].toString().trim()
            : 'المحامي';
    final live = booking.status.trim() == 'قيد التنفيذ';
    final nextStep = BookingStatusText.nextStep(booking.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: Text(
                  live ? 'استشارتك جارية الآن' : 'استشارتك القادمة',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  BookingStatusText.label(booking.status),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            lawyerName,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _date(booking.scheduledAt),
            textAlign: TextAlign.right,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          if (nextStep != null) ...[
            const SizedBox(height: 6),
            Text(
              nextStep,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (live) InAppConsultationButton(bookingId: booking.id),
          OutlinedButton(
            onPressed: () => context.push('/booking-details', extra: booking),
            child: const Text('عرض التفاصيل'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback onTap;

  const _SectionTitle({
    required this.title,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 30),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(
              action,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
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
        label: const Text(
          'ابحث عن محامٍ',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
        ),
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused) ||
                states.contains(WidgetState.pressed)) {
              return AppColors.primaryLight;
            }
            return AppColors.primary;
          }),
          overlayColor:
              WidgetStatePropertyAll(Colors.white.withValues(alpha: .08)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}

class _SpecializationsToggleButton extends StatelessWidget {
  final bool expanded;
  final int hiddenCount;
  final VoidCallback onTap;

  const _SpecializationsToggleButton({
    required this.expanded,
    required this.hiddenCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      lift: 2,
      borderRadius: 16,
      child: Material(
        color: AppColors.primary.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.primary.withValues(alpha: .10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: .20),
              ),
            ),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: AnimatedRotation(
                    turns: expanded ? .5 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        expanded
                            ? 'عرض تخصصات أقل'
                            : 'عرض المزيد من التخصصات',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        expanded
                            ? 'إخفاء التخصصات الإضافية لتبسيط الصفحة'
                            : '$hiddenCount تخصصاً إضافياً',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  expanded
                      ? Icons.unfold_less_rounded
                      : Icons.grid_view_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedCategoryCard extends StatelessWidget {
  final int index;
  final String title;
  final VoidCallback onTap;

  const _AnimatedCategoryCard({
    required this.index,
    required this.title,
    required this.onTap,
  });

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
    const colors = <Color>[
      Color(0xFF8E24AA),
      Color(0xFF43A047),
      Color(0xFF1E88E5),
      Color(0xFFFB8C00),
      Color(0xFFE53935),
      Color(0xFF795548),
      Color(0xFFFF9800),
      Color(0xFFD81B60),
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor();
    return HoverLift(
      lift: 3,
      borderRadius: 18,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: accent.withValues(alpha: .08),
          hoverColor: accent.withValues(alpha: .035),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .075),
                        blurRadius: 18,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(_iconFor(title), color: accent, size: 34),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 30,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
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
    final name = lawyer.fullName?.trim().isNotEmpty == true
        ? lawyer.fullName!.trim()
        : 'محامٍ';
    final specialization = lawyer.specializations.isNotEmpty
        ? lawyer.specializations.take(2).join('، ')
        : 'استشارات قانونية';
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
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                SafeNetworkAvatar(
                  imageUrl: hasAvatar ? lawyer.avatarUrl : null,
                  radius: 22,
                  backgroundColor: AppColors.primary.withValues(alpha: .10),
                  iconColor: AppColors.primary,
                  iconSize: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Icon(
                            Icons.verified_user_outlined,
                            color: AppColors.primary,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              name,
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        specialization,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: AppColors.tertiary,
                            size: 14,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            lawyer.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            '${lawyer.reviewCount} تقييم',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                const Icon(
                  Icons.chevron_left_rounded,
                  color: AppColors.textSecondary,
                  size: 21,
                ),
              ],
            ),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 32),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
