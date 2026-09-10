import 'package:flutter/material.dart';
import 'package:astshara/core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/loading_widget.dart';

class LawyerWalletPage extends StatefulWidget {
  const LawyerWalletPage({super.key});

  @override
  State<LawyerWalletPage> createState() => _LawyerWalletPageState();
}

class _LawyerWalletPageState extends State<LawyerWalletPage> {
  static const Map<String, String> types = {
    'zain_cash': 'زين كاش',
    'asia_hawala': 'آسيا حوالة',
    'qi_card': 'Qi Card',
  };

  Map<String, dynamic>? wallet;
  String? walletType;
  String? walletNumber;
  String? walletHolder;
  List<Map<String, dynamic>> requests = [];
  bool loading = true;
  bool submitting = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) throw Exception('يجب تسجيل الدخول');

      final profile = await SupabaseConfig.client
          .from('profiles')
          .select('id,wallet_type,wallet_number,wallet_holder_name')
          .eq('auth_id', user.id)
          .maybeSingle();

      if (profile == null) throw Exception('ملف المحامي غير موجود');

      walletType = profile['wallet_type']?.toString();
      walletNumber = profile['wallet_number']?.toString();
      walletHolder = profile['wallet_holder_name']?.toString();

      wallet = await SupabaseConfig.client
          .from('lawyer_wallets')
          .select()
          .eq('lawyer_id', profile['id'])
          .maybeSingle();

      requests = List<Map<String, dynamic>>.from(
        await SupabaseConfig.client
            .from('lawyer_payout_requests')
            .select(
              'id,amount,currency,status,wallet_type,wallet_number,'
              'wallet_holder_name,created_at,rejection_reason,provider_reference',
            )
            .eq('lawyer_id', profile['id'])
            .order('created_at', ascending: false)
            .limit(20),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorText(error))),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _editMethod() async {
    var selectedType = walletType ?? 'zain_cash';
    final numberController = TextEditingController(text: walletNumber ?? '');
    final holderController = TextEditingController(text: walletHolder ?? '');

    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('طريقة استلام المستحقات'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'نوع وسيلة الاستلام',
                      ),
                      items: types.entries
                          .map(
                            (entry) => DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedType = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: numberController,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: selectedType == 'qi_card'
                            ? 'رقم البطاقة / الحساب'
                            : 'رقم الهاتف',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: holderController,
                      decoration: const InputDecoration(
                        labelText: 'اسم صاحب الوسيلة',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop([
                    selectedType,
                    numberController.text.trim(),
                    holderController.text.trim(),
                  ]),
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );

    numberController.dispose();
    holderController.dispose();

    if (result == null || !mounted) return;

    setState(() => saving = true);
    try {
      await SupabaseConfig.client.rpc(
        'update_own_lawyer_wallet_details',
        params: {
          'p_wallet_type': result[0],
          'p_wallet_number': result[1],
          'p_wallet_holder_name': result[2],
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ وسيلة الاستلام')),
        );
      }
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر الحفظ: ${_errorText(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _requestPayout() async {
    if (walletType == null || walletNumber == null || walletHolder == null) {
      await _editMethod();
      if (!mounted || walletType == null || walletNumber == null || walletHolder == null) {
        return;
      }
    }

    final available = num.tryParse('${wallet?['available_balance'] ?? 0}') ?? 0;
    if (available <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يوجد رصيد متاح للسحب')),
        );
      }
      return;
    }

    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('طلب سحب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('المتاح: ${money(available)}'),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'المبلغ بالدينار العراقي',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(
              double.tryParse(controller.text.trim()),
            ),
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (!mounted || amount == null || amount <= 0 || amount > available) return;

    setState(() => submitting = true);
    try {
      await SupabaseConfig.client.rpc(
        'request_lawyer_payout',
        params: {'p_amount': amount},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال طلب السحب إلى الإدارة')),
        );
      }
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تنفيذ الطلب: ${_errorText(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  String money(dynamic value) =>
      '${(num.tryParse('${value ?? 0}') ?? 0).toStringAsFixed(0)} د.ع';

  String status(String value) => {
        'pending_review': 'بانتظار مراجعة الإدارة',
        'approved': 'تمت الموافقة',
        'processing': 'قيد التنفيذ',
        'paid': 'تم التحويل',
        'rejected': 'مرفوض',
        'failed': 'فشل التحويل',
      }[value] ?? value;

  String date(dynamic value) {
    final parsed = DateTime.tryParse('${value ?? ''}');
    if (parsed == null) return '—';
    final local = parsed.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  String _errorText(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    final currentWallet = wallet ?? <String, dynamic>{};

    return Scaffold(
      appBar: AppBar(title: const Text('محفظتي المالية')),
      body: RefreshIndicator(
        color: AppColors.teal,
        onRefresh: _load,
        child: loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 280),
                  LoadingWidget(size: 30),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('الرصيد المتاح'),
                          Text(
                            money(currentWallet['available_balance']),
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _stat('معلق', money(currentWallet['pending_balance'])),
                              ),
                              Expanded(
                                child: _stat('إجمالي الأرباح', money(currentWallet['lifetime_earned'])),
                              ),
                              Expanded(
                                child: _stat('المسحوبات', money(currentWallet['lifetime_paid_out'])),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.teal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                              onPressed: submitting ? null : _requestPayout,
                              icon: submitting
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: LoadingWidget(
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.payments_outlined),
                              label: Text(
                                submitting ? 'جاري الإرسال...' : 'طلب سحب',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.account_balance_wallet_outlined),
                      title: Text(
                        walletType == null
                            ? 'وسيلة الاستلام غير مضافة'
                            : 'وسيلة الاستلام: ${types[walletType] ?? walletType}',
                      ),
                      subtitle: Text(
                        walletNumber == null
                            ? 'أضف وسيلة استلام المستحقات'
                            : '$walletNumber\n${walletHolder ?? ''}',
                      ),
                      trailing: saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: LoadingWidget(size: 18),
                            )
                          : IconButton(
                              onPressed: _editMethod,
                              color: AppColors.primary,
                              icon: const Icon(Icons.edit_outlined),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'طلبات السحب',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (requests.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('لا توجد طلبات سحب حتى الآن.'),
                      ),
                    ),
                  ...requests.map(
                    (request) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.receipt_long_outlined),
                        title: Text(money(request['amount'])),
                        subtitle: Text(
                          '${types[request['wallet_type']] ?? request['wallet_type']} • '
                          '${request['wallet_number'] ?? ''}\n'
                          '${status('${request['status']}')} • ${date(request['created_at'])}'
                          '${request['rejection_reason'] != null ? '\nسبب الرفض: ${request['rejection_reason']}' : ''}'
                          '${request['provider_reference'] != null ? '\nمرجع التحويل: ${request['provider_reference']}' : ''}',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _stat(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 11)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
