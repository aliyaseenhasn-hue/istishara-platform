import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:astshara/core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';

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
    final response = await SupabaseConfig.client.rpc('get_admin_cancellation_requests');
    return (response as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _review(Map<String, dynamic> request) async {
    if (request['status'] != 'بانتظار مراجعة الإدارة') return;
    final decision = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _DecisionSheet(request: request),
    );
    if (decision == null || !mounted) return;
    try {
      double? rate;
      if (decision == 'الموافقة مع غرامة') {
        rate = await showDialog<double>(context: context, builder: (dialogContext) => const _PenaltyRateDialog());
        if (rate == null || !mounted) return;
      }
      final bookingPrice = (request['price'] as num?)?.toDouble() ?? 0;
      if (decision == 'الموافقة مع غرامة' && rate != null) {
        final amount = bookingPrice * rate / 100;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('تأكيد القرار المالي', style: TextStyle(fontWeight: FontWeight.w900)),
            content: Text(
              'قيمة الاستشارة: ${bookingPrice.toStringAsFixed(0)} د.ع\n'
              'نسبة الغرامة: ${rate!.toStringAsFixed(0)}%\n'
              'قيمة الغرامة للعرض: ${amount.toStringAsFixed(0)} د.ع\n'
              'المستفيد من التعويض: ${request['client_name']}\n\n'
              'سيتم الحساب والاعتماد النهائيان داخل قاعدة البيانات.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('رجوع')),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.check_rounded),
                label: const Text('اعتماد القرار'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
      await SupabaseConfig.client.rpc(
        'review_booking_cancellation',
        params: {'p_request_id': request['id'], 'p_decision': decision, 'p_penalty_rate': rate},
      );
      if (!mounted) return;

      setState(() {
        request['status'] = decision == 'رفض الإلغاء' ? 'مرفوض' : 'مقبول';
      });

      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(const SnackBar(content: Text('تم اعتماد القرار بنجاح.')));

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      } else {
        _refresh();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('طلبات إلغاء الحجوزات'),
          centerTitle: true,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث')],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline_rounded, size: 46, color: AppColors.error),
                  const SizedBox(height: 12),
                  const Text('تعذر تحميل طلبات الإلغاء', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  FilledButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
                ]),
              );
            }
            final requests = snapshot.data ?? const [];
            final pendingCount = requests.where((e) => e['status'] == 'بانتظار مراجعة الإدارة').length;
            if (requests.isEmpty) {
              return const Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.task_alt_rounded, size: 52, color: AppColors.success),
                  SizedBox(height: 12),
                  Text('لا توجد طلبات إلغاء حالياً', style: TextStyle(fontWeight: FontWeight.w900)),
                ]),
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                _refresh();
                await _future;
              },
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: requests.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.primaryDark, AppColors.primary], begin: Alignment.topRight, end: Alignment.bottomLeft),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(15)),
                          child: const Icon(Icons.event_busy_outlined, color: Colors.white, size: 27),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('مراجعة طلبات الإلغاء', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                            const SizedBox(height: 4),
                            Text('$pendingCount طلباً بانتظار قرار الإدارة', style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                          ]),
                        ),
                      ]),
                    );
                  }
                  return _RequestCard(request: requests[index - 1], onReview: _review);
                },
              ),
            );
          },
        ),
      );
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final Future<void> Function(Map<String, dynamic>) onReview;
  const _RequestCard({required this.request, required this.onReview});

  @override
  Widget build(BuildContext context) {
    final pending = request['status'] == 'بانتظار مراجعة الإدارة';
    final scheduled = request['scheduled_at'] == null ? null : DateTime.tryParse(request['scheduled_at'].toString())?.toLocal();
    final price = (request['price'] as num?)?.toDouble() ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pending ? AppColors.goldSoftStrong : AppColors.outlineVariant),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .035), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: pending ? AppColors.pendingBg : AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.event_busy_outlined, color: pending ? AppColors.pendingText : AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('طلب إلغاء حجز', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.textPrimary)),
              const SizedBox(height: 3),
              Text(request['consultation_type']?.toString() ?? 'استشارة قانونية', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: pending ? AppColors.pendingBg : request['status'] == 'مرفوض' ? AppColors.cancelledBg : AppColors.acceptedBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              request['status']?.toString() ?? '',
              style: TextStyle(
                color: pending ? AppColors.pendingText : request['status'] == 'مرفوض' ? AppColors.cancelledText : AppColors.acceptedText,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(15)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _row('المحامي', request['lawyer_name']),
            _row('طالب الاستشارة', request['client_name']),
            _row('طريقة التنفيذ', request['consultation_mode']),
            _row('الموعد', scheduled == null ? 'غير محدد' : DateFormat('yyyy/MM/dd - hh:mm a').format(scheduled)),
            _row('قيمة الاستشارة', '${price.toStringAsFixed(0)} د.ع'),
            _row('سبب الإلغاء', request['reason']),
            _row('تاريخ الطلب', DateFormat('yyyy/MM/dd - hh:mm a').format(DateTime.parse(request['requested_at'].toString()).toLocal())),
            if (request['penalty_rate'] != null) _row('نسبة الغرامة', '${request['penalty_rate']}%'),
            if (request['penalty_amount'] != null) _row('مبلغ الغرامة', '${request['penalty_amount']} ${request['currency']}'),
          ]),
        ),
        if (request['description']?.toString().trim().isNotEmpty == true) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.primaryFixed, borderRadius: BorderRadius.circular(14)),
            child: Text(request['description'].toString(), style: const TextStyle(color: AppColors.textPrimary, height: 1.5)),
          ),
        ],
        if (pending) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => onReview(request),
            icon: const Icon(Icons.rule_outlined),
            label: const Text('مراجعة طلب الإلغاء', style: TextStyle(fontWeight: FontWeight.w900)),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _row(String title, dynamic value) {
    final text = value?.toString().trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 112, child: Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w700))),
        const SizedBox(width: 6),
        Expanded(child: Text(text == null || text.isEmpty ? 'غير متوفر' : text, style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

class _DecisionSheet extends StatelessWidget {
  final Map<String, dynamic> request;
  const _DecisionSheet({required this.request});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: AppColors.outlineVariant, borderRadius: BorderRadius.circular(99)))),
            const SizedBox(height: 18),
            const Text('مراجعة طلب إلغاء الحجز', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text('المحامي: ${request['lawyer_name']}\nطالب الاستشارة: ${request['client_name']}\nالسبب: ${request['reason']}', style: const TextStyle(color: AppColors.textSecondary, height: 1.6)),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, 'الموافقة بدون غرامة'),
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('الموافقة بدون غرامة'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13)),
            ),
            const SizedBox(height: 9),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.pop(context, 'الموافقة مع غرامة'),
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('الموافقة مع غرامة'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.pendingBg, foregroundColor: AppColors.pendingText, padding: const EdgeInsets.symmetric(vertical: 13)),
            ),
            const SizedBox(height: 9),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, 'رفض الإلغاء'),
              icon: const Icon(Icons.close_rounded),
              label: const Text('رفض الإلغاء'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error), padding: const EdgeInsets.symmetric(vertical: 13)),
            ),
          ]),
        ),
      );
}

class _PenaltyRateDialog extends StatefulWidget {
  const _PenaltyRateDialog();
  @override
  State<_PenaltyRateDialog> createState() => _PenaltyRateDialogState();
}

class _PenaltyRateDialogState extends State<_PenaltyRateDialog> {
  double _rate = 20;

  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('نسبة الغرامة', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('اختر نسبة الغرامة، وسيتم حساب المبلغ النهائي خادمياً.'),
          const SizedBox(height: 12),
          DropdownButtonFormField<double>(
            initialValue: _rate,
            decoration: const InputDecoration(labelText: 'نسبة الغرامة', border: OutlineInputBorder()),
            items: [for (int i = 5; i <= 100; i += 5) DropdownMenuItem(value: i.toDouble(), child: Text('$i%'))],
            onChanged: (value) => setState(() => _rate = value ?? 20),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, _rate), child: const Text('متابعة')),
        ],
      );
}
