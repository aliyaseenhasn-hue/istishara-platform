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

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(clientWalletProvider);
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
            onPressed: () {
              ref.invalidate(clientWalletProvider);
              ref.invalidate(clientWalletTopupsProvider);
              ref.invalidate(clientWalletLedgerProvider);
            },
            color: AppColors.teal,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.teal,
        onRefresh: () async {
          ref.invalidate(clientWalletProvider);
          ref.invalidate(clientWalletTopupsProvider);
          ref.invalidate(clientWalletLedgerProvider);
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
            'محجوز لطلبات المواعيد: $held د.ع',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
