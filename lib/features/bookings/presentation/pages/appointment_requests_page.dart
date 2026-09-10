import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/utils/user_facing_error.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../payments/presentation/providers/client_wallet_provider.dart';
import '../providers/bookings_provider.dart';

class AppointmentRequestsPage extends ConsumerStatefulWidget {
  const AppointmentRequestsPage({super.key});

  @override
  ConsumerState<AppointmentRequestsPage> createState() =>
      _AppointmentRequestsPageState();
}

class _AppointmentRequestsPageState
    extends ConsumerState<AppointmentRequestsPage> {
  late Future<List<Map<String, dynamic>>> _future;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _channel = SupabaseConfig.client
        .channel('custom-appointment-requests-page')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'custom_appointment_requests',
          callback: (_) {
            if (mounted) _refresh();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) SupabaseConfig.client.removeChannel(channel);
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await SupabaseConfig.client
        .from('custom_appointment_requests')
        .select()
        .order('created_at', ascending: false)
        .limit(60);
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<void> _refresh() async {
    final next = _load();
    if (mounted) setState(() => _future = next);
    await next;
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text, textAlign: TextAlign.right)),
    );
  }

  Future<DateTime?> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      locale: const Locale('ar'),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _respond(Map<String, dynamic> request) async {
    final options = <DateTime>[];
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('اقتراح مواعيد للعميل'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'اختر من موعد واحد إلى ثلاثة مواعيد. سيختار العميل واحداً منها نهائياً.',
                ),
                const SizedBox(height: 12),
                ...options.asMap().entries.map(
                      (entry) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: IconButton(
                          onPressed: () =>
                              setDialogState(() => options.removeAt(entry.key)),
                          icon: const Icon(Icons.close_rounded),
                        ),
                        title: Text(_formatDate(entry.value)),
                      ),
                    ),
                OutlinedButton.icon(
                  onPressed: options.length >= 3
                      ? null
                      : () async {
                          final value = await _pickDateTime();
                          if (value != null && value.isAfter(DateTime.now())) {
                            setDialogState(() => options.add(value));
                          }
                        },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('إضافة موعد'),
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
              onPressed: options.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('إرسال المواعيد'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    try {
      await SupabaseConfig.client.rpc(
        'lawyer_respond_custom_appointment_request',
        params: {
          'p_request_id': request['id'],
          'p_options': options
              .map((date) => {'start': date.toUtc().toIso8601String()})
              .toList(),
          'p_reject_reason': null,
        },
      );
      _message('تم إرسال المواعيد المقترحة إلى العميل.');
      await _refresh();
    } catch (error) {
      _message(UserFacingError.text(error));
    }
  }

  Future<void> _reject(Map<String, dynamic> request) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('رفض الاستشارة نهائياً'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'استخدم هذا الخيار فقط إذا كنت لا تريد قبول الاستشارة. إذا كانت المشكلة في الوقت فقط فاقترح موعداً آخر بدلاً من الرفض.',
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
    try {
      await SupabaseConfig.client.rpc(
        'lawyer_respond_custom_appointment_request',
        params: {
          'p_request_id': request['id'],
          'p_options': null,
          'p_reject_reason': reason,
        },
      );
      _message('تم رفض الاستشارة نهائياً وإعادة المبلغ المحجوز للعميل.');
      await _refresh();
    } catch (error) {
      _message(UserFacingError.text(error));
    }
  }

  Future<void> _confirm(
    Map<String, dynamic> request,
    int optionIndex,
  ) async {
    try {
      await SupabaseConfig.client.rpc(
        'client_confirm_custom_appointment',
        params: {
          'p_request_id': request['id'],
          'p_option_index': optionIndex,
        },
      );
      ref.invalidate(userBookingsProvider);
      ref.invalidate(clientWalletProvider);
      ref.invalidate(clientWalletLedgerProvider);
      _message('تم تأكيد الموعد وإضافته إلى استشاراتك.');
      await _refresh();
    } catch (error) {
      _message(UserFacingError.text(error));
    }
  }

  Future<void> _cancel(Map<String, dynamic> request) async {
    try {
      await SupabaseConfig.client.rpc(
        'cancel_custom_appointment_request',
        params: {'p_request_id': request['id']},
      );
      ref.invalidate(clientWalletProvider);
      ref.invalidate(clientWalletLedgerProvider);
      _message('تم إلغاء الطلب وإعادة المبلغ المحجوز إلى محفظتك.');
      await _refresh();
    } catch (error) {
      _message(UserFacingError.text(error));
    }
  }

  static String _formatDate(DateTime date) {
    return DateFormat('EEEE، d MMMM yyyy – hh:mm a', 'ar').format(date);
  }

  List<Map<String, dynamic>> _jsonList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authStateChangesProvider).valueOrNull?.role;
    final isLawyer = role == 'lawyer';
    return Scaffold(
      appBar: AppBar(
        title: Text(isLawyer ? 'طلبات المواعيد' : 'متابعة المواعيد'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'تعذر تحميل الطلبات: ${UserFacingError.text(snapshot.error!)}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final items = snapshot.data ?? const <Map<String, dynamic>>[];
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'لا توجد طلبات مواعيد حالياً.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
              itemCount: items.length,
              itemBuilder: (context, index) => _RequestCard(
                request: items[index],
                isLawyer: isLawyer,
                clientWindows: _jsonList(items[index]['client_windows']),
                lawyerOptions: _jsonList(items[index]['lawyer_options']),
                onRespond: () => _respond(items[index]),
                onReject: () => _reject(items[index]),
                onConfirm: (option) => _confirm(items[index], option),
                onCancel: () => _cancel(items[index]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final bool isLawyer;
  final List<Map<String, dynamic>> clientWindows;
  final List<Map<String, dynamic>> lawyerOptions;
  final VoidCallback onRespond;
  final VoidCallback onReject;
  final ValueChanged<int> onConfirm;
  final VoidCallback onCancel;

  const _RequestCard({
    required this.request,
    required this.isLawyer,
    required this.clientWindows,
    required this.lawyerOptions,
    required this.onRespond,
    required this.onReject,
    required this.onConfirm,
    required this.onCancel,
  });

  DateTime? _date(dynamic value) => DateTime.tryParse('$value')?.toLocal();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = request['status']?.toString() ?? '';
    final pendingLawyer = status == 'بانتظار رد المحامي';
    final pendingClient = status == 'بانتظار اختيار العميل';
    final price = double.tryParse('${request['price'] ?? 0}') ?? 0;
    final expiry = _date(request['expires_at']);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.event_note_outlined, color: scheme.primary),
            const SizedBox(width: 9),
            Expanded(child: Text(request['package_name']?.toString() ?? 'استشارة قانونية', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
            _StatusBadge(status: status),
          ]),
          const SizedBox(height: 10),
          Text('${price.toStringAsFixed(0)} د.ع • ${request['duration_minutes']} دقيقة • ${request['consultation_type']}', textAlign: TextAlign.right),
          if (expiry != null && (pendingLawyer || pendingClient)) ...[
            const SizedBox(height: 6),
            Text('تنتهي مهلة الرد: ${AppointmentRequestsPageStateDate.format(expiry)}', textAlign: TextAlign.right, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          ],
          if (clientWindows.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('الأوقات التي اقترحها العميل', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800)),
            ...clientWindows.map((window) {
              final start = _date(window['start']);
              final end = _date(window['end']);
              return Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(start == null || end == null ? 'فترة غير متاحة' : '${AppointmentRequestsPageStateDate.format(start)} — ${DateFormat('hh:mm a', 'ar').format(end)}', textAlign: TextAlign.right),
              );
            }),
          ],
          if (!isLawyer && pendingClient && lawyerOptions.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('اختر موعداً واحداً لتأكيد الحجز', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            ...lawyerOptions.asMap().entries.map((entry) {
              final start = _date(entry.value['start']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FilledButton.tonalIcon(
                  onPressed: start == null ? null : () => onConfirm(entry.key),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: Text(start == null ? 'موعد غير صالح' : AppointmentRequestsPageStateDate.format(start)),
                ),
              );
            }),
          ],
          if (request['rejection_reason'] != null) ...[
            const SizedBox(height: 10),
            Text('سبب الرفض: ${request['rejection_reason']}', textAlign: TextAlign.right, style: TextStyle(color: scheme.error)),
          ],
          if (isLawyer && pendingLawyer) ...[
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: onReject, icon: const Icon(Icons.close_rounded), label: const Text('رفض نهائي'))),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: FilledButton.icon(onPressed: onRespond, icon: const Icon(Icons.edit_calendar_outlined), label: const Text('اقتراح مواعيد'))),
            ]),
          ],
          if (!isLawyer && (pendingLawyer || pendingClient)) ...[
            const SizedBox(height: 10),
            TextButton.icon(onPressed: onCancel, icon: const Icon(Icons.cancel_outlined), label: const Text('إلغاء الطلب وإعادة المبلغ')),
          ],
        ]),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(99)),
        child: Text(status, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
      );
}

class AppointmentRequestsPageStateDate {
  static String format(DateTime value) =>
      DateFormat('yyyy/MM/dd – hh:mm a', 'ar').format(value);
}
