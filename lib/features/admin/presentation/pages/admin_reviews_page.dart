import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:astshara/core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';

class AdminReviewsPage extends StatefulWidget {
  const AdminReviewsPage({super.key});

  @override
  State<AdminReviewsPage> createState() => _AdminReviewsPageState();
}

class _AdminReviewsPageState extends State<AdminReviewsPage> {
  late Future<Map<String, int>> _future;

  @override
  void initState() {
    super.initState();
    _future = _counts();
  }

  Future<Map<String, int>> _counts() async {
    final c = SupabaseConfig.client;
    final results = await Future.wait([
      c.from('lawyer_profiles').select('id').eq('verified', false),
      c.from('cancellation_requests').select('id').eq('status', 'بانتظار مراجعة الإدارة'),
      c.from('specialization_change_requests').select('id').eq('status', 'pending'),
      c.from('payments').select('id').eq('status', 'قيد معالجة الدفع').eq('payment_method', 'bank_transfer'),
      c.rpc('admin_list_no_show_reviews'),
    ]);
    final noShowRows = List<Map<String, dynamic>>.from(results[4] as List);
    return {
      'verifications': (results[0] as List).length,
      'cancellations': (results[1] as List).length,
      'specializations': (results[2] as List).length,
      'payments': (results[3] as List).length,
      'noShow': noShowRows.where((row) => row['status'] == 'pending').length,
    };
  }

  void _refresh() => setState(() => _future = _counts());

  void _openSection(BuildContext context, String route) {
    context.push(route).then((_) {
      if (mounted) _refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('مركز المراجعات'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث')],
      ),
      body: FutureBuilder<Map<String, int>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  const Text('تعذر تحميل المراجعات', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  FilledButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
                ]),
              ),
            );
          }

          final counts = snapshot.data ?? const <String, int>{};
          final items = <({String title, String subtitle, IconData icon, int count, String route, Color accent})>[
            (title: 'توثيق المحامين', subtitle: 'مراجعة بيانات ووثائق المحامين واعتمادها', icon: Icons.verified_user_outlined, count: counts['verifications'] ?? 0, route: '/admin/lawyer-verifications', accent: AppColors.primary),
            (title: 'طلبات إلغاء الحجوزات', subtitle: 'مراجعة الإلغاء والغرامات والتعويضات', icon: Icons.event_busy_outlined, count: counts['cancellations'] ?? 0, route: '/admin/cancellation-requests', accent: AppColors.warning),
            (title: 'تغيير التخصص', subtitle: 'مراجعة طلبات تغيير التخصص والوثائق المرفقة', icon: Icons.badge_outlined, count: counts['specializations'] ?? 0, route: '/admin/specialization-change-requests', accent: AppColors.secondaryDark),
            (title: 'مراجعة الدفعات', subtitle: 'التحقق من إيصالات التحويل اليدوي قبل اعتماد المبلغ', icon: Icons.payments_outlined, count: counts['payments'] ?? 0, route: '/admin/payments', accent: AppColors.teal),
            (title: 'عدم الحضور', subtitle: 'فحص بلاغات عدم الحضور واتخاذ القرار الإداري', icon: Icons.person_off_outlined, count: counts['noShow'] ?? 0, route: '/admin/no-show-reviews', accent: AppColors.error),
          ];
          final totalPending = items.fold<int>(0, (sum, item) => sum + item.count);

          return RefreshIndicator(
            onRefresh: () async {
              _refresh();
              await _future;
            },
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
                      child: const Icon(Icons.fact_check_outlined, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('المهام التي تحتاج قراراً', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(totalPending > 0 ? '$totalPending طلباً بانتظار المراجعة' : 'لا توجد طلبات معلقة حالياً', style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(999)),
                      child: Text('$totalPending', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                    ),
                  ]),
                ),
                const SizedBox(height: 18),
                const Text('أقسام المراجعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                ...items.map((item) => _ReviewCard(item: item, onTap: () => _openSection(context, item.route))),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ({String title, String subtitle, IconData icon, int count, String route, Color accent}) item;
  final VoidCallback onTap;

  const _ReviewCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final needsAction = item.count > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: needsAction ? item.accent.withValues(alpha: .32) : AppColors.outlineVariant),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .035), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: item.accent.withValues(alpha: .10), borderRadius: BorderRadius.circular(15)),
              child: Icon(item.icon, color: item.accent, size: 25),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(item.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.45)),
              ]),
            ),
            const SizedBox(width: 8),
            if (needsAction)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: item.accent.withValues(alpha: .10), borderRadius: BorderRadius.circular(999)),
                child: Text('${item.count}', style: TextStyle(color: item.accent, fontWeight: FontWeight.w900)),
              ),
            const SizedBox(width: 7),
            const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
          ]),
        ),
      ),
    );
  }
}
