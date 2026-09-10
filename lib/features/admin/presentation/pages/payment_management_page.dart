import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/private_storage_reference.dart';
import '../../../../core/utils/user_facing_error.dart';
import '../../../payments/domain/entities/payment.dart';
import '../providers/payment_management_provider.dart';

class PaymentManagementPage extends ConsumerStatefulWidget {
  const PaymentManagementPage({super.key});

  @override
  ConsumerState<PaymentManagementPage> createState() => _PaymentManagementPageState();
}

class _PaymentManagementPageState extends ConsumerState<PaymentManagementPage> {
  final _providerController = TextEditingController(text: 'تحويل يدوي');
  final _accountNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _instructionsController = TextEditingController();
  bool _enabled = false;
  bool _settingsLoading = true;
  bool _settingsSaving = false;
  late Future<List<Map<String, dynamic>>> _walletTopupsFuture;

  @override
  void initState() {
    super.initState();
    _walletTopupsFuture = _loadWalletTopups();
    _loadSettings();
  }

  Future<List<Map<String, dynamic>>> _loadWalletTopups() async {
    final raw = await SupabaseConfig.client.rpc('get_pending_client_wallet_topups');
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  @override
  void dispose() {
    _providerController.dispose();
    _accountNameController.dispose();
    _accountNumberController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    if (mounted) setState(() => _settingsLoading = true);
    try {
      final response = await SupabaseConfig.client.rpc('get_manual_payment_settings');
      Map<String, dynamic> settings = {};
      if (response is List && response.isNotEmpty) {
        settings = Map<String, dynamic>.from(response.first as Map);
      } else if (response is Map) {
        settings = Map<String, dynamic>.from(response);
      }
      if (!mounted) return;
      setState(() {
        _enabled = settings['enabled'] == true;
        _providerController.text = settings['provider_name']?.toString() ?? 'تحويل يدوي';
        _accountNameController.text = settings['account_name']?.toString() ?? '';
        _accountNumberController.text = settings['account_number']?.toString() ?? '';
        _instructionsController.text = settings['instructions']?.toString() ?? '';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل إعدادات الدفع: ${UserFacingError.text(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _settingsLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_settingsSaving) return;
    if (_enabled && _accountNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل رقم الحساب أو المحفظة قبل تفعيل الدفع.')),
      );
      return;
    }

    setState(() => _settingsSaving = true);
    try {
      await SupabaseConfig.client.rpc(
        'admin_update_manual_payment_settings',
        params: {
          'p_enabled': _enabled,
          'p_provider_name': _providerController.text.trim(),
          'p_account_name': _accountNameController.text.trim(),
          'p_account_number': _accountNumberController.text.trim(),
          'p_instructions': _instructionsController.text.trim(),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _enabled
                ? 'تم تفعيل شحن محفظة العميل بالدفع اليدوي. بعد اعتماد الرصيد يصبح الحجز فورياً.'
                : 'تم إيقاف الدفع اليدوي.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ إعدادات الدفع: ${UserFacingError.text(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _settingsSaving = false);
    }
  }

  Future<void> _showReceipt(String? receiptReference) async {
    try {
      final url = await PrivateStorageReference.resolve(
        SupabaseConfig.client,
        receiptReference,
        expiresIn: 300,
      );
      if (!mounted) return;
      if (url == null || url.isEmpty) {
        throw Exception('لا يوجد إيصال مرفوع');
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('إيصال الدفع', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) => progress == null
                          ? child
                          : const Padding(
                              padding: EdgeInsets.all(60),
                              child: CircularProgressIndicator(),
                            ),
                      errorBuilder: (_, __, ___) => const Padding(
                        padding: EdgeInsets.all(40),
                        child: Text('تعذر عرض صورة الإيصال.'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر فتح الإيصال: ${UserFacingError.text(e)}')),
        );
      }
    }
  }

  Future<void> _reviewWalletTopup(
    Map<String, dynamic> topup,
    bool approved,
  ) async {
    final noteController = TextEditingController();
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(approved ? 'اعتماد شحن المحفظة' : 'رفض طلب الشحن'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            approved
                ? 'تأكد من وصول ${topup['amount']} د.ع فعلياً إلى حساب المنصة. سيضاف المبلغ فوراً إلى محفظة العميل.'
                : 'لن يضاف أي رصيد إلى محفظة العميل.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'ملاحظة الإدارة (اختياري)'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(approved ? 'تأكيد وصول المبلغ' : 'رفض الإيصال')),
        ],
      ),
    );
    final note = noteController.text.trim();
    noteController.dispose();
    if (proceed != true) return;
    try {
      await SupabaseConfig.client.rpc(
        'admin_review_client_wallet_topup',
        params: {
          'p_topup_id': topup['id'],
          'p_approved': approved,
          'p_note': note.isEmpty ? null : note,
        },
      );
      if (!mounted) return;
      setState(() => _walletTopupsFuture = _loadWalletTopups());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approved ? 'تم اعتماد الشحن وإضافة الرصيد.' : 'تم رفض طلب الشحن.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ القرار: ${UserFacingError.text(error)}')),
        );
      }
    }
  }

  Future<void> _review(Payment payment, bool approved) async {
    Map<String, dynamic> bookingContext = const {};
    try {
      final row = await SupabaseConfig.client
          .from('bookings')
          .select('status,cancellation_actor_role,cancellation_reason')
          .eq('id', payment.bookingId)
          .maybeSingle();
      if (row != null) bookingContext = Map<String, dynamic>.from(row);
    } catch (_) {
      // Server-side rules remain authoritative even if context lookup fails.
    }
    if (!mounted) return;

    final refundOnly = bookingContext['status'] == 'بانتظار الاسترداد' &&
        bookingContext['cancellation_actor_role'] != null;
    final cancellationReason = bookingContext['cancellation_reason']?.toString();
    final noteController = TextEditingController();
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          approved
              ? (refundOnly ? 'تأكيد وصول مبلغ لحجز ملغي' : 'تأكيد استلام المبلغ')
              : 'رفض إثبات الدفع',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (refundOnly) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(dialogContext).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'هذا الحجز أُلغي بالفعل${cancellationReason?.trim().isNotEmpty == true ? ' بسبب: $cancellationReason' : ''}. '
                  'مراجعة الإيصال هنا هدفها مطابقة وصول المال فقط.',
                  style: const TextStyle(fontWeight: FontWeight.w800, height: 1.45),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              approved
                  ? (refundOnly
                      ? 'تأكد من وصول ${payment.amount.toStringAsFixed(0)} د.ع فعلياً إلى حساب المنصة. عند الموافقة لن يُعاد تفعيل الحجز، ولن تُحتسب عمولة أو مستحق للمحامي؛ سيُسجل المبلغ كاملاً للاسترداد للعميل.'
                      : 'تأكد من وصول المبلغ فعلياً إلى حساب المنصة قبل الموافقة. عند التأكيد ستُحتسب عمولة المنصة ويُسجل صافي المحامي تلقائياً.')
                  : (refundOnly
                      ? 'اختر الرفض فقط إذا تأكدت أن المبلغ لم يصل إلى حساب المنصة. سيبقى الحجز ملغياً ولن يُنشأ استرداد لمبلغ غير مستلم.'
                      : 'سيتم إبلاغ طالب الاستشارة أن إثبات الدفع لم يتم اعتماده.'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'ملاحظة الإدارة (اختياري)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              approved
                  ? (refundOnly ? 'تأكيد الوصول وبدء الاسترداد' : 'تأكيد الدفع')
                  : 'رفض الإثبات',
            ),
          ),
        ],
      ),
    );
    final note = noteController.text.trim();
    noteController.dispose();
    if (proceed != true || !mounted) return;

    final notifier = ref.read(paymentManagementProvider.notifier);
    if (approved) {
      await notifier.approvePayment(payment, note: note);
    } else {
      await notifier.rejectPayment(payment, note: note);
    }
    if (!mounted) return;
    final result = ref.read(paymentManagementProvider);
    if (result.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ القرار: ${UserFacingError.text(result.error ?? Exception('تعذر حفظ القرار'))}')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          approved
              ? (refundOnly ? 'تم إثبات وصول المبلغ وتسجيله للاسترداد الكامل.' : 'تم اعتماد الدفع وتسجيل المستحقات.')
              : (refundOnly ? 'تم رفض الإثبات وإغلاق الحجز الملغي دون استرداد.' : 'تم رفض إثبات الدفع.'),
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    final topups = _loadWalletTopups();
    if (mounted) setState(() => _walletTopupsFuture = topups);
    await Future.wait([
      topups,
      _loadSettings(),
      ref.read(paymentManagementProvider.notifier).refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final paymentsAsync = ref.watch(paymentManagementProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('إدارة الدفعات'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _refresh, tooltip: 'تحديث', icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
          children: [
            _buildSettingsCard(context),
            const SizedBox(height: 18),
            Row(children: [
              const Expanded(child: Text('شحن المحافظ بانتظار المراجعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
              const Chip(label: Text('مهلة 30 دقيقة')),
            ]),
            const SizedBox(height: 10),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _walletTopupsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(16)),
                    child: Text('تعذر تحميل طلبات الشحن: ${UserFacingError.text(snapshot.error!)}'),
                  );
                }
                final topups = snapshot.data ?? const <Map<String, dynamic>>[];
                if (topups.isEmpty) {
                  return const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('لا توجد طلبات شحن تحتاج مراجعة.', textAlign: TextAlign.center)));
                }
                return Column(
                  children: topups.map((topup) => _WalletTopupReviewCard(
                    topup: topup,
                    onReceipt: () => _showReceipt(topup['receipt_url']?.toString()),
                    onApprove: () => _reviewWalletTopup(topup, true),
                    onReject: () => _reviewWalletTopup(topup, false),
                  )).toList(),
                );
              },
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text('إيصالات مرتبطة بحجوزات سابقة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ),
                paymentsAsync.maybeWhen(
                  data: (items) => Chip(label: Text('${items.length}')),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            paymentsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(36),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(16)),
                child: Text('تعذر تحميل الدفعات: ${UserFacingError.text(error)}', style: TextStyle(color: scheme.onErrorContainer)),
              ),
              data: (payments) {
                if (payments.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.verified_outlined, size: 48, color: AppColors.success),
                        SizedBox(height: 10),
                        Text('لا توجد إيصالات تحتاج مراجعة', style: TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  );
                }
                return Column(
                  children: payments.map((payment) => _PaymentReviewCard(
                    payment: payment,
                    onReceipt: () => _showReceipt(payment.receiptUrl),
                    onApprove: () => _review(payment, true),
                    onReject: () => _review(payment, false),
                  )).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: _settingsLoading
            ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('حساب استلام أموال الاستشارات', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    'عند التفعيل تُوقف الفترة التجريبية المجانية، ويشحن العميل محفظته ويرفع الإيصال. بعد اعتماد الإدارة يختار الموعد ويحجزه فوراً.',
                    style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _enabled,
                    onChanged: _settingsSaving ? null : (value) => setState(() => _enabled = value),
                    title: const Text('تفعيل الدفع اليدوي للمنصة', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _providerController,
                    enabled: !_settingsSaving,
                    decoration: const InputDecoration(labelText: 'اسم طريقة التحويل', hintText: 'مثال: زين كاش أو تحويل مصرفي'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _accountNameController,
                    enabled: !_settingsSaving,
                    decoration: const InputDecoration(labelText: 'اسم صاحب الحساب'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _accountNumberController,
                    enabled: !_settingsSaving,
                    decoration: const InputDecoration(labelText: 'رقم الحساب أو المحفظة'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _instructionsController,
                    enabled: !_settingsSaving,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'تعليمات إضافية للعميل'),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _settingsSaving ? null : _saveSettings,
                    icon: _settingsSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined),
                    label: Text(_settingsSaving ? 'جاري الحفظ...' : 'حفظ إعدادات الدفع'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _WalletTopupReviewCard extends StatelessWidget {
  final Map<String, dynamic> topup;
  final VoidCallback onReceipt;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _WalletTopupReviewCard({
    required this.topup,
    required this.onReceipt,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final overdue = topup['is_overdue'] == true;
    final createdAt = DateTime.tryParse('${topup['created_at'] ?? ''}')?.toLocal();
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: overdue ? scheme.errorContainer.withValues(alpha: .45) : scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: overdue ? scheme.error : scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(overdue ? Icons.priority_high_rounded : Icons.account_balance_wallet_outlined, color: overdue ? scheme.error : scheme.primary),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(topup['client_name']?.toString() ?? 'طالب استشارة', style: const TextStyle(fontWeight: FontWeight.w900)),
              Text(overdue ? 'تجاوز مهلة المراجعة — أولوية عاجلة' : 'ضمن مهلة المراجعة', style: TextStyle(color: overdue ? scheme.error : scheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700)),
            ])),
            if (createdAt != null) Text(DateFormat('hh:mm a', 'ar').format(createdAt), style: const TextStyle(fontSize: 11)),
          ]),
          const SizedBox(height: 12),
          _adminRow('المبلغ', '${topup['amount']} د.ع'),
          const SizedBox(height: 6),
          _adminRow('رقم العملية', topup['transaction_number']?.toString() ?? 'غير متوفر'),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(onPressed: onReceipt, icon: const Icon(Icons.visibility_outlined), label: const Text('عرض إيصال الشحن')),
          const SizedBox(height: 9),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: onReject, icon: Icon(Icons.close_rounded, color: scheme.error), label: Text('رفض', style: TextStyle(color: scheme.error)))),
            const SizedBox(width: 9),
            Expanded(flex: 2, child: FilledButton.icon(onPressed: onApprove, icon: const Icon(Icons.check_rounded), label: const Text('اعتماد وإضافة الرصيد'))),
          ]),
        ]),
      ),
    );
  }

  Widget _adminRow(String label, String value) => Row(children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
        Expanded(child: Text(value, textAlign: TextAlign.end)),
      ]);
}

class _PaymentReviewCard extends StatelessWidget {
  final Payment payment;
  final VoidCallback onReceipt;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PaymentReviewCard({
    required this.payment,
    required this.onReceipt,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(13)),
                  child: Icon(Icons.receipt_long_outlined, color: scheme.onTertiaryContainer),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('إثبات دفع جديد', style: TextStyle(fontWeight: FontWeight.w900)),
                      Text('بانتظار تحقق الإدارة', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                if (payment.createdAt != null)
                  Text(DateFormat('yyyy/MM/dd').format(payment.createdAt!), style: const TextStyle(fontSize: 11)),
              ],
            ),
            const SizedBox(height: 14),
            _row('المبلغ', '${payment.amount.toStringAsFixed(0)} د.ع'),
            const SizedBox(height: 7),
            _row('رقم العملية', payment.transactionNumber ?? 'غير متوفر'),
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: onReceipt,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('عرض إيصال الدفع'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: Icon(Icons.close_rounded, color: scheme.error),
                    label: Text('رفض', style: TextStyle(color: scheme.error, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('تأكيد الاستلام'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
          Expanded(child: Text(value, textAlign: TextAlign.end)),
        ],
      );
}
