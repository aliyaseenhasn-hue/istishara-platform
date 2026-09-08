import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../bookings/domain/entities/booking.dart';
import '../../../bookings/presentation/providers/bookings_provider.dart';
import '../providers/payments_provider.dart';

class PaymentUploadPage extends ConsumerStatefulWidget {
  final Booking booking;

  const PaymentUploadPage({super.key, required this.booking});

  @override
  ConsumerState<PaymentUploadPage> createState() => _PaymentUploadPageState();
}

class _PaymentUploadPageState extends ConsumerState<PaymentUploadPage> {
  final _transactionController = TextEditingController();
  late Future<Map<String, dynamic>> _settingsFuture;
  XFile? _receipt;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _settingsFuture = _loadSettings();
  }

  @override
  void dispose() {
    _transactionController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadSettings() async {
    final response = await SupabaseConfig.client.rpc('get_manual_payment_settings');
    if (response is List && response.isNotEmpty) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    if (response is Map) return Map<String, dynamic>.from(response);
    return <String, dynamic>{'enabled': false};
  }

  Future<void> _pickReceipt() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (image == null || !mounted) return;
    setState(() {
      _receipt = image;
      _error = null;
    });
  }

  Future<void> _copyAccount(String value) async {
    if (value.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value.trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ رقم الحساب/المحفظة')),
    );
  }

  Future<void> _submit(Map<String, dynamic> settings) async {
    if (_submitting) return;
    if (settings['enabled'] != true) {
      setState(() => _error = 'طريقة الدفع اليدوي غير مفعلة حالياً.');
      return;
    }
    if (_receipt == null) {
      setState(() => _error = 'يجب رفع صورة إيصال الدفع قبل الضغط على تم الدفع.');
      return;
    }
    final transactionNumber = _transactionController.text.trim();
    if (transactionNumber.isEmpty) {
      setState(() => _error = 'يرجى إدخال رقم عملية التحويل الموجود في الإيصال.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    await ref.read(paymentsControllerProvider.notifier).submitPayment(
          bookingId: widget.booking.id,
          amount: widget.booking.price,
          method: 'bank_transfer',
          transactionNumber: transactionNumber,
          receiptFile: _receipt,
        );

    final state = ref.read(paymentsControllerProvider);
    if (!mounted) return;
    if (state.hasError) {
      setState(() {
        _submitting = false;
        _error = state.error.toString().replaceFirst('Exception: ', '');
      });
      return;
    }

    ref.invalidate(bookingPaymentProvider(widget.booking.id));
    ref.invalidate(userBookingsProvider);
    ref.invalidate(lawyerBookingsProvider);

    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إرسال إيصال الدفع إلى الإدارة للمراجعة. سيتم إشعارك بعد التحقق.'),
      ),
    );
    context.go('/bookings');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final priceText = widget.booking.price.toStringAsFixed(
      widget.booking.price.truncateToDouble() == widget.booking.price ? 0 : 2,
    );

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('دفع الاستشارة'),
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _settingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _LoadError(
              onRetry: () => setState(() => _settingsFuture = _loadSettings()),
            );
          }

          final settings = snapshot.data ?? const <String, dynamic>{};
          final enabled = settings['enabled'] == true;
          final provider = (settings['provider_name']?.toString().trim().isNotEmpty ?? false)
              ? settings['provider_name'].toString().trim()
              : 'تحويل يدوي';
          final accountName = settings['account_name']?.toString().trim() ?? '';
          final accountNumber = settings['account_number']?.toString().trim() ?? '';
          final instructions = settings['instructions']?.toString().trim() ?? '';
          final canSubmit = enabled && !_submitting && _receipt != null;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.account_balance_wallet_outlined,
                            size: 34, color: scheme.onPrimaryContainer),
                        const SizedBox(height: 8),
                        Text(
                          'المبلغ المطلوب',
                          style: textTheme.titleMedium?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$priceText د.ع',
                          style: textTheme.headlineMedium?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!enabled)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, color: scheme.onErrorContainer),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'طريقة الدفع قيد الإعداد من الإدارة ولن يُطلب منك تحويل أي مبلغ حتى يتم تفعيلها.',
                              style: TextStyle(color: scheme.onErrorContainer, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!enabled) const SizedBox(height: 16),
                  Card(
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
                          Text('بيانات التحويل',
                              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 14),
                          _InfoRow(label: 'طريقة التحويل', value: provider),
                          if (accountName.isNotEmpty) ...[
                            const Divider(height: 24),
                            _InfoRow(label: 'اسم الحساب', value: accountName),
                          ],
                          const Divider(height: 24),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: _InfoRow(
                                  label: 'رقم الحساب/المحفظة',
                                  value: accountNumber.isEmpty ? 'غير محدد بعد' : accountNumber,
                                ),
                              ),
                              if (accountNumber.isNotEmpty)
                                IconButton(
                                  tooltip: 'نسخ',
                                  onPressed: () => _copyAccount(accountNumber),
                                  icon: const Icon(Icons.copy_rounded),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: scheme.tertiary.withValues(alpha: .35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: scheme.tertiary.withValues(alpha: .14),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(Icons.priority_high_rounded, color: scheme.tertiary),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'تعليمات مهمة قبل تأكيد الدفع',
                                style: textTheme.titleMedium?.copyWith(
                                  color: scheme.onTertiaryContainer,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 13),
                        _InstructionLine(number: '1', text: 'حوّل مبلغ الاستشارة كاملاً إلى حساب المنصة الموضح أعلاه.'),
                        const SizedBox(height: 8),
                        _InstructionLine(number: '2', text: 'احتفظ بصورة واضحة للإيصال بعد إتمام التحويل.'),
                        const SizedBox(height: 8),
                        _InstructionLine(number: '3', text: 'ارفع صورة الإيصال وأدخل رقم عملية التحويل الظاهر فيه.'),
                        const SizedBox(height: 8),
                        _InstructionLine(number: '4', text: 'اضغط «تم الدفع وإرسال الإيصال». لن يعتبر الدفع مؤكداً إلا بعد مراجعة الإدارة.'),
                        if (instructions.isNotEmpty) ...[
                          const SizedBox(height: 13),
                          Divider(color: scheme.tertiary.withValues(alpha: .25)),
                          const SizedBox(height: 8),
                          Text(
                            'تعليمات إضافية من الإدارة',
                            style: TextStyle(
                              color: scheme.onTertiaryContainer,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            instructions,
                            style: TextStyle(
                              color: scheme.onTertiaryContainer,
                              height: 1.6,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _transactionController,
                    enabled: enabled && !_submitting,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'رقم عملية التحويل',
                      hintText: 'اكتب الرقم الظاهر في الإيصال',
                      prefixIcon: Icon(Icons.numbers_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: enabled && !_submitting ? _pickReceipt : null,
                    icon: Icon(_receipt == null
                        ? Icons.upload_file_rounded
                        : Icons.check_circle_outline_rounded),
                    label: Text(
                      _receipt == null
                          ? 'رفع إيصال الدفع (إلزامي)'
                          : 'تم اختيار الإيصال: ${_receipt!.name}',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                  if (_receipt == null && enabled) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.lock_outline_rounded, size: 17, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'زر تأكيد الدفع سيتفعّل بعد رفع صورة الإيصال.',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: scheme.onErrorContainer, height: 1.4),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: canSubmit ? () => _submit(settings) : null,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_receipt == null ? Icons.lock_outline_rounded : Icons.verified_outlined),
                    label: Text(
                      _submitting
                          ? 'جاري إرسال الإثبات...'
                          : _receipt == null
                              ? 'ارفع الإيصال أولاً'
                              : 'تم الدفع وإرسال الإيصال',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _submitting ? null : () => context.go('/bookings'),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('العودة إلى استشاراتي'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InstructionLine extends StatelessWidget {
  final String number;
  final String text;

  const _InstructionLine({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.tertiary,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            number,
            style: TextStyle(color: scheme.onTertiary, fontWeight: FontWeight.w900, fontSize: 12),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: TextStyle(
                color: scheme.onTertiaryContainer,
                height: 1.55,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 4),
        SelectableText(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const _LoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            const Text('تعذر تحميل بيانات الدفع'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
