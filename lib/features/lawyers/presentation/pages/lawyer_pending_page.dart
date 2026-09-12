import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';

class LawyerPendingPage extends ConsumerWidget {
  const LawyerPendingPage({super.key});

  Future<Map<String, dynamic>?> _verificationState() async {
    final authUser = SupabaseConfig.client.auth.currentUser;
    if (authUser == null) return null;
    final profile = await SupabaseConfig.client
        .from('profiles')
        .select('id')
        .eq('auth_id', authUser.id)
        .maybeSingle();
    final profileId = profile?['id']?.toString();
    if (profileId == null) return null;
    return SupabaseConfig.client
        .from('lawyer_profiles')
        .select('verification_status,rejection_reason')
        .eq('profile_id', profileId)
        .maybeSingle();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.read(authControllerProvider.notifier);
    return FutureBuilder<Map<String, dynamic>?>(
      future: _verificationState(),
      builder: (context, snapshot) {
        final status = snapshot.data?['verification_status']?.toString() ?? 'pending';
        final rejected = status == 'rejected';
        final reason = snapshot.data?['rejection_reason']?.toString().trim();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(rejected ? 'تحديث طلب التوثيق' : 'حالة الحساب', style: const TextStyle(fontWeight: FontWeight.w800)),
            centerTitle: true,
            actions: [
              IconButton(onPressed: auth.logout, icon: const Icon(Icons.logout_rounded), tooltip: 'تسجيل الخروج'),
            ],
          ),
          body: snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(AppSizes.p20, 18, AppSizes.p20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: rejected ? AppColors.error : AppColors.secondary,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: (rejected ? AppColors.error : AppColors.secondary).withValues(alpha: .14),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 82,
                                height: 82,
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: .14),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.gold.withValues(alpha: .35)),
                                ),
                                child: Icon(rejected ? Icons.edit_document : Icons.verified_user_rounded, size: 40, color: AppColors.gold),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                rejected ? 'يحتاج طلبك إلى تعديل' : 'حسابك قيد المراجعة',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                rejected
                                    ? (reason?.isNotEmpty == true ? reason! : 'راجع بياناتك ووثائقك المهنية ثم أعد إرسال الطلب للمراجعة.')
                                    : 'وصلت معلوماتك بنجاح. يقوم فريقنا الآن بمراجعة بيانات المحامي قبل تفعيل الحساب.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.6),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        if (rejected) ...[
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.outline),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 22),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'لن تحتاج إلى إنشاء حساب جديد. عدّل الملف المهني وارفع الوثيقة الصحيحة، ثم سيعود الطلب تلقائياً إلى قائمة المراجعة.',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: () => context.go('/lawyer-setup'),
                            icon: const Icon(Icons.edit_note_rounded),
                            label: const Text('تعديل البيانات وإعادة الإرسال', style: TextStyle(fontWeight: FontWeight.w800)),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ] else ...[
                          const Text('ماذا يحدث الآن؟', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.secondary)),
                          const SizedBox(height: 12),
                          const _StatusStep(icon: Icons.check_circle_rounded, title: 'تم استلام الطلب', subtitle: 'تم حفظ بياناتك بنجاح.', active: true),
                          const _StatusStep(icon: Icons.manage_search_rounded, title: 'مراجعة المعلومات', subtitle: 'يتم التحقق من بياناتك ووثائقك.', active: true),
                          const _StatusStep(icon: Icons.verified_rounded, title: 'تفعيل الحساب', subtitle: 'ستتمكن من استقبال الاستشارات بعد الموافقة.', active: false, last: true),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.outline)),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 22),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'لا تحتاج إلى إعادة التسجيل. عند اكتمال المراجعة ستتغير حالة حسابك تلقائيًا.',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: auth.logout,
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.w800)),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _StatusStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final bool last;

  const _StatusStep({required this.icon, required this.title, required this.subtitle, required this.active, this.last = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 34,
          child: Column(
            children: [
              Icon(icon, size: 27, color: active ? AppColors.primary : AppColors.outline),
              if (!last) Container(width: 2, height: 48, margin: const EdgeInsets.symmetric(vertical: 4), color: AppColors.outline),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: active ? AppColors.secondary : AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.outline, height: 1.4)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
