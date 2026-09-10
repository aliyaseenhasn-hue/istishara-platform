import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/hover_lift.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';

class LawyerAppointmentRequestsCard extends ConsumerWidget {
  const LawyerAppointmentRequestsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileId = ref.watch(currentProfileIdProvider).valueOrNull;
    if (profileId == null || profileId.isEmpty) {
      return const SizedBox.shrink();
    }

    final stream = SupabaseConfig.client
        .from('custom_appointment_requests')
        .stream(primaryKey: ['id'])
        .eq('lawyer_id', profileId);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final rows = List<Map<String, dynamic>>.from(
          snapshot.data ?? const <Map<String, dynamic>>[],
        )..sort((a, b) => _createdAt(b).compareTo(_createdAt(a)));
        final active = rows
            .where((row) {
              final status = row['status']?.toString() ?? '';
              return status == 'بانتظار رد المحامي' ||
                  status == 'بانتظار اختيار العميل';
            })
            .toList(growable: false);
        final waitingForLawyer = active
            .where((row) => row['status']?.toString() == 'بانتظار رد المحامي')
            .length;

        return HoverLift(
          borderRadius: 20,
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () => context.push('/appointment-requests'),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: waitingForLawyer > 0
                        ? AppColors.tertiary.withValues(alpha: .42)
                        : AppColors.outlineVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.tertiary.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.edit_calendar_rounded,
                            color: AppColors.tertiary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'طلبات المواعيد الخاصة',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                waitingForLawyer > 0
                                    ? '$waitingForLawyer طلب بانتظار ردك'
                                    : active.isNotEmpty
                                        ? '${active.length} طلب جارٍ'
                                        : 'لا توجد طلبات مواعيد بانتظار الرد',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_left_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                    if (active.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ...active.take(2).map(_AppointmentPreview.new),
                      if (active.length > 2) ...[
                        const SizedBox(height: 5),
                        Text(
                          '+ ${active.length - 2} طلب آخر',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: AppColors.tertiary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static DateTime _createdAt(Map<String, dynamic> row) {
    return DateTime.tryParse('${row['created_at'] ?? ''}') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class _AppointmentPreview extends StatelessWidget {
  final Map<String, dynamic> request;
  const _AppointmentPreview(this.request);

  @override
  Widget build(BuildContext context) {
    final status = request['status']?.toString() ?? '';
    final windows = _windows(request['client_windows']);
    final packageName = request['package_name']?.toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  packageName == null || packageName.isEmpty
                      ? 'استشارة قانونية'
                      : packageName,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                status == 'بانتظار رد المحامي'
                    ? 'بانتظار ردك'
                    : 'بانتظار اختيار العميل',
                style: TextStyle(
                  color: status == 'بانتظار رد المحامي'
                      ? AppColors.tertiary
                      : AppColors.primary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (windows.isNotEmpty) ...[
            const SizedBox(height: 7),
            const Text(
              'الفترات التي حددها العميل:',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            ...windows.take(3).map(
              (window) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  _formatWindow(window),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static List<Map<String, dynamic>> _windows(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static String _formatWindow(Map<String, dynamic> window) {
    final start = DateTime.tryParse('${window['start'] ?? ''}')?.toLocal();
    final end = DateTime.tryParse('${window['end'] ?? ''}')?.toLocal();
    if (start == null || end == null) return 'فترة غير صالحة';
    final startText = DateFormat('EEEE d/M • hh:mm a', 'ar').format(start);
    final endText = DateFormat('hh:mm a', 'ar').format(end);
    return '$startText — $endText';
  }
}
