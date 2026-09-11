import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/user_facing_error.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../payments/presentation/providers/client_wallet_provider.dart';
import '../providers/bookings_provider.dart';

final _clientHomeAppointmentRequestsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) async* {
  final profileId = await ref.watch(currentProfileIdProvider.future);
  if (profileId == null || profileId.isEmpty) {
    yield const <Map<String, dynamic>>[];
    return;
  }

  yield* SupabaseConfig.client
      .from('custom_appointment_requests')
      .stream(primaryKey: ['id'])
      .eq('user_id', profileId)
      .map((rows) {
        final filtered = rows
            .where(
              (row) =>
                  row['status']?.toString() == 'بانتظار اختيار العميل',
            )
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false);
        filtered.sort((a, b) {
          final ad = DateTime.tryParse(
                '${a['updated_at'] ?? a['created_at']}',
              ) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bd = DateTime.tryParse(
                '${b['updated_at'] ?? b['created_at']}',
              ) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        });
        return filtered;
      });
});

/// Shows lawyer-proposed appointment times directly on the client home screen.
/// The same request remains the source of truth; actions call the same RPCs used
/// by AppointmentRequestsPage rather than creating a parallel booking flow.
class ClientAppointmentRequestsHomeCard extends ConsumerStatefulWidget {
  const ClientAppointmentRequestsHomeCard({super.key});

  @override
  ConsumerState<ClientAppointmentRequestsHomeCard> createState() =>
      _ClientAppointmentRequestsHomeCardState();
}

class _ClientAppointmentRequestsHomeCardState
    extends ConsumerState<ClientAppointmentRequestsHomeCard> {
  final Set<String> _busy = <String>{};

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text, textAlign: TextAlign.right)),
    );
  }

  void _setBusy(String id, bool value) {
    if (!mounted) return;
    setState(() {
      if (value) {
        _busy.add(id);
      } else {
        _busy.remove(id);
      }
    });
  }

  DateTime? _date(dynamic value) => DateTime.tryParse('$value')?.toLocal();

  List<Map<String, dynamic>> _options(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  String _format(DateTime value) =>
      DateFormat('EEEE، d MMMM yyyy – hh:mm a', 'ar').format(value);

  Future<DateTime?> _pickDateTime({DateTime? initial}) async {
    final now = DateTime.now();
    final suggested = initial != null && initial.isAfter(now)
        ? initial
        : now.add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(suggested.year, suggested.month, suggested.day),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
      locale: const Locale('ar'),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: suggested.hour, minute: suggested.minute),
      helpText: 'حدد الوقت',
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<_HomeWindow?> _pickWindow(int durationMinutes) async {
    final start = await _pickDateTime();
    if (start == null || !mounted) return null;
    final end = await _pickDateTime(
      initial: start.add(Duration(minutes: durationMinutes)),
    );
    if (end == null) return null;
    if (!start.isAfter(DateTime.now().add(const Duration(minutes: 30)))) {
      _message('يجب أن تبدأ الفترة بعد أكثر من 30 دقيقة من الآن.');
      return null;
    }
    if (!end.isAfter(start)) {
      _message('نهاية الفترة يجب أن تكون بعد بدايتها.');
      return null;
    }
    if (end.difference(start) > const Duration(hours: 12)) {
      _message('الفترة الواحدة لا يمكن أن تتجاوز 12 ساعة.');
      return null;
    }
    if (end.difference(start).inMinutes < durationMinutes) {
      _message('الفترة المختارة أقصر من مدة الاستشارة.');
      return null;
    }
    return _HomeWindow(start, end);
  }

  Future<void> _accept(
    Map<String, dynamic> request,
    int optionIndex,
  ) async {
    final id = request['id']?.toString() ?? '';
    if (id.isEmpty || _busy.contains(id)) return;
    _setBusy(id, true);
    try {
      await SupabaseConfig.client.rpc(
        'client_confirm_custom_appointment',
        params: {
          'p_request_id': id,
          'p_option_index': optionIndex,
        },
      );
      ref.invalidate(userBookingsProvider);
      ref.invalidate(clientWalletProvider);
      ref.invalidate(clientWalletLedgerProvider);
      _message('تم قبول الموعد وتأكيد الاستشارة.');
    } catch (error) {
      _message(UserFacingError.text(error));
    } finally {
      _setBusy(id, false);
    }
  }

  Future<void> _change(Map<String, dynamic> request) async {
    final id = request['id']?.toString() ?? '';
    if (id.isEmpty || _busy.contains(id)) return;
    final round = int.tryParse('${request['negotiation_round'] ?? 1}') ?? 1;
    if (round >= 3) {
      _message('وصل الطلب إلى الحد الأقصى للتعديلات. اختر موعداً أو ارفض الطلب.');
      return;
    }

    final duration = int.tryParse('${request['duration_minutes'] ?? 30}') ?? 30;
    final windows = <_HomeWindow>[];
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('اقتراح تغيير للموعد'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'حدد من فترة واحدة إلى ثلاث فترات جديدة تناسبك. يبقى المبلغ محجوزاً ويعود الطلب للمحامي للرد.',
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 12),
                ...windows.asMap().entries.map(
                  (entry) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: IconButton(
                      onPressed: () => setDialogState(
                        () => windows.removeAt(entry.key),
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    title: Text(
                      '${_format(entry.value.start)} — ${DateFormat('hh:mm a', 'ar').format(entry.value.end)}',
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: windows.length >= 3
                      ? null
                      : () async {
                          final value = await _pickWindow(duration);
                          if (value != null) {
                            setDialogState(() => windows.add(value));
                          }
                        },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('إضافة فترة مناسبة'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: windows.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('إرسال التغيير'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || windows.isEmpty) return;

    _setBusy(id, true);
    try {
      await SupabaseConfig.client.rpc(
        'client_respond_custom_appointment_request',
        params: {
          'p_request_id': id,
          'p_windows': windows
              .map(
                (window) => {
                  'start': window.start.toUtc().toIso8601String(),
                  'end': window.end.toUtc().toIso8601String(),
                },
              )
              .toList(growable: false),
          'p_reject_reason': null,
        },
      );
      _message('تم إرسال الأوقات البديلة إلى المحامي.');
    } catch (error) {
      _message(UserFacingError.text(error));
    } finally {
      _setBusy(id, false);
    }
  }

  Future<void> _reject(Map<String, dynamic> request) async {
    final id = request['id']?.toString() ?? '';
    if (id.isEmpty || _busy.contains(id)) return;
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('رفض نهائي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'إذا كانت المشكلة في الوقت فقط استخدم «اقتراح تغيير». الرفض النهائي ينهي الطلب ويعيد المبلغ المحجوز إلى محفظتك.',
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 2,
              maxLines: 4,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(labelText: 'سبب الرفض'),
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
    if (reason == null) return;

    _setBusy(id, true);
    try {
      await SupabaseConfig.client.rpc(
        'client_respond_custom_appointment_request',
        params: {
          'p_request_id': id,
          'p_windows': null,
          'p_reject_reason': reason,
        },
      );
      ref.invalidate(clientWalletProvider);
      ref.invalidate(clientWalletLedgerProvider);
      _message('تم رفض الموعد وإنهاء الطلب وإعادة المبلغ المحجوز.');
    } catch (error) {
      _message(UserFacingError.text(error));
    } finally {
      _setBusy(id, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(_clientHomeAppointmentRequestsProvider);

    return requests.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (rows) {
        if (rows.isEmpty) return const SizedBox.shrink();
        final request = rows.first;
        final id = request['id']?.toString() ?? '';
        final options = _options(request['lawyer_options']);
        final isBusy = _busy.contains(id);
        final round = int.tryParse('${request['negotiation_round'] ?? 1}') ?? 1;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.teal.withValues(alpha: .55),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.teal.withValues(alpha: .10),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_calendar_rounded, color: AppColors.teal),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'موعد مقترح من المحامي',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (rows.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '+${rows.length - 1}',
                        style: const TextStyle(
                          color: AppColors.teal,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                request['package_name']?.toString() ?? 'استشارة قانونية',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              ...options.asMap().entries.map((entry) {
                final start = _date(entry.value['start']);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: FilledButton.icon(
                    onPressed: isBusy || start == null
                        ? null
                        : () => unawaited(_accept(request, entry.key)),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: Text(
                      start == null
                          ? 'موعد غير صالح'
                          : 'قبول • ${_format(start)}',
                    ),
                  ),
                );
              }),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isBusy
                          ? null
                          : () => unawaited(_reject(request)),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('رفض'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton.tonalIcon(
                      onPressed: isBusy || round >= 3
                          ? null
                          : () => unawaited(_change(request)),
                      icon: const Icon(Icons.edit_calendar_outlined),
                      label: Text(
                        round >= 3 ? 'انتهت جولات التعديل' : 'اقتراح تغيير',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => context.push(
                  '/appointment-requests?request_id=${Uri.encodeQueryComponent(id)}',
                ),
                child: const Text('فتح تفاصيل هذا الطلب'),
              ),
              if (isBusy) const LinearProgressIndicator(),
            ],
          ),
        );
      },
    );
  }
}

class _HomeWindow {
  final DateTime start;
  final DateTime end;

  const _HomeWindow(this.start, this.end);
}
