import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';

final adminUserDetailProvider = FutureProvider.family
    .autoDispose<Map<String, dynamic>, String>((ref, userId) async {
  final result = await Supabase.instance.client.rpc(
    'admin_get_user_detail',
    params: {'p_user_id': userId},
  );
  if (result is! Map) {
    throw StateError('تعذر تحميل ملف المستخدم');
  }
  return Map<String, dynamic>.from(result);
});

class AdminUserDetailsPage extends ConsumerStatefulWidget {
  final String userId;

  const AdminUserDetailsPage({super.key, required this.userId});

  @override
  ConsumerState<AdminUserDetailsPage> createState() =>
      _AdminUserDetailsPageState();
}

class _AdminUserDetailsPageState
    extends ConsumerState<AdminUserDetailsPage> {
  bool actionLoading = false;

  Future<void> _refresh() async {
    ref.invalidate(adminUserDetailProvider(widget.userId));
    await ref.read(adminUserDetailProvider(widget.userId).future);
  }

  Future<void> _changeStatus(Map<String, dynamic> profile) async {
    if (actionLoading) return;
    final currentStatus = profile['status']?.toString() ?? '';
    final name = _value(profile['full_name'], fallback: 'المستخدم');
    if (currentStatus != 'active' && currentStatus != 'blocked') return;

    String? reason;
    if (currentStatus == 'active') {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('إيقاف الحساب'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('سيتم إيقاف حساب $name ومنعه من تنفيذ العمليات داخل المنصة.'),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'سبب الإيقاف',
                  hintText: 'سبب واضح يظهر للمستخدم',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('تراجع'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) return;
                Navigator.pop(dialogContext, value);
              },
              child: const Text('تأكيد الإيقاف'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (reason == null) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('إعادة تفعيل الحساب'),
          content: Text('هل تريد إعادة تفعيل حساب $name؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('تراجع'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('إعادة التفعيل'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      setState(() => actionLoading = true);
      await Supabase.instance.client.rpc(
        'admin_set_user_status',
        params: {
          'p_user_id': widget.userId,
          'p_new_status': currentStatus == 'active' ? 'blocked' : 'active',
          'p_reason': reason,
        },
      );
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentStatus == 'active'
                  ? 'تم إيقاف حساب $name.'
                  : 'تمت إعادة تفعيل حساب $name.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث الحساب: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(adminUserDetailProvider(widget.userId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('ملف المستخدم'),
        actions: [
          IconButton(
            onPressed: actionLoading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text(
                  'تعذر تحميل ملف المستخدم\n$error',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
        data: _buildDetail,
      ),
    );
  }

  Widget _buildDetail(Map<String, dynamic> data) {
    final profile = _map(data['profile']);
    final lawyer = _nullableMap(data['lawyer']);
    final wallet = _nullableMap(data['lawyer_wallet']);
    final bookingSummary = _map(data['booking_summary']);
    final paymentSummary = _map(data['payment_summary']);
    final bookings = _list(data['recent_bookings']);
    final payments = _list(data['recent_payments']);
    final payouts = _list(data['recent_payouts']);
    final role = profile['role']?.toString() ?? '';
    final status = profile['status']?.toString() ?? '';
    final canManage = (role == 'user' || role == 'lawyer') &&
        (status == 'active' || status == 'blocked');

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
        children: [
          _identityCard(profile),
          const SizedBox(height: 16),
          _section(
            title: 'بيانات الحساب',
            icon: Icons.badge_outlined,
            children: [
              _info('نوع الحساب', _roleLabel(role)),
              _info('حالة الحساب', _statusLabel(status)),
              _info('رقم الهاتف', _value(profile['phone'])),
              _info('واتساب', _value(profile['whatsapp_number'])),
              _info('البريد الإلكتروني', _value(profile['email'])),
              _info('المدينة', _value(profile['city'])),
              _info(
                'اكتمال التسجيل',
                profile['onboarding_completed'] == true ? 'مكتمل' : 'غير مكتمل',
              ),
              _info('تاريخ التسجيل', _date(profile['created_at'])),
              _info('آخر تحديث', _date(profile['updated_at'])),
            ],
          ),
          const SizedBox(height: 14),
          _summarySection(bookingSummary, paymentSummary),
          if (role == 'lawyer') ...[
            const SizedBox(height: 14),
            _lawyerSection(lawyer),
            const SizedBox(height: 14),
            _lawyerFinanceSection(wallet, payouts),
          ] else ...[
            const SizedBox(height: 14),
            _section(
              title: 'بيانات الاسترداد / المحفظة',
              icon: Icons.account_balance_wallet_outlined,
              children: [
                _info('نوع المحفظة', _value(profile['wallet_type'])),
                _info('رقم المحفظة', _value(profile['wallet_number'])),
                _info('اسم صاحب المحفظة', _value(profile['wallet_holder_name'])),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _recentBookingsSection(bookings),
          const SizedBox(height: 14),
          _recentPaymentsSection(payments),
          if (canManage) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: actionLoading ? null : () => _changeStatus(profile),
              icon: actionLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      status == 'active'
                          ? Icons.block_rounded
                          : Icons.check_circle_outline_rounded,
                    ),
              label: Text(
                status == 'active' ? 'إيقاف هذا الحساب' : 'إعادة تفعيل الحساب',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    status == 'active' ? AppColors.error : AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _identityCard(Map<String, dynamic> profile) {
    final name = _value(profile['full_name'], fallback: 'بدون اسم');
    final role = profile['role']?.toString() ?? '';
    final status = profile['status']?.toString() ?? '';
    final avatar = profile['avatar_url']?.toString().trim() ?? '';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 31,
            backgroundColor: AppColors.goldLight,
            foregroundImage: avatar.startsWith('http') ? NetworkImage(avatar) : null,
            child: avatar.startsWith('http')
                ? null
                : Text(
                    name.characters.first,
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_roleLabel(role)} • ${_statusLabel(status)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            role == 'lawyer' ? Icons.gavel_rounded : Icons.person_outline_rounded,
            color: AppColors.goldLight,
            size: 30,
          ),
        ],
      ),
    );
  }

  Widget _summarySection(
    Map<String, dynamic> bookings,
    Map<String, dynamic> payments,
  ) {
    return _section(
      title: 'النشاط على المنصة',
      icon: Icons.analytics_outlined,
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.75,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _stat('إجمالي الحجوزات', '${bookings['total'] ?? 0}', AppColors.primary),
            _stat('الحجوزات النشطة', '${bookings['active'] ?? 0}', AppColors.success),
            _stat('المكتملة', '${bookings['completed'] ?? 0}', AppColors.teal),
            _stat('الملغاة', '${bookings['cancelled'] ?? 0}', AppColors.error),
          ],
        ),
        const SizedBox(height: 12),
        _info('عدد عمليات الدفع', '${payments['total_count'] ?? 0}'),
        _info('عمليات دفع مؤكدة', '${payments['paid_count'] ?? 0}'),
        _info('بانتظار المراجعة/الدفع', '${payments['pending_count'] ?? 0}'),
        _info('إجمالي المدفوع المؤكد', _money(payments['paid_total'])),
      ],
    );
  }

  Widget _lawyerSection(Map<String, dynamic>? lawyer) {
    if (lawyer == null) {
      return _section(
        title: 'الملف المهني',
        icon: Icons.gavel_rounded,
        children: const [Text('لم تكتمل بيانات الملف المهني لهذا المحامي.')],
      );
    }
    final specs = (lawyer['specialization'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    return _section(
      title: 'الملف المهني للمحامي',
      icon: Icons.gavel_rounded,
      children: [
        _info('رقم إجازة المحاماة', _value(lawyer['license_number'])),
        _info('صنف الإجازة', _value(lawyer['practice_license_class'])),
        _info('التخصص الرئيسي', _value(lawyer['primary_specialization'])),
        _info('التخصصات', specs.isEmpty ? '—' : specs.join('، ')),
        _info('سنوات الخبرة', '${lawyer['years_experience'] ?? 0}'),
        _info('سعر الاستشارة', _money(lawyer['consultation_price'])),
        _info('التقييم', '${lawyer['rating'] ?? 0} / 5'),
        _info('عدد التقييمات', '${lawyer['review_count'] ?? 0}'),
        _info('الاستشارات المكتملة', '${lawyer['completed_consultations'] ?? 0}'),
        _info(
          'حالة التوثيق',
          _verificationLabel(lawyer['verification_status']?.toString()),
        ),
        if ((lawyer['rejection_reason']?.toString().trim().isNotEmpty ?? false))
          _info('سبب الرفض', lawyer['rejection_reason'].toString()),
        if ((lawyer['bio']?.toString().trim().isNotEmpty ?? false)) ...[
          const Divider(height: 22),
          const Text('نبذة مهنية', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(lawyer['bio'].toString(), style: const TextStyle(height: 1.5)),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: () => context.push('/admin/lawyer-verifications'),
            icon: const Icon(Icons.verified_user_outlined),
            label: const Text('فتح إدارة توثيق المحامين'),
          ),
        ),
      ],
    );
  }

  Widget _lawyerFinanceSection(
    Map<String, dynamic>? wallet,
    List<Map<String, dynamic>> payouts,
  ) {
    return _section(
      title: 'المستحقات والسحوبات',
      icon: Icons.account_balance_wallet_outlined,
      children: [
        _info('الرصيد المتاح', _money(wallet?['available_balance'])),
        _info('الرصيد المعلّق', _money(wallet?['pending_balance'])),
        _info('إجمالي الأرباح', _money(wallet?['lifetime_earned'])),
        _info('إجمالي المسحوب', _money(wallet?['lifetime_paid_out'])),
        if (payouts.isNotEmpty) ...[
          const Divider(height: 22),
          const Text('آخر طلبات السحب', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ...payouts.take(5).map(
                (p) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.payments_outlined),
                  title: Text(_money(p['amount'])),
                  subtitle: Text('${_value(p['status'])} • ${_date(p['created_at'])}'),
                ),
              ),
        ],
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: () => context.push('/admin/financial'),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('فتح الإدارة المالية'),
          ),
        ),
      ],
    );
  }

  Widget _recentBookingsSection(List<Map<String, dynamic>> items) {
    return _section(
      title: 'آخر الحجوزات',
      icon: Icons.calendar_month_outlined,
      children: items.isEmpty
          ? const [Text('لا توجد حجوزات مسجلة.')]
          : items
              .map(
                (b) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_note_outlined),
                  title: Text(_value(b['other_party_name'])),
                  subtitle: Text(
                    '${_value(b['status'])} • ${_date(b['scheduled_at'] ?? b['created_at'])}',
                  ),
                  trailing: Text(
                    _money(b['price']),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              )
              .toList(),
    );
  }

  Widget _recentPaymentsSection(List<Map<String, dynamic>> items) {
    return _section(
      title: 'آخر عمليات الدفع',
      icon: Icons.receipt_long_outlined,
      children: items.isEmpty
          ? const [Text('لا توجد عمليات دفع مسجلة.')]
          : items
              .map(
                (p) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    p['status'] == 'تم الدفع'
                        ? Icons.check_circle_outline_rounded
                        : Icons.schedule_rounded,
                    color: p['status'] == 'تم الدفع'
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                  title: Text(_money(p['amount'])),
                  subtitle: Text(
                    '${_value(p['status'])} • ${_value(p['payment_method'])} • ${_date(p['created_at'])}',
                  ),
                ),
              )
              .toList(),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  Map<String, dynamic>? _nullableMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  List<Map<String, dynamic>> _list(dynamic value) => value is List
      ? value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false)
      : const <Map<String, dynamic>>[];

  String _value(dynamic value, {String fallback = '—'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return '—';
    return DateFormat('yyyy/MM/dd - HH:mm', 'ar').format(parsed.toLocal());
  }

  String _money(dynamic value) {
    final amount = num.tryParse(value?.toString() ?? '') ?? 0;
    return '${NumberFormat.decimalPattern('ar').format(amount)} د.ع';
  }

  String _roleLabel(String value) => {
        'user': 'طالب استشارة',
        'client': 'طالب استشارة',
        'lawyer': 'محامي',
        'admin': 'إدارة',
        'moderator': 'مشرف',
      }[value] ??
      value;

  String _statusLabel(String value) => {
        'active': 'فعال',
        'blocked': 'موقوف',
        'pending': 'قيد الانتظار',
        'deleted': 'محذوف',
      }[value] ??
      value;

  String _verificationLabel(String? value) => {
        'pending': 'بانتظار المراجعة',
        'approved': 'موثق',
        'rejected': 'مرفوض',
      }[value] ??
      (value?.trim().isNotEmpty == true ? value! : 'غير محدد');
}
