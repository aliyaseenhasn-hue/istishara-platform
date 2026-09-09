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
      if (response is! Map || !mounted) return;
      final summary = Map<String, dynamic>.from(response);
      final request = summary['cancellation_request'];
      final creditsRaw = summary['credits'];
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
    } catch (_) {
      // Optional details must never block the core booking screen.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _askReason({required bool lawyer}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(lawyer ? 'طلب إلغاء الحجز' : 'إلغاء الحجز'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              lawyer
                  ? 'سيُرسل الطلب إلى الإدارة للمراجعة. اكتب السبب بوضوح لأنه سيُحفظ ضمن سجل الإلغاء.'
                  : 'إذا كان المبلغ مدفوعاً فسيُسجل مبلغ الاستشارة للاسترداد وفق سياسة الإلغاء، ثم تحوله الإدارة إلى حساب الاستلام المرتبط.',
            ),
            if (!lawyer) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(dialogContext).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(dialogContext).colorScheme.error.withValues(alpha: .25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Theme.of(dialogContext).colorScheme.error,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'تنبيه: إذا اعتبرت الإدارة سبب الإلغاء غير مقنع، سيتم استقطاع غرامة قدرها 1% من مبلغ الاستشارة وتحويلها للمحامي.',
                        style: TextStyle(
                          color: Theme.of(dialogContext).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w800,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLines: 4,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'سبب الإلغاء',
                hintText: 'اكتب سبباً مختصراً وواضحاً',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('تراجع')),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('سبب الإلغاء إلزامي')),
                );
                return;
              }
              Navigator.pop(dialogContext, value);
            },
            child: Text(lawyer ? 'إرسال طلب الإلغاء' : 'تأكيد الإلغاء'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _requestForLawyer() async {
    if (_actionLoading) return;
    final reason = await _askReason(lawyer: true);
    if (reason == null || !mounted) return;
    try {
      setState(() => _actionLoading = true);
      await SupabaseConfig.client.rpc(
        'request_booking_cancellation',
        params: {'p_booking_id': widget.booking.id, 'p_reason': reason},
      );
      await _loadCancellationState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال طلب الإلغاء إلى الإدارة للمراجعة.')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorText(e))));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _cancelForClient() async {
    if (_actionLoading) return;
    final reason = await _askReason(lawyer: false);
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
        const SnackBar(content: Text('تم تسجيل الإلغاء وتحديث حالة الاستشارة.')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorText(e))));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  String _errorText(Object e) => e.toString().replaceFirst('Exception: ', '');

  String _actorLabel(String? role) => switch (role) {
        'client' => 'طالب الاستشارة',
        'lawyer' => 'المحامي',
        'admin' => 'الإدارة',
        'system' => 'النظام / سجل سابق',
        _ => 'غير محدد',
      };

  String _sourceLabel(String? source) => switch (source) {
        'client_direct' => 'إلغاء مباشر من طالب الاستشارة',
        'lawyer_cancellation_request' => 'طلب إلغاء من المحامي بعد مراجعة الإدارة',
        'no_show' => 'قرار عدم حضور',
        'legacy_cancellation' => 'إلغاء سابق',
        _ => source ?? 'غير محدد',
      };

  String _creditTitle(Map<String, dynamic> credit) =>
      credit['transaction_type']?.toString() == 'استرداد قيمة استشارة'
          ? 'استرداد مبلغ الاستشارة'
          : 'تعويض إضافي';

  String _creditStatus(Map<String, dynamic> credit) {
    final status = credit['status']?.toString() ?? '';
    final hasPayoutAccount = _summary?['has_payout_account'] == true;
    return switch (status) {
      'مستحق' when !hasPayoutAccount => 'يلزم إضافة حساب استلام',
      'مستحق' => 'مستحق وجاهز للتحويل',
      'بانتظار التحويل' => 'بانتظار تنفيذ التحويل',
      'قيد الانتظار' => 'قيد الانتظار',
      'settled' => 'تم التحويل',
      'بانتظار تحصيل الغرامة' => 'بانتظار تحصيل الغرامة من المحامي',
      _ => status,
    };
  }

  String _dateTime(dynamic value) {
    final parsed = DateTime.tryParse('${value ?? ''}')?.toLocal();
    if (parsed == null) return 'غير محدد';
    return '${parsed.year}/${parsed.month.toString().padLeft(2, '0')}/${parsed.day.toString().padLeft(2, '0')} - '
        '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showDetails() async {
    await _loadCancellationState();
    if (!mounted) return;
    final requestRaw = _summary?['cancellation_request'];
    final request = requestRaw is Map ? Map<String, dynamic>.from(requestRaw) : null;
    final actorRole = _summary?['cancellation_actor_role']?.toString();
    final actorName = _summary?['cancelled_by_name']?.toString();
    final reason = _summary?['cancellation_reason']?.toString();
    final source = _summary?['cancellation_source']?.toString();
    final currentUser = ref.read(authStateChangesProvider).value;
    final isClient = currentUser?.role != 'lawyer' && currentUser?.id == widget.booking.userId;
    final hasPayoutAccount = _summary?['has_payout_account'] == true;
    final needsPayoutAccount = isClient &&
        !hasPayoutAccount &&
        _credits.any((credit) {
          final status = credit['status']?.toString();
          return ['مستحق', 'pending', 'بانتظار التحويل', 'قيد الانتظار'].contains(status);
        });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('تفاصيل الإلغاء والاسترداد', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              _DetailCard(
                title: 'بيانات الإلغاء',
                icon: Icons.event_busy_outlined,
                rows: [
                  ('الحالة الحالية', _summary?['booking_status']?.toString() ?? widget.booking.status),
                  ('تم الإلغاء بواسطة', actorName?.trim().isNotEmpty == true ? '$actorName (${_actorLabel(actorRole)})' : _actorLabel(actorRole)),
                  ('مصدر الإلغاء', _sourceLabel(source)),
                  ('سبب الإلغاء', reason?.trim().isNotEmpty == true ? reason! : request?['reason']?.toString() ?? 'غير محدد'),
                  ('وقت الإلغاء', _dateTime(_summary?['cancelled_at'])),
                ],
              ),
              if (request != null) ...[
                const SizedBox(height: 12),
                _DetailCard(
                  title: 'قرار الإدارة',
                  icon: Icons.rule_outlined,
                  rows: [
                    ('حالة الطلب', request['status']?.toString() ?? 'غير محدد'),
                    ('القرار', request['decision']?.toString() ?? 'بانتظار القرار'),
                    if (request['penalty_rate'] != null) ('نسبة الغرامة', '${request['penalty_rate']}%'),
                    if (request['penalty_amount'] != null) ('قيمة التعويض', '${request['penalty_amount']} ${request['currency'] ?? 'IQD'}'),
                    ('تاريخ الطلب', _dateTime(request['requested_at'])),
                    if (request['reviewed_at'] != null) ('تاريخ المراجعة', _dateTime(request['reviewed_at'])),
                  ],
                ),
              ],
              if (_credits.isNotEmpty) ...[
                const SizedBox(height: 12),
                ..._credits.map((credit) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DetailCard(
                        title: _creditTitle(credit),
                        icon: credit['transaction_type']?.toString() == 'استرداد قيمة استشارة'
                            ? Icons.undo_rounded
                            : Icons.volunteer_activism_outlined,
                        rows: [
                          ('المبلغ', '${credit['amount']} ${credit['currency'] ?? 'IQD'}'),
                          ('الحالة', _creditStatus(credit)),
                          if (credit['provider_type'] != null) ('وسيلة التحويل', credit['provider_type'].toString()),
                          if (credit['provider_reference']?.toString().trim().isNotEmpty == true)
                            ('مرجع التحويل', credit['provider_reference'].toString()),
                          if (credit['paid_at'] != null) ('تاريخ التحويل', _dateTime(credit['paid_at'])),
                        ],
                      ),
                    )),
              ],
              if (needsPayoutAccount) ...[
                const SizedBox(height: 4),
                const _InfoBox(
                  icon: Icons.account_balance_outlined,
                  text: 'لديك مبلغ مستحق، لكن لا يوجد حساب استلام محفوظ. أضف زين كاش أو Qi Card أو آسيا حوالة أو حساباً مصرفياً حتى تتمكن الإدارة من تحويل المبلغ فعلياً.',
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    context.push('/payment-methods');
                  },
                  icon: const Icon(Icons.add_card_rounded),
                  label: const Text('إضافة حساب استلام'),
                ),
              ],
              if (_credits.isEmpty && ['بانتظار الاسترداد', 'مسترد'].contains(_summary?['booking_status'])) ...[
                const SizedBox(height: 12),
                const _InfoBox(
                  icon: Icons.account_balance_wallet_outlined,
                  text: 'تم إلغاء الاستشارة مالياً. إذا كان هناك مبلغ مدفوع فسيظهر سجل الاسترداد هنا عند اكتمال إنشائه.',
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
    final hasCancellationDetails = !_loading &&
        (_summary?['cancellation_actor_role'] != null ||
            _summary?['cancellation_request'] != null ||
            _credits.isNotEmpty ||
            ['ملغي', 'بانتظار الاسترداد', 'مسترد'].contains(liveBooking.status));

    final buttons = <Widget>[];
    if (isLawyer && !_loading && !needsReview && eligibleCancellation) {
      buttons.add(OutlinedButton.icon(
        onPressed: _actionLoading ? null : _requestForLawyer,
        icon: const Icon(Icons.event_busy_outlined),
        label: const Text('طلب إلغاء الحجز'),
      ));
    } else if (isLawyer && !_loading && _pending) {
      buttons.add(const _InfoBox(icon: Icons.hourglass_top_rounded, text: 'طلب الإلغاء بانتظار مراجعة الإدارة.'));
    } else if (isClient && clientCanCancel) {
      buttons.add(OutlinedButton.icon(
        onPressed: _actionLoading ? null : _cancelForClient,
        icon: const Icon(Icons.event_busy_outlined),
        label: const Text('إلغاء الحجز'),
      ));
    }

    if (hasCancellationDetails) {
      buttons.add(FilledButton.tonalIcon(
        onPressed: _showDetails,
        icon: const Icon(Icons.receipt_long_outlined),
        label: const Text('تفاصيل الإلغاء والاسترداد'),
      ));
    }

    return Stack(
      children: [
        BookingDetailsPage(booking: liveBooking),
        if (buttons.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < buttons.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: buttons[i]),
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

class _DetailCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<(String, String)> rows;
  const _DetailCard({required this.title, required this.icon, required this.rows});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 10),
          ...rows.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 108, child: Text(row.$1, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(row.$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
