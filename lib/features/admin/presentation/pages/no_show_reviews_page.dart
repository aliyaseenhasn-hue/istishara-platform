import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';

class NoShowReviewsPage extends StatefulWidget {
  const NoShowReviewsPage({super.key});

  @override
  State<NoShowReviewsPage> createState() => _NoShowReviewsPageState();
}

class _NoShowReviewsPageState extends State<NoShowReviewsPage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  bool _pendingOnly = true;
  String? _busyRequestId;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final result = await _supabase.rpc('admin_list_no_show_reviews_financial');
      final rows = (result as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (mounted) setState(() => _items = rows);
    } catch (error) {
      if (mounted) _showError('تعذر تحميل بلاغات عدم الحضور', error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(dynamic value) {
    final amount = _number(value).round();
    final raw = amount.toString();
    final out = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) out.write(',');
      out.write(raw[i]);
    }
    return '${out.toString()} د.ع';
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'غير محدد';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}/${two(date.month)}/${two(date.day)} - ${two(date.hour)}:${two(date.minute)}';
  }

  String _shortId(dynamic value) {
    final text = value?.toString() ?? '';
    return text.length <= 12 ? text : '${text.substring(0, 8)}…';
  }

  String _errorText(Object error) {
    if (error is PostgrestException) return error.message;
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final match = RegExp(r'message:\s*([^,\)]+)', caseSensitive: false).firstMatch(raw);
    return match?.group(1)?.trim() ?? (raw.isEmpty ? 'حدث خطأ غير متوقع.' : raw);
  }

  void _showError(String title, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title: ${_errorText(error)}')),
    );
  }

  bool _isClientNoShow(Map<String, dynamic> item) =>
      item['reason']?.toString().trim() == 'عدم حضور طالب الاستشارة';

  bool _isLawyerNoShow(Map<String, dynamic> item) =>
      item['reason']?.toString().trim() == 'عدم حضور المحامي';

  Future<void> _review(Map<String, dynamic> item, String decision) async {
    final approved = decision == 'approved';
    final clientNoShow = _isClientNoShow(item);
    final paid = _number(item['paid_amount']);
    final defaultRate = _number(item['default_penalty_rate']) > 0
        ? _number(item['default_penalty_rate'])
        : 20.0;

    final result = await showDialog<_ReviewDecision>(
      context: context,
      builder: (dialogContext) {
        var rate = defaultRate.clamp(1.0, 99.0).toDouble();
        final noteController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final penalty = approved && clientNoShow ? paid * rate / 100 : 0.0;
            final refund = approved
                ? (clientNoShow ? (paid - penalty).clamp(0, paid).toDouble() : paid)
                : 0.0;
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                title: Row(children: [
                  Icon(
                    approved ? Icons.fact_check_outlined : Icons.cancel_outlined,
                    color: approved ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      approved ? 'اعتماد بلاغ عدم الحضور' : 'رفض بلاغ عدم الحضور',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ]),
                content: SizedBox(
                  width: 470,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (approved) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: clientNoShow ? AppColors.pendingBg : AppColors.acceptedBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: clientNoShow ? AppColors.goldSoftStrong : AppColors.success.withValues(alpha: .35),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  clientNoShow
                                      ? 'عدم حضور طالب الاستشارة'
                                      : 'عدم حضور المحامي',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  clientNoShow
                                      ? 'سيتم استقطاع نسبة من المبلغ المدفوع كتعويض للمحامي، وإرجاع الباقي إلى العميل.'
                                      : 'سيتم إرجاع كامل المبلغ المدفوع إلى العميل دون أي استقطاع.',
                                  style: const TextStyle(height: 1.5, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _dialogMoneyRow('المبلغ المدفوع', _money(paid)),
                          if (clientNoShow) ...[
                            const SizedBox(height: 12),
                            Row(children: [
                              const Expanded(
                                child: Text(
                                  'نسبة الاستقطاع',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: .10),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${rate.toStringAsFixed(rate % 1 == 0 ? 0 : 1)}%',
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ]),
                            Slider(
                              value: rate,
                              min: 5,
                              max: 90,
                              divisions: 17,
                              label: '${rate.round()}%',
                              onChanged: (value) => setDialogState(() => rate = value),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Text('5%', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                Text('90%', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _dialogMoneyRow('تعويض المحامي', _money(penalty), strong: true),
                          ],
                          const SizedBox(height: 8),
                          _dialogMoneyRow(
                            clientNoShow ? 'المبلغ المعاد للعميل' : 'الاسترداد الكامل للعميل',
                            _money(refund),
                            strong: true,
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextField(
                          controller: noteController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'ملاحظة الإدارة (اختياري)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('إلغاء'),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(
                        dialogContext,
                        _ReviewDecision(
                          note: noteController.text.trim(),
                          penaltyRate: approved && clientNoShow ? rate : null,
                        ),
                      );
                    },
                    icon: Icon(approved ? Icons.check_rounded : Icons.close_rounded),
                    label: Text(approved ? 'اعتماد القرار المالي' : 'اعتماد الرفض'),
                    style: FilledButton.styleFrom(
                      backgroundColor: approved ? AppColors.success : AppColors.error,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;
    setState(() => _busyRequestId = item['id']?.toString());
    try {
      await _supabase.rpc(
        'admin_review_no_show_request_financial',
        params: {
          'p_request_id': item['id'],
          'p_decision': decision,
          'p_note': result.note.isEmpty ? null : result.note,
          'p_penalty_rate': result.penaltyRate,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approved
                  ? (clientNoShow
                      ? 'تم اعتماد البلاغ وحساب الاستقطاع والاسترداد.'
                      : 'تم اعتماد البلاغ وإنشاء الاسترداد الكامل للعميل.')
                  : 'تم رفض البلاغ وإعادة الاستشارة إلى حالتها السابقة.',
            ),
          ),
        );
      }
      await _load();
    } catch (error) {
      if (mounted) _showError('تعذر حفظ القرار', error);
    } finally {
      if (mounted) setState(() => _busyRequestId = null);
    }
  }

  Widget _dialogMoneyRow(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
        Text(
          value,
          style: TextStyle(
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            color: strong ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ]),
    );
  }

  Future<void> _completeRefund(Map<String, dynamic> item) async {
    final referenceController = TextEditingController();
    final noteController = TextEditingController();
    final result = await showDialog<_RefundDecision>(
      context: context,
      builder: (dialogContext) {
        var showReferenceError = false;
        return StatefulBuilder(
          builder: (context, setDialogState) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              title: const Row(children: [
                Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(child: Text('تسجيل تحويل الاسترداد', style: TextStyle(fontWeight: FontWeight.w900))),
              ]),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: .07),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        _dialogMoneyRow('المبلغ المطلوب تحويله', _money(item['refund_amount']), strong: true),
                        const SizedBox(height: 6),
                        _dialogMoneyRow('وسيلة الاستلام', _text(item['provider_type'])),
                        _dialogMoneyRow('اسم صاحب الحساب', _text(item['account_holder_name'])),
                        _dialogMoneyRow('رقم الحساب', _text(item['account_number']), strong: true),
                        if (_hasText(item['bank_name']))
                          _dialogMoneyRow('المصرف', _text(item['bank_name'])),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: referenceController,
                      decoration: InputDecoration(
                        labelText: 'رقم مرجع التحويل *',
                        hintText: 'أدخل رقم العملية بعد تحويل المبلغ',
                        border: const OutlineInputBorder(),
                        errorText: showReferenceError ? 'رقم مرجع التحويل مطلوب' : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظة التحويل (اختياري)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ]),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
                FilledButton.icon(
                  onPressed: () {
                    final reference = referenceController.text.trim();
                    if (reference.isEmpty) {
                      setDialogState(() => showReferenceError = true);
                      return;
                    }
                    Navigator.pop(
                      dialogContext,
                      _RefundDecision(reference: reference, note: noteController.text.trim()),
                    );
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('تأكيد تحويل المبلغ'),
                ),
              ],
            ),
          ),
        );
      },
    );
    referenceController.dispose();
    noteController.dispose();

    if (result == null || !mounted) return;
    setState(() => _busyRequestId = item['id']?.toString());
    try {
      await _supabase.rpc(
        'admin_complete_no_show_refund',
        params: {
          'p_request_id': item['id'],
          'p_provider_reference': result.reference,
          'p_admin_note': result.note.isEmpty ? null : result.note,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل تحويل الاسترداد وإغلاق العملية المالية.')),
        );
      }
      await _load();
    } catch (error) {
      if (mounted) _showError('تعذر تسجيل تحويل الاسترداد', error);
    } finally {
      if (mounted) setState(() => _busyRequestId = null);
    }
  }

  bool _hasText(dynamic value) => value?.toString().trim().isNotEmpty == true;

  String _text(dynamic value, {String fallback = 'غير متوفر'}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  String _statusLabel(dynamic status) {
    switch (status?.toString()) {
      case 'pending':
        return 'قيد المراجعة';
      case 'approved':
        return 'تمت الموافقة';
      case 'rejected':
        return 'تم الرفض';
      default:
        return _text(status, fallback: 'غير محدد');
    }
  }

  Widget _statusBadge(dynamic status) {
    final value = status?.toString();
    final Color background;
    final Color foreground;
    final IconData icon;
    if (value == 'approved') {
      background = AppColors.acceptedBg;
      foreground = AppColors.acceptedText;
      icon = Icons.check_circle_outline_rounded;
    } else if (value == 'rejected') {
      background = AppColors.cancelledBg;
      foreground = AppColors.cancelledText;
      icon = Icons.cancel_outlined;
    } else {
      background = AppColors.pendingBg;
      foreground = AppColors.pendingText;
      icon = Icons.hourglass_top_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: foreground),
        const SizedBox(width: 5),
        Text(_statusLabel(status), style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _infoRow(String label, String value, {IconData? icon, bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (icon != null) ...[
          Icon(icon, size: 17, color: AppColors.textSecondary),
          const SizedBox(width: 7),
        ],
        SizedBox(
          width: 105,
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.left,
            style: TextStyle(color: AppColors.textPrimary, fontWeight: strong ? FontWeight.w900 : FontWeight.w700),
          ),
        ),
      ]),
    );
  }

  Widget _financialPanel(Map<String, dynamic> item) {
    final clientNoShow = _isClientNoShow(item);
    final approved = item['status'] == 'approved';
    final refunded = item['financial_status'] == 'refunded' || _hasText(item['refunded_at']);
    final legacy = approved && item['financial_status'] == 'not_started';
    final paid = _number(item['paid_amount']);
    final rate = approved ? _number(item['penalty_rate']) : _number(item['default_penalty_rate']);
    final penalty = approved ? _number(item['penalty_amount']) : (clientNoShow ? paid * rate / 100 : 0.0);
    final refund = approved ? _number(item['refund_amount']) : (clientNoShow ? paid - penalty : paid);
    final hasAccount = _hasText(item['account_number']);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: refunded ? AppColors.acceptedBg : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: refunded ? AppColors.success.withValues(alpha: .35) : AppColors.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(refunded ? Icons.verified_rounded : Icons.payments_outlined, color: refunded ? AppColors.success : AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              refunded ? 'تمت تسوية الاسترداد' : 'التسوية المالية',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _infoRow('المبلغ المدفوع', _money(paid)),
        if (clientNoShow && !legacy) ...[
          _infoRow('نسبة الاستقطاع', '${rate.toStringAsFixed(rate % 1 == 0 ? 0 : 1)}%'),
          _infoRow('تعويض المحامي', _money(penalty), strong: true),
        ],
        if (!legacy) _infoRow('المبلغ للعميل', _money(refund), strong: true),
        if (legacy) ...[
          const SizedBox(height: 4),
          const Text(
            'هذا قرار قديم تم اعتماده قبل إضافة نظام التسوية المالية لبلاغات عدم الحضور، لذلك لا يتم إنشاء حركة مالية جديدة له تلقائياً.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.45, fontSize: 12.5),
          ),
        ] else if (approved && refund > 0) ...[
          const Divider(height: 22),
          if (hasAccount) ...[
            _infoRow('وسيلة الاستلام', _text(item['provider_type'])),
            _infoRow('صاحب الحساب', _text(item['account_holder_name'])),
            _infoRow('رقم الحساب', _text(item['account_number']), strong: true),
            if (_hasText(item['bank_name'])) _infoRow('المصرف', _text(item['bank_name'])),
          ] else if (!refunded)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.pendingBg, borderRadius: BorderRadius.circular(13)),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'العميل لم يحدد حساب استلام افتراضياً بعد. سيظهر زر التحويل هنا تلقائياً بعد إضافة حساب الاستلام.',
                    style: TextStyle(height: 1.45, fontWeight: FontWeight.w700),
                  ),
                ),
              ]),
            ),
          if (refunded) ...[
            _infoRow('مرجع التحويل', _text(item['refund_reference']), strong: true),
            _infoRow('تاريخ التحويل', _formatDate(item['refunded_at'])),
          ],
        ],
      ]),
    );
  }

  Widget _requestCard(Map<String, dynamic> item) {
    final pending = item['status'] == 'pending';
    final clientNoShow = _isClientNoShow(item);
    final lawyerNoShow = _isLawyerNoShow(item);
    final busy = _busyRequestId == item['id']?.toString();
    final approved = item['status'] == 'approved';
    final refund = _number(item['refund_amount']);
    final refunded = item['financial_status'] == 'refunded' || _hasText(item['refunded_at']);
    final legacy = approved && item['financial_status'] == 'not_started';
    final canTransfer = approved && !legacy && refund > 0 && !refunded && _hasText(item['account_number']);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: pending ? AppColors.goldSoftStrong : AppColors.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: clientNoShow ? AppColors.pendingBg : AppColors.cancelledBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              clientNoShow ? Icons.person_off_outlined : Icons.gavel_outlined,
              color: clientNoShow ? AppColors.warning : AppColors.error,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                clientNoShow ? 'بلاغ عدم حضور طالب الاستشارة' : (lawyerNoShow ? 'بلاغ عدم حضور المحامي' : _text(item['reason'])),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5),
              ),
              const SizedBox(height: 5),
              Text('الحجز ${_shortId(item['booking_id'])}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ]),
          ),
          _statusBadge(item['status']),
        ]),
        const SizedBox(height: 14),
        _infoRow('طالب الاستشارة', _text(item['client_name']), icon: Icons.person_outline_rounded),
        _infoRow('المحامي', _text(item['lawyer_name']), icon: Icons.balance_outlined),
        _infoRow('موعد الاستشارة', _formatDate(item['scheduled_at']), icon: Icons.schedule_rounded),
        _infoRow('حالة الدفع', _text(item['payment_status'], fallback: item['payment_required'] == true ? 'لم يتم تأكيد الدفع' : 'لا يتطلب دفعاً')),
        if (_hasText(item['transaction_number']))
          _infoRow('رقم العملية', _text(item['transaction_number'])),
        _financialPanel(item),
        if (_hasText(item['review_note'])) ...[
          const SizedBox(height: 10),
          Text('ملاحظة الإدارة: ${_text(item['review_note'])}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
        ],
        if (busy) ...[
          const SizedBox(height: 14),
          const LinearProgressIndicator(),
        ] else if (pending) ...[
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _review(item, 'approved'),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('الموافقة والتسوية'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _review(item, 'rejected'),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('رفض البلاغ'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
              ),
            ),
          ]),
        ] else if (canTransfer) ...[
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => _completeRefund(item),
            icon: const Icon(Icons.currency_exchange_rounded),
            label: Text('تسجيل تحويل ${_money(refund)} للعميل'),
          ),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _pendingOnly
        ? _items.where((e) => e['status'] == 'pending').toList()
        : _items;
    final pendingCount = _items.where((e) => e['status'] == 'pending').length;
    final readyRefunds = _items.where((e) {
      return e['status'] == 'approved' &&
          _number(e['refund_amount']) > 0 &&
          e['financial_status'] != 'refunded' &&
          e['financial_status'] != 'not_started';
    }).length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('بلاغات عدم الحضور'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
          actions: [
            IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث'),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryDark, AppColors.primary],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Row(children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(16)),
                            child: const Icon(Icons.person_off_outlined, color: Colors.white, size: 27),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('مراجعة البلاغ والتسوية المالية', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                              const SizedBox(height: 4),
                              Text('$pendingCount بانتظار القرار • $readyRefunds بانتظار الاسترداد', style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ]),
                        const SizedBox(height: 13),
                        const Text(
                          'غياب المحامي: استرداد 100% للعميل. غياب العميل: استقطاع النسبة التي تعتمدها الإدارة وتعويض المحامي بها، ثم إعادة الباقي للعميل.',
                          style: TextStyle(color: Colors.white, height: 1.5, fontSize: 12.5),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.outlineVariant)),
                      child: SwitchListTile(
                        value: _pendingOnly,
                        activeThumbColor: AppColors.primary,
                        onChanged: (v) => setState(() => _pendingOnly = v),
                        title: const Text('عرض البلاغات المعلقة فقط', style: TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: const Text('أوقف الخيار لعرض عمليات الاسترداد والبلاغات السابقة أيضاً', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (visible.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 58, horizontal: 20),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.outlineVariant)),
                        child: const Column(children: [
                          Icon(Icons.task_alt_rounded, size: 44, color: AppColors.success),
                          SizedBox(height: 10),
                          Text('لا توجد بلاغات في الحالة المحددة', style: TextStyle(fontWeight: FontWeight.w800)),
                        ]),
                      )
                    else
                      ...visible.map(_requestCard),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ReviewDecision {
  final String note;
  final double? penaltyRate;

  const _ReviewDecision({required this.note, required this.penaltyRate});
}

class _RefundDecision {
  final String reference;
  final String note;

  const _RefundDecision({required this.reference, required this.note});
}
