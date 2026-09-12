import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../providers/lawyer_setup_provider.dart';

class LawyerSetupPage extends ConsumerStatefulWidget {
  const LawyerSetupPage({super.key});

  @override
  ConsumerState<LawyerSetupPage> createState() => _LawyerSetupPageState();
}

class _LawyerSetupPageState extends ConsumerState<LawyerSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _licenseController = TextEditingController();
  final _bioController = TextEditingController();
  final _experienceController = TextEditingController();
  final _priceController = TextEditingController();
  Uint8List? _idCardBytes;
  Uint8List? _profilePhotoBytes;

  @override
  void dispose() {
    _licenseController.dispose();
    _bioController.dispose();
    _experienceController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String type) async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;
    final bytes = await image.readAsBytes();
    setState(() {
      if (type == 'id') _idCardBytes = bytes;
      if (type == 'profile') _profilePhotoBytes = bytes;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_idCardBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('صورة هوية النقابة إلزامية'), backgroundColor: AppColors.error));
      return;
    }
    final user = ref.read(authStateChangesProvider).value;
    if (user == null) return;

    await ref.read(lawyerSetupControllerProvider.notifier).completeProfile(
      authUid: user.id,
      fullName: user.fullName ?? '',
      email: user.email,
      licenseNumber: _licenseController.text.trim(),
      bio: _bioController.text.trim(),
      yearsExperience: int.tryParse(_experienceController.text.trim()) ?? 0,
      consultationPrice: double.tryParse(_priceController.text.trim()) ?? 0,
      profilePhotoBytes: _profilePhotoBytes,
      idCardBytes: _idCardBytes,
    );
    if (!mounted) return;

    final result = ref.read(lawyerSetupControllerProvider);
    if (result.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إرسال الملف: ${result.error.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ البيانات وإرسال الملف للمراجعة.')),
    );
    context.go('/lawyer-pending');
  }

  InputDecoration _input(String label, {String? hint, IconData? icon}) => InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon),
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.outline)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lawyerSetupControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('إعداد الملف المهني', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
        actions: [IconButton(onPressed: () => ref.read(authControllerProvider.notifier).logout(), icon: const Icon(Icons.logout_rounded), tooltip: 'تسجيل الخروج')],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSizes.p20, 16, AppSizes.p20, 40),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(26)),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('مرحباً بك في استشارة', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                SizedBox(height: 8),
                Text('أكمل بياناتك المهنية حتى يظهر ملفك بصورة موثوقة وتتمكن من استقبال طلبات الاستشارة.', style: TextStyle(color: Colors.white, height: 1.55, fontSize: 13)),
              ]),
            ),
            const SizedBox(height: 24),
            _sectionTitle('الصورة الشخصية', 'استخدم صورة مهنية واضحة لزيادة الثقة.'),
            const SizedBox(height: 12),
            Center(child: GestureDetector(
              onTap: state.isLoading ? null : () => _pickImage('profile'),
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, border: Border.all(color: AppColors.gold, width: 2)),
                child: _profilePhotoBytes == null
                    ? const Icon(Icons.add_a_photo_outlined, size: 34, color: AppColors.textSecondary)
                    : ClipOval(child: Image.memory(_profilePhotoBytes!, fit: BoxFit.cover)),
              ),
            )),
            const SizedBox(height: 24),
            _sectionTitle('بيانات المهنة', 'هذه البيانات تستخدم للتحقق من أهليتك كمحامٍ.'),
            const SizedBox(height: 12),
            TextFormField(controller: _licenseController, enabled: !state.isLoading, decoration: _input('رقم هوية النقابة', hint: 'أدخل الرقم كما هو في الهوية', icon: Icons.badge_outlined), validator: (v) => v?.trim().isEmpty ?? true ? 'رقم هوية النقابة مطلوب' : null),
            const SizedBox(height: 14),
            TextFormField(controller: _bioController, enabled: !state.isLoading, maxLines: 5, maxLength: 1000, decoration: _input('نبذة تعريفية', hint: 'اكتب نبذة مختصرة عن خبرتك وتخصصك...', icon: Icons.description_outlined), validator: (v) => v?.trim().isEmpty ?? true ? 'النبذة التعريفية مطلوبة' : null),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: TextFormField(controller: _experienceController, enabled: !state.isLoading, decoration: _input('سنوات الخبرة', icon: Icons.workspace_premium_outlined), keyboardType: TextInputType.number, validator: (v) => v?.trim().isEmpty ?? true ? 'مطلوب' : null)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _priceController, enabled: !state.isLoading, decoration: _input('السعر (د.ع)', icon: Icons.payments_outlined), keyboardType: TextInputType.number, validator: (v) { final p = double.tryParse(v?.trim() ?? ''); return p == null || p <= 0 ? 'حدد السعر' : null; })),
            ]),
            const SizedBox(height: 24),
            _sectionTitle('وثيقة التحقق', 'صورة هوية النقابة إلزامية لإرسال الملف إلى المراجعة.'),
            const SizedBox(height: 12),
            InkWell(
              onTap: state.isLoading ? null : () => _pickImage('id'),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 170,
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: _idCardBytes == null ? AppColors.error.withValues(alpha: .45) : AppColors.gold, width: 1.5)),
                child: _idCardBytes == null
                    ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.cloud_upload_outlined, size: 40, color: AppColors.gold), SizedBox(height: 8), Text('رفع هوية النقابة'), SizedBox(height: 4), Text('اضغط لاختيار صورة واضحة', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))])
                    : ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.memory(_idCardBytes!, fit: BoxFit.cover)),
              ),
            ),
            const SizedBox(height: 28),
            state.isLoading
                ? const LoadingWidget()
                : FilledButton.icon(onPressed: _submit, icon: const Icon(Icons.verified_outlined), label: const Text('حفظ وإرسال للمراجعة', style: TextStyle(fontWeight: FontWeight.w800)), style: FilledButton.styleFrom(backgroundColor: AppColors.secondary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
          ]),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.secondary)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))]);
}
