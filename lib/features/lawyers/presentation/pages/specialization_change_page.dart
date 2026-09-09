import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
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

  String? _currentPrimary;
  String? _requestedPrimary;
  String? _pendingPrimary;
  List<String> _currentAdditional = <String>[];
  final List<String> _draftAdditional = <String>[];
  PlatformFile? _idCard;
  DateTime? _nextAdditionalChangeAt;
  bool _canChangeAdditional = true;
  bool _loading = true;
  bool _savingAdditional = false;
  bool _submittingPrimary = false;

  bool get _busy => _savingAdditional || _submittingPrimary;
  bool get _additionalChanged => !listEquals(_currentAdditional, _draftAdditional);

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    if (mounted) setState(() => _loading = true);
    try {
      final raw = await SupabaseConfig.client.rpc('get_specialization_management_status');
      final data = Map<String, dynamic>.from(raw as Map);
      final additionalRaw = data['additional_specializations'];
      final additional = additionalRaw is List
          ? additionalRaw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList(growable: false)
          : <String>[];
      final nextRaw = data['next_additional_change_at']?.toString();
      final next = nextRaw == null || nextRaw.isEmpty ? null : DateTime.tryParse(nextRaw)?.toLocal();

      if (!mounted) return;
      setState(() {
        _currentPrimary = data['primary_specialization']?.toString();
        _pendingPrimary = data['pending_primary_specialization']?.toString();
        _currentAdditional = List<String>.from(additional);
        _draftAdditional
          ..clear()
          ..addAll(additional);
        _canChangeAdditional = data['can_change_additional'] == true;
        _nextAdditionalChangeAt = next;
        _requestedPrimary = null;
        _idCard = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorText(error))));
    }
  }

  String _errorText(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    final messageMatch = RegExp(r'message:\s*([^,}]+)').firstMatch(text);
    return messageMatch?.group(1)?.trim() ?? text;
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    final d = value.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}/${two(d.month)}/${two(d.day)}';
  }

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر قراءة الملف المختار.')));
      return;
    }
    setState(() => _idCard = file);
  }

  Future<void> _choosePrimary() async {
    if (_busy || _pendingPrimary != null) return;
    final available = _options.where((item) => item != _currentPrimary).toList(growable: false);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SingleSpecializationPicker(
        options: available,
        selected: _requestedPrimary,
        title: 'اختر التخصص الرئيسي',
        subtitle: 'اختر تخصصاً واحداً فقط لإرساله إلى الإدارة للمراجعة.',
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _requestedPrimary = result;
      _idCard = null;
    });
  }

  Future<void> _chooseAdditional() async {
    if (_busy || !_canChangeAdditional || _currentPrimary == null) return;
    final available = _options.where((item) => item != _currentPrimary).toList(growable: false);
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MultiSpecializationPicker(
        options: available,
        selected: _draftAdditional,
        maxSelected: _maxAdditional,
        title: 'اختر مجالات الممارسة الإضافية',
        subtitle: 'يمكنك اختيار مجالين إضافيين كحد أقصى.',
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _draftAdditional
        ..clear()
        ..addAll(result);
    });
  }

  void _removeAdditional(String value) {
    if (_busy || !_canChangeAdditional) return;
    setState(() => _draftAdditional.remove(value));
  }

  Future<void> _saveAdditional() async {
    if (!_canChangeAdditional) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يمكن التغيير مرة كل 30 يوماً. الموعد التالي ${_formatDate(_nextAdditionalChangeAt)}.')),
      );
      return;
    }
    if (!_additionalChanged) return;
    if (_draftAdditional.length > _maxAdditional) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يمكن اختيار مجالين إضافيين كحد أقصى.')));
      return;
    }

    setState(() => _savingAdditional = true);
    try {
      await SupabaseConfig.client.rpc(
        'update_additional_specializations',
        params: {'p_additional_specializations': List<String>.unmodifiable(_draftAdditional)},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث مجالات الممارسة الإضافية مباشرة.')));
      await _loadStatus();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorText(error))));
    } finally {
      if (mounted) setState(() => _savingAdditional = false);
    }
  }

  Future<void> _submitPrimaryChange() async {
    final requested = _requestedPrimary;
    final idCard = _idCard;
    if (_pendingPrimary != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لديك طلب تغيير تخصص رئيسي قيد مراجعة الإدارة بالفعل.')));
      return;
    }
    if (requested == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر التخصص الرئيسي الجديد.')));
      return;
    }
    if (idCard == null || idCard.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أرفق هوية النقابة لمراجعة تغيير التخصص الرئيسي.')));
      return;
    }

    setState(() => _submittingPrimary = true);
    try {
      final repo = LawyersRepositoryImpl(SupabaseConfig.client);
      final url = await repo.uploadFile(idCard.bytes!, idCard.name, 'lawyer_documents');
      await repo.requestSpecializationChange(<String>[requested], unionIdCardUrl: url);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلب تغيير التخصص الرئيسي إلى الإدارة.')));
      await _loadStatus();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorText(error))));
    } finally {
      if (mounted) setState(() => _submittingPrimary = false);
    }
  }

  Widget _currentSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: const [BoxShadow(color: Color(0x10082B49), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('تخصصاتك الحالية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          _StatusRow(
            icon: Icons.workspace_premium_rounded,
            title: 'التخصص الرئيسي',
            value: _currentPrimary ?? 'غير محدد',
            emphasized: true,
          ),
          const SizedBox(height: 10),
          _StatusRow(
            icon: Icons.account_tree_outlined,
            title: 'مجالات ممارسة إضافية',
            value: _currentAdditional.isEmpty ? 'لا توجد' : _currentAdditional.join('، '),
          ),
        ],
      ),
    );
  }

  Widget _primarySection() {
    final pending = _pendingPrimary;
    final requested = _requestedPrimary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.goldSoftStrong),
        boxShadow: const [BoxShadow(color: Color(0x0F8A681C), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.goldGradient, begin: Alignment.topRight, end: Alignment.bottomLeft),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.workspace_premium_rounded, color: AppColors.goldDark, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'التخصص الرئيسي يمثل مجالك المهني الأساسي، ولذلك يتطلب تغييره مراجعة الإدارة وهوية النقابة.',
                    style: TextStyle(color: AppColors.goldDark, height: 1.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          if (pending != null && pending.isNotEmpty) ...[
            const SizedBox(height: 14),
            _PendingPrimaryCard(value: pending),
          ] else ...[
            const SizedBox(height: 16),
            const Text('التخصص الرئيسي الجديد', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            const SizedBox(height: 8),
            const Text(
              'اضغط على البطاقة واختر تخصصاً من القائمة.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            _SpecializationSelectorCard(
              value: requested,
              placeholder: 'اختر التخصص الرئيسي',
              helper: requested == null ? 'تخصص واحد فقط' : 'تم اختيار التخصص المطلوب',
              icon: Icons.workspace_premium_outlined,
              primaryMode: true,
              enabled: !_busy,
              onTap: _choosePrimary,
            ),
            if (requested != null && _currentAdditional.contains(requested)) ...[
              const SizedBox(height: 10),
              const Text(
                'هذا المجال موجود حالياً ضمن مجالات الممارسة الإضافية. عند اعتماد التغيير سيصبح رئيسياً ويُزال تلقائياً من الإضافية.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.45),
              ),
            ],
            const SizedBox(height: 16),
            InkWell(
              onTap: _busy ? null : _pick,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _idCard == null ? AppColors.surfaceContainerLow : AppColors.acceptedBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _idCard == null ? AppColors.outlineVariant : AppColors.success),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _idCard == null ? AppColors.primaryFixed : AppColors.acceptedBg,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        _idCard == null ? Icons.badge_outlined : Icons.check_circle_rounded,
                        color: _idCard == null ? AppColors.primaryDark : AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _idCard?.name ?? 'إرفاق هوية النقابة',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _idCard == null ? 'JPG، PNG، WEBP أو PDF' : 'تم إرفاق المستند',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
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
            ElevatedButton.icon(
              onPressed: _busy ? null : _submitPrimaryChange,
              icon: _submittingPrimary
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnPrimary))
                  : const Icon(Icons.send_rounded),
              label: Text(_submittingPrimary ? 'جارٍ إرسال الطلب...' : 'إرسال طلب تغيير التخصص الرئيسي'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _additionalSection() {
    final primary = _currentPrimary;
    final locked = !_canChangeAdditional;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: const [BoxShadow(color: Color(0x10082B49), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.skyGradient, begin: Alignment.topRight, end: Alignment.bottomLeft),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(locked ? Icons.lock_clock_outlined : Icons.auto_awesome_rounded, color: AppColors.secondaryDark, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    locked
                        ? 'تم تعديل مجالات الممارسة الإضافية مؤخراً. يمكنك التغيير مرة أخرى بتاريخ ${_formatDate(_nextAdditionalChangeAt)}.'
                        : 'اختر حتى مجالين إضافيين. يمكن تغييرهما مباشرة دون مراجعة الإدارة، مرة واحدة كل 30 يوماً.',
                    style: const TextStyle(color: AppColors.secondaryDark, height: 1.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('مجالات الممارسة الإضافية', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    SizedBox(height: 3),
                    Text('تظهر للعميل كمجالات إضافية وليست كتخصص رئيسي.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.8)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppColors.secondaryContainer, borderRadius: BorderRadius.circular(99)),
                child: Text(
                  '${_draftAdditional.length}/$_maxAdditional',
                  style: const TextStyle(color: AppColors.secondaryDark, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SpecializationSelectorCard(
            value: _draftAdditional.isEmpty ? null : _draftAdditional.join('، '),
            placeholder: 'اختر المجالات الإضافية',
            helper: _draftAdditional.isEmpty ? 'يمكن اختيار مجال أو مجالين' : 'اضغط لتعديل الاختيارات',
            icon: Icons.account_tree_outlined,
            primaryMode: false,
            enabled: !locked && !_busy && primary != null,
            onTap: _chooseAdditional,
          ),
          if (_draftAdditional.isNotEmpty) ...[
            const SizedBox(height: 13),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _draftAdditional.map((item) {
                final accent = _specializationAccent(item);
                final soft = _specializationSoft(item);
                return InputChip(
                  label: Text(item),
                  avatar: Icon(_specializationIcon(item), size: 17, color: accent),
                  deleteIcon: const Icon(Icons.close_rounded, size: 17),
                  onDeleted: locked || _busy ? null : () => _removeAdditional(item),
                  backgroundColor: soft,
                  side: BorderSide(color: accent.withValues(alpha: .35)),
                  labelStyle: TextStyle(fontWeight: FontWeight.w800, color: accent),
                );
              }).toList(growable: false),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: locked || _busy || !_additionalChanged ? null : _saveAdditional,
            icon: _savingAdditional
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnPrimary))
                : const Icon(Icons.save_rounded),
            label: Text(_savingAdditional ? 'جارٍ الحفظ...' : 'حفظ مجالات الممارسة الإضافية'),
          ),
          if (!locked) ...[
            const SizedBox(height: 8),
            const Text(
              'بعد الحفظ يبدأ احتساب مدة 30 يوماً قبل السماح بالتغيير التالي.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('إدارة التخصصات'),
        leading: IconButton(
          tooltip: 'رجوع',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _busy ? null : _loadStatus,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadStatus,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
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
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: const [BoxShadow(color: Color(0x22082B49), blurRadius: 20, offset: Offset(0, 8))],
                        ),
                        child: const Row(
                          children: [
                            CircleAvatar(
                              radius: 27,
                              backgroundColor: Color(0x33FFFFFF),
                              child: Icon(Icons.balance_rounded, color: Colors.white, size: 28),
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'اختيار التخصصات',
                                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    'اختيار أوضح وأسرع: افتح قائمة التخصصات، ابحث عن المجال، ثم اختره كما تختار أحد خيارات السعر.',
                                    style: TextStyle(color: Color(0xE6FFFFFF), height: 1.45),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _currentSummary(),
                      const SizedBox(height: 26),
                      const _SectionTitle(
                        number: '01',
                        title: 'التخصص الرئيسي',
                        subtitle: 'اختيار واحد — تغييره يحتاج مراجعة الإدارة.',
                        accent: AppColors.goldDark,
                        background: AppColors.goldLight,
                      ),
                      const SizedBox(height: 12),
                      _primarySection(),
                      const SizedBox(height: 26),
                      const _SectionTitle(
                        number: '02',
                        title: 'مجالات الممارسة الإضافية',
                        subtitle: 'حتى مجالين — تغيير مباشر مرة كل 30 يوماً.',
                        accent: AppColors.secondaryDark,
                        background: AppColors.secondaryContainer,
                      ),
                      const SizedBox(height: 12),
                      _additionalSection(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _SpecializationSelectorCard extends StatelessWidget {
  const _SpecializationSelectorCard({
    required this.value,
    required this.placeholder,
    required this.helper,
    required this.icon,
    required this.primaryMode,
    required this.enabled,
    required this.onTap,
  });

  final String? value;
  final String placeholder;
  final String helper;
  final IconData icon;
  final bool primaryMode;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.trim().isNotEmpty;
    final accent = primaryMode ? AppColors.goldDark : AppColors.secondaryDark;
    final soft = primaryMode ? AppColors.goldLight : AppColors.secondaryContainer;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: enabled ? 1 : .52,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: hasValue
                  ? LinearGradient(
                      colors: [soft, AppColors.surface],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    )
                  : null,
              color: hasValue ? null : AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: hasValue ? accent.withValues(alpha: .55) : AppColors.outlineVariant, width: hasValue ? 1.5 : 1),
              boxShadow: hasValue ? [BoxShadow(color: accent.withValues(alpha: .10), blurRadius: 14, offset: const Offset(0, 5))] : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: hasValue ? accent : soft,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: hasValue ? Colors.white : accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasValue ? value! : placeholder,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: hasValue ? accent : AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(helper, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.8)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(11)),
                  child: Icon(hasValue ? Icons.edit_rounded : Icons.keyboard_arrow_down_rounded, color: accent, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SingleSpecializationPicker extends StatefulWidget {
  const _SingleSpecializationPicker({
    required this.options,
    required this.selected,
    required this.title,
    required this.subtitle,
  });

  final List<String> options;
  final String? selected;
  final String title;
  final String subtitle;

  @override
  State<_SingleSpecializationPicker> createState() => _SingleSpecializationPickerState();
}

class _SingleSpecializationPickerState extends State<_SingleSpecializationPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.options
        .where((item) => _query.trim().isEmpty || item.contains(_query.trim()))
        .toList(growable: false);

    return _PickerShell(
      title: widget.title,
      subtitle: widget.subtitle,
      accent: AppColors.goldDark,
      soft: AppColors.goldLight,
      icon: Icons.workspace_premium_rounded,
      searchHint: 'ابحث عن التخصص الرئيسي...',
      onSearch: (value) => setState(() => _query = value),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 9),
        itemBuilder: (context, index) {
          final item = filtered[index];
          return _SpecializationOptionTile(
            value: item,
            selected: widget.selected == item,
            selectionLabel: 'تخصص رئيسي',
            onTap: () => Navigator.pop(context, item),
          );
        },
      ),
    );
  }
}

class _MultiSpecializationPicker extends StatefulWidget {
  const _MultiSpecializationPicker({
    required this.options,
    required this.selected,
    required this.maxSelected,
    required this.title,
    required this.subtitle,
  });

  final List<String> options;
  final List<String> selected;
  final int maxSelected;
  final String title;
  final String subtitle;

  @override
  State<_MultiSpecializationPicker> createState() => _MultiSpecializationPickerState();
}

class _MultiSpecializationPickerState extends State<_MultiSpecializationPicker> {
  late final List<String> _selected = List<String>.from(widget.selected);
  String _query = '';

  void _toggle(String item) {
    if (_selected.contains(item)) {
      setState(() => _selected.remove(item));
      return;
    }
    if (_selected.length >= widget.maxSelected) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('يمكن اختيار ${widget.maxSelected} كحد أقصى.')));
      return;
    }
    setState(() => _selected.add(item));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.options
        .where((item) => _query.trim().isEmpty || item.contains(_query.trim()))
        .toList(growable: false);

    return _PickerShell(
      title: widget.title,
      subtitle: widget.subtitle,
      accent: AppColors.secondaryDark,
      soft: AppColors.secondaryContainer,
      icon: Icons.account_tree_rounded,
      searchHint: 'ابحث عن مجال الممارسة...',
      onSearch: (value) => setState(() => _query = value),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.secondaryContainer, borderRadius: BorderRadius.circular(14)),
              child: Text(
                '${_selected.length}/${widget.maxSelected}',
                style: const TextStyle(color: AppColors.secondaryDark, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, List<String>.from(_selected)),
                icon: const Icon(Icons.check_rounded),
                label: const Text('اعتماد الاختيارات'),
              ),
            ),
          ],
        ),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 9),
        itemBuilder: (context, index) {
          final item = filtered[index];
          final selected = _selected.contains(item);
          final limitReached = !selected && _selected.length >= widget.maxSelected;
          return _SpecializationOptionTile(
            value: item,
            selected: selected,
            selectionLabel: selected ? 'مجال إضافي مختار' : 'مجال ممارسة إضافي',
            disabled: limitReached,
            onTap: () => _toggle(item),
          );
        },
      ),
    );
  }
}

class _PickerShell extends StatelessWidget {
  const _PickerShell({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.soft,
    required this.icon,
    required this.searchHint,
    required this.onSearch,
    required this.child,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final Color soft;
  final IconData icon;
  final String searchHint;
  final ValueChanged<String> onSearch;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: FractionallySizedBox(
        heightFactor: .88,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: AppColors.outlineVariant, borderRadius: BorderRadius.circular(99)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(15)),
                      child: Icon(icon, color: accent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 3),
                          Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.2, height: 1.35)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: TextField(
                  onChanged: onSearch,
                  decoration: InputDecoration(
                    hintText: searchHint,
                    prefixIcon: Icon(Icons.search_rounded, color: accent),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLow,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.outlineVariant)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: accent, width: 1.5)),
                  ),
                ),
              ),
              Expanded(child: child),
              if (footer != null) footer!,
            ],
          ),
        ),
      ),
    );
  }
}

class _SpecializationOptionTile extends StatelessWidget {
  const _SpecializationOptionTile({
    required this.value,
    required this.selected,
    required this.selectionLabel,
    required this.onTap,
    this.disabled = false,
  });

  final String value;
  final bool selected;
  final String selectionLabel;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final accent = _specializationAccent(value);
    final soft = _specializationSoft(value);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 140),
      opacity: disabled ? .42 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(17),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              gradient: selected
                  ? LinearGradient(colors: [soft, Colors.white], begin: Alignment.topRight, end: Alignment.bottomLeft)
                  : null,
              color: selected ? null : AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: selected ? accent : AppColors.outlineVariant, width: selected ? 1.7 : 1),
              boxShadow: selected ? [BoxShadow(color: accent.withValues(alpha: .12), blurRadius: 12, offset: const Offset(0, 4))] : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: selected ? accent : soft, borderRadius: BorderRadius.circular(14)),
                  child: Icon(_specializationIcon(value), color: selected ? Colors.white : accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          color: selected ? accent : AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(selectionLabel, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: selected ? accent : AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: selected ? accent : AppColors.outlineVariant),
                  ),
                  child: Icon(selected ? Icons.check_rounded : Icons.add_rounded, color: selected ? Colors.white : accent, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingPrimaryCard extends StatelessWidget {
  const _PendingPrimaryCard({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.pendingBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.goldSoftStrong),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, color: AppColors.goldDark),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('طلب قيد مراجعة الإدارة', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.pendingText)),
                const SizedBox(height: 3),
                Text('التخصص الرئيسي المطلوب: $value', style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.title,
    required this.value,
    this.emphasized = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final accent = emphasized ? AppColors.goldDark : AppColors.secondaryDark;
    final soft = emphasized ? AppColors.goldLight : AppColors.secondaryContainer;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [soft, AppColors.surface], begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accent.withValues(alpha: .22)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
                const SizedBox(height: 3),
                Text(value, style: TextStyle(color: accent, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.background,
  });

  final String number;
  final String title;
  final String subtitle;
  final Color accent;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
          child: Text(number, style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 12)),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

Color _specializationAccent(String value) {
  final index = LegalSpecializations.all.indexOf(value);
  switch ((index < 0 ? value.length : index) % 6) {
    case 0:
      return AppColors.primary;
    case 1:
      return AppColors.secondaryDark;
    case 2:
      return AppColors.teal;
    case 3:
      return AppColors.goldDark;
    case 4:
      return AppColors.success;
    default:
      return const Color(0xFF6C5AA8);
  }
}

Color _specializationSoft(String value) {
  final index = LegalSpecializations.all.indexOf(value);
  switch ((index < 0 ? value.length : index) % 6) {
    case 0:
      return AppColors.primaryFixed;
    case 1:
      return AppColors.secondaryContainer;
    case 2:
      return const Color(0xFFE8F7F8);
    case 3:
      return AppColors.goldLight;
    case 4:
      return AppColors.acceptedBg;
    default:
      return const Color(0xFFF0ECFA);
  }
}

IconData _specializationIcon(String value) {
  if (value.contains('جنائي') || value.contains('مخدرات') || value.contains('إلكترونية')) {
    return Icons.policy_rounded;
  }
  if (value.contains('أسرة') || value.contains('شخصية') || value.contains('زواج') || value.contains('طلاق') || value.contains('نفقة') || value.contains('حضانة') || value.contains('إرث')) {
    return Icons.family_restroom_rounded;
  }
  if (value.contains('شركة') || value.contains('شركات') || value.contains('تجاري') || value.contains('استثمار') || value.contains('وكالات')) {
    return Icons.business_center_rounded;
  }
  if (value.contains('عقار') || value.contains('إيجار') || value.contains('مقاولات')) {
    return Icons.home_work_outlined;
  }
  if (value.contains('عقد') || value.contains('صياغة') || value.contains('مناقصات')) {
    return Icons.description_outlined;
  }
  if (value.contains('مصارف') || value.contains('تمويل') || value.contains('ضرائب') || value.contains('كمارك') || value.contains('ديون')) {
    return Icons.account_balance_rounded;
  }
  if (value.contains('عسكري') || value.contains('الأمن')) {
    return Icons.security_rounded;
  }
  if (value.contains('عمال') || value.contains('العمل') || value.contains('ضمان')) {
    return Icons.groups_rounded;
  }
  return Icons.balance_rounded;
}
