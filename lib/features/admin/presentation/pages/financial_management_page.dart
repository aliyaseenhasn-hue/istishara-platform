import 'package:flutter/material.dart';
import 'package:astshara/core/config/supabase_config.dart';

class FinancialManagementPage extends StatefulWidget {
  const FinancialManagementPage({super.key});

  @override
  State<FinancialManagementPage> createState() => _FinancialManagementPageState();
}

class _FinancialManagementPageState extends State<FinancialManagementPage> {
  Map<String, dynamic>? settings;
  List<Map<String, dynamic>> payouts = [];
  List<Map<String, dynamic>> clientCredits = [];
  bool loading = true;
  bool processing = false;
  final rateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    rateController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    try {
      settings = await SupabaseConfig.client
          .from('platform_financial_settings')
          .select()
          .eq('id', true)
          .single();
      rateController.text = '${settings?['commission_rate'] ?? 0}';

      final results = await Future.wait([
        SupabaseConfig.client
            .from('lawyer_payout_requests')
            .select(
              'id,lawyer_id,amount,currency,status,wallet_type,wallet_number,'
              'wallet_holder_name,created_at,rejection_reason,provider_reference',
            )
            .order('created_at', ascending: false)
            .limit(50),
        SupabaseConfig.client.rpc('admin_list_client_credit_operations'),
      ]);
      payouts = List<Map<String, dynamic>>.from(results[0] as List);
      clientCredits = List<Map<String, dynamic>>.from(results[1] as List);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل البيانات: ${_errorText(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _saveRate() async {
    final rate = double.tryParse(rateController.text.trim());
    if (rate == null || rate < 0 || rate > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل نسبة بين 0 و100')),
      );
      return;
    }
    try {
      await SupabaseConfig.client.rpc('admin_set_commission_rate', params: {'p_rate': rate});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ نسبة العمولة للدفعات الجديدة')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر الحفظ: ${_errorText(e)}')),
        );
      }
    }
  }

  Future<String?> _askProviderReference({bool required = false}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد التحويل'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            required
                ? 'حوّل المبلغ فعلياً خارج التطبيق أولاً، ثم أدخل رقم مرجع العملية. لن تُعتبر التسوية مكتملة بدونه.'
                : 'أدخل رقم مرجع التحويل إن توفر.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: required ? 'رقم مرجع التحويل (إلزامي)' : 'رقم مرجع التحويل',
              hintText: 'مثال: رقم العملية في Zain Cash أو Qi Card',
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (required && value.isEmpty) return;
              Navigator.of(dialogContext).pop(value);
            },
            child: const Text('تم التحويل'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<String?> _askRejectionReason() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('رفض طلب السحب'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'سبب الرفض'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.isEmpty) return;
              Navigator.of(dialogContext).pop(reason);
            },
            child: const Text('رفض الطلب'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _markLawyerPaid(Map<String, dynamic> row) async {
    final reference = await _askProviderReference();
    if (!mounted || reference == null) return;
    setState(() => processing = true);
    try {
      await SupabaseConfig.client.rpc('admin_complete_payout', params: {
        'p_payout_id': row['id'],
        'p_status': 'paid',
        'p_provider_reference': reference.isEmpty ? null : reference,
        'p_rejection_reason': null,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل التحويل وتحديث مستحقات المحامي')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تسجيل التحويل: ${_errorText(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => processing = false);
    }
  }

  Future<void> _rejectLawyerPayout(Map<String, dynamic> row) async {
    final reason = await _askRejectionReason();
    if (!mounted || reason == null) return;
    setState(() => processing = true);
    try {
      await SupabaseConfig.client.rpc('admin_complete_payout', params: {
        'p_payout_id': row['id'],
        'p_status': 'rejected',
        'p_provider_reference': null,
        'p_rejection_reason': reason,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفض الطلب وإعادة المبلغ إلى رصيد المحامي')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر رفض الطلب: ${_errorText(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => processing = false);
    }
  }

  Future<void> _prepareClientSettlement(Map<String, dynamic> row) async {
    setState(() => processing = true);
    try {
      await SupabaseConfig.client.rpc(
        'admin_prepare_client_credit_settlement',
        params: {'p_credit_id': row['credit_id']},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تجهيز بيانات التحويل من حساب الاستلام المرتبط.')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تجهيز التحويل: ${_errorText(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => processing = false);
    }
  }

  Future<void> _completeClientSettlement(Map<String, dynamic> row) async {
    final reference = await _askProviderReference(required: true);
    if (!mounted || reference == null || reference.isEmpty) return;
    setState(() => processing = true);
    try {
      await SupabaseConfig.client.rpc(
        'admin_complete_client_credit_settlement',
        params: {
          'p_settlement_id': row['settlement_id'],
          'p_provider_reference': reference,
          'p_admin_note': null,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل تحويل المبلغ إلى العميل وإشعاره.')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إكمال التسوية: ${_errorText(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => processing = false);
    }
  }

  Future<void> _showCompensationDialog() async {
    final searchController = TextEditingController();
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    List<Map<String, dynamic>> clients = [];
    String? selectedClientId;
    bool searching = false;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة تعويض للعميل'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'ابحث باسم العميل أو رقم الهاتف',
                    suffixIcon: IconButton(
                      onPressed: searching
                          ? null
                          : () async {
                              setDialogState(() => searching = true);
                              try {
                                final response = await SupabaseConfig.client.rpc(
                                  'admin_search_clients',
                                  params: {'p_query': searchController.text.trim()},
                                );
                                clients = List<Map<String, dynamic>>.from(response as List);
                              } finally {
                                setDialogState(() => searching = false);
                              }
                            },
                      icon: searching
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                if (clients.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedClientId,
                    decoration: const InputDecoration(labelText: 'اختر العميل'),
                    items: clients
                        .map((row) => DropdownMenuItem<String>(
                              value: row['id'].toString(),
                              child: Text('${row['full_name']} ${row['phone'] ?? ''}'),
                            ))
                        .toList(),
                    onChanged: (value) => setDialogState(() => selectedClientId = value),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'مبلغ التعويض', suffixText: 'د.ع'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'سبب التعويض'),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text.trim());
                if (selectedClientId == null || amount == null || amount <= 0) return;
                try {
                  await SupabaseConfig.client.rpc('admin_create_client_compensation', params: {
                    'p_user_id': selectedClientId,
                    'p_amount': amount,
                    'p_reason': reasonController.text.trim(),
                  });
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('تعذر إضافة التعويض: ${_errorText(e)}')),
                    );
                  }
                }
              },
              child: const Text('تسجيل التعويض'),
            ),
          ],
        ),
      ),
    );
    searchController.dispose();
    amountController.dispose();
    reasonController.dispose();
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل التعويض كمبلغ مستحق للعميل.')),
      );
      await _load();
    }
  }

  String money(dynamic value) =>
      '${(num.tryParse('${value ?? 0}') ?? 0).toStringAsFixed(0)} د.ع';

  String statusLabel(String status) => {
        'pending_review': 'بانتظار التحويل اليدوي',
        'approved': 'تمت الموافقة',
        'processing': 'قيد التنفيذ',
        'paid': 'تم التحويل',
        'rejected': 'مرفوض',
        'failed': 'فشل التحويل',
        'pending': 'مستحق',
        'بانتظار التحويل': 'بانتظار التحويل',
        'settled': 'تم التحويل',
      }[status] ?? status;

  String walletLabel(String? type) => {
        'zain_cash': 'زين كاش',
        'asia_hawala': 'آسيا حوالة',
        'qi_card': 'Qi Card',
        'bank_account': 'حساب مصرفي',
      }[type] ?? type ?? '—';

  String date(dynamic value) {
    final parsed = DateTime.tryParse('${value ?? ''}');
    if (parsed == null) return '—';
    final local = parsed.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  String _errorText(Object error) => error.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    final pendingLawyer = payouts.where((row) => row['status'] == 'pending_review').length;
    final pendingClients = clientCredits.where((row) => row['credit_status'] != 'settled').length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإدارة المالية'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: loading
            ? ListView(children: const [SizedBox(height: 300), Center(child: CircularProgressIndicator())])
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('إعدادات المنصة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: rateController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'نسبة العمولة للدفعات الجديدة (%)', suffixText: '%'),
                        ),
                        const SizedBox(height: 10),
                        FilledButton(onPressed: _saveRate, child: const Text('حفظ النسبة')),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.payments_outlined),
                      title: const Text('التسويات اليدوية'),
                      subtitle: Text(
                        'طلبات المحامين: $pendingLawyer • مستحقات العملاء: $pendingClients\n'
                        'التحويل يتم فعلياً خارج التطبيق ثم يُسجل مرجعه هنا.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(children: [
                    const Expanded(child: Text('استردادات وتعويضات العملاء', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                    FilledButton.icon(
                      onPressed: processing ? null : _showCompensationDialog,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('تعويض عميل'),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  if (clientCredits.isEmpty)
                    const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('لا توجد مستحقات للعملاء.'))),
                  ...clientCredits.map((row) {
                    final hasAccount = (row['account_number']?.toString().trim().isNotEmpty ?? false);
                    final settlementId = row['settlement_id']?.toString();
                    final settled = row['credit_status'] == 'settled' || row['settlement_status'] == 'paid';
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const Icon(Icons.person_outline_rounded),
                            const SizedBox(width: 10),
                            Expanded(child: Text('${row['client_name']}', style: const TextStyle(fontWeight: FontWeight.w800))),
                            Chip(label: Text(statusLabel('${row['credit_status']}'))),
                          ]),
                          const SizedBox(height: 8),
                          Text(money(row['amount']), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                          Text('السبب: ${row['transaction_type'] ?? '—'}'),
                          Text('التاريخ: ${date(row['created_at'])}'),
                          const Divider(height: 22),
                          if (hasAccount) ...[
                            Text('وسيلة الاستلام: ${walletLabel(row['provider_type']?.toString())}'),
                            Text('اسم صاحب الحساب: ${row['account_holder_name'] ?? '—'}'),
                            SelectableText('رقم الاستلام: ${row['account_number'] ?? '—'}'),
                            if (row['bank_name'] != null) Text('المصرف: ${row['bank_name']}'),
                          ] else
                            const Text('العميل لم يربط حساب استلام بعد.', style: TextStyle(fontWeight: FontWeight.w700)),
                          if (row['provider_reference'] != null) Text('مرجع التحويل: ${row['provider_reference']}'),
                          if (!settled) ...[
                            const SizedBox(height: 12),
                            if (settlementId == null)
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: processing || !hasAccount ? null : () => _prepareClientSettlement(row),
                                  icon: const Icon(Icons.account_balance_wallet_outlined),
                                  label: const Text('تجهيز التحويل إلى حساب العميل'),
                                ),
                              )
                            else
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: processing ? null : () => _completeClientSettlement(row),
                                  icon: const Icon(Icons.check_circle_outline_rounded),
                                  label: const Text('تم التحويل فعلياً'),
                                ),
                              ),
                          ],
                        ]),
                      ),
                    );
                  }),
                  const SizedBox(height: 26),
                  const Text('طلبات سحب المحامين', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (payouts.isEmpty)
                    const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('لا توجد طلبات سحب.'))),
                  ...payouts.map((row) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              const Icon(Icons.account_balance_wallet_outlined),
                              const SizedBox(width: 10),
                              Expanded(child: Text(money(row['amount']), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
                              Chip(label: Text(statusLabel('${row['status']}'))),
                            ]),
                            const SizedBox(height: 8),
                            Text('الوسيلة: ${walletLabel(row['wallet_type']?.toString())}'),
                            Text('رقم الاستلام: ${row['wallet_number'] ?? '—'}'),
                            Text('اسم صاحب الوسيلة: ${row['wallet_holder_name'] ?? '—'}'),
                            Text('تاريخ الطلب: ${date(row['created_at'])}'),
                            if (row['provider_reference'] != null) Text('مرجع التحويل: ${row['provider_reference']}'),
                            if (row['rejection_reason'] != null) Text('سبب الرفض: ${row['rejection_reason']}'),
                            if (row['status'] == 'pending_review') ...[
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: processing ? null : () => _rejectLawyerPayout(row),
                                    icon: const Icon(Icons.close),
                                    label: const Text('رفض وإعادة الرصيد'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: processing ? null : () => _markLawyerPaid(row),
                                    icon: const Icon(Icons.check_circle_outline),
                                    label: const Text('تم التحويل'),
                                  ),
                                ),
                              ]),
                            ],
                          ]),
                        ),
                      )),
                ],
              ),
      ),
    );
  }
}
