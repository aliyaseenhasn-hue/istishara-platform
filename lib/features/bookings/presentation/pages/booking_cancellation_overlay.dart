import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _credits = const [];

  @override
  void initState() {
    super.initState();
    _loadCancellationState();
  }

  Future<void> _loadCancellationState() async {
    try {
      final response = await SupabaseConfig.client.rpc(
        'get_booking_cancellation_summary',
        params: {'p_booking_id': widget.booking.id},
      );
      if (response is Map) {
        final summary = Map<String, dynamic>.from(response);
        final request = summary['cancellation_request'];
        final creditsRaw = summary['credits'];
        if (!mounted) return;
        setState(() {
          _summary = summary;
          if (request is Map) {
            final map = Map<String, dynamic>.from(request);
            _requestStatus = map['status']?.toString();
            _pending = _requestStatus == 'بانتظار مراجعة الإدارة';
          } else {
            _requestStatus = null;
            _pending = false;
          }
          _credits = creditsRaw is List
              ? creditsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
              : const [];
        });
      }
    } catch (_) {
      // Cancellation details must not block opening the core booking screen.
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
            const Text('سيُرسل طلب الإلغاء إلى الإدارة للمراجعة. اكتب السبب بوضوح لأنه سيُحفظ ضمن تفاصيل الإلغاء.'),
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
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('تراجع')),
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
      await _loadCancellationState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلب الإلغاء إلى الإدارة للمراجعة.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorText(e))));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _cancelForClient() async {
    if (_actionLoading) return;
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء الحجز'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'بعد الإلغاء لا يمكن إعادة الحجز نفسه. إذا كان المبلغ مدفوعاً فسيُسجل كامل مبلغ الاستشارة للاسترداد، وتتابع الإدارة تحويله إلى حساب الاستلام المرتبط.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'سبب الإلغاء', hintText: 'سبب مختصر وواضح'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('تراجع')),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('سبب الإلغاء إلزامي')));
                return;
              }
              Navigator.of(dialogContext).pop(value);
            },
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;
    try {
      setState(() => _actionLoading = true);
      await SupabaseConfig.client.rpc(
        'request_client_booking_cancellation',
        params: {'p_booking_id': widget.booking.id, 'p_reason': reason},
      );
      ref.invalidate(userBookingsProvider);
      ref.invalidate(lawyerBookingsProvider);
      ref.invalidate(bookingDetailsProvider(widget.booking.id));
      await _loadCancellationState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل الإلغاء. إذا كان الحجز مدفوعاً فسيظهر الاسترداد ضمن التفاصيل المالية.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorText(e))));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  String _errorText(Object e) => e.toString().replaceFirst('Exception: ', '');

  String _actorLabel(String? role) => switch (role) {
        'client' => 'طالب الاستشارة',
        'lawyer' => 'المحامي',
        'admin' => 'الإدارة',
        'system' => 'النظام / سجل قديم',
        _ => 'غير محدد',
      };

  String _creditTitle(Map<String, dynamic> credit) {
    final type = credit['transaction_type']?.toString();
    return type == 'استرداد قيمة استشارة' ? 'استرداد مبلغ الاستشارة' : 'تعويض إلغاء من المحامي';
  }

  String _creditStatus(Map<String, dynamic> credit) {
    final status = credit['status']?.toString() ?? '';
    return switch (status) {
      'مستحق' => 'مستحق وجاهز للتحويل',
      'بانتظار التحويل' => 'بانتظار تنفيذ التحويل',
      'settled' => 'تم التحويل',
      'بانتظار تحصيل الغرامة' => 'بانتظار تحصيل الغرامة من المحامي',
      _ => status,
    };
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
        ['قيد انتظار الدفع', 'قيد معالجة الدفع', 'قيد مراجعة المحامي', 'بانتظار التأكيد', 'مؤكد'].contains(liveBooking.status) &&
        liveBooking.scheduledAt.isAfter(DateTime.now());

    final actorRole = _summary?['cancellation_actor_role']?.toString();
    final reason = _summary?['cancellation_reason']?.toString();
    final cancelledAt = DateTime.tryParse(_summary?['cancelled_at']?.toString() ?? '')?.toLocal();
    final cancelledOrRefunding = ['ملغي', 'بانتظار الاسترداد', 'مسترد'].contains(liveBooking.status) || actorRole != null;
    final request = _summary?['cancellation_request'];
    final requestMap = request is Map ? Map<String, dynamic>.from(request) : null;

    final footer = <Widget>[];
    if (isLawyer && !_loading && !needsReview && eligibleCancellation) {
      footer.add(OutlinedButton.icon(
        onPressed: _actionLoading ? null : _showRequestDialog,
        icon: const Icon(Icons.event_busy_outlined),
        label: const Text('طلب إلغاء الحجز'),
      ));
    } else if (isLawyer && !_loading && _pending) {
      footer.add(const _InfoBox(icon: Icons.hourglass_top_rounded, text: 'طلب الإلغاء بانتظار مراجعة الإدارة.'));
    } else if (isClient && clientCanCancel) {
      footer.add(OutlinedButton.icon(
        onPressed: _actionLoading ? null : _cancelForClient,
        icon: const Icon(Icons.event_busy_outlined),
        label: const Text('إلغاء الحجز'),
      ));
    }

    if (!_loading && cancelledOrRefunding) {
      footer.add(_InfoBox(
        icon: Icons.info_outline_rounded,
        text: 'تم الإلغاء بواسطة: ${_actorLabel(actorRole)}'
            '${reason == null || reason.trim().isEmpty ? '' : '\nالسبب: $reason'}'
            '${cancelledAt == null ? '' : '\nوقت الإلغاء: ${cancelledAt.year}/${cancelledAt.month.toString().padLeft(2, '0')}/${cancelledAt.day.toString().padLeft(2, '0')} - ${cancelledAt.hour.toString().padLeft(2, '0')}:${cancelledAt.minute.toString().padLeft(2, '0')}'}',
      ));
    }

    if (isLawyer && requestMap != null && _requestStatus != null && !_pending) {
      final decision = requestMap['decision']?.toString();
      final penalty = requestMap['penalty_amount'];
      footer.add(_InfoBox(
        icon: Icons.rule_outlined,
        text: 'قرار الإدارة: ${decision ?? _requestStatus}'
            '${penalty == null ? '' : '\nالغرامة/التعويض: $penalty ${requestMap['currency'] ?? 'IQD'}'}'
            '\nالحالة: $_requestStatus',
      ));
    }

    if (isClient && _credits.isNotEmpty) {
      footer.add(Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(children: [
              Icon(Icons.account_balance_wallet_outlined),
              SizedBox(width: 8),
              Text('الاسترداد والتعويض', style: TextStyle(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 8),
            ..._credits.map((credit) => Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    '${_creditTitle(credit)}: ${credit['amount']} ${credit['currency']}\n${_creditStatus(credit)}',
                    style: const TextStyle(height: 1.45),
                  ),
                )),
          ],
        ),
      ));
    }

    return Stack(
      children: [
        BookingDetailsPage(booking: liveBooking),
        if (footer.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < footer.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: footer[i]),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoBox({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(height: 1.45))),
          ],
        ),
      );
}
