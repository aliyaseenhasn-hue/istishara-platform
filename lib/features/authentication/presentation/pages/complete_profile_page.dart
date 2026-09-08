import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/legal_specializations.dart';
import '../../../../shared/providers/global_loading_provider.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../lawyers/presentation/providers/lawyer_setup_provider.dart';
import '../providers/auth_provider.dart';

class CompleteProfilePage extends ConsumerStatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  ConsumerState<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends ConsumerState<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final List<String> _selectedSpecializations = [];
  final List<String> _specializations = LegalSpecializations.all;

  String _selectedRole = 'user';
  Uint8List? _profilePhotoBytes;
  Uint8List? _idCardBytes;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _nameController.text = user.userMetadata?['full_name'] ?? user.userMetadata?['name'] ?? '';
      _emailController.text = user.email ?? '';
    }
    _initialized = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String type) async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        if (type == 'profile') _profilePhotoBytes = bytes;
        if (type == 'id') _idCardBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر اختيار الصورة: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final authId = Supabase.instance.client.auth.currentUser?.id;
    if (authId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر الحصول على معرف المستخدم'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (_selectedRole == 'lawyer') {
      if (_profilePhotoBytes == null || _idCardBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى رفع الصورة الشخصية وصورة الهوية'), backgroundColor: AppColors.error),
        );
        return;
      }
      if (_selectedSpecializations.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى اختيار تخصص واحد على الأقل'), backgroundColor: AppColors.error),
        );
        return;
      }

      await ref.read(lawyerSetupControllerProvider.notifier).completeProfile(
        authUid: authId,
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        specializations: _selectedSpecializations,
        profilePhotoBytes: _profilePhotoBytes,
        idCardBytes: _idCardBytes,
      );
      if (!mounted) return;
      final state = ref.read(lawyerSetupControllerProvider);
      if (state.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء الحفظ: ${state.error}'), backgroundColor: AppColors.error),
        );
      } else {
        _showSuccessDialog();
      }
      return;
    }

    await ref.read(authControllerProvider.notifier).updateInitialProfile(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      role: _selectedRole,
    );
    if (mounted) context.go('/');
  }

  void _showSuccessDialog() {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('تم إرسال الطلب'),
        content: const Text('تم إرسال ملفك للمراجعة. ستظهر حالة الحساب في التطبيق فور الانتهاء من التدقيق.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('حسناً', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _cancelAndLogout() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('إلغاء العملية؟'),
        content: const Text('سيتم تسجيل خروجك ولن يتم حفظ البيانات المدخلة. هل تريد الاستمرار؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('رجوع')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authControllerProvider.notifier).logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(BuildContext context, {required String label, required IconData icon}) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: .45),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide(color: scheme.outlineVariant)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide(color: scheme.outlineVariant)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide(color: scheme.primary, width: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLoading = ref.watch(globalLoadingProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: _cancelAndLogout),
        title: const Text('إكمال الملف الشخصي', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSizes.p24, 8, AppSizes.p24, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroHeader(scheme: scheme),
              const SizedBox(height: 28),
              _SectionCard(child: _buildRoleSection()),
              const SizedBox(height: 16),
              _SectionCard(child: _buildBasicSection()),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                child: _selectedRole == 'lawyer' ? _buildLawyerSection() : const SizedBox.shrink(),
              ),
              const SizedBox(height: 22),
              if (isLoading)
                const Center(child: LoadingWidget())
              else
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _submit,
                    icon: Icon(_selectedRole == 'lawyer' ? Icons.send_rounded : Icons.arrow_forward_rounded),
                    label: Text(_selectedRole == 'lawyer' ? 'إرسال طلب الانضمام' : 'حفظ والمتابعة'),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text('يمكنك تعديل بعض البيانات لاحقاً من ملفك الشخصي.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle(title: 'نوع الحساب', subtitle: 'اختر طريقة استخدامك لتطبيق استشارة'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _RoleCard(title: 'طالب استشارة', subtitle: 'أطلب استشارة', icon: Icons.person_search_rounded, selected: _selectedRole == 'user', onTap: () => setState(() => _selectedRole = 'user'))),
            const SizedBox(width: 12),
            Expanded(child: _RoleCard(title: 'محامي', subtitle: 'أقدم استشارات', icon: Icons.gavel_rounded, selected: _selectedRole == 'lawyer', onTap: () => setState(() => _selectedRole = 'lawyer'))),
          ],
        ),
      ],
    );
  }

  Widget _buildBasicSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle(title: 'المعلومات الأساسية', subtitle: 'هذه البيانات تظهر في ملفك عند الحاجة'),
        const SizedBox(height: 17),
        TextFormField(controller: _nameController, textInputAction: TextInputAction.next, decoration: _inputDecoration(context, label: 'الاسم الكامل', icon: Icons.person_outline_rounded), validator: (v) => v?.trim().isEmpty ?? true ? 'الاسم مطلوب' : null),
        const SizedBox(height: 14),
        TextFormField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: _inputDecoration(context, label: 'البريد الإلكتروني (اختياري)', icon: Icons.mail_outline_rounded), validator: (v) => v != null && v.isNotEmpty && !v.contains('@') ? 'البريد الإلكتروني غير صحيح' : null),
      ],
    );
  }

  Widget _buildLawyerSection() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionTitle(title: 'البيانات المهنية', subtitle: 'معلومات مطلوبة للتحقق من حساب المحامي'),
            const SizedBox(height: 18),
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: scheme.surfaceContainerHighest,
                    backgroundImage: _profilePhotoBytes != null ? MemoryImage(_profilePhotoBytes!) : null,
                    child: _profilePhotoBytes == null ? Icon(Icons.person_rounded, size: 44, color: scheme.onSurfaceVariant) : null,
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Material(
                      color: scheme.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () => _pickImage('profile'),
                        customBorder: const CircleBorder(),
                        child: Padding(padding: const EdgeInsets.all(10), child: Icon(Icons.edit_rounded, size: 16, color: scheme.onPrimary)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('الصورة الشخصية', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 22),
            Text('التخصصات القانونية', style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurface)),
            const SizedBox(height: 4),
            Text('اختر تخصصاً واحداً أو أكثر', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 11),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _specializations.map((spec) {
                final selected = _selectedSpecializations.contains(spec);
                return FilterChip(
                  label: Text(spec),
                  selected: selected,
                  onSelected: (value) => setState(() {
                    if (value) {
                      _selectedSpecializations.add(spec);
                    } else {
                      _selectedSpecializations.remove(spec);
                    }
                  }),
                  selectedColor: scheme.primaryContainer,
                  checkmarkColor: scheme.primary,
                  side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  labelStyle: TextStyle(color: selected ? scheme.onPrimaryContainer : scheme.onSurface, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),
            Text('هوية النقابة', style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurface)),
            const SizedBox(height: 4),
            Text('يتم استخدام الصورة للتحقق فقط', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 11),
            InkWell(
              onTap: () => _pickImage('id'),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 155,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: .45),
                  border: Border.all(color: _idCardBytes == null ? scheme.outlineVariant : scheme.primary, width: _idCardBytes == null ? 1 : 1.5),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: _idCardBytes == null
                    ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.badge_outlined, size: 40, color: scheme.primary), const SizedBox(height: 8), Text('اضغط لرفع صورة الهوية', style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface)), const SizedBox(height: 3), Text('JPG أو PNG', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant))])
                    : ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.memory(_idCardBytes!, fit: BoxFit.cover)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final ColorScheme scheme;
  const _HeroHeader({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(width: 76, height: 76, alignment: Alignment.center, decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(25), border: Border.all(color: scheme.primary.withValues(alpha: .28))), child: Icon(Icons.assignment_ind_rounded, size: 40, color: scheme.primary)),
        const SizedBox(height: 20),
        Text('أكمل ملفك الشخصي', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: scheme.onSurface)),
        const SizedBox(height: 7),
        Text('خطوة واحدة تفصلك عن تجربة قانونية آمنة ومتكاملة.', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.55)),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: dark ? scheme.surfaceContainerHighest.withValues(alpha: .72) : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .85)),
        boxShadow: dark ? null : [BoxShadow(color: Colors.black.withValues(alpha: .035), blurRadius: 24, offset: const Offset(0, 9))],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: scheme.onSurface)), const SizedBox(height: 4), Text(subtitle, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant, height: 1.45))]);
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({required this.title, required this.subtitle, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 1.7 : 1),
        ),
        child: Column(
          children: [
            Container(width: 44, height: 44, alignment: Alignment.center, decoration: BoxDecoration(color: selected ? scheme.primary.withValues(alpha: .12) : scheme.surfaceContainerHighest, shape: BoxShape.circle), child: Icon(icon, color: selected ? scheme.primary : scheme.onSurfaceVariant, size: 24)),
            const SizedBox(height: 9),
            Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: selected ? scheme.onPrimaryContainer : scheme.onSurface)),
            const SizedBox(height: 3),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: selected ? scheme.onPrimaryContainer.withValues(alpha: .75) : scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
