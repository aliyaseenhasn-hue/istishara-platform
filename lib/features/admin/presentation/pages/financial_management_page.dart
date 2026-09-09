import 'package:flutter/material.dart';
import 'package:astshara/core/config/supabase_config.dart';
import '../../../../core/utils/user_facing_error.dart';

class FinancialManagementPage extends StatefulWidget {
  const FinancialManagementPage({super.key});

  @override
  State<FinancialManagementPage> createState() => _FinancialManagementPageState();
}

class _FinancialManagementPageState extends State<FinancialManagementPage> {
  Map<String, dynamic>? settings;
  List<Map<String, dynamic>> payouts = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> clientCredits = <Map<String, dynamic>>[];
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
      final settingsRow = await SupabaseConfig.client
          .from('platform_financial_settings')
          .select()
          .eq('id', true)
          .single();
      final payoutRows = await SupabaseConfig.client
          .from('lawyer_payout_requests')
          .select(
            'id,lawyer_id,amount,currency,status,wallet_type,wallet_number,'
            'wallet_holder_name,created_at,rejection_reason,provider_reference',
          )
          .order('created_at', ascending: false)
          .limit(50);
      final creditRows = await SupabaseConfig.client
          .rpc('admin_list_client_credit_operations');

      settings = Map<String, dynamic>.from(settingsRow);
      payouts = (payoutRows as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      clientCredits = (creditRows as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      rateController.text = '${settings?['commission_rate'] ?? 0}';
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
      _showMessage('أدخل نسبة بين 0 و100');
      return;
    }
    try {
      await SupabaseConfig.client
          .rpc('admin_set_commission_rate', params: {'p_rate': rate});
      _showMessage('تم حفظ نسبة العمولة للدفعات الجديدة');
      await _load();
    } catch (e) {
      _showMessage('تعذر الحفظ: ${_errorText(e)}');
    }
  }

  Future<String?> _askReference() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد التحويل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'حوّل المبلغ فعلياً خارج التطبيق أولاً، ثم أدخل رقم مرجع العملية. لن تعتبر العملية مكتملة بدون المرجع.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'رقم مرجع التحويل (إلزامي)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('رقم المرجع إلزامي')),
                );
                return;
              }
              Navigator.pop(dialogContext, value);
            },
            child: const Text('تم التحويل'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<String?> _askReason(String title) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'السبب (إلزامي)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('اكتب السبب أولاً')),
                );
                return;
              }
              Navigator.pop(dialogContext, value);
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _markLawyerPaid(Map<String, dynamic> row) async {
    final reference = await _askReference();
    if (!mounted || reference == null) return;
    await _runAction(() async {
      await SupabaseConfig.client.rpc('admin_complete_payout', params: {
        'p_payout_id': row['id'],
        'p_status': 'paid',
        'p_provider_reference': reference,
        'p_rejection_reason': null,
      });
    }, 'تم تسجيل التحويل وتحديث مستحقات المحامي');
  }

  Future<void> _rejectLawyerPayout(Map<String, dynamic> row) async {
    final reason = await _askReason('رفض طلب السحب');
    if (!mounted || reason == null) return;
    await _runAction(() async {
      await SupabaseConfig.client.rpc('admin_complete_payout', params: {
        'p_payout_id': row['id'],
        'p_status': 'rejected',
        'p_provider_reference': null,
        'p_rejection_reason': reason,
      });
    }, 'تم رفض الطلب وإعادة المبلغ إلى رصيد المحامي');
  }

  Future<void> _prepareClientSettlement(Map<String, dynamic> row) async {
    await _runAction(() async {
      await SupabaseConfig.client.rpc(
        'admin_prepare_client_credit_settlement',
        params: {'p_credit_id': row['credit_id']},
      );
    }, 'تم تجهيز بيانات التحويل إلى حساب العميل');
  }

  Future<void> _completeClientSettlement(Map<String, dynamic> row) async {
    final reference = await _askReference();
    if (!mounted || reference == null) return;
    await _runAction(() async {
      await SupabaseConfig.client.rpc(
        'admin_complete_client_credit_settlement',
        params: {
          'p_settlement_id': row['settlement_id'],
          'p_provider_reference': reference,
          'p_admin_note': null,
        },
      );
    }, 'تم تسجيل تحويل المبلغ إلى العميل وإشعاره');
  }

  Future<void> _showCompensationDialog() async {
    final searchController = TextEditingController();
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    List<Map<String, dynamic>> clients = <Map<String, dynamic>>[];
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                                    params: {
                                      'p_query': searchController.text.trim(),
                                    },
                                  );
                                  clients = (response as List)
                                      .map((e) => Map<String, dynamic>.from(e as Map))
                                      .toList();
                                } catch (e) {
                                  if (dialogContext.mounted) {
                                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'تعذر البحث: ${_errorText(e)}',
                                        ),
                                      ),
                                    );
                                  }
                                } finally {
                                  if (dialogContext.mounted) {
                                    setDialogState(() => searching = false);
                                  }
                                }
                              },
                        icon: searching
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  if (clients.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedClientId,
                      decoration: const InputDecoration(
                        labelText: 'اختر العميل',
                        border: OutlineInputBorder(),
                      ),
                      items: clients
                          .map(
                            (row) => DropdownMenuItem<String>(
                              value: row['id'].toString(),
                              child: Text(
                                '${row['full_name'] ?? 'عميل'} ${row['phone'] ?? ''}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => selectedClientId = value),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'مبلغ التعويض',
                      suffixText: 'د.ع',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'سبب التعويض',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text.trim());
                final reason = reasonController.text.trim();
                if (selectedClientId == null || amount == null || amount <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('اختر العميل وأدخل مبلغاً صحيحاً')),
                  );
                  return;
                }
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('سبب التعويض إلزامي')),
                  );
                  return;
                }
                try {
                  await SupabaseConfig.client.rpc(
                    'admin_create_client_compensation',
                    params: {
                      'p_user_id': selectedClientId,
                      'p_amount': amount,
                      'p_reason': reason,
                    },
                  );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text('تعذر إضافة التعويض: ${_errorText(e)}'),
                      ),
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
      _showMessage('تم تسجيل التعويض كمبلغ مستحق للعميل');
      await _load();
    }
  }

  Future<void> _runAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
    if (processing) return;
    if (mounted) setState(() => processing = true);
    try {
      await action();
      _showMessage(successMessage);
      await _load();
    } catch (e) {
      _showMessage(_errorText(e));
    } finally {
      if (mounted) setState(() => processing = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _money(dynamic value) =>
      '${(num.tryParse('${value ?? 0}') ?? 0).toStringAsFixed(0)} د.ع';

  String _statusLabel(String status) => <String, String>{
        'pending_review': 'بانتظار التحويل اليدوي',
        'approved': 'تمت الموافقة',
        'processing': 'قيد التنفيذ',
        'paid': 'تم التحويل',
        'rejected': 'مرفوض',
        'failed': 'فشل التحويل',
        'pending': 'مستحق',
        'بانتظار التحويل': 'بانتظار التحويل',
        'settled': 'تم التحويل',
      }[status] ??
      status;

  String _walletLabel(String? type) => <String, String>{
        'zain_cash': 'زين كاش',
        'asia_hawala': 'آسيا حوالة',
        'qi_card': 'Qi Card',
        'bank_account': 'حساب مصرفي',
      }[type] ??
      type ??
      '—';

  String _date(dynamic value) {
    final parsed = DateTime.tryParse('${value ?? ''}');
    if (parsed == null) return '—';
    final local = parsed.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  String _errorText(Object error) => UserFacingError.text(error);

  @override
  Widget build(BuildContext context) {
    final pendingLawyer =
        payouts.where((row) => row['status'] == 'pending_review').length;
    final pendingClients =
        clientCredits.where((row) => row['credit_status'] != 'settled').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإدارة المالية'),
        actions: [
          IconButton(
            onPressed: loading || processing ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 280),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'إعدادات المنصة',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: rateController,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'نسبة العمولة للدفعات الجديدة (%)',
                              suffixText: '%',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: processing ? null : _saveRate,
                            child: const Text('حفظ النسبة'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.payments_outlined),
                      title: const Text('التسويات اليدوية'),
                      subtitle: Text(
                        'طلبات المحامين: $pendingLawyer • مستحقات العملاء: $pendingClients\n'
                        'التحويل يتم خارج التطبيق ثم يسجل مرجعه هنا.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'استردادات وتعويضات العملاء',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: processing ? null : _showCompensationDialog,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('تعويض عميل'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (clientCredits.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text('لا توجد مستحقات للعملاء.'),
                      ),
                    ),
                  ...clientCredits.map(_clientCreditCard),
                  const SizedBox(height: 24),
                  const Text(
                    'طلبات سحب المحامين',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (payouts.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text('لا توجد طلبات سحب.'),
                      ),
                    ),
                  ...payouts.map(_lawyerPayoutCard),
                ],
              ),
      ),
    );
  }

  Widget _clientCreditCard(Map<String, dynamic> row) {
    final hasAccount =
        row['account_number']?.toString().trim().isNotEmpty ?? false;
    final settlementId = row['settlement_id']?.toString();
    final settled = row['credit_status'] == 'settled' ||
        row['settlement_status'] == 'paid';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${row['client_name'] ?? 'عميل'}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Chip(label: Text(_statusLabel('${row['credit_status']}'))),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _money(row['amount']),
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            Text('السبب: ${row['transaction_type'] ?? '—'}'),
            Text('التاريخ: ${_date(row['created_at'])}'),
            const Divider(height: 22),
            if (hasAccount) ...[
              Text(
                'وسيلة الاستلام: ${_walletLabel(row['provider_type']?.toString())}',
              ),
              Text('اسم صاحب الحساب: ${row['account_holder_name'] ?? '—'}'),
              SelectableText('رقم الاستلام: ${row['account_number'] ?? '—'}'),
              if (row['bank_name'] != null) Text('المصرف: ${row['bank_name']}'),
            ] else
              const Text(
                'العميل لم يربط حساب استلام بعد.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            if (row['provider_reference'] != null)
              Text('مرجع التحويل: ${row['provider_reference']}'),
            if (!settled) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: settlementId == null
                    ? FilledButton.icon(
                        onPressed: processing || !hasAccount
                            ? null
                            : () => _prepareClientSettlement(row),
                        icon: const Icon(Icons.account_balance_wallet_outlined),
                        label: const Text('تجهيز التحويل إلى حساب العميل'),
                      )
                    : FilledButton.icon(
                        onPressed: processing
                            ? null
                            : () => _completeClientSettlement(row),
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('تم التحويل فعلياً'),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _lawyerPayoutCard(Map<String, dynamic> row) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _money(row['amount']),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Chip(label: Text(_statusLabel('${row['status']}'))),
              ],
            ),
            const SizedBox(height: 8),
            Text('الوسيلة: ${_walletLabel(row['wallet_type']?.toString())}'),
            Text('رقم الاستلام: ${row['wallet_number'] ?? '—'}'),
            Text('اسم صاحب الوسيلة: ${row['wallet_holder_name'] ?? '—'}'),
            Text('تاريخ الطلب: ${_date(row['created_at'])}'),
            if (row['provider_reference'] != null)
              Text('مرجع التحويل: ${row['provider_reference']}'),
            if (row['rejection_reason'] != null)
              Text('سبب الرفض: ${row['rejection_reason']}'),
            if (row['status'] == 'pending_review') ...[
              const SizedBox(height: 12),
              Row(
                children: [
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
                      label: const Text('تم التحويل + المرجع'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
