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
  void initState() { super.initState(); _future = _load(); }
  Future<List<Map<String, dynamic>>> _load() async {
    final response = await SupabaseConfig.client.rpc('get_admin_cancellation_requests');
    return (response as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }
  void _refresh() => setState(() => _future = _load());

  Future<void> _review(Map<String, dynamic> request) async {
    if (request['status'] != 'بانتظار مراجعة الإدارة') return;
    final decision = await showModalBottomSheet<String>(context: context, isScrollControlled: true, builder: (sheetContext) => _DecisionSheet(request: request));
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
            title: const Text('تأكيد القرار المالي'),
            content: Text('قيمة الاستشارة: ${bookingPrice.toStringAsFixed(0)} د.ع\nنسبة الغرامة: ${rate!.toStringAsFixed(0)}%\nقيمة الغرامة للعرض: ${amount.toStringAsFixed(0)} د.ع\nالمستفيد من التعويض: ${request['client_name']}\n\nسيتم الحساب والاعتماد النهائيان داخل قاعدة البيانات.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('رجوع')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('اعتماد القرار')),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
      await SupabaseConfig.client.rpc('review_booking_cancellation', params: {'p_request_id': request['id'], 'p_decision': decision, 'p_penalty_rate': rate});
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('طلبات إلغاء الحجوزات'), backgroundColor: AppColors.primary, foregroundColor: Colors.white, actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh), tooltip: 'تحديث')]),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('تعذر تحميل طلبات الإلغاء: ${snapshot.error}'));
        final requests = snapshot.data ?? const [];
        if (requests.isEmpty) return const Center(child: Text('لا توجد طلبات إلغاء حالياً.'));
        return ListView.separated(padding: const EdgeInsets.all(16), itemCount: requests.length, separatorBuilder: (_, __) => const SizedBox(height: 12), itemBuilder: (context, index) => _RequestCard(request: requests[index], onReview: _review));
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
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [const Icon(Icons.event_busy_outlined), const SizedBox(width: 8), Expanded(child: Text(request['status']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold))), if (pending) const Chip(label: Text('مطلوب إجراء'))]),
      const Divider(height: 22),
      _row('المحامي', request['lawyer_name']), _row('طالب الاستشارة', request['client_name']), _row('الحجز الداخلي', request['booking_id']), _row('نوع الاستشارة', request['consultation_type']), _row('طريقة التنفيذ', request['consultation_mode']),
      _row('الموعد', scheduled == null ? 'غير محدد' : DateFormat('yyyy/MM/dd - hh:mm a').format(scheduled)), _row('قيمة الاستشارة', '${price.toStringAsFixed(0)} د.ع'), _row('سبب الإلغاء', request['reason']),
      _row('تاريخ الطلب', DateFormat('yyyy/MM/dd - hh:mm a').format(DateTime.parse(request['requested_at'].toString()).toLocal())),
      if (request['penalty_rate'] != null) _row('نسبة الغرامة', '${request['penalty_rate']}%'), if (request['penalty_amount'] != null) _row('مبلغ الغرامة', '${request['penalty_amount']} ${request['currency']}'), if (request['description']?.toString().trim().isNotEmpty == true) _row('تفاصيل الاستشارة', request['description']),
      if (pending) ...[const SizedBox(height: 14), FilledButton.icon(onPressed: () => onReview(request), icon: const Icon(Icons.rule_outlined), label: const Text('مراجعة طلب الإلغاء'))],
    ])));
  }
  Widget _row(String title, dynamic value) => Padding(padding: const EdgeInsets.only(bottom: 7), child: Text('$title: ${value?.toString().trim().isNotEmpty == true ? value : 'غير متوفر'}', textAlign: TextAlign.right));
}

class _DecisionSheet extends StatelessWidget {
  final Map<String, dynamic> request;
  const _DecisionSheet({required this.request});
  @override
  Widget build(BuildContext context) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text('مراجعة طلب إلغاء الحجز', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
    const SizedBox(height: 8), Text('المحامي: ${request['lawyer_name']}\nطالب الاستشارة: ${request['client_name']}\nالسبب: ${request['reason']}'), const SizedBox(height: 18),
    FilledButton(onPressed: () => Navigator.pop(context, 'الموافقة بدون غرامة'), child: const Text('الموافقة بدون غرامة')), const SizedBox(height: 8),
    FilledButton.tonal(onPressed: () => Navigator.pop(context, 'الموافقة مع غرامة'), child: const Text('الموافقة مع غرامة')), const SizedBox(height: 8),
    OutlinedButton(onPressed: () => Navigator.pop(context, 'رفض الإلغاء'), child: const Text('رفض الإلغاء')),
  ])));
}

class _PenaltyRateDialog extends StatefulWidget {
  const _PenaltyRateDialog();
  @override State<_PenaltyRateDialog> createState() => _PenaltyRateDialogState();
}
class _PenaltyRateDialogState extends State<_PenaltyRateDialog> {
  double _rate = 20;
  @override
  Widget build(BuildContext context) => AlertDialog(title: const Text('نسبة الغرامة'), content: Column(mainAxisSize: MainAxisSize.min, children: [const Text('اختر نسبة الغرامة، وسيتم حساب المبلغ النهائي خادمياً.'), const SizedBox(height: 10), DropdownButtonFormField<double>(initialValue: _rate, decoration: const InputDecoration(labelText: 'نسبة الغرامة'), items: [for (int i = 5; i <= 100; i += 5) DropdownMenuItem(value: i.toDouble(), child: Text('$i%'))], onChanged: (value) => setState(() => _rate = value ?? 20))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, _rate), child: const Text('متابعة'))]);
}
