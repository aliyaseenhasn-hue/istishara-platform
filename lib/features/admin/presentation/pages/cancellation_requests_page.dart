import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:astshara/core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/user_facing_error.dart';

class CancellationRequestsPage extends StatefulWidget {
  const CancellationRequestsPage({super.key});

  @override
  State<CancellationRequestsPage> createState() => _CancellationRequestsPageState();
}

class _CancellationRequestsPageState extends State<CancellationRequestsPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final response = await SupabaseConfig.client.rpc('get_admin_cancellation_requests_v2');
    final rows = (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    await Future.wait(rows.map((row) async {
      try {
        final summary = await SupabaseConfig.client.rpc(
          'get_booking_cancellation_summary',
          params: {'p_booking_id': row['booking_id']},
        );
        if (summary is Map) {
          row['cancellation_summary'] = Map<String, dynamic>.from(summary);
        }
      } catch (_) {}
    }));
    return rows;
  }

  void _refresh() => setState(() => _future = _load());

  Map<String, dynamic>? _requestSummary(Map<String, dynamic> request) {
    final summaryRaw = request['cancellation_summary'];
    if (summaryRaw is! Map) return null;
    final summary = Map<String, dynamic>.from(summaryRaw);
    final req = summary['cancellation_request'];
    return req is Map ? Map<String, dynamic>.from(req) : null;
  }

  String _requesterRole(Map<String, dynamic> request) =>
      _requestSummary(request)?['requester_role']?.toString() ?? 'lawyer';

  Future<void> _review(Map<String, dynamic> request) async {
    if (request['status'] != 'بانتظار مراجعة الإدارة') return;
    final requesterRole = _requesterRole(request);
    final decision = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DecisionSheet(
        request: request,
        requesterRole: requesterRole,
      ),
    );
    if (decision == null || !mounted) return;

    try {
      double? rate;
      if (decision == 'الموافقة مع غرامة') {
        if (requesterRole == 'client') {
          rate = 1;
        } else {
          rate = await showDialog<double>(
            context: context,
            builder: (_) => const _PenaltyRateDialog(),
          );
          if (rate == null || !mounted) return;
        }
      }

      final paid = request['payment_status'] == 'تم الدفع';
      final paidAmount = (request['refund_amount'] as num?)?.toDouble() ?? 0;
      final price = (request['price'] as num?)?.toDouble() ?? 0;
      final isClient = requesterRole == 'client';
      final penalty = isClient && decision == 'الموافقة مع غرامة' && paid
          ? paidAmount * 0.01
          : (!isClient && decision == 'الموافقة مع غرامة' && rate != null
              ? price * rate / 100
              : 0.0);
      final clientRefund = isClient && paid
          ? paidAmount - penalty
          : (paid ? paidAmount : 0.0);

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'تأكيد قرار الإلغاء',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Text(
            isClient
                ? 'مقدم الطلب: طالب الاستشارة\n'
                    'قيمة الاستشارة: ${price.toStringAsFixed(0)} د.ع\n'
                    'حالة الدفع: ${request['payment_status'] ?? 'لا توجد دفعة مؤكدة'}\n'
                    'قرار الإدارة: ${decision == 'الموافقة مع غرامة' ? 'السبب غير مقنع — غرامة 1%' : 'السبب مقنع — بدون غرامة'}\n'
                    '${paid ? 'المبلغ الذي سيُعاد للعميل: ${clientRefund.toStringAsFixed(0)} د.ع\n' : ''}'
                    '${paid && penalty > 0 ? 'المبلغ المستحق للمحامي: ${penalty.toStringAsFixed(0)} د.ع\n' : ''}'
                    '\nبعد الاعتماد يصبح القرار المالي نهائياً.'
                : 'مقدم الطلب: المحامي\n'
                    'قيمة الاستشارة: ${price.toStringAsFixed(0)} د.ع\n'
                    'حالة الدفع: ${request['payment_status'] ?? 'لا توجد دفعة مؤكدة'}\n'
                    'قرار الإدارة: $decision\n'
                    '${paid ? 'الاسترداد الأصلي للعميل: ${paidAmount.toStringAsFixed(0)} د.ع\n' : ''}'
                    '${penalty > 0 ? 'التعويض الإضافي للعميل: ${penalty.toStringAsFixed(0)} د.ع\n' : ''}',
            style: const TextStyle(height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('رجوع'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.check_rounded),
              label: const Text('اعتماد القرار'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      await SupabaseConfig.client.rpc(
        'review_booking_cancellation',
        params: {
          'p_request_id': request['id'],
          'p_decision': decision,
          'p_penalty_rate': rate,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isClient
                ? (decision == 'الموافقة مع غرامة'
                    ? 'تم اعتماد غرامة 1% واسترداد 99% للعميل.'
                    : 'تم اعتماد الاسترداد الكامل بدون غرامة.')
                : 'تم اعتماد قرار إلغاء المحامي وتحديث الماليات.',
          ),
        ),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            UserFacingError.text(
              e,
              fallback: 'تعذر اعتماد قرار الإلغاء. حاول مرة أخرى.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('طلبات إلغاء الحجوزات'),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 46, color: AppColors.error),
                  const SizedBox(height: 12),
                  const Text('تعذر تحميل طلبات الإلغاء', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          final requests = snapshot.data ?? const <Map<String, dynamic>>[];
          if (requests.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.task_alt_rounded, size: 52, color: AppColors.success),
                  SizedBox(height: 12),
                  Text('لا توجد طلبات إلغاء حالياً', style: TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _refresh();
              await _future;
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) => _RequestCard(
                request: requests[index],
                onReview: _review,
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
  final Future<void> Function(Map<String, dynamic>) onReview;

  const _RequestCard({required this.request, required this.onReview});

  Map<String, dynamic>? get _requestSummary {
    final raw = request['cancellation_summary'];
    if (raw is! Map) return null;
    final summary = Map<String, dynamic>.from(raw);
    final nested = summary['cancellation_request'];
    return nested is Map ? Map<String, dynamic>.from(nested) : null;
  }

  @override
  Widget build(BuildContext context) {
    final requesterRole = _requestSummary?['requester_role']?.toString() ?? 'lawyer';
    final isClient = requesterRole == 'client';
    final pending = request['status'] == 'بانتظار مراجعة الإدارة';
    final scheduled = request['scheduled_at'] == null
        ? null
        : DateTime.tryParse(request['scheduled_at'].toString())?.toLocal();
    final price = (request['price'] as num?)?.toDouble() ?? 0;
    final paymentStatus = request['payment_status']?.toString() ?? 'لا توجد دفعة مؤكدة';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: pending ? AppColors.goldSoftStrong : AppColors.outlineVariant,
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
                  color: pending ? AppColors.pendingBg : AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isClient ? Icons.person_outline_rounded : Icons.gavel_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isClient ? 'طلب إلغاء من طالب الاستشارة' : 'طلب إلغاء من المحامي',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      request['consultation_type']?.toString() ?? 'استشارة قانونية',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _row('مقدم الطلب', isClient ? 'طالب الاستشارة' : 'المحامي'),
          _row('المحامي', request['lawyer_name']),
          _row('طالب الاستشارة', request['client_name']),
          _row('الموعد', scheduled == null ? 'غير محدد' : DateFormat('yyyy/MM/dd - hh:mm a').format(scheduled)),
          _row('قيمة الاستشارة', '${price.toStringAsFixed(0)} د.ع'),
          _row('حالة الدفع', paymentStatus),
          _row('سبب الإلغاء', request['reason']),
          if (isClient && pending && paymentStatus == 'تم الدفع')
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                'لم يُحدد مبلغ الاسترداد بعد: السبب المقنع = 100%، والسبب غير المقنع = 99% للعميل + 1% للمحامي.',
                style: TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w800,
                  height: 1.45,
                ),
              ),
            ),
          if (request['decision'] != null) _row('قرار الإدارة', request['decision']),
          if (request['penalty_rate'] != null) _row('نسبة الغرامة', '${request['penalty_rate']}%'),
          if (request['penalty_amount'] != null) _row('قيمة الغرامة/التعويض', '${request['penalty_amount']} ${request['currency'] ?? 'IQD'}'),
          if (pending) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => onReview(request),
              icon: const Icon(Icons.rule_outlined),
              label: const Text('مراجعة الإلغاء والماليات'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String title, dynamic value) {
    final text = value?.toString().trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 122,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text == null || text.isEmpty ? 'غير متوفر' : text,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionSheet extends StatelessWidget {
  final Map<String, dynamic> request;
  final String requesterRole;

  const _DecisionSheet({required this.request, required this.requesterRole});

  @override
  Widget build(BuildContext context) {
    final isClient = requesterRole == 'client';
    final paid = request['payment_status'] == 'تم الدفع';
    final amount = (request['refund_amount'] as num?)?.toDouble() ?? 0;

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isClient ? 'تقييم سبب إلغاء العميل' : 'مراجعة طلب إلغاء المحامي',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              'السبب: ${request['reason'] ?? 'غير محدد'}',
              style: const TextStyle(height: 1.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            if (isClient)
              Text(
                paid
                    ? 'المبلغ المدفوع ${amount.toStringAsFixed(0)} د.ع. إذا كان السبب مقنعاً يُعاد 100%. إذا كان غير مقنع يُعاد 99% ويُحوّل 1% للمحامي.'
                    : 'لا توجد دفعة مؤكدة حالياً. يمكنك اعتماد الإلغاء بدون غرامة، أما الغرامة فتحتاج دفعة أو إيصالاً قيد التحقق.',
                style: const TextStyle(fontWeight: FontWeight.w800, height: 1.5),
              )
            else
              const Text(
                'اختر قرار الإدارة المناسب لطلب المحامي. التعويض على المحامي منفصل عن أصل مبلغ الاسترداد للعميل.',
                style: TextStyle(fontWeight: FontWeight.w700, height: 1.5),
              ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, 'الموافقة بدون غرامة'),
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: Text(isClient ? 'السبب مقنع — استرداد 100%' : 'قبول الإلغاء بدون غرامة'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            ),
            const SizedBox(height: 9),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.pop(context, 'الموافقة مع غرامة'),
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: Text(isClient ? 'السبب غير مقنع — غرامة 1%' : 'قبول الإلغاء + تعويض للعميل'),
            ),
            if (!isClient) ...[
              const SizedBox(height: 9),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, 'رفض الإلغاء'),
                icon: const Icon(Icons.close_rounded),
                label: const Text('رفض طلب الإلغاء والإبقاء على الحجز'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PenaltyRateDialog extends StatefulWidget {
  const _PenaltyRateDialog();

  @override
  State<_PenaltyRateDialog> createState() => _PenaltyRateDialogState();
}

class _PenaltyRateDialogState extends State<_PenaltyRateDialog> {
  double _rate = 20;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('نسبة تعويض العميل'),
      content: DropdownButtonFormField<double>(
        initialValue: _rate,
        decoration: const InputDecoration(labelText: 'النسبة'),
        items: [
          for (int i = 5; i <= 100; i += 5)
            DropdownMenuItem(value: i.toDouble(), child: Text('$i%')),
        ],
        onChanged: (value) => setState(() => _rate = value ?? 20),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(context, _rate), child: const Text('متابعة')),
      ],
    );
  }
}
