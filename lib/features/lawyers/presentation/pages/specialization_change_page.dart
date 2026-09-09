import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/legal_specializations.dart';
import '../../data/repositories/lawyers_repository_impl.dart';

class SpecializationChangePage extends ConsumerStatefulWidget {
  const SpecializationChangePage({super.key});

  @override
  ConsumerState<SpecializationChangePage> createState() => _SpecializationChangePageState();
}

class _SpecializationChangePageState extends ConsumerState<SpecializationChangePage> {
  static const _options = LegalSpecializations.all;
  static const _max = LegalSpecializations.maxLawyerSpecializations;

  final List<String> _selected = <String>[];
  PlatformFile? _idCard;
  bool _saving = false;

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر قراءة الملف المختار.')),
      );
      return;
    }
    setState(() => _idCard = file);
  }

  void _toggleSpecialization(String specialization, bool value) {
    if (value) {
      if (_selected.contains(specialization)) return;
      if (_selected.length >= _max) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الحد الأقصى 3 تخصصات: تخصص رئيسي وتخصصان إضافيان.'),
          ),
        );
        return;
      }
      setState(() => _selected.add(specialization));
      return;
    }
    setState(() => _selected.remove(specialization));
  }

  Future<void> _submit() async {
    final idCard = _idCard;
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر تخصصاً رئيسياً واحداً على الأقل.')),
      );
      return;
    }
    if (_selected.length > _max) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يمكن اعتماد ثلاثة تخصصات كحد أقصى.')),
      );
      return;
    }
    if (idCard == null || idCard.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أرفق صورة هوية النقابة.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = LawyersRepositoryImpl(SupabaseConfig.client);
      final url = await repo.uploadFile(idCard.bytes!, idCard.name, 'lawyer_documents');
      await repo.requestSpecializationChange(
        List<String>.unmodifiable(_selected),
        unionIdCardUrl: url,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال الطلب إلى الإدارة للمراجعة.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _selectionSummary() {
    if (_selected.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppColors.primaryDark, size: 20),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'أول تخصص تختاره سيكون تخصصك الرئيسي، ويمكنك إضافة تخصصين فقط.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.45),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'التخصص الرئيسي: ${_selected.first}',
            style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryDark),
          ),
          if (_selected.length > 1) ...[
            const SizedBox(height: 5),
            Text(
              'إضافي: ${_selected.skip(1).join('، ')}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 5),
          Text(
            '${_selected.length}/$_max تخصصات مختارة',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلب تغيير التخصص'),
        leading: IconButton(
          tooltip: 'رجوع',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.brandGradient,
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      radius: 27,
                      backgroundColor: Color(0x33FFFFFF),
                      child: Icon(Icons.gavel_rounded, color: Colors.white, size: 28),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'حدّث تخصصك المهني',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'تخصص رئيسي واحد وتخصصان إضافيان كحد أقصى، بعد مراجعة الإدارة.',
                            style: TextStyle(color: Color(0xE6FFFFFF), height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionTitle(
                number: '01',
                title: 'التخصصات المطلوبة',
                subtitle: 'اختر الرئيسي أولاً، ثم أضف حتى تخصصين آخرين.',
              ),
              const SizedBox(height: 12),
              _selectionSummary(),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.outline),
                ),
                child: Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: _options.map((specialization) {
                    final selected = _selected.contains(specialization);
                    final position = selected ? _selected.indexOf(specialization) : -1;
                    final suffix = position == 0 ? ' • رئيسي' : (position > 0 ? ' • إضافي' : '');
                    return FilterChip(
                      label: Text('$specialization$suffix'),
                      selected: selected,
                      showCheckmark: true,
                      checkmarkColor: AppColors.textOnPrimary,
                      selectedColor: AppColors.primaryLight,
                      backgroundColor: AppColors.background,
                      side: BorderSide(
                        color: selected ? AppColors.primary : AppColors.outline,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      labelStyle: TextStyle(
                        color: selected ? AppColors.textOnPrimary : AppColors.textPrimary,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                      ),
                      onSelected: _saving ? null : (value) => _toggleSpecialization(specialization, value),
                    );
                  }).toList(growable: false),
                ),
              ),
              const SizedBox(height: 24),
              const _SectionTitle(
                number: '02',
                title: 'وثيقة التحقق',
                subtitle: 'مطلوبة للتأكد من صلاحية التخصصات الجديدة.',
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _saving ? null : _pick,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _idCard == null ? AppColors.outline : AppColors.primary,
                      width: _idCard == null ? 1 : 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _idCard == null ? Icons.badge_outlined : Icons.check_circle_rounded,
                          color: _idCard == null ? AppColors.primaryDark : AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _idCard?.name ?? 'إرفاق هوية النقابة',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _idCard == null ? 'JPG أو PNG أو PDF' : 'تم اختيار المستند بنجاح',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_user_outlined, size: 20, color: AppColors.primaryDark),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'تستخدم الوثيقة لغرض التحقق والمراجعة فقط، ولا تظهر لطالبي الاستشارة.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnPrimary),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_saving ? 'جارٍ إرسال الطلب...' : 'إرسال الطلب للمراجعة'),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'ستراجع الإدارة الطلب قبل اعتماد التخصصات الجديدة.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.number, required this.title, required this.subtitle});

  final String number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primaryFixed,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}
