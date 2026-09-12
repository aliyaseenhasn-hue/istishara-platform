import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../providers/lawyer_verification_provider.dart';

class LawyerVerificationPage extends ConsumerWidget {
  const LawyerVerificationPage({super.key});

  void _showImageDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('صورة الهوية'),
              leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ),
            Flexible(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('تعذر عرض الوثيقة.'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref, String profileId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد توثيق المحامي'),
        content: Text('هل راجعت وثائق $name وتريد تفعيل حسابه كمحامٍ موثّق؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('رجوع')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.verified_rounded),
            label: const Text('تأكيد التوثيق'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(lawyerVerificationProvider.notifier).approveLawyer(profileId);
    if (!context.mounted) return;
    final result = ref.read(lawyerVerificationProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.hasError
            ? 'تعذر توثيق الحساب: ${result.error.toString().replaceFirst('Exception: ', '')}'
            : 'تم توثيق حساب $name بنجاح.'),
        backgroundColor: result.hasError ? AppColors.error : AppColors.success,
      ),
    );
  }

  Future<void> _reject(BuildContext context, WidgetRef ref, String profileId, String name) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إعادة الطلب للتعديل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('لن يُحذف حساب $name. سيظهر له سبب الرفض ويمكنه تعديل الملف وإعادة إرساله.'),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'سبب الرفض أو المطلوب تعديله',
                hintText: 'مثال: صورة هوية النقابة غير واضحة',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          FilledButton.icon(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('اكتب سبب الرفض حتى يعرف المحامي ما المطلوب تعديله.')),
                );
                return;
              }
              Navigator.pop(dialogContext, value);
            },
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('إرسال للتعديل'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !context.mounted) return;

    await ref.read(lawyerVerificationProvider.notifier).rejectLawyer(profileId, reason: reason);
    if (!context.mounted) return;
    final result = ref.read(lawyerVerificationProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.hasError
            ? 'تعذر حفظ قرار الرفض: ${result.error.toString().replaceFirst('Exception: ', '')}'
            : 'تم إرجاع طلب $name للتعديل دون حذف ملفه.'),
        backgroundColor: result.hasError ? AppColors.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingLawyersAsync = ref.watch(lawyerVerificationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات توثيق المحامين'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: pendingLawyersAsync.isLoading ? null : () => ref.invalidate(lawyerVerificationProvider),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: pendingLawyersAsync.when(
        data: (lawyers) => lawyers.isEmpty
            ? const Center(child: Text('لا توجد طلبات معلقة حالياً'))
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(lawyerVerificationProvider);
                  await ref.read(lawyerVerificationProvider.future);
                },
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSizes.p20),
                  itemCount: lawyers.length,
                  itemBuilder: (context, index) {
                    final lawyer = lawyers[index];
                    final name = lawyer.fullName?.trim().isNotEmpty == true ? lawyer.fullName!.trim() : 'المحامي';
                    final specializationText = lawyer.specializations.isEmpty ? 'غير محدد' : lawyer.specializations.join('، ');
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(backgroundColor: AppColors.surfaceVariant, child: Icon(Icons.person, color: AppColors.primary)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text('رقم الإجازة: ${lawyer.licenseNumber ?? 'غير متوفر'}', style: const TextStyle(color: AppColors.outline, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Text('الصلاحية: ${lawyer.practiceLicenseClass ?? 'غير محددة'}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('التخصص: $specializationText', style: const TextStyle(fontSize: 14)),
                            const SizedBox(height: 4),
                            Text('الخبرة: ${lawyer.yearsExperience ?? 0} سنوات', style: const TextStyle(fontSize: 14)),
                            const SizedBox(height: 4),
                            Text('السعر: ${lawyer.consultationPrice ?? 0} د.ع', style: const TextStyle(fontSize: 14)),
                            const SizedBox(height: 8),
                            Text('النبذة: ${lawyer.bio ?? 'غير متوفرة'}', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            const SizedBox(height: 16),
                            const Text('الوثائق المرفوعة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 8),
                            if (lawyer.idCardUrl != null && lawyer.idCardUrl!.isNotEmpty)
                              InkWell(
                                onTap: () => _showImageDialog(context, lawyer.idCardUrl!),
                                child: Container(
                                  height: 120,
                                  width: double.infinity,
                                  decoration: BoxDecoration(border: Border.all(color: AppColors.surfaceVariant), borderRadius: BorderRadius.circular(8)),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(lawyer.idCardUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
                                  ),
                                ),
                              )
                            else
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(color: AppColors.cancelledBg, borderRadius: BorderRadius.circular(10)),
                                child: const Text('لا توجد وثيقة تحقق قابلة للمراجعة.', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                              ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: lawyer.idCardUrl == null || lawyer.idCardUrl!.isEmpty ? null : () => _approve(context, ref, lawyer.profileId, name),
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                                    child: const Text('موافقة وتوثيق'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _reject(context, ref, lawyer.profileId, name),
                                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                                    child: const Text('إرسال للتعديل'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
        loading: () => const LoadingWidget(),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('تعذر تحميل طلبات التوثيق: $err', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => ref.invalidate(lawyerVerificationProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
