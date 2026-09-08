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

  bool _isValidFutureSlot(Map<String, dynamic> slot) {
    final start = DateTime.tryParse(slot['starts_at']?.toString() ?? '')?.toLocal();
    final price = double.tryParse('${slot['price'] ?? ''}') ?? 0;
    final duration = int.tryParse('${slot['duration_minutes'] ?? ''}') ?? 0;
    return start != null && start.isAfter(DateTime.now()) && price > 0 && duration > 0;
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

  Future<void> _addSlot() async {
    final date = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)), initialDate: DateTime.now().add(const Duration(days: 1)));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
    if (time == null || !mounted) return;

    int duration = 30;
    final priceController = TextEditingController();
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
              const Text('حدد مدة الاستشارة والسعر الخاص بهذا الموعد.'),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: duration,
                decoration: const InputDecoration(labelText: 'مدة الاستشارة'),
                items: const [15, 30, 45, 60, 90, 120].map((m) => DropdownMenuItem(value: m, child: Text('$m دقيقة'))).toList(),
                onChanged: (value) { if (value != null) setDialogState(() => duration = value); },
              ),
              const SizedBox(height: 14),
              TextField(controller: priceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'السعر', suffixText: 'د.ع', hintText: 'مثال: 25000')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                final price = double.tryParse(priceController.text.trim().replaceAll(',', ''));
                if (price == null || price <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('يرجى إدخال سعر صحيح أكبر من صفر')));
                  return;
                }
                Navigator.pop(dialogContext, {'duration': duration, 'price': price});
              },
              child: const Text('حفظ الموعد'),
            ),
          ],
        ),
      ),
    );
    priceController.dispose();
    if (details == null || !mounted) return;

    final start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر إضافة الموعد. تحقق من البيانات وحاول مرة أخرى.')));
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
      bottomNavigationBar: FutureBuilder<List<Map<String, dynamic>>>(
        future: _slotsFuture,
        builder: (context, snapshot) {
          final slots = snapshot.data ?? const <Map<String, dynamic>>[];
          final hasValidFutureSlot = slots.any(_isValidFutureSlot);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: FilledButton.icon(
                onPressed: hasValidFutureSlot ? () => context.go('/lawyer-home') : null,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('إكمال إعداد التوفر'),
              ),
            ),
          );
        },
      ),
    );
  }
}
