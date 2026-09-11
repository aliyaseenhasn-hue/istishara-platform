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
  List<Map<String, dynamic>> clientWithdrawals = <Map<String, dynamic>>[];
  bool loading = true;
  bool processing = false;

  final rateController = TextEditingController();
  final clientWithdrawalMinController = TextEditingController();
  final clientWithdrawalMinDaysController = TextEditingController();
  final clientWithdrawalMaxDaysController = TextEditingController();
  final lawyerHoldHoursController = TextEditingController();

  bool clientWithdrawalEnabled = true;
  String clientWithdrawalFeeMode = 'actual_transfer_fee';
  String lawyerPayoutFrequency = 'weekly';
  int lawyerPayoutWeekday = 4;

  static const weekdayLabels = <int, String>{
    0: 'الأحد',
    1: 'الاثنين',
    2: 'الثلاثاء',
    3: 'الأربعاء',
    4: 'الخميس',
    5: 'الجمعة',
    6: 'السبت',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    rateController.dispose();
    clientWithdrawalMinController.dispose();
    clientWithdrawalMinDaysController.dispose();
    clientWithdrawalMaxDaysController.dispose();
    lawyerHoldHoursController.dispose();
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
            'wallet_holder_name,created_at,rejection_reason,provider_reference,'
            'financial_policy_version,scheduled_payout_date',
          )
          .order('created_at', ascending: false)
          .limit(50);
      final creditRows =
          await SupabaseConfig.client.rpc('admin_list_client_credit_operations');
      final withdrawalRows = await SupabaseConfig.client
          .rpc('admin_list_client_wallet_withdrawals');

      settings = Map<String, dynamic>.from(settingsRow);
      payouts = (payoutRows as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      clientCredits = (creditRows as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      clientWithdrawals = (withdrawalRows as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      rateController.text = '${settings?['commission_rate'] ?? 0}';
      clientWithdrawalMinController.text =
          '${settings?['client_withdrawal_min_amount'] ?? 10000}';
      clientWithdrawalMinDaysController.text =
          '${settings?['client_withdrawal_processing_min_business_days'] ?? 1}';
      clientWithdrawalMaxDaysController.text =
          '${settings?['client_withdrawal_processing_max_business_days'] ?? 3}';
      lawyerHoldHoursController.text =
          '${settings?['lawyer_earnings_hold_hours'] ?? 24}';
      clientWithdrawalEnabled =
          settings?['client_withdrawal_enabled'] == true;
      clientWithdrawalFeeMode =
          '${settings?['client_withdrawal_fee_mode'] ?? 'actual_transfer_fee'}';
      lawyerPayoutFrequency =
          '${settings?['lawyer_payout_frequency'] ?? 'weekly'}';
      lawyerPayoutWeekday =
          int.tryParse('${settings?['lawyer_payout_weekday'] ?? 4}') ?? 4;
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

  Future<void> _savePolicy() async {
    final rate = double.tryParse(rateController.text.trim());
    final withdrawalMin =
        double.tryParse(clientWithdrawalMinController.text.trim());
    final minDays =
        int.tryParse(clientWithdrawalMinDaysController.text.trim());
    final maxDays =
        int.tryParse(clientWithdrawalMaxDaysController.text.trim());
    final holdHours = int.tryParse(lawyerHoldHoursController.text.trim());

    if (rate == null || rate < 0 || rate > 100) {
      _showMessage('أدخل نسبة عمولة بين 0 و100');
      return;
    }
    if (withdrawalMin == null || withdrawalMin < 0) {
      _showMessage('أدخل حداً أدنى صحيحاً لسحب العميل');
      return;
    }
    if (minDays == null || maxDays == null || minDays < 0 || maxDays < minDays || maxDays > 30) {
      _showMessage('مدة معالجة السحب يجب أن تكون صحيحة وبحد أقصى 30 يوم عمل');
      return;
    }
    if (holdHours == null || holdHours < 0 || holdHours > 720) {
      _showMessage('مدة حجز مستحق المحامي يجب أن تكون بين 0 و720 ساعة');
      return;
    }

    await _runAction(() async {
      final version = await SupabaseConfig.client.rpc(
        'admin_update_financial_policy',
        params: {
          'p_commission_rate': rate,
          'p_client_withdrawal_enabled': clientWithdrawalEnabled,
          'p_client_withdrawal_min_amount': withdrawalMin,
          'p_client_withdrawal_processing_min_business_days': minDays,
          'p_client_withdrawal_processing_max_business_days': maxDays,
          'p_client_withdrawal_fee_mode': clientWithdrawalFeeMode,
          'p_lawyer_earnings_hold_hours': holdHours,
          'p_lawyer_payout_frequency': lawyerPayoutFrequency,
          'p_lawyer_payout_weekday': lawyerPayoutWeekday,
        },
      );
      _showMessage('تم إنشاء إصدار مالي جديد رقم $version. يطبق على الطلبات الجديدة فقط.');
    }, null);
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

  Future<Map<String, dynamic>?> _askClientWithdrawalTransfer(
    Map<String, dynamic> row,
  ) async {
    final referenceController = TextEditingController();
    final feeController = TextEditingController(text: '0');
    final actualFee = row['fee_mode'] == 'actual_transfer_fee';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل تحويل سحب العميل'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('المبلغ المحجوز: ${_money(row['amount'])}'),
              const SizedBox(height: 6),
              Text(
                actualFee
                    ? 'لا توجد عمولة للمنصة. أدخل فقط رسوم التحويل الفعلية إن وجدت.'
                    : 'سياسة هذا الطلب لا تخصم أي رسوم من العميل.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: referenceController,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'مرجع التحويل (إلزامي)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (actualFee) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: feeController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'رسوم التحويل الفعلية',
                    suffixText: 'د.ع',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final reference = referenceController.text.trim();
              final fee = actualFee
                  ? double.tryParse(feeController.text.trim())
                  : 0.0;
              if (reference.isEmpty || fee == null || fee < 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('أدخل مرجع التحويل ورسوماً صحيحة')),
                );
                return;
              }
              Navigator.pop(dialogContext, {
                'reference': reference,
                'fee': fee,
              });
            },
            child: const Text('تأكيد التحويل'),
          ),
        ],
      ),
    );
    referenceController.dispose();
    feeController.dispose();
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

  Future<void> _startClientWithdrawal(Map<String, dynamic> row) async {
    await _runAction(() async {
      await SupabaseConfig.client.rpc(
        'admin_process_client_wallet_withdrawal',
        params: {
          'p_request_id': row['request_id'],
          'p_action': 'processing',
          'p_provider_reference': null,
          'p_transfer_fee': 0,
          'p_note': null,
        },
      );
    }, 'تم بدء معالجة طلب السحب');
  }

  Future<void> _payClientWithdrawal(Map<String, dynamic> row) async {
    final data = await _askClientWithdrawalTransfer(row);
    if (!mounted || data == null) return;
    await _runAction(() async {
      await SupabaseConfig.client.rpc(
        'admin_process_client_wallet_withdrawal',
        params: {
          'p_request_id': row['request_id'],
          'p_action': 'paid',
          'p_provider_reference': data['reference'],
          'p_transfer_fee': data['fee'],
          'p_note': null,
        },
      );
    }, 'تم تسجيل تحويل رصيد العميل');
  }

  Future<void> _rejectClientWithdrawal(Map<String, dynamic> row) async {
    final reason = await _askReason('رفض طلب سحب رصيد العميل');
    if (!mounted || reason == null) return;
    await _runAction(() async {
      await SupabaseConfig.client.rpc(
        'admin_process_client_wallet_withdrawal',
        params: {
          'p_request_id': row['request_id'],
          'p_action': 'rejected',
          'p_provider_reference': null,
          'p_transfer_fee': 0,
          'p_note': reason,
        },
      );
    }, 'تم رفض طلب السحب وإعادة المبلغ إلى رصيد العميل');
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
    String? successMessage,
  ) async {
    if (processing) return;
    if (mounted) setState(() => processing = true);
    try {
      await action();
      if (successMessage != null) _showMessage(successMessage);
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
        'pending_review': 'بانتظار المراجعة',
        'approved': 'تمت الموافقة',
        'processing': 'قيد التنفيذ',
        'paid': 'تم التحويل',
        'rejected': 'مرفوض',
        'cancelled': 'ملغي',
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
    final pendingLawyer = payouts
        .where((row) => row['status'] == 'pending_review')
        .length;
    final pendingClients =
        clientCredits.where((row) => row['credit_status'] != 'settled').length;
    final pendingWalletWithdrawals = clientWithdrawals
        .where((row) =>
            row['status'] == 'pending_review' || row['status'] == 'processing')
        .length;
    final version = settings?['financial_policy_version'] ?? '—';

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
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'السياسة المالية',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Chip(label: Text('الإصدار $version')),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'أي حفظ ينشئ إصداراً جديداً. التغيير يطبق على الحجوزات وطلبات السحب الجديدة فقط ولا يغير عمولة أو مدة حجز أي عملية سابقة.',
                            style: TextStyle(height: 1.45),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: rateController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'عمولة المنصة (%)',
                              suffixText: '%',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Divider(),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('السماح للعميل بسحب الرصيد غير المستخدم'),
                            subtitle: const Text('يسحب من الرصيد المتاح فقط، وليس المبلغ المحجوز.'),
                            value: clientWithdrawalEnabled,
                            onChanged: processing
                                ? null
                                : (value) =>
                                    setState(() => clientWithdrawalEnabled = value),
                          ),
                          TextField(
                            controller: clientWithdrawalMinController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'الحد الأدنى لسحب العميل',
                              suffixText: 'د.ع',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: clientWithdrawalMinDaysController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'أقل مدة معالجة',
                                    suffixText: 'يوم عمل',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: clientWithdrawalMaxDaysController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'أقصى مدة معالجة',
                                    suffixText: 'يوم عمل',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: clientWithdrawalFeeMode,
                            decoration: const InputDecoration(
                              labelText: 'رسوم سحب العميل',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'actual_transfer_fee',
                                child: Text('رسوم التحويل الفعلية فقط'),
                              ),
                              DropdownMenuItem(
                                value: 'none',
                                child: Text('بدون أي رسوم على العميل'),
                              ),
                            ],
                            onChanged: processing
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setState(() => clientWithdrawalFeeMode = value);
                                    }
                                  },
                          ),
                          const SizedBox(height: 14),
                          const Divider(),
                          TextField(
                            controller: lawyerHoldHoursController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'مدة حجز مستحق المحامي بعد اكتمال الاستشارة',
                              suffixText: 'ساعة',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: lawyerPayoutFrequency,
                            decoration: const InputDecoration(
                              labelText: 'دورية تحويل مستحقات المحامين',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'weekly',
                                child: Text('أسبوعياً'),
                              ),
                              DropdownMenuItem(
                                value: 'daily',
                                child: Text('يومياً'),
                              ),
                              DropdownMenuItem(
                                value: 'manual',
                                child: Text('يدوياً حسب طلب الإدارة'),
                              ),
                            ],
                            onChanged: processing
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setState(() => lawyerPayoutFrequency = value);
                                    }
                                  },
                          ),
                          if (lawyerPayoutFrequency == 'weekly') ...[
                            const SizedBox(height: 10),
                            DropdownButtonFormField<int>(
                              initialValue: lawyerPayoutWeekday,
                              decoration: const InputDecoration(
                                labelText: 'يوم التسوية الأسبوعية',
                                border: OutlineInputBorder(),
                              ),
                              items: weekdayLabels.entries
                                  .map(
                                    (entry) => DropdownMenuItem<int>(
                                      value: entry.key,
                                      child: Text(entry.value),
                                    ),
                                  )
                                  .toList(),
                              onChanged: processing
                                  ? null
                                  : (value) {
                                      if (value != null) {
                                        setState(() => lawyerPayoutWeekday = value);
                                      }
                                    },
                            ),
                          ],
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: processing ? null : _savePolicy,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('حفظ وإصدار سياسة مالية جديدة'),
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
                        'سحب أرصدة العملاء: $pendingWalletWithdrawals • طلبات المحامين: $pendingLawyer • مستحقات وتعويضات العملاء: $pendingClients\n'
                        'المال الحقيقي يحول خارج التطبيق ثم يسجل مرجع التحويل هنا.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'طلبات سحب أرصدة العملاء',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (clientWithdrawals.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text('لا توجد طلبات سحب أرصدة من العملاء.'),
                      ),
                    ),
                  ...clientWithdrawals.map(_clientWithdrawalCard),
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

  Widget _clientWithdrawalCard(Map<String, dynamic> row) {
    final status = '${row['status'] ?? ''}';
    final active = status == 'pending_review' || status == 'processing';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.outbox_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${row['client_name'] ?? 'عميل'}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Chip(label: Text(_statusLabel(status))),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _money(row['amount']),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            Text('وسيلة الاستلام: ${_walletLabel(row['provider_type']?.toString())}'),
            Text('اسم صاحب الحساب: ${row['account_holder_name'] ?? '—'}'),
            SelectableText('رقم الاستلام: ${row['account_number'] ?? '—'}'),
            if (row['bank_name'] != null) Text('المصرف: ${row['bank_name']}'),
            Text('إصدار السياسة: ${row['financial_policy_version'] ?? '—'}'),
            Text(
              row['fee_mode'] == 'actual_transfer_fee'
                  ? 'الرسوم: رسوم التحويل الفعلية فقط'
                  : 'الرسوم: لا تخصم رسوم من العميل',
            ),
            Text('تاريخ الطلب: ${_date(row['requested_at'])}'),
            if (active)
              Text('الموعد الأقصى للمعالجة: ${_date(row['processing_deadline_at'])}'),
            if (row['transfer_fee'] != null && status == 'paid')
              Text('رسوم التحويل الفعلية: ${_money(row['transfer_fee'])}'),
            if (row['net_amount'] != null && status == 'paid')
              Text('صافي المحول: ${_money(row['net_amount'])}'),
            if (row['provider_reference'] != null)
              Text('مرجع التحويل: ${row['provider_reference']}'),
            if (row['rejection_reason'] != null)
              Text('سبب الرفض: ${row['rejection_reason']}'),
            if (active) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (status == 'pending_review')
                    OutlinedButton.icon(
                      onPressed: processing
                          ? null
                          : () => _startClientWithdrawal(row),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('بدء المعالجة'),
                    ),
                  OutlinedButton.icon(
                    onPressed:
                        processing ? null : () => _rejectClientWithdrawal(row),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('رفض وإعادة الرصيد'),
                  ),
                  FilledButton.icon(
                    onPressed:
                        processing ? null : () => _payClientWithdrawal(row),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('تم التحويل'),
                  ),
                ],
              ),
            ],
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
            if (row['scheduled_payout_date'] != null)
              Text('موعد التسوية المجدول: ${_date(row['scheduled_payout_date'])}'),
            if (row['financial_policy_version'] != null)
              Text('إصدار السياسة: ${row['financial_policy_version']}'),
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
                      onPressed: processing
                          ? null
                          : () => _rejectLawyerPayout(row),
                      icon: const Icon(Icons.close),
                      label: const Text('رفض وإعادة الرصيد'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed:
                          processing ? null : () => _markLawyerPaid(row),
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
