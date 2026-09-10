import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/user_facing_error.dart';
import '../../../../shared/widgets/hover_lift.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';

class LawyerAppointmentRequestsCard extends ConsumerWidget {
  const LawyerAppointmentRequestsCard({super.key});

  Future<void> _approve(
    BuildContext context,
    Map<String, dynamic> request,
  ) async {
    final windows = _windows(request['client_windows']);
    final selectable = windows
        .map((window) => _start(window))
        .whereType<DateTime>()
        .where((date) => date.isAfter(DateTime.now().add(const Duration(minutes: 30))))
        .toList(growable: false);

    if (selectable.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا يوجد موعد صالح للموافقة عليه. افتح الطلب واقترح موعداً بديلاً.',
            textAlign: TextAlign.right,
          ),
        ),
      );
      return;
    }

    final selected = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('الموافقة على موعد العميل'),
        content: SizedBox(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'اختر الموعد الذي يناسبك من المواعيد التي حددها العميل. سيُرسل للعميل ليؤكده نهائياً.',
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 12),
              ...selectable.map(
                (date) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FilledButton.tonalIcon(
                    onPressed: () => Navigator.pop(dialogContext, date),
                    icon: const Icon(Icons.event_available_rounded),
                    label: Text(_formatDate(date)),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  context.push('/appointment-requests');
                },
                icon: const Icon(Icons.edit_calendar_outlined),
                label: const Text('اقتراح موعد مختلف'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );

    if (selected == null || !context.mounted) return;

    try {
      await SupabaseConfig.client.rpc(
        'lawyer_respond_custom_appointment_request',
        params: {
          'p_request_id': request['id'],
          'p_options': [
            {'start': selected.toUtc().toIso8601String()},
          ],
          'p_reject_reason': null,
        },
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تمت الموافقة وإرسال الموعد إلى العميل للتأكيد النهائي.',
            textAlign: TextAlign.right,
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            UserFacingError.text(error),
            textAlign: TextAlign.right,
          ),
        ),
      );
    }
  }

  Future<void> _reject(
    BuildContext context,
    Map<String, dynamic> request,
  ) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('رفض طلب الموعد'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(
            labelText: 'سبب الرفض',
            hintText: 'اكتب سبباً مختصراً للعميل',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('تأكيد الرفض'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (reason == null || !context.mounted) return;

    try {
      await SupabaseConfig.client.rpc(
        'lawyer_respond_custom_appointment_request',
        params: {
          'p_request_id': request['id'],
          'p_options': null,
          'p_reject_reason': reason,
        },
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم رفض طلب الموعد وإعادة المبلغ المحجوز إلى العميل.',
            textAlign: TextAlign.right,
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            UserFacingError.text(error),
            textAlign: TextAlign.right,
          ),
        ),
      );
    }
  }

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
        )..sort((a, b) {
            final aWaiting = a['status']?.toString() == 'بانتظار رد المحامي';
            final bWaiting = b['status']?.toString() == 'بانتظار رد المحامي';
            if (aWaiting != bWaiting) return aWaiting ? -1 : 1;
            return _createdAt(b).compareTo(_createdAt(a));
          });

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
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppColors.surface,
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
                                ? '$waitingForLawyer طلب بانتظار موافقتك أو رفضك'
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
                    if (active.isNotEmpty)
                      TextButton(
                        onPressed: () => context.push('/appointment-requests'),
                        child: const Text('عرض الكل'),
                      ),
                  ],
                ),
                if (active.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...active.take(3).map(
                        (request) => _AppointmentPreview(
                          request: request,
                          onApprove: () => _approve(context, request),
                          onReject: () => _reject(context, request),
                          onOpen: () => context.push('/appointment-requests'),
                        ),
                      ),
                  if (active.length > 3) ...[
                    const SizedBox(height: 5),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => context.push('/appointment-requests'),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                        label: Text('عرض ${active.length - 3} طلب آخر'),
                      ),
                    ),
                  ],
                ],
              ],
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

  static List<Map<String, dynamic>> _windows(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static DateTime? _start(Map<String, dynamic> window) {
    return DateTime.tryParse('${window['start'] ?? ''}')?.toLocal();
  }

  static String _formatDate(DateTime date) {
    return DateFormat('EEEE، d MMMM yyyy – hh:mm a', 'ar').format(date);
  }
}

class _AppointmentPreview extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onOpen;

  const _AppointmentPreview({
    required this.request,
    required this.onApprove,
    required this.onReject,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final status = request['status']?.toString() ?? '';
    final waitingForLawyer = status == 'بانتظار رد المحامي';
    final windows = LawyerAppointmentRequestsCard._windows(
      request['client_windows'],
    );
    final packageName = request['package_name']?.toString().trim();
    final price = double.tryParse('${request['price'] ?? 0}') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: waitingForLawyer
              ? AppColors.tertiary.withValues(alpha: .20)
              : AppColors.outlineVariant,
        ),
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
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: waitingForLawyer
                      ? AppColors.tertiary.withValues(alpha: .10)
                      : AppColors.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  waitingForLawyer
                      ? 'بانتظار ردك'
                      : 'بانتظار تأكيد العميل',
                  style: TextStyle(
                    color: waitingForLawyer
                        ? AppColors.tertiary
                        : AppColors.primary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${price.toStringAsFixed(0)} د.ع • ${request['duration_minutes'] ?? 30} دقيقة • ${request['consultation_type'] ?? 'استشارة'}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (windows.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'المواعيد التي حددها العميل:',
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
          const SizedBox(height: 10),
          if (waitingForLawyer)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('رفض'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('موافقة'),
                  ),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.schedule_send_rounded, size: 18),
              label: const Text('عرض حالة الطلب'),
            ),
        ],
      ),
    );
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
