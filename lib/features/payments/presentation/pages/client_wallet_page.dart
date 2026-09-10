import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

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
  late Future<Map<String, dynamic>> _settingsFuture;
  XFile? _receipt;
  bool _submitting = false;

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
                  receipt: _receipt,
                  submitting: _submitting,
                  onCopy: (value) async {
                    await Clipboard.setData(ClipboardData(text: value));
                    _message('تم نسخ رقم الحساب/المحفظة.');
                  },
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
  final XFile? receipt;
  final bool submitting;
  final ValueChanged<String> onCopy;
  final VoidCallback onPickReceipt;
  final VoidCallback? onSubmit;

  const _TopupCard({
    required this.settings,
    required this.amountController,
    required this.transactionController,
    required this.receipt,
    required this.submitting,
    required this.onCopy,
    required this.onPickReceipt,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = settings['enabled'] == true;
    final accountNumber = settings['account_number']?.toString().trim() ?? '';
    final accountName = settings['account_name']?.toString().trim() ?? '';
    final provider =
        settings['provider_name']?.toString().trim() ?? 'تحويل يدوي';
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
            TextField(
              controller: amountController,
              enabled: enabled && !submitting,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              scrollPadding: const EdgeInsets.only(bottom: 120),
              decoration: const InputDecoration(
                labelText: 'مبلغ الشحن بالدينار',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: transactionController,
              enabled: enabled && !submitting,
              textInputAction: TextInputAction.done,
              scrollPadding: const EdgeInsets.only(bottom: 150),
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
