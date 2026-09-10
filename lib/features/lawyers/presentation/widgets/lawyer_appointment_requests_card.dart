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

  Future<void> _sendOptions(
    BuildContext context,
    Map<String, dynamic> request,
    List<DateTime> options,
    String successMessage,
  ) async {
    try {
      await SupabaseConfig.client.rpc(
        'lawyer_respond_custom_appointment_request',
        params: {
          'p_request_id': request['id'],
          'p_options': options
              .map((date) => {'start': date.toUtc().toIso8601String()})
              .toList(growable: false),
          'p_reject_reason': null,
        },
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage, textAlign: TextAlign.right)),
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

  Future<void> _approveClientWindow(
    BuildContext context,
    Map<String, dynamic> request,
  ) async {
    final duration = int.tryParse('${request['duration_minutes'] ?? 30}') ?? 30;
    final windows = _windows(request['client_windows'])
        .map(_dateWindow)
        .whereType<_DateWindow>()
        .where(
          (window) => window.end.isAfter(
            DateTime.now().add(Duration(minutes: duration + 30)),
          ),
        )
        .toList(growable: false);

    if (windows.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لم تعد فترات العميل صالحة. اقترح موعداً بديلاً.',
            textAlign: TextAlign.right,
          ),
        ),
      );
      return;
    }

    final chosenWindow = await showDialog<_DateWindow>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('اختر فترة مناسبة للعميل'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'اختر إحدى الفترات التي حددها العميل، ثم حدد وقت بدء الاستشارة داخلها.',
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 12),
              ...windows.map(
                (window) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FilledButton.tonalIcon(
                    onPressed: () => Navigator.pop(dialogContext, window),
                    icon: const Icon(Icons.event_available_rounded),
                    label: Text(_formatWindowRange(window)),
                  ),
                ),
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

    if (chosenWindow == null || !context.mounted) return;

    final initial = chosenWindow.start.isAfter(DateTime.now().add(const Duration(minutes: 30)))
        ? chosenWindow.start
        : DateTime.now().add(const Duration(minutes: 30));
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'حدد وقت بدء الاستشارة داخل فترة العميل',
    );
    if (time == null || !context.mounted) return;

    final exactStart = DateTime(
      chosenWindow.start.year,
      chosenWindow.start.month,
      chosenWindow.start.day,
      time.hour,
      time.minute,
    );
    final exactEnd = exactStart.add(Duration(minutes: duration));
    final earliestAllowed = DateTime.now().add(const Duration(minutes: 30));

    if (exactStart.isBefore(chosenWindow.start) ||
        exactStart.isBefore(earliestAllowed) ||
        exactEnd.isAfter(chosenWindow.end)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'اختر وقتاً داخل الفترة المحددة، مع مساحة تكفي لمدة الاستشارة ($duration دقيقة).',
            textAlign: TextAlign.right,
          ),
        ),
      );
      return;
    }

    await _sendOptions(
      context,
      request,
      [exactStart],
      'تم قبول موعد من فترة العميل وإرساله له للتأكيد النهائي.',
    );
  }

  Future<DateTime?> _pickAlternativeDateTime(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      locale: const Locale('ar'),
    );
    if (date == null || !context.mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      helpText: 'الموعد البديل المقترح للعميل',
    );
    if (time == null) return null;

    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!value.isAfter(now.add(const Duration(minutes: 30)))) return null;
    return value;
  }

  Future<void> _counterOffer(
    BuildContext context,
    Map<String, dynamic> request,
  ) async {
    final options = <DateTime>[];
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('المواعيد لا تناسبني — اقتراح بديل'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'يمكنك اقتراح من موعد واحد إلى ثلاثة مواعيد بديلة. لن يُلغى الطلب ولن يُعاد المبلغ؛ سينتظر اختيار العميل النهائي.',
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 12),
                ...options.asMap().entries.map(
                  (entry) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: IconButton(
                      onPressed: () => setDialogState(
                        () => options.removeAt(entry.key),
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    title: Text(
                      _formatDate(entry.value),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: options.length >= 3
                      ? null
                      : () async {
                          final value = await _pickAlternativeDateTime(context);
                          if (value != null && !options.contains(value)) {
                            setDialogState(() => options.add(value));
                          } else if (value == null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'اختر موعداً مستقبلياً يبعد أكثر من 30 دقيقة.',
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    options.isEmpty ? 'إضافة موعد بديل' : 'إضافة موعد آخر',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              onPressed: options.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.send_rounded),
              label: const Text('إرسال للعميل'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || options.isEmpty || !context.mounted) return;

    await _sendOptions(
      context,
      request,
      options,
      'تم رفض الفترات الحالية وإرسال المواعيد البديلة إلى العميل.',
    );
  }

  Future<void> _rejectFinal(
    BuildContext context,
    Map<String, dynamic> request,
  ) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('رفض الطلب نهائياً'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'استخدم الرفض النهائي فقط إذا كنت لا تريد قبول الاستشارة. سيُنهي الطلب ويعيد المبلغ المحجوز إلى العميل.',
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 2,
              maxLines: 4,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: 'سبب الرفض',
                hintText: 'اكتب سبباً مختصراً للعميل',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('رفض نهائي'),
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
            'تم رفض الطلب نهائياً وإعادة المبلغ المحجوز إلى العميل.',
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
                                ? '$waitingForLawyer طلب بانتظار قبول موعد أو اقتراح بديل'
                                : active.isNotEmpty
                                    ? '${active.length} طلب بانتظار تأكيد العميل'
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
                          onApprove: () => _approveClientWindow(context, request),
                          onCounterOffer: () => _counterOffer(context, request),
                          onRejectFinal: () => _rejectFinal(context, request),
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

  static _DateWindow? _dateWindow(Map<String, dynamic> window) {
    final start = DateTime.tryParse('${window['start'] ?? ''}')?.toLocal();
    final end = DateTime.tryParse('${window['end'] ?? ''}')?.toLocal();
    if (start == null || end == null || !end.isAfter(start)) return null;
    return _DateWindow(start: start, end: end);
  }

  static String _formatDate(DateTime date) {
    return DateFormat('EEEE، d MMMM yyyy – hh:mm a', 'ar').format(date);
  }

  static String _formatWindowRange(_DateWindow window) {
    final start = DateFormat('EEEE d/M • hh:mm a', 'ar').format(window.start);
    final end = DateFormat('hh:mm a', 'ar').format(window.end);
    return '$start — $end';
  }
}

class _AppointmentPreview extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onApprove;
  final VoidCallback onCounterOffer;
  final VoidCallback onRejectFinal;
  final VoidCallback onOpen;

  const _AppointmentPreview({
    required this.request,
    required this.onApprove,
    required this.onCounterOffer,
    required this.onRejectFinal,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final status = request['status']?.toString() ?? '';
    final waitingForLawyer = status == 'بانتظار رد المحامي';
    final windows = LawyerAppointmentRequestsCard._windows(
      request['client_windows'],
    );
    final lawyerOptions = LawyerAppointmentRequestsCard._windows(
      request['lawyer_options'],
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
          if (!waitingForLawyer && lawyerOptions.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'المواعيد التي أرسلتها للعميل:',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            ...lawyerOptions.take(3).map(
              (option) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  _formatOption(option),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (waitingForLawyer) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCounterOffer,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: const Text('موعد بديل'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('قبول موعد'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: onRejectFinal,
              icon: const Icon(Icons.close_rounded, size: 17),
              label: const Text('رفض الطلب نهائياً'),
            ),
          ] else
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

  static String _formatOption(Map<String, dynamic> option) {
    final start = DateTime.tryParse('${option['start'] ?? ''}')?.toLocal();
    if (start == null) return 'موعد غير صالح';
    return DateFormat('EEEE d/M • hh:mm a', 'ar').format(start);
  }
}

class _DateWindow {
  final DateTime start;
  final DateTime end;

  const _DateWindow({required this.start, required this.end});
}
