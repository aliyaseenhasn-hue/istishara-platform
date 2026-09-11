import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/user_facing_error.dart';
import '../../../../shared/styles/priority_visuals.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../payments/presentation/providers/client_wallet_provider.dart';
import '../providers/bookings_provider.dart';

class AppointmentRequestsPage extends ConsumerStatefulWidget {
  final String? focusRequestId;

  const AppointmentRequestsPage({super.key, this.focusRequestId});

  @override
  ConsumerState<AppointmentRequestsPage> createState() =>
      _AppointmentRequestsPageState();
}

class _AppointmentRequestsPageState
    extends ConsumerState<AppointmentRequestsPage> {
  late Future<List<Map<String, dynamic>>> _future;
  RealtimeChannel? _channel;
  GlobalKey _focusCardKey = GlobalKey();
  bool _didFocus = false;
  final Set<String> _busyIds = <String>{};

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
            if (mounted) unawaited(_refresh());
          },
        )
        .subscribe();
  }

  @override
  void didUpdateWidget(covariant AppointmentRequestsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusRequestId != widget.focusRequestId) {
      _didFocus = false;
      _focusCardKey = GlobalKey();
      _future = _load();
    }
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) {
      unawaited(SupabaseConfig.client.removeChannel(channel));
    }
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    try {
      await SupabaseConfig.client.rpc('expire_stale_custom_appointment_requests');
    } catch (_) {}

    final rows = await SupabaseConfig.client
        .from('custom_appointment_requests')
        .select()
        .order('created_at', ascending: false)
        .limit(60);
    final items = (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: true);

    final focusId = widget.focusRequestId?.trim();
    if (focusId != null &&
        focusId.isNotEmpty &&
        !items.any((row) => row['id']?.toString() == focusId)) {
      final focused = await SupabaseConfig.client
          .from('custom_appointment_requests')
          .select()
          .eq('id', focusId)
          .maybeSingle();
      if (focused != null) {
        items.insert(0, Map<String, dynamic>.from(focused));
      }
    }
    return items;
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

  void _setBusy(dynamic requestId, bool value) {
    final id = requestId?.toString();
    if (id == null || !mounted) return;
    setState(() {
      if (value) {
        _busyIds.add(id);
      } else {
        _busyIds.remove(id);
      }
    });
  }

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
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<_ProposedWindow?> _pickWindow(int durationMinutes) async {
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
    return _ProposedWindow(start, end);
  }

  Future<void> _lawyerRespond(Map<String, dynamic> request) async {
    final options = <DateTime>[];
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('اقتراح مواعيد بديلة'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'اختر من موعد واحد إلى ثلاثة مواعيد. تُحجز هذه الأوقات مؤقتاً للعميل حتى انتهاء مهلة رده.',
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
                        title: Text(_formatDate(entry.value)),
                      ),
                    ),
                OutlinedButton.icon(
                  onPressed: options.length >= 3
                      ? null
                      : () async {
                          final value = await _pickDateTime();
                          if (value != null &&
                              value.isAfter(DateTime.now().add(
                                const Duration(minutes: 30),
                              ))) {
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
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.white,
              ),
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
    _setBusy(request['id'], true);
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
      _message('تم إرسال المواعيد وحجزها مؤقتاً للعميل حتى انتهاء مهلة الرد.');
      await _refresh();
    } catch (error) {
      _message(UserFacingError.text(error));
    } finally {
      _setBusy(request['id'], false);
    }
  }

  Future<void> _lawyerAcceptClientWindow(
    Map<String, dynamic> request,
  ) async {
    final windows = _jsonList(request['client_windows']);
    if (windows.isEmpty) return;
    final parsed = windows
        .map((window) => _ProposedWindow.tryParse(window))
        .whereType<_ProposedWindow>()
        .toList(growable: false);
    if (parsed.isEmpty) return;

    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('اختر فترة مناسبة للعميل'),
        children: parsed.asMap().entries.map((entry) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, entry.key),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '${_formatDate(entry.value.start)} — ${DateFormat('hh:mm a', 'ar').format(entry.value.end)}',
                textAlign: TextAlign.right,
              ),
            ),
          );
        }).toList(),
      ),
    );
    if (selected == null || !mounted) return;
    final window = parsed[selected];
    final exact = await _pickDateTime(initial: window.start);
    if (exact == null) return;
    final duration = int.tryParse('${request['duration_minutes']}') ?? 30;
    final exactEnd = exact.add(Duration(minutes: duration));
    if (exact.isBefore(window.start) || exactEnd.isAfter(window.end)) {
      _message('يجب أن يقع الموعد كاملاً داخل الفترة التي حددها العميل.');
      return;
    }
    if (!exact.isAfter(DateTime.now().add(const Duration(minutes: 30)))) {
      _message('يجب أن يكون الموعد بعد أكثر من 30 دقيقة من الآن.');
      return;
    }

    _setBusy(request['id'], true);
    try {
      await SupabaseConfig.client.rpc(
        'lawyer_respond_custom_appointment_request',
        params: {
          'p_request_id': request['id'],
          'p_options': [
            {'start': exact.toUtc().toIso8601String()},
          ],
          'p_reject_reason': null,
        },
      );
      _message('تم إرسال الموعد وحجزه مؤقتاً للعميل حتى يؤكده أو تنتهي المهلة.');
      await _refresh();
    } catch (error) {
      _message(UserFacingError.text(error));
    } finally {
      _setBusy(request['id'], false);
    }
  }

  Future<String?> _askRejectReason({required bool isLawyer}) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('رفض نهائي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isLawyer
                  ? 'إذا كانت المشكلة في الوقت فقط فاقترح موعداً آخر. الرفض النهائي ينهي الطلب ويعيد المبلغ المحجوز للعميل.'
                  : 'إذا كانت المشكلة في الوقت فقط فاختر «اقتراح تغيير». الرفض النهائي ينهي الطلب ويعيد المبلغ المحجوز إلى محفظتك.',
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
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
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
    return reason;
  }

  Future<void> _lawyerReject(Map<String, dynamic> request) async {
    final reason = await _askRejectReason(isLawyer: true);
    if (reason == null) return;
    _setBusy(request['id'], true);
    try {
      await SupabaseConfig.client.rpc(
        'lawyer_respond_custom_appointment_request',
        params: {
          'p_request_id': request['id'],
          'p_options': null,
          'p_reject_reason': reason,
        },
      );
      _message('تم رفض الاستشارة نهائياً وإعادة المبلغ للعميل.');
      await _refresh();
    } catch (error) {
      _message(UserFacingError.text(error));
    } finally {
      _setBusy(request['id'], false);
    }
  }

  Future<void> _clientChange(Map<String, dynamic> request) async {
    final duration = int.tryParse('${request['duration_minutes']}') ?? 30;
    final windows = <_ProposedWindow>[];
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('اقتراح تغيير للموعد'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'حدد من فترة واحدة إلى ثلاث فترات جديدة تناسبك. ستتحرر مواعيد المحامي الحالية ويعود الطلب إليه للرد.',
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
                          '${_formatDate(entry.value.start)} — ${DateFormat('hh:mm a', 'ar').format(entry.value.end)}',
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
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.goldDark,
                foregroundColor: Colors.white,
              ),
              onPressed: windows.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('إرسال التغيير'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    _setBusy(request['id'], true);
    try {
      await SupabaseConfig.client.rpc(
        'client_respond_custom_appointment_request',
        params: {
          'p_request_id': request['id'],
          'p_windows': windows
              .map(
                (window) => {
                  'start': window.start.toUtc().toIso8601String(),
                  'end': window.end.toUtc().toIso8601String(),
                },
              )
              .toList(),
          'p_reject_reason': null,
        },
      );
      _message('تم إرسال الأوقات البديلة إلى المحامي.');
      await _refresh();
    } catch (error) {
      _message(UserFacingError.text(error));
    } finally {
      _setBusy(request['id'], false);
    }
  }

  Future<void> _clientReject(Map<String, dynamic> request) async {
    final reason = await _askRejectReason(isLawyer: false);
    if (reason == null) return;
    _setBusy(request['id'], true);
    try {
      await SupabaseConfig.client.rpc(
        'client_respond_custom_appointment_request',
        params: {
          'p_request_id': request['id'],
          'p_windows': null,
          'p_reject_reason': reason,
        },
      );
      ref.invalidate(clientWalletProvider);
      ref.invalidate(clientWalletLedgerProvider);
      _message('تم رفض الموعد وإنهاء الطلب وإعادة المبلغ المحجوز.');
      await _refresh();
    } catch (error) {
      _message(UserFacingError.text(error));
    } finally {
      _setBusy(request['id'], false);
    }
  }

  Future<bool> _confirmSelectedAppointment(DateTime start) async {
    var checked = false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تأكيد الموعد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _formatDate(start),
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: checked,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'أؤكد أن هذا هو الموعد الذي أريد حجزه',
                  textAlign: TextAlign.right,
                ),
                onChanged: (value) =>
                    setDialogState(() => checked = value == true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('رجوع'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              onPressed: checked
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const Text('تأكيد الموعد'),
            ),
          ],
        ),
      ),
    );
    return result == true;
  }

  Future<void> _confirm(
    Map<String, dynamic> request,
    int optionIndex,
  ) async {
    final options = _jsonList(request['lawyer_options']);
    if (optionIndex < 0 || optionIndex >= options.length) {
      _message('الموعد المختار غير صالح.');
      return;
    }
    final start = DateTime.tryParse('${options[optionIndex]['start']}')?.toLocal();
    if (start == null) {
      _message('الموعد المختار غير صالح.');
      return;
    }
    if (!await _confirmSelectedAppointment(start) || !mounted) return;

    _setBusy(request['id'], true);
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
    } finally {
      _setBusy(request['id'], false);
    }
  }

  Future<void> _cancel(Map<String, dynamic> request) async {
    _setBusy(request['id'], true);
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
    } finally {
      _setBusy(request['id'], false);
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

  void _focusAfterBuild(List<Map<String, dynamic>> items) {
    final focusId = widget.focusRequestId?.trim();
    if (_didFocus || focusId == null || focusId.isEmpty) return;
    if (!items.any((item) => item['id']?.toString() == focusId)) return;
    _didFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final focusContext = _focusCardKey.currentContext;
      if (focusContext != null) {
        Scrollable.ensureVisible(
          focusContext,
          alignment: 0.08,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _rebook(Map<String, dynamic> request) {
    final lawyerId = request['lawyer_id']?.toString();
    if (lawyerId == null || lawyerId.isEmpty) {
      _message('تعذر تحديد المحامي لهذا الطلب.');
      return;
    }
    context.push('/lawyer-details/${Uri.encodeComponent(lawyerId)}');
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
            return const LoadingWidget(size: 30);
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
          _focusAfterBuild(items);
          final focusId = widget.focusRequestId?.trim();
          return RefreshIndicator(
            color: AppColors.teal,
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final id = item['id']?.toString() ?? '';
                final focused = focusId != null && focusId == id;
                return Container(
                  key: focused ? _focusCardKey : null,
                  child: _RequestCard(
                    request: item,
                    isLawyer: isLawyer,
                    clientWindows: _jsonList(item['client_windows']),
                    lawyerOptions: _jsonList(item['lawyer_options']),
                    focused: focused,
                    busy: _busyIds.contains(id),
                    onLawyerAccept: () => _lawyerAcceptClientWindow(item),
                    onLawyerRespond: () => _lawyerRespond(item),
                    onLawyerReject: () => _lawyerReject(item),
                    onClientChange: () => _clientChange(item),
                    onClientReject: () => _clientReject(item),
                    onConfirm: (option) => _confirm(item, option),
                    onCancel: () => _cancel(item),
                    onRebook: () => _rebook(item),
                  ),
                );
              },
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
  final bool focused;
  final bool busy;
  final VoidCallback onLawyerAccept;
  final VoidCallback onLawyerRespond;
  final VoidCallback onLawyerReject;
  final VoidCallback onClientChange;
  final VoidCallback onClientReject;
  final ValueChanged<int> onConfirm;
  final VoidCallback onCancel;
  final VoidCallback onRebook;

  const _RequestCard({
    required this.request,
    required this.isLawyer,
    required this.clientWindows,
    required this.lawyerOptions,
    required this.focused,
    required this.busy,
    required this.onLawyerAccept,
    required this.onLawyerRespond,
    required this.onLawyerReject,
    required this.onClientChange,
    required this.onClientReject,
    required this.onConfirm,
    required this.onCancel,
    required this.onRebook,
  });

  DateTime? _date(dynamic value) => DateTime.tryParse('$value')?.toLocal();

  String _expiredMessage(String? waitingOn) {
    if (waitingOn == 'lawyer') {
      return isLawyer
          ? 'لم ترد على طلب الموعد ضمن المهلة المحددة، لذلك أُلغي الطلب تلقائياً.'
          : 'لم يرد المحامي ضمن المهلة المحددة، لذلك أُلغي طلب الموعد تلقائياً وأُعيد المبلغ المحجوز إلى محفظتك.';
    }
    if (waitingOn == 'client') {
      return isLawyer
          ? 'لم يرد العميل على المواعيد المقترحة ضمن المهلة المحددة، لذلك أُلغي الطلب تلقائياً.'
          : 'لم ترد على المواعيد المقترحة ضمن المهلة المحددة، لذلك أُلغي الطلب تلقائياً وأُعيد المبلغ المحجوز إلى محفظتك.';
    }
    return isLawyer
        ? 'انتهت مهلة الرد على هذا الطلب، لذلك أُلغي تلقائياً.'
        : 'انتهت مهلة الرد على هذا الطلب، لذلك أُلغي تلقائياً وأُعيد المبلغ المحجوز إلى محفظتك.';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = request['status']?.toString() ?? '';
    final pendingLawyer = status == 'بانتظار رد المحامي';
    final pendingClient = status == 'بانتظار اختيار العميل';
    final expired = status == 'منتهي';
    final round = int.tryParse('${request['negotiation_round'] ?? 1}') ?? 1;
    final rejectedBy = request['rejected_by']?.toString();
    final expiredWaitingOn = request['expired_waiting_on']?.toString();
    final price = double.tryParse('${request['price'] ?? 0}') ?? 0;
    final expiry = _date(request['expires_at']);
    final expiredAt = _date(request['expired_at']);
    final visual = PriorityVisuals.consultation(status);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: focused
            ? Color.alphaBlend(
                visual.accent.withValues(alpha: .15),
                scheme.surface,
              )
            : Color.alphaBlend(
                visual.accent.withValues(alpha: visual.level >= 3 ? .065 : .025),
                scheme.surface,
              ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: visual.accent.withValues(alpha: focused ? .85 : .42),
          width: focused ? 2.2 : visual.level >= 3 ? 1.4 : 1,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: visual.accent.withValues(alpha: .16),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : const [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(visual.icon, color: visual.accent),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    request['package_name']?.toString() ?? 'استشارة قانونية',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                _StatusBadge(status: status),
              ],
            ),
            if (focused) ...[
              const SizedBox(height: 8),
              Text(
                'تم فتح هذا الطلب من الإشعار',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: visual.accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              '${price.toStringAsFixed(0)} د.ع • ${request['duration_minutes']} دقيقة • ${request['consultation_type']}',
              textAlign: TextAlign.right,
            ),
            if (expiry != null && (pendingLawyer || pendingClient)) ...[
              const SizedBox(height: 6),
              Text(
                '${pendingLawyer ? (isLawyer ? 'مهلة ردك' : 'مهلة رد المحامي') : (isLawyer ? 'مهلة رد العميل' : 'مهلة ردك')} تنتهي: ${AppointmentRequestsPageStateDate.format(expiry)}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: AppColors.pendingText,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            if (expired) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.error.withValues(alpha: .35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _expiredMessage(expiredWaitingOn),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppColors.cancelledText,
                        fontWeight: FontWeight.w800,
                        height: 1.45,
                      ),
                    ),
                    if (expiredAt != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        'وقت الإلغاء: ${AppointmentRequestsPageStateDate.format(expiredAt)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: AppColors.cancelledText,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isLawyer) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onRebook,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('احجز مرة أخرى'),
                ),
              ],
            ],
            if (clientWindows.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                isLawyer ? 'الأوقات التي اقترحها العميل' : 'الأوقات التي اقترحتها',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              ...clientWindows.map((window) {
                final start = _date(window['start']);
                final end = _date(window['end']);
                return Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    start == null || end == null
                        ? 'فترة غير متاحة'
                        : '${AppointmentRequestsPageStateDate.format(start)} — ${DateFormat('hh:mm a', 'ar').format(end)}',
                    textAlign: TextAlign.right,
                  ),
                );
              }),
            ],
            if (lawyerOptions.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                isLawyer
                    ? 'المواعيد التي أرسلتها للعميل'
                    : 'المواعيد المقترحة من المحامي',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              if (pendingClient) ...[
                const SizedBox(height: 4),
                Text(
                  'هذه الأوقات محجوزة مؤقتاً لهذا الطلب حتى انتهاء مهلة الرد.',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              ...lawyerOptions.asMap().entries.map((entry) {
                final start = _date(entry.value['start']);
                if (isLawyer || !pendingClient) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      start == null
                          ? 'موعد غير صالح'
                          : AppointmentRequestsPageStateDate.format(start),
                      textAlign: TextAlign.right,
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: busy || start == null
                        ? null
                        : () => onConfirm(entry.key),
                    icon: const Icon(Icons.check_box_outlined),
                    label: Text(
                      start == null
                          ? 'موعد غير صالح'
                          : 'اختيار • ${AppointmentRequestsPageStateDate.format(start)}',
                    ),
                  ),
                );
              }),
            ],
            if (request['rejection_reason'] != null) ...[
              const SizedBox(height: 10),
              Text(
                '${rejectedBy == 'client' ? 'سبب رفض العميل' : rejectedBy == 'lawyer' ? 'سبب رفض المحامي' : 'سبب الرفض'}: ${request['rejection_reason']}',
                textAlign: TextAlign.right,
                style: const TextStyle(color: AppColors.error),
              ),
            ],
            if (busy) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                color: visual.accent,
                backgroundColor: visual.background,
              ),
            ],
            if (isLawyer && pendingLawyer) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.white,
                ),
                onPressed: busy ? null : onLawyerAccept,
                icon: const Icon(Icons.schedule_rounded),
                label: const Text('اختيار وقت من اقتراح العميل'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(color: AppColors.error.withValues(alpha: .55)),
                      ),
                      onPressed: busy ? null : onLawyerReject,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('رفض نهائي'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.pendingBg,
                        foregroundColor: AppColors.pendingText,
                      ),
                      onPressed: busy ? null : onLawyerRespond,
                      icon: const Icon(Icons.edit_calendar_outlined),
                      label: const Text('موعد بديل'),
                    ),
                  ),
                ],
              ),
            ],
            if (!isLawyer && pendingClient) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(color: AppColors.error.withValues(alpha: .55)),
                      ),
                      onPressed: busy ? null : onClientReject,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('رفض نهائي'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.pendingBg,
                        foregroundColor: AppColors.pendingText,
                      ),
                      onPressed: busy || round >= 3 ? null : onClientChange,
                      icon: const Icon(Icons.edit_calendar_outlined),
                      label: Text(
                        round >= 3 ? 'انتهت جولات التعديل' : 'اقتراح تغيير',
                      ),
                    ),
                  ),
                ],
              ),
              if (round >= 3) ...[
                const SizedBox(height: 6),
                Text(
                  'وصل الطلب إلى الحد الأقصى للتعديلات. يمكنك قبول أحد المواعيد أو رفض الطلب.',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
            if (!isLawyer && pendingLawyer) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                onPressed: busy ? null : onCancel,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('إلغاء الطلب وإعادة المبلغ'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProposedWindow {
  final DateTime start;
  final DateTime end;

  const _ProposedWindow(this.start, this.end);

  static _ProposedWindow? tryParse(Map<String, dynamic> value) {
    final start = DateTime.tryParse('${value['start']}')?.toLocal();
    final end = DateTime.tryParse('${value['end']}')?.toLocal();
    if (start == null || end == null) return null;
    return _ProposedWindow(start, end);
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = status == 'منتهي' ? 'أُلغي لعدم الرد' : status;
    final visual = PriorityVisuals.consultation(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: visual.background,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: visual.accent.withValues(alpha: .28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: visual.foreground,
        ),
      ),
    );
  }
}

class AppointmentRequestsPageStateDate {
  static String format(DateTime value) =>
      DateFormat('yyyy/MM/dd – hh:mm a', 'ar').format(value);
}
