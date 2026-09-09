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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorText(error))),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر قراءة الملف المختار.')),
      );
      return;
    }
    setState(() => _idCard = file);
  }

  void _selectRequestedPrimary(String value) {
    if (_busy || _pendingPrimary != null || value == _currentPrimary) return;
    setState(() {
      _requestedPrimary = _requestedPrimary == value ? null : value;
      _idCard = null;
    });
  }

  void _toggleAdditional(String value, bool selected) {
    if (_busy || !_canChangeAdditional || value == _currentPrimary) return;
    if (selected) {
      if (_draftAdditional.contains(value)) return;
      if (_draftAdditional.length >= _maxAdditional) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يمكن اختيار مجالين إضافيين كحد أقصى.')),
        );
        return;
      }
      setState(() => _draftAdditional.add(value));
    } else {
      setState(() => _draftAdditional.remove(value));
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يمكن اختيار مجالين إضافيين كحد أقصى.')),
      );
      return;
    }

    setState(() => _savingAdditional = true);
    try {
      await SupabaseConfig.client.rpc(
        'update_additional_specializations',
        params: {'p_additional_specializations': List<String>.unmodifiable(_draftAdditional)},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث مجالات الممارسة الإضافية مباشرة.')),
      );
      await _loadStatus();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorText(error))),
      );
    } finally {
      if (mounted) setState(() => _savingAdditional = false);
    }
  }

  Future<void> _submitPrimaryChange() async {
    final requested = _requestedPrimary;
    final idCard = _idCard;
    if (_pendingPrimary != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لديك طلب تغيير تخصص رئيسي قيد مراجعة الإدارة بالفعل.')),
      );
      return;
    }
    if (requested == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر التخصص الرئيسي الجديد.')),
      );
      return;
    }
    if (idCard == null || idCard.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أرفق هوية النقابة لمراجعة تغيير التخصص الرئيسي.')),
      );
      return;
    }

    setState(() => _submittingPrimary = true);
    try {
      final repo = LawyersRepositoryImpl(SupabaseConfig.client);
      final url = await repo.uploadFile(idCard.bytes!, idCard.name, 'lawyer_documents');
      await repo.requestSpecializationChange(<String>[requested], unionIdCardUrl: url);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال طلب تغيير التخصص الرئيسي إلى الإدارة.')),
      );
      await _loadStatus();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorText(error))),
      );
    } finally {
      if (mounted) setState(() => _submittingPrimary = false);
    }
  }

  Widget _currentSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
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
    final available = _options.where((item) => item != _currentPrimary).toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(16),
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
            decoration: BoxDecoration(color: AppColors.primaryFixed, borderRadius: BorderRadius.circular(14)),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.admin_panel_settings_outlined, color: AppColors.primaryDark, size: 21),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'تغيير التخصص الرئيسي يحتاج مراجعة الإدارة وهوية النقابة. لا يتغير ملفك الحالي إلا بعد الموافقة.',
                    style: TextStyle(color: AppColors.primaryDark, height: 1.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          if (pending != null && pending.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.outline),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: AppColors.primaryDark),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('طلب قيد مراجعة الإدارة', style: TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text('التخصص الرئيسي المطلوب: $pending', style: const TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            const Text('اختر التخصص الرئيسي الجديد', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: available.map((item) {
                final selected = requested == item;
                return ChoiceChip(
                  label: Text(item),
                  selected: selected,
                  showCheckmark: true,
                  selectedColor: AppColors.primaryLight,
                  backgroundColor: AppColors.background,
                  side: BorderSide(color: selected ? AppColors.primary : AppColors.outline),
                  labelStyle: TextStyle(
                    color: selected ? AppColors.textOnPrimary : AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  ),
                  onSelected: _busy ? null : (_) => _selectRequestedPrimary(item),
                );
              }).toList(growable: false),
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
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _idCard == null ? AppColors.outline : AppColors.primary),
                ),
                child: Row(
                  children: [
                    Icon(
                      _idCard == null ? Icons.badge_outlined : Icons.check_circle_rounded,
                      color: _idCard == null ? AppColors.primaryDark : AppColors.success,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _idCard?.name ?? 'إرفاق هوية النقابة',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
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
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnPrimary),
                    )
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
    final available = _options.where((item) => item != primary).toList(growable: false);
    final locked = !_canChangeAdditional;

    return Container(
      padding: const EdgeInsets.all(16),
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
            decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(14)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(locked ? Icons.lock_clock_outlined : Icons.edit_note_rounded, color: AppColors.primaryDark, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    locked
                        ? 'تم تعديل مجالات الممارسة الإضافية مؤخراً. يمكنك التغيير مرة أخرى بتاريخ ${_formatDate(_nextAdditionalChangeAt)}.'
                        : 'يمكنك تغيير مجالات الممارسة الإضافية مباشرة دون مراجعة الإدارة، مرة واحدة كل 30 يوماً.',
                    style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'مجالات الممارسة الإضافية  ${_draftAdditional.length}/$_maxAdditional',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          const Text(
            'هذه المجالات تظهر للعميل كمجالات ممارسة إضافية وليست كتخصص رئيسي.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
          ),
          if (_draftAdditional.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _draftAdditional.map((item) {
                return Chip(
                  label: Text(item),
                  avatar: const Icon(Icons.check_circle_rounded, size: 17, color: AppColors.primaryDark),
                  deleteIcon: const Icon(Icons.close_rounded, size: 17),
                  onDeleted: locked || _busy ? null : () => _toggleAdditional(item, false),
                  backgroundColor: AppColors.primaryFixed,
                  side: const BorderSide(color: AppColors.primaryLight),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                );
              }).toList(growable: false),
            ),
          ],
          const SizedBox(height: 13),
          IgnorePointer(
            ignoring: locked || _busy || primary == null,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: locked || primary == null ? .45 : 1,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: available.map((item) {
                  final selected = _draftAdditional.contains(item);
                  final limitReached = !selected && _draftAdditional.length >= _maxAdditional;
                  return FilterChip(
                    label: Text(item),
                    selected: selected,
                    showCheckmark: true,
                    selectedColor: AppColors.primaryLight,
                    backgroundColor: AppColors.background,
                    side: BorderSide(color: selected ? AppColors.primary : AppColors.outline),
                    checkmarkColor: AppColors.textOnPrimary,
                    labelStyle: TextStyle(
                      color: selected ? AppColors.textOnPrimary : AppColors.textPrimary,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    ),
                    onSelected: limitReached ? null : (value) => _toggleAdditional(item, value),
                  );
                }).toList(growable: false),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: locked || _busy || !_additionalChanged ? null : _saveAdditional,
            icon: _savingAdditional
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnPrimary),
                  )
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
                          borderRadius: BorderRadius.circular(24),
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
                                    'إدارة تخصصاتك المهنية',
                                    style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    'الرئيسي يخضع لمراجعة الإدارة، أما مجالات الممارسة الإضافية فتديرها بنفسك وفق مدة 30 يوماً.',
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
                        subtitle: 'تغييره يحتاج طلباً ومراجعة الإدارة.',
                      ),
                      const SizedBox(height: 12),
                      _primarySection(),
                      const SizedBox(height: 26),
                      const _SectionTitle(
                        number: '02',
                        title: 'مجالات الممارسة الإضافية',
                        subtitle: 'حتى مجالين — تغيير مباشر مرة كل 30 يوماً.',
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
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: emphasized ? AppColors.primaryFixed : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryDark, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: emphasized ? AppColors.primaryDark : AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
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
