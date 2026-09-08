import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astshara/core/config/supabase_config.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../providers/bookings_provider.dart';
import '../providers/bookings_realtime_provider.dart';
import '../../domain/entities/booking.dart';
import '../../domain/cancellation_policy.dart';
import 'booking_details_page.dart';

class BookingDetailsWithCancellation extends ConsumerStatefulWidget {
  final Booking booking;
  const BookingDetailsWithCancellation({super.key, required this.booking});

  @override
  ConsumerState<BookingDetailsWithCancellation> createState() => _BookingDetailsWithCancellationState();
}

class _BookingDetailsWithCancellationState extends ConsumerState<BookingDetailsWithCancellation> {
  bool _pending = false;
  bool _loading = true;
  bool _actionLoading = false;
  String? _requestStatus;
  Map<String, dynamic>? _credit;

  @override
  void initState() {
    super.initState();
    _loadCancellationState();
  }

  Future<void> _loadCancellationState() async {
    try {
      final user = ref.read(authStateChangesProvider).value;
      if (user == null) return;
      if (user.role == 'lawyer') {
        final rows = await SupabaseConfig.client.rpc('get_my_cancellation_requests');
        final list = rows is List ? rows : const [];
        for (final row in list) {
          final map = Map<String, dynamic>.from(row as Map);
          if (map['booking_id']?.toString() == widget.booking.id) {
            _requestStatus = map['status']?.toString();
            _pending = _requestStatus == 'بانتظار مراجعة الإدارة';
            break;
          }
        }
      } else if (user.id == widget.booking.userId) {
        final row = await SupabaseConfig.client
            .from('client_credits')
            .select('amount,currency,status,created_at')
            .eq('booking_id', widget.booking.id)
            .maybeSingle();
        _credit = row == null ? null : Map<String, dynamic>.from(row);
      }
    } catch (_) {
      // Optional cancellation/credit state must not block the core booking screen.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showRequestDialog() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('طلب إلغاء الحجز'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('يرجى توضيح سبب إلغاء الحجز. سيتم إرسال الطلب إلى الإدارة للمراجعة.'),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLines: 5,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'سبب الإلغاء', hintText: 'اكتب سبب الإلغاء هنا'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('سبب الإلغاء إلزامي')));
                return;
              }
              Navigator.of(dialogContext).pop(controller.text.trim());
            },
            child: const Text('إرسال طلب الإلغاء'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;
    try {
      setState(() => _actionLoading = true);
      await SupabaseConfig.client.rpc(
        'request_booking_cancellation',
        params: {'p_booking_id': widget.booking.id, 'p_reason': reason},
      );
      if (!mounted) return;
      setState(() {
        _pending = true;
        _requestStatus = 'بانتظار مراجعة الإدارة';
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلب إلغاء الحجز إلى الإدارة للمراجعة.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _cancelForClient() async {
    if (_actionLoading) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء الحجز'),
        content: const Text('هل تريد إلغاء هذا الحجز؟ لا يمكن التراجع عن الإلغاء بعد تنفيذه.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('تراجع')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('تأكيد الإلغاء')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      setState(() => _actionLoading = true);
      await SupabaseConfig.client.rpc(
        'change_booking_status',
        params: {'p_booking_id': widget.booking.id, 'p_new_status': 'ملغي'},
      );
      ref.invalidate(userBookingsProvider);
      ref.invalidate(lawyerBookingsProvider);
      ref.invalidate(bookingDetailsProvider(widget.booking.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إلغاء الحجز بنجاح')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveBooking = ref.watch(bookingRealtimeProvider(widget.booking.id)).valueOrNull ?? widget.booking;
    final user = ref.watch(authStateChangesProvider).value;
    final isLawyer = user?.role == 'lawyer';
    final isClient = user?.id == liveBooking.userId && !isLawyer;
    final eligibleCancellation = BookingCancellationPolicy.canRequest(
      status: liveBooking.status,
      scheduledAt: liveBooking.scheduledAt,
      pendingReview: _pending,
    );
    final needsReview = isLawyer &&
        !liveBooking.lawyerApproved &&
        ['قيد انتظار الدفع', 'قيد معالجة الدفع', 'قيد مراجعة المحامي'].contains(liveBooking.status);
    final clientCanCancel = isClient &&
        ['قيد انتظار الدفع', 'قيد معالجة الدفع', 'مؤكد'].contains(liveBooking.status) &&
        liveBooking.scheduledAt.isAfter(DateTime.now());
    final decisionText = switch (_requestStatus) {
      'تم رفض الطلب' => 'تم رفض طلب إلغاء الحجز من الإدارة.',
      'تمت الموافقة' => 'تمت الموافقة على طلب إلغاء الحجز بدون غرامة.',
      'بانتظار تحصيل الغرامة' => 'تمت الموافقة على الإلغاء مع غرامة، والغرامة بانتظار التحصيل.',
      'تم تحصيل الغرامة' => 'تمت الموافقة على الإلغاء وتم تحصيل الغرامة.',
      _ => null,
    };

    return Stack(
      children: [
        BookingDetailsPage(booking: liveBooking),
        if (isLawyer && !_loading && !needsReview && eligibleCancellation)
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: SafeArea(
              child: OutlinedButton.icon(
                onPressed: _actionLoading ? null : _showRequestDialog,
                icon: const Icon(Icons.event_busy_outlined),
                label: const Text('طلب إلغاء الحجز'),
              ),
            ),
          ),
        if (isLawyer && !_loading && _pending)
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
                child: const Row(children: [Icon(Icons.hourglass_top_rounded), SizedBox(width: 10), Expanded(child: Text('طلب إلغاء الحجز بانتظار مراجعة الإدارة.'))]),
              ),
            ),
          ),
        if (isLawyer && !_loading && !_pending && decisionText != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [const Icon(Icons.info_outline_rounded), const SizedBox(width: 10), Expanded(child: Text(decisionText))]),
              ),
            ),
          ),
        if (isClient && clientCanCancel)
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: SafeArea(
              child: OutlinedButton.icon(
                onPressed: _actionLoading ? null : _cancelForClient,
                icon: const Icon(Icons.event_busy_outlined),
                label: const Text('إلغاء الحجز'),
              ),
            ),
          ),
        if (isClient && _credit != null && _credit!['status'] == 'مستحق')
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [const Icon(Icons.account_balance_wallet_outlined), const SizedBox(width: 10), Expanded(child: Text('تعويض مستحق لك: ${_credit!['amount']} ${_credit!['currency']}'))]),
              ),
            ),
          ),
      ],
    );
  }
}
