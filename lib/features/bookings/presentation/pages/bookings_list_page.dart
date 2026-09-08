import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/bookings_provider.dart';

class BookingsListPage extends ConsumerWidget {
  const BookingsListPage({super.key});

  static bool _canArchive(String status) {
    final value = status.trim();
    return const {'مكتمل', 'ملغي', 'مسترد', 'مرفوض'}.contains(value);
  }

  static bool _needsLawyerReview(String status) {
    final value = status.trim();
    if (value.contains('رفض') || value.contains('إلغاء') || value == 'مكتمل' || value == 'قيد التنفيذ' || value == 'مؤكد' || value == 'مقبول') {
      return false;
    }
    return value.contains('انتظار') || value.contains('معلق') || value.contains('جديد') || value.contains('طلب') || value.isEmpty;
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')} - ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
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
        content: const Text('سيتم إخفاء الاستشارة من قائمتك فقط مع الاحتفاظ بسجلها وبياناتها في النظام.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(bookingsControllerProvider.notifier).archiveBooking(bookingId, isLawyer: isLawyer);
    if (!context.mounted) return;
    final state = ref.read(bookingsControllerProvider);
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حذف الاستشارة حالياً.')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حذف الاستشارة من القائمة.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authStateChangesProvider);
    final isLawyer = auth.maybeWhen(data: (user) => user?.role == 'lawyer', orElse: () => false);
    final bookingsAsync = isLawyer ? ref.watch(lawyerBookingsProvider) : ref.watch(userBookingsProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(isLawyer ? 'الاستشارات الواردة' : 'استشاراتي'),
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      body: bookingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('تعذر تحميل الاستشارات', style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextButton.icon(
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
          ]),
        ),
        data: (bookings) {
          if (bookings.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(20)),
                    child: Icon(Icons.inbox_outlined, color: scheme.onPrimaryContainer, size: 34),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isLawyer ? 'لا توجد استشارات واردة حالياً' : 'ليس لديك أي حجوزات حالياً',
                    style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurface),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isLawyer ? 'ستظهر طلبات طالبي الاستشارة هنا فور وصولها.' : 'ستظهر هنا الاستشارات عند توفرها.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.push(isLawyer ? '/lawyer-availability' : '/lawyers'),
                    icon: Icon(isLawyer ? Icons.schedule_rounded : Icons.search_rounded),
                    label: Text(isLawyer ? 'إدارة أوقات التوفر' : 'استعرض المحامين'),
                  ),
                ]),
              ),
            );
          }

          final pendingCount = isLawyer ? bookings.where((booking) => _needsLawyerReview(booking.status)).length : 0;

          return RefreshIndicator(
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
                  return _IncomingSummary(total: bookings.length, pending: pendingCount);
                }

                final bookingIndex = isLawyer ? index - 1 : index;
                final booking = bookings[bookingIndex];
                final canArchive = _canArchive(booking.status);

                return Consumer(builder: (context, ref, child) {
                  final clientNameAsync = isLawyer ? ref.watch(bookingClientNameProvider(booking.id)) : null;
                  final lawyerInfoAsync = !isLawyer ? ref.watch(bookingLawyerInfoProvider(booking.id)) : null;
                  final rpcName = lawyerInfoAsync?.valueOrNull?['full_name']?.toString().trim();
                  final bookingName = booking.lawyerName?.trim();
                  final displayName = isLawyer
                      ? clientNameAsync!.maybeWhen(
                          data: (name) => name != null && name.trim().isNotEmpty ? name.trim() : 'طالب استشارة',
                          loading: () => 'جاري تحميل الاسم...',
                          orElse: () => 'طالب استشارة',
                        )
                      : (bookingName != null && bookingName.isNotEmpty
                          ? bookingName
                          : (rpcName != null && rpcName.isNotEmpty ? rpcName : 'اسم المحامي غير متوفر'));
                  final lawyerAvatar = lawyerInfoAsync?.valueOrNull?['avatar_url']?.toString();

                  if (isLawyer) {
                    return _IncomingBookingCard(
                      name: displayName,
                      status: booking.status,
                      consultationType: booking.consultationType ?? 'استشارة قانونية',
                      scheduledAt: booking.scheduledAt,
                      onTap: () => context.push('/booking-details', extra: booking),
                      onDelete: canArchive
                          ? () => _archiveBooking(context, ref, bookingId: booking.id, isLawyer: true)
                          : null,
                    );
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: scheme.surfaceContainerLowest,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: scheme.outlineVariant)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => context.push('/booking-details', extra: booking),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Column(children: [
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: scheme.surfaceContainerHigh,
                              backgroundImage: lawyerAvatar != null && lawyerAvatar.isNotEmpty ? NetworkImage(lawyerAvatar) : null,
                              child: lawyerAvatar == null || lawyerAvatar.isEmpty ? Icon(Icons.person_outline, color: scheme.primary) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(child: Text(displayName, textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: scheme.onSurface))),
                                  const SizedBox(width: 8),
                                  _StatusChip(status: booking.status),
                                ]),
                                const SizedBox(height: 6),
                                Text(booking.consultationType ?? 'استشارة قانونية', textAlign: TextAlign.right, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                                const SizedBox(height: 5),
                                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                  Icon(Icons.schedule_rounded, size: 15, color: scheme.onSurfaceVariant),
                                  const SizedBox(width: 4),
                                  Flexible(child: Text(_formatDate(booking.scheduledAt), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12))),
                                ]),
                              ]),
                            ),
                            const SizedBox(width: 6),
                            Padding(padding: const EdgeInsets.only(top: 16), child: Icon(Icons.chevron_left_rounded, color: scheme.onSurfaceVariant)),
                          ]),
                          if (canArchive) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => _archiveBooking(context, ref, bookingId: booking.id, isLawyer: false),
                                icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                                label: Text('حذف من القائمة', style: TextStyle(color: scheme.error, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ]),
                      ),
                    ),
                  );
                });
              },
            ),
          );
        },
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
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: .48),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary.withValues(alpha: .16)),
      ),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(14)),
          child: Icon(Icons.inbox_rounded, color: scheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('طلبات الاستشارة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: scheme.onSurface)),
            const SizedBox(height: 3),
            Text(
              pending > 0 ? '$pending بانتظار مراجعتك من أصل $total' : '$total استشارة واردة',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _IncomingBookingCard extends StatelessWidget {
  final String name;
  final String status;
  final String consultationType;
  final DateTime scheduledAt;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _IncomingBookingCard({
    required this.name,
    required this.status,
    required this.consultationType,
    required this.scheduledAt,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final needsReview = BookingsListPage._needsLawyerReview(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: needsReview ? scheme.primary.withValues(alpha: .38) : scheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: needsReview ? scheme.primaryContainer : scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.person_outline_rounded, color: needsReview ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, textAlign: TextAlign.right, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: scheme.onSurface)),
                  const SizedBox(height: 3),
                  Text('طالب الاستشارة', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ]),
              ),
              const SizedBox(width: 10),
              _StatusChip(status: status),
            ]),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                _InfoLine(icon: Icons.gavel_rounded, label: 'نوع الاستشارة', value: consultationType),
                const SizedBox(height: 10),
                _InfoLine(icon: Icons.schedule_rounded, label: 'الموعد', value: BookingsListPage._formatDate(scheduledAt)),
              ]),
            ),
            if (needsReview) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: scheme.secondaryContainer.withValues(alpha: .62), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Icon(Icons.notifications_active_outlined, size: 19, color: scheme.onSecondaryContainer),
                  const SizedBox(width: 8),
                  Expanded(child: Text('هذا الطلب بانتظار مراجعتك', style: TextStyle(color: scheme.onSecondaryContainer, fontWeight: FontWeight.w800, fontSize: 12.5))),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            Row(children: [
              if (onDelete != null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                    label: Text('حذف', style: TextStyle(color: scheme.error, fontWeight: FontWeight.w800)),
                    style: OutlinedButton.styleFrom(side: BorderSide(color: scheme.error.withValues(alpha: .55)), padding: const EdgeInsets.symmetric(vertical: 13)),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.visibility_outlined, size: 19),
                  label: const Text('عرض التفاصيل'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoLine({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      Icon(icon, size: 18, color: scheme.primary),
      const SizedBox(width: 8),
      Text('$label:', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
      const SizedBox(width: 6),
      Expanded(child: Text(value, textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: scheme.onSurface, fontWeight: FontWeight.w700))),
    ]);
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final normalized = status.trim();
    Color background;
    Color foreground;
    if (normalized == 'مؤكد' || normalized == 'مكتمل' || normalized == 'قيد التنفيذ' || normalized == 'مقبول') {
      background = AppColors.acceptedBg;
      foreground = AppColors.acceptedText;
    } else if (normalized.contains('إلغاء') || normalized.contains('رفض') || normalized.contains('عدم حضور')) {
      background = AppColors.cancelledBg;
      foreground = AppColors.cancelledText;
    } else {
      background = scheme.secondaryContainer;
      foreground = scheme.onSecondaryContainer;
    }
    final label = normalized.isEmpty ? 'بانتظار المراجعة' : normalized;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999), border: Border.all(color: scheme.outlineVariant.withValues(alpha: .5))),
      child: Text(label, style: TextStyle(color: foreground, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }
}
