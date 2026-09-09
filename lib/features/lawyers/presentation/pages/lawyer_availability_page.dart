import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:astshara/core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_time_format.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';

class LawyerAvailabilityPage extends ConsumerStatefulWidget {
  const LawyerAvailabilityPage({super.key});

  @override
  ConsumerState<LawyerAvailabilityPage> createState() => _LawyerAvailabilityPageState();
}

class _LawyerAvailabilityPageState extends ConsumerState<LawyerAvailabilityPage> {
  static const List<double> _fallbackPriceOptions = <double>[20000, 25000, 30000, 40000, 50000];

  late Future<List<Map<String, dynamic>>> _slotsFuture;
  final Set<String> _pendingCancellationBookings = <String>{};
  final Set<String> _submittingCancellationBookings = <String>{};

  @override
  void initState() {
    super.initState();
    _slotsFuture = _loadSlots();
  }

  Future<String?> _profileId() async {
    final user = ref.read(authStateChangesProvider).value;
    if (user == null) return null;
    final row = await SupabaseConfig.client.from('profiles').select('id').eq('auth_id', user.id).maybeSingle();
    return row?['id']?.toString();
  }

  Future<List<double>> _priceOptions() async {
    try {
      final raw = await SupabaseConfig.client.rpc('get_consultation_pricing_config');
      final row = raw is List && raw.isNotEmpty && raw.first is Map
          ? Map<String, dynamic>.from(raw.first as Map)
          : null;
      final rawOptions = row?['price_options'];
      if (rawOptions is List) {
        final values = rawOptions
            .map((value) => double.tryParse(value.toString()))
            .whereType<double>()
            .where((value) => value > 0)
            .toSet()
            .toList()
          ..sort();
        if (values.isNotEmpty) return values;
      }
    } catch (_) {}
    return _fallbackPriceOptions;
  }

  Future<List<Map<String, dynamic>>> _loadSlots() async {
    final lawyerId = await _profileId();
    if (lawyerId == null) return <Map<String, dynamic>>[];
    final rawSlots = await SupabaseConfig.client
        .from('lawyer_availability_slots')
        .select('id, starts_at, ends_at, is_available, duration_minutes, price')
        .eq('lawyer_id', lawyerId)
        .order('starts_at', ascending: false);
    final slots = (rawSlots as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();

    _pendingCancellationBookings.clear();
    try {
      final requests = await SupabaseConfig.client.rpc('get_my_cancellation_requests');
      final list = requests is List ? requests : const <dynamic>[];
      _pendingCancellationBookings.addAll(list.whereType<Map>().where((row) => row['status']?.toString() == 'بانتظار مراجعة الإدارة').map((row) => row['booking_id'].toString()));
    } catch (_) {}

    if (slots.isEmpty) return slots;
    final starts = slots.map((s) => DateTime.tryParse(s['starts_at']?.toString() ?? '')).whereType<DateTime>().toList();
    if (starts.isEmpty) return slots;
    final minStart = starts.reduce((a, b) => a.isBefore(b) ? a : b).subtract(const Duration(minutes: 2)).toUtc().toIso8601String();
    final maxStart = starts.reduce((a, b) => a.isAfter(b) ? a : b).add(const Duration(minutes: 2)).toUtc().toIso8601String();

    try {
      final rawBookings = await SupabaseConfig.client
          .from('bookings')
          .select('id, scheduled_at, status, consultation_status')
          .eq('lawyer_id', lawyerId)
          .gte('scheduled_at', minStart)
          .lte('scheduled_at', maxStart)
          .order('scheduled_at');
      final bookings = (rawBookings as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
      const terminal = {'ملغي', 'ملغى', 'مسترد', 'مكتمل'};
      for (final slot in slots) {
        final slotStart = DateTime.tryParse(slot['starts_at']?.toString() ?? '');
        if (slotStart == null) continue;
        for (final booking in bookings) {
          if (terminal.contains(booking['status']?.toString())) continue;
          final bookingStart = DateTime.tryParse(booking['scheduled_at']?.toString() ?? '');
          if (bookingStart == null) continue;
          if (bookingStart.difference(slotStart).inSeconds.abs() <= 120) {
            slot['booking_id'] = booking['id']?.toString();
            slot['booking_status'] = booking['status']?.toString();
            slot['consultation_status'] = booking['consultation_status']?.toString();
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('تعذر تحميل الحجوزات المرتبطة بالمواعيد: $e');
    }
    return slots;
  }

  Future<void> _refresh() async {
    final nextFuture = _loadSlots();
    setState(() => _slotsFuture = nextFuture);
    await nextFuture;
  }

  Future<void> _deleteSlot(String id) async {
    try {
      await SupabaseConfig.client.from('lawyer_availability_slots').delete().eq('id', id);
      if (mounted) await _refresh();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حذف الموعد حالياً.')));
    }
  }

  Future<void> _requestCancellation(Map<String, dynamic> slot) async {
    final bookingId = slot['booking_id']?.toString();
    if (bookingId == null || bookingId.isEmpty || _submittingCancellationBookings.contains(bookingId)) return;
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('طلب إلغاء الحجز'),
        content: TextField(controller: controller, maxLines: 4, decoration: const InputDecoration(labelText: 'سبب الإلغاء')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          FilledButton(onPressed: () { final value = controller.text.trim(); if (value.isNotEmpty) Navigator.pop(dialogContext, value); }, child: const Text('إرسال')),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;
    setState(() => _submittingCancellationBookings.add(bookingId));
    try {
      await SupabaseConfig.client.rpc('request_booking_cancellation', params: {'p_booking_id': bookingId, 'p_reason': reason});
      if (!mounted) return;
      setState(() => _pendingCancellationBookings.add(bookingId));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلب الإلغاء إلى الإدارة.')));
      await _refresh();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر إرسال طلب الإلغاء حالياً.')));
    } finally {
      if (mounted) setState(() => _submittingCancellationBookings.remove(bookingId));
    }
  }

  DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

  Future<DateTime?> _pickConsultationDate() async {
    final now = DateTime.now();
    final firstDate = _dateOnly(now);
    final lastDate = firstDate.add(const Duration(days: 90));
    DateTime selected = firstDate.add(const Duration(days: 1));

    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return StatefulBuilder(
          builder: (context, setSheetState) => Directionality(
            textDirection: ui.TextDirection.rtl,
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.calendar_month_rounded, color: scheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'تاريخ الاستشارة',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'اختر اليوم من التقويم بوضوح',
                                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: .42),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Column(
                        children: [
                          Text(
                            DateFormat('EEEE', 'ar').format(selected),
                            style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('d MMMM yyyy', 'ar').format(selected),
                            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),
                  CalendarDatePicker(
                    initialDate: selected,
                    firstDate: firstDate,
                    lastDate: lastDate,
                    onDateChanged: (value) => setSheetState(() => selected = value),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: const Text('إلغاء'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.pop(sheetContext, selected),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('اعتماد التاريخ'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  TimeOfDay _defaultConsultationTime(DateTime date) {
    final now = DateTime.now();
    final isToday = _dateOnly(date) == _dateOnly(now);
    if (!isToday) return const TimeOfDay(hour: 10, minute: 0);

    final next = now.add(const Duration(minutes: 30));
    final roundedMinute = ((next.minute + 4) ~/ 5) * 5;
    final normalized = DateTime(next.year, next.month, next.day, next.hour, 0).add(Duration(minutes: roundedMinute));
    return TimeOfDay(hour: normalized.hour, minute: normalized.minute);
  }

  Future<TimeOfDay?> _pickConsultationTime(DateTime date) async {
    final initialTime = _defaultConsultationTime(date);
    DateTime selected = DateTime(date.year, date.month, date.day, initialTime.hour, initialTime.minute);

    return showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return StatefulBuilder(
          builder: (context, setSheetState) => Directionality(
            textDirection: ui.TextDirection.rtl,
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.alarm_rounded, color: scheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'وقت الاستشارة',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'حرّك عجلات الساعة مثل منبّه الآيفون',
                                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        children: [
                          Text(
                            DateFormat('EEEE، d MMMM', 'ar').format(date),
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppTimeFormat.time12(selected),
                            style: TextStyle(color: scheme.primary, fontSize: 29, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 220,
                    child: CupertinoTheme(
                      data: CupertinoThemeData(
                        brightness: Theme.of(sheetContext).brightness,
                        textTheme: CupertinoTextThemeData(
                          dateTimePickerTextStyle: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.time,
                        use24hFormat: false,
                        minuteInterval: 5,
                        initialDateTime: selected,
                        onDateTimeChanged: (value) {
                          setSheetState(() {
                            selected = DateTime(date.year, date.month, date.day, value.hour, value.minute);
                          });
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: const Text('إلغاء'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.pop(
                              sheetContext,
                              TimeOfDay(hour: selected.hour, minute: selected.minute),
                            ),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('اعتماد الوقت'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _addSlot() async {
    final date = await _pickConsultationDate();
    if (date == null || !mounted) return;
    final time = await _pickConsultationTime(date);
    if (time == null || !mounted) return;

    final proposedStart = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (!proposedStart.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن إضافة موعد بتاريخ أو وقت سابق. اختر موعداً لاحقاً.')),
      );
      return;
    }

    final priceOptions = await _priceOptions();
    if (!mounted) return;
    int duration = 30;
    double selectedPrice = priceOptions.contains(25000) ? 25000 : priceOptions.first;
    final details = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تفاصيل الموعد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(dialogContext).colorScheme.primaryContainer.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      DateFormat('EEEE، d MMMM yyyy', 'ar').format(proposedStart),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppTimeFormat.time12(proposedStart),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('حدد مدة الاستشارة واختر السعر ضمن النطاق المعتمد في المنصة.'),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: duration,
                decoration: const InputDecoration(labelText: 'مدة الاستشارة'),
                items: const [15, 30, 45, 60, 90, 120].map((m) => DropdownMenuItem(value: m, child: Text('$m دقيقة'))).toList(),
                onChanged: (value) { if (value != null) setDialogState(() => duration = value); },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<double>(
                initialValue: selectedPrice,
                decoration: const InputDecoration(labelText: 'سعر الاستشارة', helperText: 'السعر مضبوط من إدارة المنصة'),
                items: priceOptions
                    .map((price) => DropdownMenuItem<double>(value: price, child: Text('${price.toStringAsFixed(0)} د.ع')))
                    .toList(growable: false),
                onChanged: (value) { if (value != null) setDialogState(() => selectedPrice = value); },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {'duration': duration, 'price': selectedPrice}),
              child: const Text('حفظ الموعد'),
            ),
          ],
        ),
      ),
    );
    if (details == null || !mounted) return;

    final start = proposedStart;
    if (!start.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن إضافة موعد بتاريخ أو وقت سابق. اختر موعداً لاحقاً.')),
      );
      return;
    }
    final durationMinutes = details['duration'] as int;
    final price = details['price'] as double;
    final lawyerId = await _profileId();
    if (lawyerId == null) return;

    try {
      await SupabaseConfig.client.from('lawyer_availability_slots').insert({
        'lawyer_id': lawyerId,
        'starts_at': start.toUtc().toIso8601String(),
        'ends_at': start.add(Duration(minutes: durationMinutes)).toUtc().toIso8601String(),
        'duration_minutes': durationMinutes,
        'price': price,
        'is_available': true,
      });
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة الموعد مع المدة والسعر.')));
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString().toLowerCase();
      if (raw.contains('past') || raw.contains('سابق') || raw.contains('الماضي')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن إضافة موعد بتاريخ أو وقت سابق. اختر موعداً لاحقاً.')),
        );
      } else if (raw.contains('سعر') || raw.contains('price')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('سعر الاستشارة خارج الحدود المعتمدة في المنصة. أعد اختيار السعر.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر إضافة الموعد. تحقق من البيانات وحاول مرة أخرى.')));
      }
    }
  }

  Widget _slotCard(Map<String, dynamic> slot) {
    final scheme = Theme.of(context).colorScheme;
    final start = DateTime.tryParse(slot['starts_at']?.toString() ?? '')?.toLocal();
    if (start == null) return const SizedBox.shrink();
    final duration = int.tryParse('${slot['duration_minutes'] ?? 30}') ?? 30;
    final price = double.tryParse('${slot['price'] ?? ''}');
    final isPast = start.isBefore(DateTime.now());
    final available = slot['is_available'] == true;
    final bookingId = slot['booking_id']?.toString();
    final isBooked = !isPast && !available && bookingId != null && bookingId.isNotEmpty;
    final pending = isBooked && _pendingCancellationBookings.contains(bookingId);
    final submitting = isBooked && _submittingCancellationBookings.contains(bookingId);
    final statusText = isPast ? 'موعد سابق' : (isBooked ? 'محجوز' : (available ? 'متاح للحجز' : 'غير متاح'));
    final statusColor = isPast ? scheme.onSurfaceVariant : (isBooked ? AppColors.warning : (available ? AppColors.success : scheme.onSurfaceVariant));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(isBooked ? Icons.event_busy_rounded : Icons.event_available_rounded, color: statusColor, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(DateFormat('EEEE، d MMMM yyyy', 'ar').format(start), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('${AppTimeFormat.time12(start)} • $duration دقيقة${price == null ? '' : ' • ${price.toStringAsFixed(0)} د.ع'}', textAlign: TextAlign.right, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              const SizedBox(height: 6),
              Text(statusText, textAlign: TextAlign.right, style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 12)),
            ])),
            if (!isBooked && (isPast || available)) IconButton(onPressed: () => _deleteSlot(slot['id'].toString()), icon: Icon(Icons.delete_outline_rounded, color: scheme.error)),
          ]),
          if (isBooked) ...[
            const SizedBox(height: 12),
            pending
                ? Container(padding: const EdgeInsets.all(12), alignment: Alignment.center, decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)), child: const Text('طلب الإلغاء بانتظار مراجعة الإدارة'))
                : OutlinedButton.icon(onPressed: submitting ? null : () => _requestCancellation(slot), icon: submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.event_busy_outlined), label: const Text('طلب إلغاء الحجز')),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الخطوة ٢ من ٢: أوقات التوفر'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(onPressed: _addSlot, icon: const Icon(Icons.add_rounded), label: const Text('إضافة موعد')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _slotsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return const Center(child: Text('تعذر تحميل المواعيد.'));
          final slots = snapshot.data ?? const <Map<String, dynamic>>[];
          if (slots.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('أضف موعداً وحدد مدة الاستشارة والسعر حتى يتمكن طالب الاستشارة من اختيار ما يناسبه.', textAlign: TextAlign.center)));
          return RefreshIndicator(onRefresh: _refresh, child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 130), children: slots.map(_slotCard).toList()));
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          child: FilledButton.icon(
            onPressed: () => context.go('/lawyer-home'),
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('إكمال إعداد التوفر'),
          ),
        ),
      ),
    );
  }
}
