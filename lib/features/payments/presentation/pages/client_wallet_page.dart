import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/user_facing_error.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../data/repositories/payments_repository_impl.dart';
import '../providers/client_wallet_provider.dart';

class ClientWalletPage extends ConsumerStatefulWidget {
  final double? requiredAmount;

  const ClientWalletPage({super.key, this.requiredAmount});

  @override
  ConsumerState<ClientWalletPage> createState() => _ClientWalletPageState();
}

class _ClientWalletPageState extends ConsumerState<ClientWalletPage> {
  final _amountController = TextEditingController();
  final _transactionController = TextEditingController();
  final _amountFocusNode = FocusNode();
  final _transactionFocusNode = FocusNode();
  late Future<Map<String, dynamic>> _settingsFuture;
  XFile? _receipt;
  bool _submitting = false;
  bool _withdrawing = false;

  bool get _useSafeWalletKeypads =>
      kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    if (widget.requiredAmount != null && widget.requiredAmount! > 0) {
      _amountController.text = widget.requiredAmount!.toStringAsFixed(0);
    }
    _settingsFuture = _loadSettings();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _transactionController.dispose();
    _amountFocusNode.dispose();
    _transactionFocusNode.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadSettings() async {
    final raw = await SupabaseConfig.client.rpc('get_manual_payment_settings');
    if (raw is List && raw.isNotEmpty) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{'enabled': false};
  }

  Future<String?> _openSafeNumericKeypad({
    required String initialValue,
    required String title,
    required String helperText,
    required String confirmText,
    required bool formatAsAmount,
    required int minimumValue,
    int maxDigits = 30,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    return showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .45),
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        final availableHeight = MediaQuery.sizeOf(sheetContext).height;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: availableHeight * .72),
          child: Material(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            clipBehavior: Clip.antiAlias,
            child: _NumericKeypadSheet(
              initialValue: initialValue,
              title: title,
              helperText: helperText,
              confirmText: confirmText,
              formatAsAmount: formatAsAmount,
              minimumValue: minimumValue,
              maxDigits: maxDigits,
            ),
          ),
        );
      },
    );
  }

  Future<void> _editAmountWithSafeKeypad() async {
    final value = await _openSafeNumericKeypad(
      initialValue: _amountController.text,
      title: 'أدخل مبلغ الشحن',
      helperText: 'أدخل المبلغ الذي قمت بتحويله فعلياً',
      confirmText: 'اعتماد المبلغ',
      formatAsAmount: true,
      minimumValue: 1000,
      maxDigits: 10,
    );
    if (value == null || !mounted) return;
    setState(() => _amountController.text = value);
  }

  Future<void> _editTransactionWithSafeKeypad() async {
    final value = await _openSafeNumericKeypad(
      initialValue: _transactionController.text,
      title: 'رقم عملية التحويل',
      helperText: 'أدخل الرقم الظاهر في إيصال التحويل',
      confirmText: 'اعتماد رقم العملية',
      formatAsAmount: false,
      minimumValue: 0,
      maxDigits: 30,
    );
    if (value == null || !mounted) return;
    setState(() => _transactionController.text = value);
  }

  Future<void> _pickReceipt() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (image != null && mounted) setState(() => _receipt = image);
  }

  Future<void> _requestWithdrawal() async {
    if (_withdrawing) return;
    try {
      final policy = await ref.read(financialPolicyProvider.future);
      final wallet = await ref.read(clientWalletProvider.future);
      if (!mounted) return;

      if (policy['client_withdrawal_enabled'] != true) {
        _message('سحب الرصيد غير متاح حالياً.');
        return;
      }

      final minimum =
          (num.tryParse('${policy['client_withdrawal_min_amount'] ?? 10000}') ??
                  10000)
              .round();
      if (wallet.availableBalance < minimum) {
        _message('الحد الأدنى للسحب هو ${_money(minimum.toDouble())} د.ع.');
        return;
      }

      final value = await _openSafeNumericKeypad(
        initialValue: '',
        title: 'سحب الرصيد غير المستخدم',
        helperText:
            'المتاح ${_money(wallet.availableBalance)} د.ع • الحد الأدنى ${_money(minimum.toDouble())} د.ع',
        confirmText: 'إرسال طلب السحب',
        formatAsAmount: true,
        minimumValue: minimum,
        maxDigits: 10,
      );
      if (value == null || !mounted) return;
      final amount = double.tryParse(value);
      if (amount == null || amount < minimum) {
        _message('مبلغ السحب أقل من الحد الأدنى.');
        return;
      }
      if (amount > wallet.availableBalance) {
        _message('المبلغ أكبر من الرصيد المتاح.');
        return;
      }

      setState(() => _withdrawing = true);
      await SupabaseConfig.client.rpc(
        'request_client_wallet_withdrawal',
        params: {'p_amount': amount},
      );
      ref.invalidate(clientWalletProvider);
      ref.invalidate(clientWalletWithdrawalsProvider);
      ref.invalidate(clientWalletLedgerProvider);
      if (mounted) {
        _message('تم إرسال طلب السحب وحجز المبلغ إلى حين تنفيذ التحويل.');
      }
    } catch (error) {
      if (!mounted) return;
      final text = UserFacingError.text(error);
      final needsAccount = text.contains('حساب استلام') ||
          text.contains('طرق الدفع') ||
          text.contains('وسيلة استلام');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text, textAlign: TextAlign.right),
          action: needsAccount
              ? SnackBarAction(
                  label: 'إضافة حساب',
                  onPressed: () => context.push('/payment-methods'),
                )
              : null,
        ),
      );
    } finally {
      if (mounted) setState(() => _withdrawing = false);
    }
  }

  Future<void> _cancelWithdrawal(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء طلب السحب'),
        content: const Text(
          'سيعود المبلغ المحجوز فوراً إلى رصيدك المتاح. لا يمكن الإلغاء بعد أن تبدأ الإدارة تنفيذ التحويل.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('إلغاء الطلب'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await SupabaseConfig.client.rpc(
        'cancel_client_wallet_withdrawal',
        params: {'p_request_id': id},
      );
      ref.invalidate(clientWalletProvider);
      ref.invalidate(clientWalletWithdrawalsProvider);
      ref.invalidate(clientWalletLedgerProvider);
      if (mounted) _message('تم إلغاء طلب السحب وإعادة المبلغ إلى الرصيد المتاح.');
    } catch (error) {
      if (mounted) _message(UserFacingError.text(error));
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', ''),
    );
    final transaction = _transactionController.text.trim();
    if (amount == null || amount < 1000) {
      _message('أدخل مبلغ شحن صحيحاً.');
      return;
    }
    if (transaction.isEmpty) {
      _message('أدخل رقم عملية التحويل الظاهر في الإيصال.');
      return;
    }
    if (_receipt == null) {
      _message('ارفع صورة إيصال التحويل أولاً.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final repository = PaymentsRepositoryImpl(SupabaseConfig.client);
      final receiptUrl = await repository.uploadReceipt(
        await _receipt!.readAsBytes(),
        'wallet_topup_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await SupabaseConfig.client.rpc(
        'submit_client_wallet_topup',
        params: {
          'p_amount': amount,
          'p_transaction_number': transaction,
          'p_receipt_url': receiptUrl,
        },
      );
      ref.invalidate(clientWalletTopupsProvider);
      if (!mounted) return;
      setState(() {
        _receipt = null;
        _transactionController.clear();
      });
      _message('تم إرسال الإيصال. ستراجعه الإدارة خلال 30 دقيقة في ساعات العمل.');
      context.go('/home');
    } catch (error) {
      if (mounted) _message(UserFacingError.text(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text, textAlign: TextAlign.right)),
    );
  }

  String _money(double value) => NumberFormat('#,##0', 'ar').format(value);

  void _invalidateWalletData() {
    ref.invalidate(clientWalletProvider);
    ref.invalidate(financialPolicyProvider);
    ref.invalidate(clientWalletWithdrawalsProvider);
    ref.invalidate(clientWalletTopupsProvider);
    ref.invalidate(clientWalletLedgerProvider);
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(clientWalletProvider);
    final policy = ref.watch(financialPolicyProvider);
    final withdrawals = ref.watch(clientWalletWithdrawalsProvider);
    final topups = ref.watch(clientWalletTopupsProvider);
    final ledger = ref.watch(clientWalletLedgerProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('محفظتي'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'طلبات المواعيد',
            onPressed: () => context.push('/appointment-requests'),
            color: AppColors.primary,
            icon: const Icon(Icons.event_note_outlined),
          ),
          IconButton(
            tooltip: 'تحديث',
            onPressed: _invalidateWalletData,
            color: AppColors.teal,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.teal,
        onRefresh: () async {
          _invalidateWalletData();
          await ref.read(clientWalletProvider.future);
        },
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
          children: [
            wallet.when(
              loading: () => const SizedBox(
                height: 150,
                child: LoadingWidget(size: 30),
              ),
              error: (error, _) => _ErrorCard(text: UserFacingError.text(error)),
              data: (value) => _BalanceCard(
                available: _money(value.availableBalance),
                held: _money(value.heldBalance),
              ),
            ),
            if (widget.requiredAmount != null) ...[
              const SizedBox(height: 12),
              _NoticeCard(
                text:
                    'المبلغ المطلوب للحجز: ${_money(widget.requiredAmount!)} د.ع. بعد اعتماد الشحن ارجع إلى المحامي واختر موعداً متاحاً أو اقترح الأوقات التي تناسبك.',
              ),
            ],
            const SizedBox(height: 16),
            policy.when(
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: LoadingWidget(size: 24),
                ),
              ),
              error: (error, _) => _ErrorCard(text: UserFacingError.text(error)),
              data: (value) => _WithdrawalPolicyCard(
                policy: value,
                withdrawing: _withdrawing,
                onWithdraw: _requestWithdrawal,
                onPaymentMethods: () => context.push('/payment-methods'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'طلبات سحب الرصيد',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            withdrawals.when(
              loading: () => const LoadingWidget(size: 26),
              error: (error, _) => _ErrorCard(text: UserFacingError.text(error)),
              data: (items) => items.isEmpty
                  ? const _EmptyCard(text: 'لا توجد طلبات سحب حتى الآن.')
                  : Column(
                      children: items
                          .map(
                            (item) => _WithdrawalHistoryCard(
                              item: item,
                              onCancel: item['status'] == 'pending_review'
                                  ? () => _cancelWithdrawal('${item['id']}')
                                  : null,
                            ),
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(height: 18),
            FutureBuilder<Map<String, dynamic>>(
              future: _settingsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: LoadingWidget(size: 26),
                    ),
                  );
                }
                final settings = snapshot.data ?? const <String, dynamic>{};
                return _TopupCard(
                  settings: settings,
                  amountController: _amountController,
                  transactionController: _transactionController,
                  amountFocusNode: _amountFocusNode,
                  transactionFocusNode: _transactionFocusNode,
                  useSafeWalletKeypads: _useSafeWalletKeypads,
                  receipt: _receipt,
                  submitting: _submitting,
                  onCopy: (value) async {
                    await Clipboard.setData(ClipboardData(text: value));
                    _message('تم نسخ رقم الحساب/المحفظة.');
                  },
                  onEditAmount: _editAmountWithSafeKeypad,
                  onEditTransaction: _editTransactionWithSafeKeypad,
                  onPickReceipt: _pickReceipt,
                  onSubmit: settings['enabled'] == true ? _submit : null,
                );
              },
            ),
            const SizedBox(height: 22),
            const Text(
              'طلبات الشحن',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            topups.when(
              loading: () => const LoadingWidget(size: 26),
              error: (error, _) => _ErrorCard(text: UserFacingError.text(error)),
              data: (items) => items.isEmpty
                  ? const _EmptyCard(text: 'لا توجد طلبات شحن حتى الآن.')
                  : Column(
                      children: items
                          .map((item) => _TopupHistoryCard(item: item))
                          .toList(),
                    ),
            ),
            const SizedBox(height: 22),
            const Text(
              'حركة المحفظة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            ledger.when(
              loading: () => const LoadingWidget(size: 26),
              error: (error, _) => _ErrorCard(text: UserFacingError.text(error)),
              data: (items) => items.isEmpty
                  ? const _EmptyCard(text: 'لا توجد حركات مالية حتى الآن.')
                  : Column(
                      children:
                          items.map((item) => _LedgerCard(item: item)).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final String available;
  final String held;
  const _BalanceCard({required this.available, required this.held});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [scheme.primary, scheme.secondary]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'الرصيد المتاح',
            textAlign: TextAlign.right,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            '$available د.ع',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'الرصيد المحجوز: $held د.ع',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'قد يكون محجوزاً لموعد أو لطلب سحب قيد المعالجة.',
            textAlign: TextAlign.right,
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _WithdrawalPolicyCard extends StatelessWidget {
  final Map<String, dynamic> policy;
  final bool withdrawing;
  final VoidCallback onWithdraw;
  final VoidCallback onPaymentMethods;

  const _WithdrawalPolicyCard({
    required this.policy,
    required this.withdrawing,
    required this.onWithdraw,
    required this.onPaymentMethods,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = policy['client_withdrawal_enabled'] == true;
    final minimum =
        num.tryParse('${policy['client_withdrawal_min_amount'] ?? 10000}') ??
            10000;
    final minDays =
        num.tryParse('${policy['client_withdrawal_processing_min_business_days'] ?? 1}') ??
            1;
    final maxDays =
        num.tryParse('${policy['client_withdrawal_processing_max_business_days'] ?? 3}') ??
            3;
    final actualFee = policy['client_withdrawal_fee_mode'] == 'actual_transfer_fee';
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'سحب الرصيد غير المستخدم',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              enabled
                  ? 'يمكن سحب الرصيد المتاح فقط. الحد الأدنى ${NumberFormat('#,##0', 'ar').format(minimum)} د.ع، والمدة المتوقعة $minDays–$maxDays أيام عمل.'
                  : 'سحب الرصيد متوقف مؤقتاً بقرار الإدارة.',
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45),
            ),
            if (enabled) ...[
              const SizedBox(height: 5),
              Text(
                actualFee
                    ? 'لا توجد عمولة للمنصة على السحب؛ تخصم فقط رسوم التحويل الفعلية إن وجدت.'
                    : 'لا تخصم رسوم من مبلغ السحب.',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onPaymentMethods,
                      icon: const Icon(Icons.account_balance_outlined),
                      label: const Text('حساب الاستلام'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: withdrawing ? null : onWithdraw,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        foregroundColor: Colors.white,
                      ),
                      icon: withdrawing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: LoadingWidget(size: 16, color: Colors.white),
                            )
                          : const Icon(Icons.payments_outlined),
                      label: Text(withdrawing ? 'جاري الإرسال...' : 'طلب سحب'),
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

class _WithdrawalHistoryCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onCancel;

  const _WithdrawalHistoryCard({required this.item, this.onCancel});

  String _status(String value) => const <String, String>{
        'pending_review': 'بانتظار مراجعة الإدارة',
        'processing': 'قيد التحويل',
        'paid': 'تم التحويل',
        'rejected': 'مرفوض',
        'cancelled': 'ملغي',
      }[value] ??
      value;

  String _provider(String value) => const <String, String>{
        'zain_cash': 'زين كاش',
        'asia_hawala': 'آسيا حوالة',
        'qi_card': 'Qi Card',
        'bank_account': 'حساب مصرفي',
      }[value] ??
      value;

  @override
  Widget build(BuildContext context) {
    final amount = num.tryParse('${item['amount'] ?? 0}') ?? 0;
    final fee = num.tryParse('${item['transfer_fee'] ?? 0}') ?? 0;
    final net = num.tryParse('${item['net_amount'] ?? amount}') ?? amount;
    final requested = DateTime.tryParse('${item['requested_at'] ?? ''}')?.toLocal();
    final deadline =
        DateTime.tryParse('${item['processing_deadline_at'] ?? ''}')?.toLocal();
    final status = '${item['status'] ?? ''}';
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  status == 'paid'
                      ? Icons.check_circle_outline_rounded
                      : Icons.outbox_outlined,
                  color: status == 'paid' ? AppColors.success : AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${NumberFormat('#,##0', 'ar').format(amount)} د.ع',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                Chip(label: Text(_status(status))),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'إلى: ${_provider('${item['provider_type'] ?? ''}')} • ${item['account_number'] ?? '—'}',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            if (requested != null)
              Text('تاريخ الطلب: ${DateFormat('yyyy/MM/dd – hh:mm a', 'ar').format(requested)}'),
            if (deadline != null && status != 'paid' && status != 'rejected' && status != 'cancelled')
              Text('موعد المعالجة الأقصى: ${DateFormat('yyyy/MM/dd', 'ar').format(deadline)}'),
            if (status == 'paid') ...[
              if (fee > 0) Text('رسوم التحويل الفعلية: ${NumberFormat('#,##0', 'ar').format(fee)} د.ع'),
              Text('صافي المحول: ${NumberFormat('#,##0', 'ar').format(net)} د.ع'),
              if (item['provider_reference'] != null)
                Text('مرجع التحويل: ${item['provider_reference']}'),
            ],
            if (item['rejection_reason'] != null)
              Text('سبب الرفض: ${item['rejection_reason']}'),
            if (onCancel != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.close_rounded),
                label: const Text('إلغاء طلب السحب وإعادة الرصيد'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopupCard extends StatelessWidget {
  final Map<String, dynamic> settings;
  final TextEditingController amountController;
  final TextEditingController transactionController;
  final FocusNode amountFocusNode;
  final FocusNode transactionFocusNode;
  final bool useSafeWalletKeypads;
  final XFile? receipt;
  final bool submitting;
  final ValueChanged<String> onCopy;
  final VoidCallback onEditAmount;
  final VoidCallback onEditTransaction;
  final VoidCallback onPickReceipt;
  final VoidCallback? onSubmit;

  const _TopupCard({
    required this.settings,
    required this.amountController,
    required this.transactionController,
    required this.amountFocusNode,
    required this.transactionFocusNode,
    required this.useSafeWalletKeypads,
    required this.receipt,
    required this.submitting,
    required this.onCopy,
    required this.onEditAmount,
    required this.onEditTransaction,
    required this.onPickReceipt,
    required this.onSubmit,
  });

  Widget _safeInputField(
    BuildContext context, {
    required bool enabled,
    required String label,
    required String value,
    required String emptyText,
    required IconData leadingIcon,
    required VoidCallback onTap,
    String? formattedValue,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final rawValue = value.trim();
    final active = enabled && !submitting;

    return Semantics(
      button: true,
      enabled: active,
      label: label,
      value: rawValue,
      child: Material(
        color: active
            ? scheme.surfaceContainerLowest
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: active ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 74),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active ? scheme.outline : scheme.outlineVariant,
                width: 1.1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  leadingIcon,
                  color: active ? AppColors.primary : scheme.outline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        label,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rawValue.isEmpty
                            ? emptyText
                            : (formattedValue ?? rawValue),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: rawValue.isEmpty ? 15 : 19,
                          fontWeight: rawValue.isEmpty
                              ? FontWeight.w600
                              : FontWeight.w900,
                          color: rawValue.isEmpty
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.dialpad_rounded,
                  color: active ? AppColors.teal : scheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = settings['enabled'] == true;
    final accountNumber = settings['account_number']?.toString().trim() ?? '';
    final accountName = settings['account_name']?.toString().trim() ?? '';
    final provider =
        settings['provider_name']?.toString().trim() ?? 'تحويل يدوي';
    final amountRaw = amountController.text.trim();
    final amountParsed = int.tryParse(amountRaw.replaceAll(',', ''));
    final formattedAmount = amountParsed == null
        ? amountRaw
        : '${NumberFormat('#,##0', 'ar').format(amountParsed)} د.ع';

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'شحن المحفظة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'حوّل المبلغ أولاً، ثم ارفع الإيصال. اعتماد الإدارة يضيف الرصيد ولا يرتبط بأي موعد.',
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 14),
            _InfoLine(label: 'طريقة التحويل', value: provider),
            if (accountName.isNotEmpty)
              _InfoLine(label: 'اسم الحساب', value: accountName),
            Row(
              children: [
                Expanded(
                  child: _InfoLine(
                    label: 'رقم الحساب/المحفظة',
                    value: accountNumber.isEmpty ? 'غير محدد' : accountNumber,
                  ),
                ),
                if (accountNumber.isNotEmpty)
                  IconButton(
                    onPressed: () => onCopy(accountNumber),
                    color: AppColors.primary,
                    icon: const Icon(Icons.copy_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (useSafeWalletKeypads)
              _safeInputField(
                context,
                enabled: enabled,
                label: 'مبلغ الشحن بالدينار',
                value: amountRaw,
                emptyText: 'اضغط لإدخال المبلغ',
                leadingIcon: Icons.payments_outlined,
                onTap: onEditAmount,
                formattedValue: amountRaw.isEmpty ? null : formattedAmount,
              )
            else
              TextField(
                controller: amountController,
                focusNode: amountFocusNode,
                enabled: enabled && !submitting,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                scrollPadding: const EdgeInsets.symmetric(vertical: 16),
                onSubmitted: (_) => transactionFocusNode.requestFocus(),
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                decoration: const InputDecoration(
                  labelText: 'مبلغ الشحن بالدينار',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
            const SizedBox(height: 10),
            if (useSafeWalletKeypads)
              _safeInputField(
                context,
                enabled: enabled,
                label: 'رقم عملية التحويل',
                value: transactionController.text,
                emptyText: 'اضغط لإدخال رقم العملية',
                leadingIcon: Icons.numbers_rounded,
                onTap: onEditTransaction,
              )
            else
              TextField(
                controller: transactionController,
                focusNode: transactionFocusNode,
                enabled: enabled && !submitting,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                scrollPadding: const EdgeInsets.symmetric(vertical: 16),
                onSubmitted: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                decoration: const InputDecoration(
                  labelText: 'رقم عملية التحويل',
                  prefixIcon: Icon(Icons.numbers_rounded),
                ),
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: enabled && !submitting ? onPickReceipt : null,
              style: receipt == null
                  ? null
                  : OutlinedButton.styleFrom(
                      foregroundColor: AppColors.success,
                      side: BorderSide(
                        color: AppColors.success.withValues(alpha: .55),
                      ),
                    ),
              icon: Icon(
                receipt == null
                    ? Icons.upload_file_rounded
                    : Icons.check_circle_outline_rounded,
              ),
              label: Text(
                receipt == null ? 'رفع إيصال التحويل' : 'تم اختيار الإيصال',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: enabled && !submitting ? onSubmit : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              icon: submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: LoadingWidget(size: 18, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                submitting
                    ? 'جاري الإرسال...'
                    : enabled
                        ? 'إرسال للمراجعة'
                        : 'الشحن غير متاح حالياً',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumericKeypadSheet extends StatefulWidget {
  final String initialValue;
  final String title;
  final String helperText;
  final String confirmText;
  final bool formatAsAmount;
  final int minimumValue;
  final int maxDigits;

  const _NumericKeypadSheet({
    required this.initialValue,
    required this.title,
    required this.helperText,
    required this.confirmText,
    required this.formatAsAmount,
    required this.minimumValue,
    required this.maxDigits,
  });

  @override
  State<_NumericKeypadSheet> createState() => _NumericKeypadSheetState();
}

class _NumericKeypadSheetState extends State<_NumericKeypadSheet> {
  late String _digits;

  @override
  void initState() {
    super.initState();
    _digits = widget.initialValue.replaceAll(RegExp(r'[^0-9]'), '');
  }

  int get _numericValue => int.tryParse(_digits) ?? 0;

  bool get _canConfirm {
    if (_digits.isEmpty) return false;
    if (widget.formatAsAmount) return _numericValue >= widget.minimumValue;
    return true;
  }

  String get _displayValue {
    if (_digits.isEmpty) return widget.formatAsAmount ? '0 د.ع' : '—';
    if (!widget.formatAsAmount) return _digits;
    return '${NumberFormat('#,##0', 'ar').format(_numericValue)} د.ع';
  }

  void _append(String digit) {
    if (_digits.length >= widget.maxDigits) return;
    setState(() {
      if (_digits == '0') _digits = '';
      _digits += digit;
    });
  }

  void _backspace() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  Widget _digitButton(String digit) => SizedBox(
        height: 52,
        child: OutlinedButton(
          onPressed: () => _append(digit),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            digit,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ),
      );

  Widget _digitRow(List<String> digits) => Row(
        children: [
          for (var index = 0; index < digits.length; index++) ...[
            Expanded(child: _digitButton(digits[index])),
            if (index != digits.length - 1) const SizedBox(width: 8),
          ],
        ],
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            Text(
              widget.helperText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _displayValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: widget.formatAsAmount ? 25 : 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _digitRow(const ['1', '2', '3']),
            const SizedBox(height: 8),
            _digitRow(const ['4', '5', '6']),
            const SizedBox(height: 8),
            _digitRow(const ['7', '8', '9']),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _digits.isEmpty ? null : _backspace,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.backspace_outlined, size: 19),
                      label: const Text('حذف'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: _digitButton('0')),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _digits.isEmpty
                          ? null
                          : () => setState(() => _digits = ''),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('مسح'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _canConfirm
                    ? () => Navigator.of(context).pop(_digits)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  widget.confirmText,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  const _InfoLine({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          children: [
            Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
            Expanded(child: SelectableText(value, textAlign: TextAlign.end)),
          ],
        ),
      );
}

class _TopupHistoryCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _TopupHistoryCard({required this.item});
  @override
  Widget build(BuildContext context) {
    final status = item['status']?.toString() ?? '';
    final scheme = Theme.of(context).colorScheme;
    final color = status == 'معتمد'
        ? AppColors.success
        : status == 'مرفوض'
            ? scheme.error
            : AppColors.goldDark;
    final amount = double.tryParse('${item['amount'] ?? 0}') ?? 0;
    final date = DateTime.tryParse('${item['created_at'] ?? ''}')?.toLocal();
    return Card(
      child: ListTile(
        leading: Icon(Icons.receipt_long_outlined, color: color),
        title: Text(
          '${NumberFormat('#,##0', 'ar').format(amount)} د.ع',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${item['transaction_number'] ?? ''}${date == null ? '' : '\n${DateFormat('yyyy/MM/dd – hh:mm a', 'ar').format(date)}'}${item['admin_note'] == null ? '' : '\nملاحظة الإدارة: ${item['admin_note']}'}',
        ),
        trailing: Text(
          status,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _LedgerCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _LedgerCard({required this.item});
  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse('${item['amount'] ?? 0}') ?? 0;
    final labels = <String, String>{
      'topup': 'شحن معتمد',
      'booking_payment': 'دفع استشارة',
      'appointment_hold': 'حجز مبلغ لطلب الموعد',
      'appointment_release': 'إعادة مبلغ محجوز',
      'appointment_capture': 'تأكيد دفع الموعد',
      'withdrawal_hold': 'حجز مبلغ لطلب سحب',
      'withdrawal_release': 'إعادة مبلغ طلب سحب',
      'withdrawal_capture': 'تنفيذ سحب الرصيد',
      'admin_adjustment': 'تسوية إدارية',
    };
    return Card(
      child: ListTile(
        leading: Icon(
          amount >= 0
              ? Icons.add_circle_outline
              : Icons.remove_circle_outline,
          color: amount >= 0
              ? AppColors.success
              : Theme.of(context).colorScheme.error,
        ),
        title: Text(
          labels[item['entry_type']] ?? 'حركة محفظة',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          'الرصيد بعد الحركة: ${NumberFormat('#,##0', 'ar').format(double.tryParse('${item['balance_after'] ?? 0}') ?? 0)} د.ع',
        ),
        trailing: Text(
          '${amount > 0 ? '+' : ''}${NumberFormat('#,##0', 'ar').format(amount)}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final String text;
  const _NoticeCard({required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.w700, height: 1.5),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  final String text;
  const _ErrorCard({required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        color: Theme.of(context).colorScheme.errorContainer,
        child: Text(text),
      );
}

class _EmptyCard extends StatelessWidget {
  final String text;
  const _EmptyCard({required this.text});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
}
