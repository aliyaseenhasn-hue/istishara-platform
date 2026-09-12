import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../lawyers/presentation/providers/lawyer_setup_provider.dart';

class LawyerOnboardingPage extends ConsumerStatefulWidget {
  final String fullName;
  final String email;

  const LawyerOnboardingPage({super.key, required this.fullName, required this.email});

  @override
  ConsumerState<LawyerOnboardingPage> createState() => _LawyerOnboardingPageState();
}

class _LawyerOnboardingPageState extends ConsumerState<LawyerOnboardingPage> {
  Uint8List? _profilePhotoBytes;
  Uint8List? _idCardBytes;

  Future<void> _pickImage(String type) async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        if (type == 'profile') {
          _profilePhotoBytes = bytes;
        } else if (type == 'id') {
          _idCardBytes = bytes;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في اختيار الصورة: $e'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _submit() async {
    if (_profilePhotoBytes == null || _idCardBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى رفع الصورة الشخصية وصورة هوية النقابة'), backgroundColor: AppColors.error));
      return;
    }
    final authId = Supabase.instance.client.auth.currentUser?.id;
    if (authId == null) return;
    await ref.read(lawyerSetupControllerProvider.notifier).completeProfile(authUid: authId, fullName: widget.fullName, email: widget.email, profilePhotoBytes: _profilePhotoBytes, idCardBytes: _idCardBytes);
    if (mounted) _showSuccessDialog();
  }

  void _showSuccessDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('تم إرسال الطلب بنجاح', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('شكراً لانضمامك! ملفك الآن قيد المراجعة والتدقيق. ستظهر حالة الحساب في التطبيق بعد إرسال الطلب.', style: TextStyle(height: 1.55)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: FilledButton.styleFrom(backgroundColor: AppColors.secondary, foregroundColor: AppColors.onSecondary),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lawyerState = ref.watch(lawyerSetupControllerProvider);
    final isLoading = lawyerState.isLoading;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('بيانات المحامي المهنية', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppSizes.p20, 18, AppSizes.p20, 28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _buildHero(),
                const SizedBox(height: 26),
                _buildStepHeader('01', 'الصورة الشخصية', 'تظهر للعملاء في نتائج البحث والملف الشخصي.'),
                const SizedBox(height: 14),
                _buildProfilePicker(),
                const SizedBox(height: 24),
                _buildStepHeader('02', 'وثيقة التحقق', 'ارفع صورة واضحة لهوية النقابة أو المستند المطلوب للمراجعة.'),
                const SizedBox(height: 14),
                _buildIdPicker(),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(17)),
                  child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.lock_outline_rounded, size: 19, color: AppColors.primary),
                    SizedBox(width: 10),
                    Expanded(child: Text('نحافظ على سرية مستنداتك ونستخدمها لغرض التحقق من أهليتك كمحامٍ.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5))),
                  ]),
                ),
              ]),
            ),
          ),
          _buildBottomSection(isLoading),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(28)),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('الانضمام كمحامٍ', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
        SizedBox(height: 8),
        Text('أكمل بياناتك المهنية وارفع مستندات التحقق حتى نتمكن من مراجعة طلبك بأمان.', style: TextStyle(color: Colors.white, height: 1.55)),
        SizedBox(height: 18),
        Row(children: [
          Icon(Icons.verified_user_rounded, color: Colors.white, size: 19),
          SizedBox(width: 8),
          Expanded(child: Text('بياناتك تستخدم للتحقق المهني فقط.', style: TextStyle(color: Colors.white, fontSize: 12))),
        ]),
      ]),
    );
  }

  Widget _buildProfilePicker() {
    return Center(child: Stack(children: [
      Container(
        width: 126,
        height: 126,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.gold, width: 2)),
        child: CircleAvatar(radius: 58, backgroundColor: AppColors.surfaceVariant, backgroundImage: _profilePhotoBytes != null ? MemoryImage(_profilePhotoBytes!) : null, child: _profilePhotoBytes == null ? const Icon(Icons.person_outline_rounded, size: 58, color: AppColors.outline) : null),
      ),
      Positioned(
        bottom: 2,
        right: 2,
        child: Material(
          color: AppColors.secondary,
          shape: const CircleBorder(),
          child: InkWell(onTap: () => _pickImage('profile'), customBorder: const CircleBorder(), child: const Padding(padding: EdgeInsets.all(11), child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20))),
        ),
      ),
    ]));
  }

  Widget _buildIdPicker() {
    return InkWell(
      onTap: () => _pickImage('id'),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 190,
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: _idCardBytes == null ? AppColors.outline : AppColors.gold, width: _idCardBytes == null ? 1 : 2)),
        child: _idCardBytes == null
            ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                DecoratedBox(decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.all(Radius.circular(18))), child: Padding(padding: EdgeInsets.all(14), child: Icon(Icons.badge_outlined, size: 30, color: AppColors.primary))),
                SizedBox(height: 12),
                Text('اضغط لرفع صورة هوية النقابة', style: TextStyle(fontWeight: FontWeight.w800)),
                SizedBox(height: 5),
                Text('JPG أو PNG • صورة واضحة ومقروءة', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ])
            : ClipRRect(borderRadius: BorderRadius.circular(21), child: Stack(fit: StackFit.expand, children: [
                Image.memory(_idCardBytes!, fit: BoxFit.cover),
                Positioned(
                  top: 12,
                  left: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                    child: const Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_circle_rounded, color: Colors.white, size: 16), SizedBox(width: 5), Text('تم رفع المستند', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))])),
                  ),
                ),
              ])),
      ),
    );
  }

  Widget _buildStepHeader(String number, String title, String subtitle) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 36, height: 36, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(12)), child: Text(number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
      const SizedBox(width: 11),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.secondary)),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.45)),
      ])),
    ]);
  }

  Widget _buildBottomSection(bool isLoading) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSizes.p20, 14, AppSizes.p20, 18),
      decoration: BoxDecoration(color: AppColors.surface, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 18, offset: const Offset(0, -6))]),
      child: isLoading
          ? const LoadingWidget()
          : FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.send_rounded),
              label: const Text('إرسال طلب الانضمام', style: TextStyle(fontWeight: FontWeight.w800)),
              style: FilledButton.styleFrom(backgroundColor: AppColors.secondary, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
            ),
    );
  }
}
