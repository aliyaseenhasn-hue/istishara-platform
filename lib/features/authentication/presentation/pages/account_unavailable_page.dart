import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/supabase_config.dart';

class AccountUnavailablePage extends StatefulWidget {
  const AccountUnavailablePage({super.key});

  @override
  State<AccountUnavailablePage> createState() => _AccountUnavailablePageState();
}

class _AccountUnavailablePageState extends State<AccountUnavailablePage> {
  late final Future<Map<String, dynamic>> _details = _loadDetails();

  Future<Map<String, dynamic>> _loadDetails() async {
    final authUser = SupabaseConfig.client.auth.currentUser;
    if (authUser == null) return const {'status': 'signed_out'};

    final profile = await SupabaseConfig.client
        .from('profiles')
        .select('id,status')
        .eq('auth_id', authUser.id)
        .maybeSingle();

    if (profile == null) return const {'status': 'unknown'};

    Map<String, dynamic>? latest;
    try {
      latest = await SupabaseConfig.client
          .from('account_status_audit')
          .select('new_status,reason,changed_at')
          .eq('user_id', profile['id'])
          .order('changed_at', ascending: false)
          .limit(1)
          .maybeSingle();
    } catch (_) {}

    return {
      'status': profile['status']?.toString() ?? 'unknown',
      'reason': latest?['reason']?.toString(),
      'changed_at': latest?['changed_at'],
    };
  }

  String _statusTitle(String status) => switch (status) {
        'blocked' => 'الحساب موقوف مؤقتاً',
        'pending' => 'الحساب قيد المراجعة',
        'deleted' => 'الحساب غير متاح',
        _ => 'الحساب غير فعال',
      };

  String _statusMessage(String status) => switch (status) {
        'blocked' => 'تم إيقاف استخدام خدمات المنصة لهذا الحساب حتى تتم إعادة تفعيله من الإدارة.',
        'pending' => 'لا يمكن استخدام خدمات المنصة قبل اكتمال مراجعة حالة الحساب.',
        'deleted' => 'هذا الحساب غير متاح للاستخدام حالياً.',
        _ => 'لا يمكن تنفيذ عمليات على هذا الحساب في حالته الحالية.',
      };

  String? _formatDate(dynamic value) {
    final parsed = DateTime.tryParse('${value ?? ''}')?.toLocal();
    if (parsed == null) return null;
    return '${parsed.year}/${parsed.month.toString().padLeft(2, '0')}/${parsed.day.toString().padLeft(2, '0')} '
        '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _signOut() async {
    await SupabaseConfig.client.auth.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: FutureBuilder<Map<String, dynamic>>(
                future: _details,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data = snapshot.data ?? const <String, dynamic>{};
                  final status = data['status']?.toString() ?? 'unknown';
                  final reason = data['reason']?.toString().trim();
                  final changedAt = _formatDate(data['changed_at']);

                  return Card(
                    elevation: 0,
                    color: scheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            Icons.lock_person_outlined,
                            size: 54,
                            color: scheme.error,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _statusTitle(status),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _statusMessage(status),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              height: 1.6,
                            ),
                          ),
                          if (reason != null && reason.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: scheme.errorContainer,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                'السبب: $reason',
                                style: TextStyle(
                                  color: scheme.onErrorContainer,
                                  fontWeight: FontWeight.w700,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                          if (changedAt != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              'آخر تحديث للحالة: $changedAt',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          OutlinedButton.icon(
                            onPressed: _signOut,
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('تسجيل الخروج'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
