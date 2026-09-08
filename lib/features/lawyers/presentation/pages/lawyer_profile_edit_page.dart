import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../domain/entities/lawyer_profile.dart';
import '../providers/lawyers_provider.dart';
import '../widgets/lawyer_achievements_gallery.dart';

class LawyerProfileEditPage extends ConsumerStatefulWidget {
  const LawyerProfileEditPage({super.key});
  @override
  ConsumerState<LawyerProfileEditPage> createState() => _LawyerProfileEditPageState();
}

class _LawyerProfileEditPageState extends ConsumerState<LawyerProfileEditPage> {
  static const _licenseClasses = <String>['أ', 'ب', 'ج', 'مطلقة'];
  final _formKey = GlobalKey<FormState>();
  final _bioController = TextEditingController();
  final _differentConsultationPriceController = TextEditingController();
  late List<LawyerService> _services;
  bool _isLoading = false;
  String? _lawyerProfileId;
  String? _practiceLicenseClass;
  String? _initialProfileSignature;

  @override
  void initState() { super.initState(); _services = []; _loadProfile(); }
  @override
  void dispose() { _bioController.dispose(); _differentConsultationPriceController.dispose(); super.dispose(); }

  String _buildProfileSignature() {
    final price = double.tryParse(_differentConsultationPriceController.text.trim()) ?? 0;
    return jsonEncode({
      'bio': _bioController.text.trim(),
      'license': _practiceLicenseClass ?? '',
      'price': price,
      'services': _services.map((service) => {
        'title': service.title.trim(),
        'price': service.price,
        'description': (service.description ?? '').trim(),
      }).toList(growable: false),
    });
  }

  bool get _hasProfileChanges => _initialProfileSignature == null || _buildProfileSignature() != _initialProfileSignature;

  Future<void> _loadProfile() async {
    final user = ref.read(authStateChangesProvider).value;
    if (user == null) return;
    try {
      final profile = await ref.read(lawyersRepositoryProvider).getOwnLawyerProfile(user.id);
      if (profile != null && mounted) {
        setState(() {
          _services = List<LawyerService>.from(profile.services);
          _bioController.text = profile.bio ?? '';
          _practiceLicenseClass = _licenseClasses.contains(profile.practiceLicenseClass) ? profile.practiceLicenseClass : null;
          final price = profile.consultationPrice ?? 0;
          _differentConsultationPriceController.text = price > 0 ? price.toStringAsFixed(0) : '';
          _lawyerProfileId = profile.id;
          _initialProfileSignature = _buildProfileSignature();
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحميل الملف المهني: $e'), backgroundColor: AppColors.error));
    }
  }

  void _addService() => setState(() => _services.add(const LawyerService(title: '', price: 0)));
  void _removeService(int index) => setState(() => _services.removeAt(index));

  Future<bool> _persist() async {
    if (!_formKey.currentState!.validate()) return false;
    _formKey.currentState!.save();
    if (_practiceLicenseClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى اختيار صلاحية المحامي'), backgroundColor: AppColors.error));
      return false;
    }
    final price = double.tryParse(_differentConsultationPriceController.text.trim()) ?? 0;
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تحديد سعر الاستشارة المختلفة بشكل صحيح'), backgroundColor: AppColors.error));
      return false;
    }
    if (_services.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف باقة استشارة واحدة على الأقل قبل المتابعة'), backgroundColor: AppColors.error));
      return false;
    }
    for (final service in _services) {
      if (service.title.trim().isEmpty || service.price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تأكد من أن كل باقة تحتوي على اسم وسعر صحيحين'), backgroundColor: AppColors.error));
        return false;
      }
    }
    setState(() => _isLoading = true);
    try {
      final user = ref.read(authStateChangesProvider).value;
      if (user == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('انتهت جلسة تسجيل الدخول، يرجى تسجيل الدخول مرة أخرى'), backgroundColor: AppColors.error));
        return false;
      }
      final repo = ref.read(lawyersRepositoryProvider);
      final profile = await repo.getOwnLawyerProfile(user.id);
      if (profile == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يتم العثور على الملف المهني للمحامي'), backgroundColor: AppColors.error));
        return false;
      }
      await repo.updateLawyerProfile(profile.copyWith(
        bio: _bioController.text.trim(),
        services: _services,
        consultationPrice: price,
        practiceLicenseClass: _practiceLicenseClass,
      ));
      ref.invalidate(lawyerProfileProvider(profile.profileId));
      _initialProfileSignature = _buildProfileSignature();
      return true;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في حفظ الملف المهني: $e'), backgroundColor: AppColors.error));
      return false;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    _formKey.currentState?.save();
    if (!_hasProfileChanges) {
      if (mounted) context.go('/lawyer-home');
      return;
    }
    if (!await _persist() || !mounted) return;
    context.go('/lawyer-home');
  }

  void _cancel() {
    if (_isLoading) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/lawyer-home');
    }
  }

  InputDecoration _input(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: AppColors.surfaceContainerLow,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.outlineVariant)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.teal, width: 1.7)),
    floatingLabelStyle: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );

  Widget _sectionHeader({required IconData icon, required String title, required String subtitle, required bool accent}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: accent ? AppColors.goldGradient : AppColors.skyGradient),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: accent ? AppColors.secondaryDark : AppColors.tertiary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({required Widget child, bool accent = false}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent ? AppColors.goldLight : AppColors.outlineVariant),
        boxShadow: const [BoxShadow(color: Color(0x12082B49), blurRadius: 18, offset: Offset(0, 7))],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الملف المهني', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        actions: [
          if (!_isLoading)
            IconButton(tooltip: 'حفظ وإنهاء', icon: const Icon(Icons.check_rounded), onPressed: _save),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppSizes.p20, 18, AppSizes.p20, 132),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [AppColors.primary, AppColors.primaryContainer]),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [BoxShadow(color: Color(0x22082B49), blurRadius: 20, offset: Offset(0, 9))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(color: AppColors.goldLight.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(17)),
                            child: const Icon(Icons.workspace_premium_rounded, color: AppColors.goldLight, size: 28),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ملفك المهني', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                                SizedBox(height: 6),
                                Text('رتّب معلوماتك وباقاتك ليظهر ملفك بصورة احترافية وواضحة لطالب الاستشارة.', style: TextStyle(color: Colors.white70, height: 1.45, fontSize: 12.5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _sectionCard(
                      accent: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _sectionHeader(icon: Icons.verified_user_rounded, title: 'الصلاحية المهنية', subtitle: 'معلومة داخلية تستخدمها الإدارة ولا تظهر لطالب الاستشارة.', accent: true),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _practiceLicenseClass,
                            decoration: _input('الصلاحية'),
                            items: _licenseClasses.map((value) => DropdownMenuItem<String>(value: value, child: Text(value == 'مطلقة' ? 'مطلقة' : 'الفئة $value'))).toList(),
                            onChanged: (value) => setState(() => _practiceLicenseClass = value),
                            validator: (value) => value == null ? 'اختر صلاحية واحدة' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _sectionHeader(icon: Icons.gavel_rounded, title: 'التخصص المهني', subtitle: 'يمكنك إرسال طلب إلى الإدارة لتغيير تخصصك المعتمد.', accent: false),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _isLoading ? null : () => context.push('/lawyer-specialization-change'),
                            icon: const Icon(Icons.edit_rounded),
                            label: const Text('طلب تغيير التخصص'),
                            style: OutlinedButton.styleFrom(foregroundColor: AppColors.tertiary, side: const BorderSide(color: AppColors.tertiaryLight), backgroundColor: AppColors.surfaceContainerLow, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _sectionHeader(icon: Icons.person_outline_rounded, title: 'النبذة المهنية', subtitle: 'اكتب تعريفاً مختصراً يوضح خبرتك ومجالات عملك.', accent: false),
                          const SizedBox(height: 16),
                          TextFormField(controller: _bioController, maxLines: 6, maxLength: 1000, decoration: _input('نبذة مهنية', hint: 'اكتب نبذة عن خبرتك وتخصصك وإنجازاتك...'), validator: (v) => v == null || v.trim().isEmpty ? 'السيرة الذاتية مطلوبة' : null),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_lawyerProfileId != null)
                      _sectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _sectionHeader(icon: Icons.photo_library_outlined, title: 'الإنجازات المهنية', subtitle: 'أضف ما يعكس خبرتك وإنجازاتك المهنية بصورة مرتبة.', accent: true),
                            const SizedBox(height: 16),
                            LawyerAchievementsGallery(lawyerId: _lawyerProfileId!, editable: true),
                          ],
                        ),
                      ),
                    if (_lawyerProfileId != null) const SizedBox(height: 16),
                    _sectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _sectionHeader(icon: Icons.payments_outlined, title: 'أسعار الاستشارات', subtitle: 'حدد سعرك الأساسي للاستشارة المختلفة ثم أضف الباقات التي تقدمها.', accent: true),
                          const SizedBox(height: 16),
                          TextFormField(controller: _differentConsultationPriceController, decoration: _input('سعر الاستشارة المختلفة (د.ع)', hint: 'مثلاً: 50000'), keyboardType: TextInputType.number, validator: (v) { final p = double.tryParse(v?.trim() ?? ''); return p == null || p <= 0 ? 'حدد سعرًا أكبر من صفر' : null; }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _sectionHeader(icon: Icons.inventory_2_outlined, title: 'باقات الاستشارة', subtitle: 'أضف باقات واضحة باسم وسعر ووصف مختصر ليسهل على العميل الاختيار.', accent: false),
                          const SizedBox(height: 16),
                          if (_services.isEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                              decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.outlineVariant)),
                              child: const Column(children: [Icon(Icons.add_business_rounded, color: AppColors.teal, size: 30), SizedBox(height: 8), Text('لم تتم إضافة أي باقة بعد', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)), SizedBox(height: 4), Text('أضف أول باقة لتفعيل استقبال الاستشارات.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textSecondary))]),
                            ),
                          ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _services.length, itemBuilder: (context, index) => _buildServiceEditor(index)),
                          const SizedBox(height: 4),
                          FilledButton.icon(
                            onPressed: _addService,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('إضافة باقة جديدة', style: TextStyle(fontWeight: FontWeight.w800)),
                            style: FilledButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          decoration: const BoxDecoration(color: AppColors.surface, boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, -4))]),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _cancel,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('إلغاء', style: TextStyle(fontWeight: FontWeight.w900)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    backgroundColor: AppColors.surface,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _save,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('حفظ', style: TextStyle(fontWeight: FontWeight.w900)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceEditor(int index) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.outlineVariant)),
    child: Column(children: [
      Row(children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(color: AppColors.goldLight.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.workspace_premium_rounded, color: AppColors.secondary, size: 19)),
        const SizedBox(width: 9),
        Expanded(child: Text('الباقة ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary))),
        IconButton(tooltip: 'حذف', icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error), onPressed: () => _removeService(index)),
      ]),
      const SizedBox(height: 10),
      TextFormField(initialValue: _services[index].title, decoration: _input('عنوان الباقة', hint: 'مثلاً: استشارة هاتفية 30 دقيقة'), onSaved: (v) => _services[index] = _services[index].copyWith(title: v ?? ''), validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null),
      const SizedBox(height: 10),
      TextFormField(initialValue: _services[index].price.toString(), decoration: _input('السعر (د.ع)'), keyboardType: TextInputType.number, onSaved: (v) => _services[index] = _services[index].copyWith(price: double.tryParse(v ?? '0') ?? 0), validator: (v) { final p = double.tryParse(v ?? ''); return p == null || p <= 0 ? 'حدد سعراً صحيحاً' : null; }),
      const SizedBox(height: 10),
      TextFormField(initialValue: _services[index].description, decoration: _input('وصف مختصر (اختياري)'), maxLines: 2, onSaved: (v) => _services[index] = _services[index].copyWith(description: v)),
    ]),
  );
}
