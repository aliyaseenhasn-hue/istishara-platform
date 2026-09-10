import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/styles/priority_visuals.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../domain/entities/booking.dart';
import '../providers/booking_timing_provider.dart';
import '../providers/bookings_provider.dart';

class BookingsListPage extends ConsumerWidget {
  const BookingsListPage({super.key});

  static bool _canArchive(String status) {
    final value = status.trim();
    return const {'مكتمل', 'ملغي', 'مسترد', 'مرفوض'}.contains(value);
  }

  static bool _awaitsAdminReview(String status) {
    final value = status.trim();
    return value == 'بانتظار مراجعة الإدارة' ||
        value == 'بانتظار مراجعة عدم الحضور' ||
        value == 'بانتظار الاسترداد';
  }

  static bool _needsLawyerReview(String status) {
    final value = status.trim();
    if (_awaitsAdminReview(value)) return false;
    if (value.contains('رفض') ||
        value.contains('إلغاء') ||
        value == 'مكتمل' ||
        value == 'قيد التنفيذ' ||
        value == 'مؤكد' ||
        value == 'مقبول') {
      return false;
    }
    return value.contains('انتظار') ||
        value.contains('معلق') ||
        value.contains('جديد') ||
        value.contains('طلب') ||
        value.isEmpty;
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')} - ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  static DateTime? _dateFrom(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  static String _friendlyError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final match = RegExp(r'message:\s*([^,\)]+)', caseSensitive: false)
        .firstMatch(raw);
    return match?.group(1)?.trim() ??
        (raw.isEmpty ? 'تعذر تنفيذ العملية حالياً.' : raw);
  }

  Future<void> _archiveBooking(
    BuildContext context,
    WidgetRef ref, {
    required String bookingId,
    required bool isLawyer,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الاستشارة من القائمة؟'),
        content: const Text(
          'سيتم إخفاء الاستشارة من قائمتك فقط مع الاحتفاظ بسجلها وبياناتها في النظام.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref
        .read(bookingsControllerProvider.notifier)
        .archiveBooking(bookingId, isLawyer: isLawyer);
    if (!context.mounted) return;
    final state = ref.read(bookingsControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.hasError
              ? 'تعذر حذف الاستشارة حالياً.'
              : 'تم حذف الاستشارة من القائمة.',
        ),
      ),
    );
  }

  Future<void> _startBooking(
    BuildContext context,
    WidgetRef ref,
    Booking booking,
  ) async {
    try {
      await ref
          .read(bookingsControllerProvider.notifier)
          .updateBookingStatus(booking.id, 'قيد التنفيذ');
      if (!context.mounted) return;
      context.push(
        '/booking-details',
        extra: booking.copyWith(
          status: 'قيد التنفيذ',
          startedAt: DateTime.now(),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authStateChangesProvider);
    final isLawyer = auth.maybeWhen(
      data: (user) => user?.role == 'lawyer',
      orElse: () => false,
    );
    final bookingsAsync = isLawyer
        ? ref.watch(lawyerBookingsProvider)
        : ref.watch(userBookingsProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(isLawyer ? 'الاستشارات الواردة' : 'استشاراتي'),
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      body: bookingsAsync.when(
        loading: () => const LoadingWidget(size: 30),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'تعذر تحميل الاستشارات',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: () {
                  if (isLawyer) {
                    ref.invalidate(lawyerBookingsProvider);
                  } else {
                    ref.invalidate(userBookingsProvider);
                  }
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
        data: (bookings) {
          if (bookings.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.inbox_outlined,
                        color: scheme.onPrimaryContainer,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isLawyer
                          ? 'لا توجد استشارات واردة حالياً'
                          : 'ليس لديك أي حجوزات حالياً',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isLawyer
                          ? 'ستظهر طلبات طالبي الاستشارة هنا فور وصولها.'
                          : 'ستظهر هنا الاستشارات عند توفرها.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => context.push(
                        isLawyer ? '/lawyer-availability' : '/lawyers',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            isLawyer ? AppColors.primary : AppColors.teal,
                        foregroundColor: Colors.white,
                      ),
                      icon: Icon(
                        isLawyer ? Icons.schedule_rounded : Icons.search_rounded,
                      ),
                      label: Text(
                        isLawyer
                            ? 'إدارة أوقات التوفر'
                            : 'استعرض المحامين',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final pendingCount = isLawyer
              ? bookings
                  .where((booking) => _needsLawyerReview(booking.status))
                  .length
              : 0;

          return RefreshIndicator(
            color: AppColors.teal,
            onRefresh: () async {
              if (isLawyer) {
                ref.invalidate(lawyerBookingsProvider);
                await ref.read(lawyerBookingsProvider.future);
              } else {
                ref.invalidate(userBookingsProvider);
                await ref.read(userBookingsProvider.future);
              }
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
              itemCount: bookings.length + (isLawyer ? 1 : 0),
              itemBuilder: (context, index) {
                if (isLawyer && index == 0) {
                  return _IncomingSummary(
                    total: bookings.length,
                    pending: pendingCount,
                  );
                }

                final bookingIndex = isLawyer ? index - 1 : index;
                final booking = bookings[bookingIndex];

                return Consumer(
                  builder: (context, ref, child) {
                    final clientNameAsync = isLawyer
                        ? ref.watch(bookingClientNameProvider(booking.id))
                        : null;
                    final lawyerInfoAsync = !isLawyer
                        ? ref.watch(bookingLawyerInfoProvider(booking.id))
                        : null;
                    final liveTiming = isLawyer
                        ? ref.watch(bookingTimingProvider(booking.id)).valueOrNull
                        : null;

                    final liveStatus =
                        liveTiming?['status']?.toString() ?? booking.status;
                    final liveScheduledAt =
                        _dateFrom(liveTiming?['scheduled_at']) ??
                            booking.scheduledAt;
                    final liveStartedAt = _dateFrom(liveTiming?['started_at']) ??
                        booking.startedAt;
                    final livePaymentConfirmedAt =
                        _dateFrom(liveTiming?['payment_confirmed_at']) ??
                            booking.paymentConfirmedAt;
                    final liveDuration = int.tryParse(
                          '${liveTiming?['package_duration_minutes'] ?? booking.packageDurationMinutes}',
                        ) ??
                        booking.packageDurationMinutes;
                    final effectiveBooking = booking.copyWith(
                      status: liveStatus,
                      scheduledAt: liveScheduledAt,
                      startedAt: liveStartedAt,
                      paymentConfirmedAt: livePaymentConfirmedAt,
                      packageDurationMinutes: liveDuration,
                    );
                    final canArchive = _canArchive(liveStatus);

                    final rpcName = lawyerInfoAsync?.valueOrNull?['full_name']
                        ?.toString()
                        .trim();
                    final bookingName = booking.lawyerName?.trim();
                    final displayName = isLawyer
                        ? clientNameAsync!.maybeWhen(
                            data: (name) =>
                                name != null && name.trim().isNotEmpty
                                    ? name.trim()
                                    : 'طالب استشارة',
                            loading: () => 'جاري تحميل الاسم...',
                            orElse: () => 'طالب استشارة',
                          )
                        : (bookingName != null && bookingName.isNotEmpty
                            ? bookingName
                            : (rpcName != null && rpcName.isNotEmpty
                                ? rpcName
                                : 'اسم المحامي غير متوفر'));
                    final lawyerAvatar =
                        lawyerInfoAsync?.valueOrNull?['avatar_url']?.toString();

                    if (isLawyer) {
                      return _IncomingBookingCard(
                        name: displayName,
                        booking: effectiveBooking,
                        consultationType:
                            booking.consultationType ?? 'استشارة قانونية',
                        onTap: () => context.push(
                          '/booking-details',
                          extra: effectiveBooking,
                        ),
                        onStart: () =>
                            _startBooking(context, ref, effectiveBooking),
                        onDelete: canArchive
                            ? () => _archiveBooking(
                                  context,
                                  ref,
                                  bookingId: booking.id,
                                  isLawyer: true,
                                )
                            : null,
                      );
                    }

                    return _ClientBookingCard(
                      displayName: displayName,
                      lawyerAvatar: lawyerAvatar,
                      booking: effectiveBooking,
                      canArchive: canArchive,
                      onTap: () => context.push(
                        '/booking-details',
                        extra: effectiveBooking,
                      ),
                      onDelete: canArchive
                          ? () => _archiveBooking(
                                context,
                                ref,
                                bookingId: booking.id,
                                isLawyer: false,
                              )
                          : null,
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ClientBookingCard extends StatelessWidget {
  final String displayName;
  final String? lawyerAvatar;
  final Booking booking;
  final bool canArchive;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _ClientBookingCard({
    required this.displayName,
    required this.lawyerAvatar,
    required this.booking,
    required this.canArchive,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visual = PriorityVisuals.consultation(booking.status);
    final important = visual.level >= 3;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Color.alphaBlend(
        visual.accent.withValues(alpha: important ? .075 : .035),
        scheme.surface,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: visual.accent.withValues(alpha: important ? .58 : .32),
          width: important ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: visual.background,
                    backgroundImage:
                        lawyerAvatar != null && lawyerAvatar!.isNotEmpty
                            ? NetworkImage(lawyerAvatar!)
                            : null,
                    child: lawyerAvatar == null || lawyerAvatar!.isEmpty
                        ? Icon(Icons.person_outline, color: visual.accent)
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
                                displayName,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusChip(status: booking.status),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          booking.consultationType ?? 'استشارة قانونية',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 15,
                              color: visual.accent,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                BookingsListPage._formatDate(
                                  booking.scheduledAt,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: visual.accent,
                    ),
                  ),
                ],
              ),
              if (important) ...[
                const SizedBox(height: 11),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: visual.background,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          visual.label,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: visual.foreground,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Icon(visual.icon, color: visual.accent, size: 18),
                    ],
                  ),
                ),
              ],
              if (canArchive && onDelete != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                    ),
                    label: const Text(
                      'حذف من القائمة',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IncomingSummary extends StatelessWidget {
  final int total;
  final int pending;

  const _IncomingSummary({required this.total, required this.pending});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasPending = pending > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasPending
            ? AppColors.pendingBg
            : scheme.primaryContainer.withValues(alpha: .48),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasPending
              ? AppColors.goldDark.withValues(alpha: .34)
              : scheme.primary.withValues(alpha: .16),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              hasPending ? Icons.pending_actions_rounded : Icons.inbox_rounded,
              color: hasPending ? AppColors.goldDark : scheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'طلبات الاستشارة',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasPending
                      ? '$pending بانتظار مراجعتك من أصل $total'
                      : '$total استشارة واردة',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: hasPending
                        ? AppColors.pendingText
                        : scheme.onSurfaceVariant,
                    fontWeight: hasPending ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomingBookingCard extends StatefulWidget {
  final String name;
  final Booking booking;
  final String consultationType;
  final VoidCallback onTap;
  final VoidCallback onStart;
  final VoidCallback? onDelete;

  const _IncomingBookingCard({
    required this.name,
    required this.booking,
    required this.consultationType,
    required this.onTap,
    required this.onStart,
    this.onDelete,
  });

  @override
  State<_IncomingBookingCard> createState() => _IncomingBookingCardState();
}

class _IncomingBookingCardState extends State<_IncomingBookingCard> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant _IncomingBookingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.booking.status != widget.booking.status ||
        oldWidget.booking.scheduledAt != widget.booking.scheduledAt ||
        oldWidget.booking.paymentConfirmedAt !=
            widget.booking.paymentConfirmedAt) {
      _now = DateTime.now();
      _syncTicker();
    }
  }

  void _syncTicker() {
    _timer?.cancel();
    _timer = null;
    if (widget.booking.status != 'مؤكد') return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = widget.booking.status;
    final needsReview = BookingsListPage._needsLawyerReview(status);
    final awaitsAdminReview = BookingsListPage._awaitsAdminReview(status);
    final canStart = widget.booking.canStartAt(_now);
    final visual = canStart
        ? const PriorityVisual(
            accent: AppColors.teal,
            background: Color(0xFFE8F7F8),
            foreground: Color(0xFF23636A),
            icon: Icons.play_circle_fill_rounded,
            label: 'حان موعد الاستشارة',
            level: 4,
          )
        : PriorityVisuals.consultation(status);
    final highlighted = needsReview || awaitsAdminReview || canStart || visual.level >= 3;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Color.alphaBlend(
        visual.accent.withValues(alpha: highlighted ? .075 : .035),
        scheme.surface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: visual.accent.withValues(alpha: highlighted ? .62 : .30),
          width: highlighted ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: visual.background,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      canStart
                          ? Icons.play_circle_outline_rounded
                          : Icons.person_outline_rounded,
                      color: visual.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.name,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'طالب الاستشارة',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StatusChip(status: status),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: .78),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _InfoLine(
                      icon: Icons.gavel_rounded,
                      label: 'نوع الاستشارة',
                      value: widget.consultationType,
                      accent: visual.accent,
                    ),
                    const SizedBox(height: 10),
                    _InfoLine(
                      icon: Icons.schedule_rounded,
                      label: 'الموعد',
                      value: BookingsListPage._formatDate(
                        widget.booking.scheduledAt,
                      ),
                      accent: visual.accent,
                    ),
                  ],
                ),
              ),
              if (highlighted) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: visual.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(visual.icon, size: 19, color: visual.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          canStart
                              ? 'حان موعد الاستشارة — يمكنك البدء الآن'
                              : awaitsAdminReview
                                  ? 'هذا الطلب بانتظار مراجعة الإدارة'
                                  : needsReview
                                      ? 'هذا الطلب بانتظار مراجعتك'
                                      : visual.label,
                          style: TextStyle(
                            color: visual.foreground,
                            fontWeight: FontWeight.w900,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (widget.onDelete != null) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onDelete,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.error,
                        ),
                        label: const Text(
                          'حذف',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: AppColors.error.withValues(alpha: .55),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: canStart ? widget.onStart : widget.onTap,
                      icon: Icon(
                        canStart
                            ? Icons.play_arrow_rounded
                            : Icons.visibility_outlined,
                        size: 20,
                      ),
                      label: Text(
                        canStart ? 'بدء الاستشارة' : 'عرض التفاصيل',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            canStart ? AppColors.teal : AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: accent),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final visual = PriorityVisuals.consultation(status);
    final label = status.trim().isEmpty ? 'بانتظار المراجعة' : status.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: visual.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: visual.accent.withValues(alpha: .28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: visual.foreground,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
