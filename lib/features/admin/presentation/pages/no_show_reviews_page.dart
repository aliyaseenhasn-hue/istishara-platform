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
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final result = await _supabase.rpc('admin_list_no_show_reviews');
      final rows = (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (mounted) setState(() => _items = rows);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحميل مراجعات عدم الحضور. حاول مرة أخرى.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showBookingDetails(Map<String, dynamic> item) async {
    try {
      final result = await _supabase.rpc(
        'admin_get_no_show_booking_details',
        params: {'p_booking_id': item['booking_id']},
      );
      final rows = (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (!mounted) return;
      if (rows.isEmpty) throw Exception('booking_not_found');
      final booking = rows.first;
      await showDialog<void>(
        context: context,
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
            contentPadding: const EdgeInsets.fromLTRB(22, 8, 22, 10),
            title: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: AppColors.primaryFixed, borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('تفاصيل الحجز', style: TextStyle(fontWeight: FontWeight.w900))),
            ]),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _detailSection('طالب الاستشارة', Icons.person_outline, [
                    _detail('الاسم', booking['client_name']),
                    _detail('رقم الهاتف', booking['client_phone']),
                    _detail('البريد الإلكتروني', booking['client_email']),
                  ]),
                  const SizedBox(height: 12),
                  _detailSection('المحامي', Icons.gavel_outlined, [
                    _detail('الاسم', booking['lawyer_name']),
                    _detail('التخصص', booking['lawyer_specialization']),
                    _detail('رقم الهاتف', booking['lawyer_phone']),
                    _detail('البريد الإلكتروني', booking['lawyer_email']),
                  ]),
                  const SizedBox(height: 12),
                  _detailSection('بيانات الموعد', Icons.event_outlined, [
                    _detail('رقم الحجز', _shortId(booking['booking_id'])),
                    _detail('حالة الحجز', booking['status']),
                    _detail('حالة الاستشارة', booking['consultation_status']),
                    _detail('تاريخ ووقت الموعد', _formatDate(booking['scheduled_at'])),
                    _detail('نوع الاستشارة', booking['consultation_type']),
                    _detail('طريقة الاستشارة', booking['consultation_mode']),
                    _detail('المبلغ', booking['price']),
                    _detail('حالة الدفع', booking['payment_status']),
                  ]),
                  const SizedBox(height: 12),
                  _detailSection('بلاغ عدم الحضور', Icons.person_off_outlined, [
                    _detail('السبب', booking['report_reason'] ?? item['reason']),
                    _detail('تاريخ البلاغ', _formatDate(booking['report_created_at'] ?? item['created_at'])),
                  ], warning: true),
                ]),
              ),
            ),
            actions: [
              FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check_rounded),
                label: const Text('إغلاق'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحميل تفاصيل الحجز.')),
        );
      }
    }
  }

  Widget _detailSection(String title, IconData icon, List<Widget> children, {bool warning = false}) {
    final accent = warning ? AppColors.warning : AppColors.primary;
    final background = warning ? AppColors.pendingBg : AppColors.surfaceContainerLow;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: warning ? AppColors.goldSoftStrong : AppColors.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: accent)),
        ]),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }

  Widget _detail(String label, dynamic value) {
    final text = value?.toString().trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 108, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
        const SizedBox(width: 8),
        Expanded(child: Text(text == null || text.isEmpty ? 'غير متوفر' : text, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
      ]),
    );
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

  Future<void> _review(Map<String, dynamic> item, String decision) async {
    final approved = decision == 'approved';
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Icon(approved ? Icons.check_circle_outline_rounded : Icons.cancel_outlined, color: approved ? AppColors.success : AppColors.error),
            const SizedBox(width: 8),
            Expanded(child: Text(approved ? 'تأكيد الموافقة على البلاغ' : 'رفض بلاغ عدم الحضور', style: const TextStyle(fontWeight: FontWeight.w900))),
          ]),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'ملاحظة الإدارة (اختياري)', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              icon: Icon(approved ? Icons.check_rounded : Icons.close_rounded),
              label: Text(approved ? 'اعتماد الموافقة' : 'اعتماد الرفض'),
              style: FilledButton.styleFrom(
                backgroundColor: approved ? AppColors.success : AppColors.error,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (note == null) return;
    try {
      await _supabase.rpc(
        'admin_review_no_show_request',
        params: {'p_request_id': item['id'], 'p_decision': decision, 'p_note': note.isEmpty ? null : note},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approved ? 'تمت الموافقة على البلاغ' : 'تم رفض البلاغ')),
        );
      }
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ القرار. حاول مرة أخرى.')),
        );
      }
    }
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
        return status?.toString() ?? 'غير محدد';
    }
  }

  Widget _statusBadge(dynamic status) {
    final value = status?.toString();
    Color background;
    Color foreground;
    IconData icon;
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
        Icon(icon, size: 16, color: foreground),
        const SizedBox(width: 5),
        Text(_statusLabel(status), style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _pendingOnly ? _items.where((e) => e['status'] == 'pending').toList() : _items;
    final pendingCount = _items.where((e) => e['status'] == 'pending').length;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('مراجعة عدم الحضور'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
          actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث')],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.primaryDark, AppColors.primary], begin: Alignment.topRight, end: Alignment.bottomLeft),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.person_off_outlined, color: Colors.white, size: 27),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('بلاغات عدم الحضور', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                            const SizedBox(height: 4),
                            Text('${_items.length} طلباً إجمالاً • $pendingCount بانتظار القرار', style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
                          ]),
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
                        title: const Text('عرض الطلبات المعلقة فقط', style: TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: const Text('أخفِ الطلبات التي تم اتخاذ قرار بشأنها', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                          Text('لا توجد طلبات في الحالة المحددة', style: TextStyle(fontWeight: FontWeight.w800)),
                        ]),
                      )
                    else
                      ...visible.map((item) {
                        final pending = item['status'] == 'pending';
                        final reason = item['reason']?.toString().trim();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: pending ? AppColors.goldSoftStrong : AppColors.outlineVariant),
                            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .045), blurRadius: 14, offset: const Offset(0, 5))],
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(color: pending ? AppColors.pendingBg : AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(14)),
                                child: Icon(Icons.person_off_outlined, color: pending ? AppColors.pendingText : AppColors.primary),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Text('بلاغ عدم حضور', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                                  const SizedBox(height: 3),
                                  Text('الحجز ${_shortId(item['booking_id'])}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                ]),
                              ),
                              _statusBadge(item['status']),
                            ]),
                            const SizedBox(height: 13),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(14)),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                Row(children: [
                                  const Icon(Icons.report_problem_outlined, size: 18, color: AppColors.warning),
                                  const SizedBox(width: 7),
                                  Expanded(child: Text(reason == null || reason.isEmpty ? 'سبب البلاغ غير محدد' : reason, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                                ]),
                                if (item['created_at'] != null) ...[
                                  const SizedBox(height: 9),
                                  Row(children: [
                                    const Icon(Icons.schedule_rounded, size: 17, color: AppColors.textSecondary),
                                    const SizedBox(width: 7),
                                    Text(_formatDate(item['created_at']), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                                  ]),
                                ],
                                if (item['review_note'] != null && item['review_note'].toString().trim().isNotEmpty) ...[
                                  const SizedBox(height: 9),
                                  Text('ملاحظة الإدارة: ${item['review_note']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5)),
                                ],
                              ]),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () => _showBookingDetails(item),
                              icon: const Icon(Icons.visibility_outlined, size: 20),
                              label: const Text('عرض تفاصيل الحجز', style: TextStyle(fontWeight: FontWeight.w900)),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                            if (pending) ...[
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _review(item, 'rejected'),
                                    icon: const Icon(Icons.close_rounded, size: 19),
                                    label: const Text('رفض البلاغ', style: TextStyle(fontWeight: FontWeight.w800)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                      side: const BorderSide(color: AppColors.error),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => _review(item, 'approved'),
                                    icon: const Icon(Icons.check_rounded, size: 19),
                                    label: const Text('قبول البلاغ', style: TextStyle(fontWeight: FontWeight.w800)),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.success,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                  ),
                                ),
                              ]),
                            ],
                          ]),
                        );
                      }),
                  ],
                ),
              ),
      ),
    );
  }
}
