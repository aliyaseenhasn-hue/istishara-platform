import 'package:flutter/material.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/user_facing_error.dart';
import '../../../../shared/widgets/loading_widget.dart';

class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  Map<String, dynamic>? account;
  bool loading = true;
  bool saving = false;
  String provider = 'zain_cash';
  final holderController = TextEditingController();
  final numberController = TextEditingController();
  final bankController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    holderController.dispose();
    numberController.dispose();
    bankController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    try {
      final authUser = SupabaseConfig.client.auth.currentUser;
      if (authUser == null) throw Exception('يرجى تسجيل الدخول أولاً');
      final profile = await SupabaseConfig.client
          .from('profiles')
          .select('id')
          .eq('auth_id', authUser.id)
          .maybeSingle();
      final profileId = profile?['id']?.toString();
      if (profileId == null) throw Exception('تعذر تحديد حساب المستخدم');
      final row = await SupabaseConfig.client
          .from('client_payout_accounts')
          .select()
          .eq('user_id', profileId)
          .eq('is_default', true)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        account = row;
        provider = row?['provider_type']?.toString() ?? 'zain_cash';
        holderController.text = row?['account_holder_name']?.toString() ?? '';
        numberController.text = row?['account_number']?.toString() ?? '';
        bankController.text = row?['bank_name']?.toString() ?? '';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل حساب الاستلام: ${_errorText(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    if (saving) return;
    final holder = holderController.text.trim();
    final number = numberController.text.trim();
    if (holder.isEmpty || number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل اسم صاحب الحساب ورقم الحساب أو المحفظة.')),
      );
      return;
    }
    if (provider != 'bank_account' && number.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تحقق من رقم المحفظة أو البطاقة قبل الحفظ.')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      await SupabaseConfig.client.rpc(
        'upsert_client_payout_account',
        params: {
          'p_provider_type': provider,
          'p_account_holder_name': holder,
          'p_account_number': number,
          'p_bank_name': provider == 'bank_account' ? bankController.text.trim() : null,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ حساب استلام الأموال بنجاح.')),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر الحفظ: ${_errorText(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _providerLabel(String value) => {
        'zain_cash': 'زين كاش',
        'qi_card': 'Qi Card',
        'asia_hawala': 'آسيا حوالة',
        'bank_account': 'حساب مصرفي',
      }[value] ?? value;

  String _errorText(Object e) => UserFacingError.text(e);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final connected = account != null;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('حساب استلام الأموال', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: loading
          ? const LoadingWidget(size: 30)
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppSizes.p20, 10, AppSizes.p20, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [scheme.primaryContainer, scheme.secondaryContainer],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(color: scheme.surface.withValues(alpha: .8), shape: BoxShape.circle),
                      child: Icon(Icons.account_balance_wallet_rounded, color: scheme.primary, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('حسابك الحقيقي لاستلام الأموال', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: scheme.onPrimaryContainer)),
                        const SizedBox(height: 4),
                        Text(
                          connected ? 'مرتبط وجاهز لاستلام الاستردادات والتعويضات' : 'اربط وسيلة استلام قبل طلب أي استرداد أو تعويض',
                          style: TextStyle(fontSize: 12, color: scheme.onPrimaryContainer.withValues(alpha: .8), height: 1.5),
                        ),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.primary.withValues(alpha: .18)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.verified_user_outlined, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'هذا الحساب لا يمثل رصيداً داخل التطبيق. تستخدمه الإدارة لتحويل الاستردادات أو التعويضات إليك فعلياً. لا تُعد أي عملية مكتملة إلا بعد تسجيل مرجع التحويل الحقيقي.',
                        style: TextStyle(color: scheme.onSurfaceVariant, height: 1.55, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 18),
                Card(
                  elevation: 0,
                  color: scheme.surfaceContainerLowest,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: scheme.outlineVariant)),
                  child: Padding(
                    padding: const EdgeInsets.all(17),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const Text('بيانات الاستلام', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: provider,
                        decoration: const InputDecoration(labelText: 'وسيلة الاستلام', prefixIcon: Icon(Icons.account_balance_wallet_outlined)),
                        items: const [
                          DropdownMenuItem(value: 'zain_cash', child: Text('زين كاش')),
                          DropdownMenuItem(value: 'qi_card', child: Text('Qi Card')),
                          DropdownMenuItem(value: 'asia_hawala', child: Text('آسيا حوالة')),
                          DropdownMenuItem(value: 'bank_account', child: Text('حساب مصرفي')),
                        ],
                        onChanged: saving ? null : (value) => setState(() => provider = value ?? 'zain_cash'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: holderController,
                        enabled: !saving,
                        decoration: const InputDecoration(labelText: 'اسم صاحب الحساب', prefixIcon: Icon(Icons.person_outline_rounded)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: numberController,
                        enabled: !saving,
                        textDirection: TextDirection.ltr,
                        keyboardType: provider == 'bank_account' ? TextInputType.text : TextInputType.number,
                        decoration: InputDecoration(
                          labelText: provider == 'qi_card' ? 'رقم البطاقة/الحساب' : provider == 'bank_account' ? 'رقم الحساب / IBAN' : 'رقم المحفظة',
                          prefixIcon: const Icon(Icons.numbers_rounded),
                        ),
                      ),
                      if (provider == 'bank_account') ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: bankController,
                          enabled: !saving,
                          decoration: const InputDecoration(labelText: 'اسم المصرف', prefixIcon: Icon(Icons.account_balance_outlined)),
                        ),
                      ],
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: saving ? null : _save,
                        icon: saving
                            ? const SizedBox(width: 22, height: 22, child: LoadingWidget(size: 18, color: Colors.white))
                            : const Icon(Icons.save_outlined),
                        label: Text(saving ? 'جاري الحفظ...' : connected ? 'تحديث حساب الاستلام' : 'حفظ حساب الاستلام'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: AppColors.teal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ]),
                  ),
                ),
                if (connected) ...[
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    child: ListTile(
                      leading: const Icon(Icons.check_circle_rounded, color: AppColors.success),
                      title: Text(_providerLabel(account!['provider_type']?.toString() ?? '')),
                      subtitle: Text('${account!['account_holder_name']}\n${account!['account_number']}'),
                      isThreeLine: true,
                    ),
                  ),
                ],
              ]),
            ),
    );
  }
}
