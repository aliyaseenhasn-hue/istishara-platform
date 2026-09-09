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
  static const _maxAdditional = LegalSpecializations.maxLawyerSpecializations - 1;

  String? _primarySpecialization;
  final List<String> _additionalSpecializations = <String>[];
  PlatformFile? _idCard;
  bool _saving = false;

  List<String> get _requestedSpecializations => <String>[
        if (_primarySpecialization != null) _primarySpecialization!,
        ..._additionalSpecializations,
      ];

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

  void _selectPrimary(String specialization) {
    if (_saving || _primarySpecialization == specialization) return;
    setState(() {
      _additionalSpecializations.remove(specialization);
      _primarySpecialization = specialization;
    });
  }

  void _toggleAdditional(String specialization, bool value) {
    if (_saving || specialization == _primarySpecialization) return;
    if (value) {
      if (_additionalSpecializations.contains(specialization)) return;
      if (_additionalSpecializations.length >= _maxAdditional) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يمكنك اختيار تخصصين فرعيين كحد أقصى.')),
        );
        return;
      }
      setState(() => _additionalSpecializations.add(specialization));
      return;
    }
    setState(() => _additionalSpecializations.remove(specialization));
  }

  Future<void> _submit() async {
    final primary = _primarySpecialization;
    final idCard = _idCard;
    if (primary == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر تخصصك الرئيسي أولاً.')),
      );
      return;
    }
    if (_additionalSpecializations.length > _maxAdditional) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يمكن اختيار تخصصين فرعيين كحد أقصى.')),
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
        List<String>.unmodifiable(_requestedSpecializations),
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

  Widget _primarySelectionCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium_rounded, color: AppColors.primaryDark, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'التخصص الرئيسي',
                        style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryDark),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _primarySpecialization ?? 'لم يتم اختيار تخصص رئيسي بعد',
                        style: TextStyle(
                          color: _primarySpecialization == null ? AppColors.textSecondary : AppColors.primaryDark,
                          fontSize: 12.5,
                          fontWeight: _primarySpecialization == null ? FontWeight.w500 : FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          ..._options.map((specialization) {
            final selected = _primarySpecialization == specialization;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SpecializationChoiceTile(
                title: specialization,
                selected: selected,
                enabled: !_saving,
                badge: selected ? 'الرئيسي' : null,
                onTap: () => _selectPrimary(specialization),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _additionalSelectionCard() {
    final primary = _primarySpecialization;
    final available = _options.where((item) => item != primary).toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_tree_outlined, color: AppColors.primaryDark, size: 21),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'التخصصات الفرعية  ${_additionalSpecializations.length}/$_maxAdditional',
                        style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        primary == null
                            ? 'اختر التخصص الرئيسي أولاً لتفعيل الخيارات الفرعية.'
                            : 'اختيارية، ويمكنك تحديد تخصصين فقط.',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_additionalSpecializations.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _additionalSpecializations
                  .map(
                    (item) => Chip(
                      avatar: const Icon(Icons.check_circle_rounded, size: 17, color: AppColors.primaryDark),
                      label: Text(item),
                      deleteIcon: const Icon(Icons.close_rounded, size: 17),
                      onDeleted: _saving ? null : () => _toggleAdditional(item, false),
                      backgroundColor: AppColors.primaryFixed,
                      side: const BorderSide(color: AppColors.primaryLight),
                      labelStyle: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 13),
          IgnorePointer(
            ignoring: primary == null || _saving,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: primary == null ? .45 : 1,
              child: Wrap(
                spacing: 9,
                runSpacing: 9,
                children: available.map((specialization) {
                  final selected = _additionalSpecializations.contains(specialization);
                  final limitReached = !selected && _additionalSpecializations.length >= _maxAdditional;
                  return FilterChip(
                    label: Text(specialization),
                    selected: selected,
                    showCheckmark: true,
                    checkmarkColor: AppColors.textOnPrimary,
                    selectedColor: AppColors.primaryLight,
                    backgroundColor: AppColors.background,
                    side: BorderSide(color: selected ? AppColors.primary : AppColors.outline),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    labelStyle: TextStyle(
                      color: selected ? AppColors.textOnPrimary : AppColors.textPrimary,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    ),
                    onSelected: limitReached ? null : (value) => _toggleAdditional(specialization, value),
                  );
                }).toList(growable: false),
              ),
            ),
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
                            style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'حدد تخصصاً رئيسياً واحداً أولاً، ثم أضف تخصصين فرعيين عند الحاجة.',
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
                title: 'اختر التخصص الرئيسي',
                subtitle: 'هذا هو المجال الأساسي الذي سيظهر أولاً في ملفك المهني.',
              ),
              const SizedBox(height: 12),
              _primarySelectionCard(),
              const SizedBox(height: 26),
              const _SectionTitle(
                number: '02',
                title: 'اختر التخصصات الفرعية',
                subtitle: 'اختيارية — يمكنك إضافة تخصص واحد أو تخصصين فقط.',
              ),
              const SizedBox(height: 12),
              _additionalSelectionCard(),
              const SizedBox(height: 26),
              const _SectionTitle(
                number: '03',
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
                        decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(14)),
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
                decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(14)),
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

class _SpecializationChoiceTile extends StatelessWidget {
  const _SpecializationChoiceTile({
    required this.title,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.badge,
  });

  final String title;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryFixed : AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.outline,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.primary : Colors.transparent,
                  border: Border.all(color: selected ? AppColors.primary : AppColors.textSecondary, width: 1.6),
                ),
                child: selected ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : null,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: selected ? AppColors.primaryDark : AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(99)),
                  child: Text(
                    badge!,
                    style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
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
          decoration: BoxDecoration(color: AppColors.primaryFixed, borderRadius: BorderRadius.circular(11)),
          child: Text(
            number,
            style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w900, fontSize: 12),
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
