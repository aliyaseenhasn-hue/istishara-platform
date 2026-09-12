import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/styles/priority_visuals.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../domain/entities/booking.dart';
import '../providers/bookings_provider.dart';

enum LawyerConsultationsFilter { active, completed }

class LawyerConsultationsPage extends ConsumerWidget {
  final LawyerConsultationsFilter filter;

  const LawyerConsultationsPage({
    super.key,
    required this.filter,
  });

  bool _matches(Booking booking) {
    switch (filter) {
      case LawyerConsultationsFilter.active:
        return booking.status == 'مؤكد' || booking.status == 'قيد التنفيذ';
      case LawyerConsultationsFilter.completed:
        return booking.status == 'مكتمل';
    }
  }

  List<Booking> _sorted(List<Booking> source) {
    final items = source.where(_matches).toList();
    if (filter == LawyerConsultationsFilter.active) {
      items.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    } else {
      items.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    }
    return items;
  }

  String get _title => filter == LawyerConsultationsFilter.active
      ? 'الاستشارات النشطة'
      : 'الاستشارات المكتملة';

  String get _emptyText => filter == LawyerConsultationsFilter.active
      ? 'لا توجد استشارات نشطة حالياً'
      : 'لا توجد استشارات مكتملة حتى الآن';

  String get _sortHint => filter == LawyerConsultationsFilter.active
      ? 'مرتبة حسب أقرب موعد استحقاق'
      : 'مرتبة حسب أحدث موعد أولاً';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final bookingsAsync = ref.watch(lawyerBookingsProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(_title, style: const TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      body: bookingsAsync.when(
        loading: () => const LoadingWidget(size: 30),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('تعذر تحميل الاستشارات'),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: () => ref.invalidate(lawyerBookingsProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
        data: (bookings) {
          final items = _sorted(bookings);
          return RefreshIndicator(
            color: AppColors.teal,
            onRefresh: () async {
              ref.invalidate(lawyerBookingsProvider);
              await ref.read(lawyerBookingsProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: filter == LawyerConsultationsFilter.active
                        ? const Color(0xFFE8F7F8)
                        : AppColors.acceptedBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (filter == LawyerConsultationsFilter.active
                              ? AppColors.teal
                              : AppColors.success)
                          .withValues(alpha: .25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.sort_rounded,
                        size: 19,
                        color: filter == LawyerConsultationsFilter.active
                            ? AppColors.teal
                            : AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _sortHint,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${items.length}',
                        style: TextStyle(
                          color: filter == LawyerConsultationsFilter.active
                              ? AppColors.teal
                              : AppColors.success,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  _EmptyState(text: _emptyText)
                else
                  ...items.map((booking) => _ConsultationCard(booking: booking)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.event_available_rounded, size: 36, color: scheme.primary),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsultationCard extends ConsumerWidget {
  final Booking booking;
  const _ConsultationCard({required this.booking});

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')} - ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final clientNameAsync = ref.watch(bookingClientNameProvider(booking.id));
    final clientName = clientNameAsync.valueOrNull?.trim();
    final name = clientName != null && clientName.isNotEmpty
        ? clientName
        : 'طالب استشارة';
    final visual = PriorityVisuals.consultation(booking.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Color.alphaBlend(
        visual.accent.withValues(alpha: booking.status == 'قيد التنفيذ' ? .09 : .045),
        scheme.surface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: visual.accent.withValues(alpha: .42),
          width: booking.status == 'قيد التنفيذ' ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/booking-details', extra: booking),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: visual.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(visual.icon, color: visual.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: visual.background,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: visual.accent.withValues(alpha: .25),
                            ),
                          ),
                          child: Text(
                            booking.status,
                            style: TextStyle(
                              color: visual.foreground,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      booking.consultationType ?? 'استشارة قانونية',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.schedule_rounded, size: 15, color: visual.accent),
                        const SizedBox(width: 5),
                        Text(
                          _formatDate(booking.scheduledAt),
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_left_rounded, color: visual.accent),
            ],
          ),
        ),
      ),
    );
  }
}
