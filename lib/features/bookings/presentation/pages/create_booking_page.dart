import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../lawyers/domain/entities/lawyer_profile.dart';
import '../providers/bookings_provider.dart';

class CreateBookingPage extends ConsumerStatefulWidget {
  final LawyerProfile lawyer;
  final LawyerService? service;
  final bool isCustom;

  const CreateBookingPage({
    super.key,
    required this.lawyer,
    this.service,
    this.isCustom = false,
  });

  @override
  ConsumerState<CreateBookingPage> createState() => _CreateBookingPageState();
}

class _CreateBookingPageState extends ConsumerState<CreateBookingPage> {
  int _step = 0;
  LawyerService? _package;
  String _consultationType = 'نصية';
  String _consultationMode = 'عن بعد';
  AvailableBookingSlot? _selectedSlot;
  final _descriptionController = TextEditingController();
  final _customConsultationTypeController = TextEditingController();
  Uint8List? _fileBytes;
  String? _fileName;
  bool _followingLawyer = false;

  @override
  void initState() {
    super.initState();
    _package = widget.service;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _customConsultationTypeController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(message, textAlign: TextAlign.right),
      ),
    );
  }

  bool _validateStep() {
    switch (_step) {
      case 0:
        if (!widget.isCustom && _package == null) {
          _showMessage('يرجى اختيار نوع الاستشارة');
          return false;
        }
        if (widget.isCustom &&
            _customConsultationTypeController.text.trim().isEmpty) {
          _showMessage('يرجى كتابة نوع الاستشارة');
          return false;
        }
        return true;
      case 2:
        if (_selectedSlot == null) {
          _showMessage('يرجى اختيار موعد');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  Future<void> _continue() async {
    if (!_validateStep()) return;
    if (_step < 3) {
      setState(() => _step++);
      return;
    }
    await _submitBooking();
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  void _cancelAndReturnHome() {
    context.go('/home');
  }

  Future<void> _followLawyerAndReturnHome() async {
    if (_followingLawyer) return;
    setState(() => _followingLawyer = true);
    try {
      final authUser = SupabaseConfig.client.auth.currentUser;
      if (authUser == null) {
        _showMessage('يرجى تسجيل الدخول أولاً');
        return;
      }

      final profile = await SupabaseConfig.client
          .from('profiles')
          .select('id')
          .eq('auth_id', authUser.id)
          .maybeSingle();
      final profileId = profile?['id']?.toString();
      if (profileId == null || profileId.isEmpty) {
        _showMessage('تعذر تحديد حساب طالب الاستشارة');
        return;
      }

      final existing = await SupabaseConfig.client
          .from('lawyer_followers')
          .select('lawyer_id')
          .eq('follower_id', profileId)
          .eq('lawyer_id', widget.lawyer.profileId)
          .maybeSingle();

      if (existing == null) {
        await SupabaseConfig.client.from('lawyer_followers').insert({
          'follower_id': profileId,
          'lawyer_id': widget.lawyer.profileId,
        });
      }

      if (!mounted) return;
      _showMessage('تمت متابعة المحامي. في حال توفر موعد سيتم إشعارك.');
      await Future<void>.delayed(const Duration(milliseconds: 850));
      if (mounted) context.go('/home');
    } catch (e) {
      _showMessage(
        'تعذر متابعة المحامي: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) setState(() => _followingLawyer = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) return;
    setState(() {
      _fileBytes = file.bytes;
      _fileName = file.name;
    });
  }

  Future<void> _submitBooking() async {
    final user = ref.read(authStateChangesProvider).value;
    if (user == null) {
      _showMessage('يرجى تسجيل الدخول أولاً');
      return;
    }
    final type = widget.isCustom
        ? _customConsultationTypeController.text.trim()
        : _consultationType;
    final booking = await ref
        .read(bookingsControllerProvider.notifier)
        .createBooking(
          lawyerId: widget.lawyer.profileId,
          serviceId: _package?.id,
          scheduledAt: _selectedSlot?.startsAt,
          slotId: _selectedSlot?.id,
          consultationType: type,
          consultationMode: _consultationMode,
          description: _descriptionController.text.trim(),
          documentBytes: _fileBytes,
          documentName: _fileName,
        );
    if (!mounted) return;
    if (booking == null) {
      final error = ref.read(bookingsControllerProvider).error;
      _showMessage(
        error?.toString().replaceFirst('Exception: ', '') ??
            'تعذر إنشاء الحجز',
      );
      return;
    }
    await context.push(
      booking.paymentRequired && _consultationMode != 'في المكتب'
          ? '/upload-payment'
          : '/booking-details',
      extra: booking,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookingsControllerProvider);
    final slots = ref.watch(availableSlotsProvider(widget.lawyer.profileId));
    final releaseSettings = ref.watch(appReleaseSettingsProvider);
    final noSlots = _step == 2 && slots.valueOrNull?.isEmpty == true;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'طلب استشارة',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            Text(
              'أكمل البيانات لإرسال طلبك',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: noSlots
            ? _NoSlotsView(
                lawyer: widget.lawyer,
                loading: _followingLawyer,
                onFollow: _followLawyerAndReturnHome,
                onCancel: _cancelAndReturnHome,
              )
            : Column(
                children: [
                  _ProgressHeader(step: _step),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _LawyerSummary(lawyer: widget.lawyer),
                          const SizedBox(height: 14),
                          releaseSettings.when(
                            data: (settings) =>
                                settings['free_beta_enabled'] == true
                                ? _FreeBetaNotice(
                                    text:
                                        settings['beta_notice']?.toString() ??
                                        'الاستشارات مجانية خلال الفترة التجريبية، ولن يتم تحصيل أي مبلغ.',
                                  )
                                : const SizedBox.shrink(),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                          if (releaseSettings
                                  .valueOrNull?['free_beta_enabled'] ==
                              true)
                            const SizedBox(height: 14),
                          _buildStepContent(slots),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: noSlots
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: _BottomActions(
                step: _step,
                loading: state.isLoading,
                onContinue: _continue,
                onBack: _step > 0 ? _back : null,
              ),
            ),
    );
  }

  Widget _buildStepContent(AsyncValue<List<AvailableBookingSlot>> slots) {
    switch (_step) {
      case 0:
        return _StepCard(
          title: 'معلومات الاستشارة',
          subtitle: 'اختر نوع الاستشارة وطريقة تنفيذها المناسبة لك.',
          icon: Icons.forum_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.isCustom && widget.lawyer.services.isNotEmpty)
                ...widget.lawyer.services.map(
                  (service) => _SelectablePackage(
                    service: service,
                    selected: _package?.id == service.id,
                    onTap: () => setState(() => _package = service),
                  ),
                )
              else
                TextField(
                  controller: _customConsultationTypeController,
                  decoration: const InputDecoration(
                    labelText: 'نوع الاستشارة',
                    hintText: 'اكتب نوع الاستشارة',
                    prefixIcon: Icon(Icons.balance_outlined),
                  ),
                ),
              const SizedBox(height: 14),
              _SelectField<String>(
                label: 'طريقة التنفيذ',
                value: _consultationMode,
                items: const ['عن بعد', 'في المكتب'],
                icon: Icons.location_on_outlined,
                onChanged: (value) =>
                    setState(() => _consultationMode = value),
              ),
              const SizedBox(height: 12),
              _SelectField<String>(
                label: 'نوع التواصل',
                value: _consultationType,
                items: const ['نصية', 'صوتية', 'مرئية'],
                icon: Icons.chat_bubble_outline,
                onChanged: (value) =>
                    setState(() => _consultationType = value),
              ),
            ],
          ),
        );
      case 1:
        return _StepCard(
          title: 'تفاصيل الطلب',
          subtitle: 'اكتب ملخصاً واضحاً لموضوع الاستشارة حتى يطلع عليه المحامي.',
          icon: Icons.description_outlined,
          child: TextField(
            controller: _descriptionController,
            minLines: 6,
            maxLines: 9,
            decoration: const InputDecoration(
              labelText: 'تفاصيل الاستشارة',
              hintText: 'اكتب الوقائع أو السؤال القانوني الذي تريد مناقشته...',
              alignLabelWithHint: true,
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 105),
                child: Icon(Icons.edit_note_rounded),
              ),
            ),
          ),
        );
      case 2:
        return _StepCard(
          title: 'اختر الموعد',
          subtitle: 'اختر أحد المواعيد المتاحة لدى المحامي.',
          icon: Icons.calendar_month_outlined,
          child: slots.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => _InfoBox(
              icon: Icons.cloud_off_outlined,
              title: 'تعذر تحميل المواعيد',
              text: error.toString(),
            ),
            data: (items) => Column(
              children: items
                  .map(
                    (slot) => _SelectableSlot(
                      slot: slot,
                      selected: _selectedSlot?.id == slot.id,
                      onTap: () => setState(() => _selectedSlot = slot),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      case 3:
        return _StepCard(
          title: 'مراجعة الطلب',
          subtitle: 'تأكد من المعلومات قبل إرسال طلب الاستشارة للمحامي.',
          icon: Icons.fact_check_outlined,
          child: Column(
            children: [
              _ReviewRow(
                label: 'المحامي',
                value: widget.lawyer.fullName ?? 'محامي',
              ),
              _ReviewRow(
                label: 'الخدمة',
                value: widget.isCustom
                    ? 'استشارة مختلفة'
                    : (_package?.title ?? 'غير محددة'),
              ),
              _ReviewRow(
                label: 'نوع التواصل',
                value: widget.isCustom
                    ? _customConsultationTypeController.text.trim()
                    : _consultationType,
              ),
              _ReviewRow(label: 'طريقة التنفيذ', value: _consultationMode),
              if (_selectedSlot != null)
                _ReviewRow(label: 'الموعد', value: _formatSlot(_selectedSlot!)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.attach_file_rounded),
                  label: Text(_fileName ?? 'إرفاق مستند (اختياري)'),
                ),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _formatSlot(AvailableBookingSlot slot) {
    final date =
        '${slot.startsAt.day}/${slot.startsAt.month}/${slot.startsAt.year}';
    final time = TimeOfDay.fromDateTime(slot.startsAt).format(context);
    return '$date $time';
  }
}

class _NoSlotsView extends StatelessWidget {
  final LawyerProfile lawyer;
  final bool loading;
  final VoidCallback onFollow;
  final VoidCallback onCancel;

  const _NoSlotsView({
    required this.lawyer,
    required this.loading,
    required this.onFollow,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasAvatar = lawyer.avatarUrl?.isNotEmpty == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .06),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: .08),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.event_busy_rounded,
                    color: AppColors.primary,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'لا توجد مواعيد متاحة حالياً',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'يمكنك الضغط على «متابعة المحامي» وسيتم إشعارك فور إضافة موعد جديد يمكنك حجزه.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      CircleAvatar(
                        radius: 23,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: .10),
                        backgroundImage:
                            hasAvatar ? NetworkImage(lawyer.avatarUrl!) : null,
                        child: hasAvatar
                            ? null
                            : const Icon(
                                Icons.person_outline_rounded,
                                color: AppColors.primary,
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              lawyer.fullName ?? 'محامٍ',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              lawyer.specializations.isEmpty
                                  ? 'استشارات قانونية'
                                  : lawyer.specializations.take(2).join(' • '),
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: loading ? null : onFollow,
                    icon: loading
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.notifications_active_outlined),
                    label: const Text(
                      'متابعة المحامي',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: loading ? null : onCancel,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text(
                      'إلغاء',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FreeBetaNotice extends StatelessWidget {
  final String text;
  const _FreeBetaNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Icon(Icons.science_outlined, color: scheme.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: scheme.onSecondaryContainer,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final int step;
  const _ProgressHeader({required this.step});

  @override
  Widget build(BuildContext context) {
    const labels = ['النوع', 'التفاصيل', 'الموعد', 'التأكيد'];
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: List.generate(labels.length, (index) {
          final active = index <= step;
          final current = index == step;
          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary
                        : scheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                    border: current
                        ? Border.all(color: AppColors.ctaGold, width: 2)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: active && index < step
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        )
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: active
                                ? Colors.white
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                ),
                const SizedBox(height: 5),
                Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: current ? FontWeight.w900 : FontWeight.w600,
                    color: current
                        ? AppColors.primary
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _LawyerSummary extends StatelessWidget {
  final LawyerProfile lawyer;
  const _LawyerSummary({required this.lawyer});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasAvatar = lawyer.avatarUrl?.isNotEmpty == true;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            AppColors.primary.withValues(alpha: .12),
            scheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: .14)),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primary.withValues(alpha: .10),
            backgroundImage: hasAvatar ? NetworkImage(lawyer.avatarUrl!) : null,
            child: hasAvatar
                ? null
                : const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'الاستشارة مع',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lawyer.fullName ?? 'محامٍ',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  lawyer.specializations.isEmpty
                      ? 'استشارات قانونية'
                      : lawyer.specializations.take(2).join(' • '),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11.5,
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

class _StepCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _StepCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _InfoBox({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(text, textAlign: TextAlign.right),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectablePackage extends StatelessWidget {
  final LawyerService service;
  final bool selected;
  final VoidCallback onTap;

  const _SelectablePackage({
    required this.service,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: .07)
              : scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : scheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: selected ? AppColors.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                service.title,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '${service.price.toStringAsFixed(0)} د.ع',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final IconData icon;
  final ValueChanged<T> onChanged;

  const _SelectField({
    required this.label,
    required this.value,
    required this.items,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      items: items
          .map((item) => DropdownMenuItem<T>(value: item, child: Text('$item')))
          .toList(),
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}

class _SelectableSlot extends StatelessWidget {
  final AvailableBookingSlot slot;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableSlot({
    required this.slot,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time = TimeOfDay.fromDateTime(slot.startsAt).format(context);
    final date =
        '${slot.startsAt.day}/${slot.startsAt.month}/${slot.startsAt.year}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: .07)
              : scheme.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected ? AppColors.primary : scheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                date,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(time, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final int step;
  final bool loading;
  final VoidCallback onContinue;
  final VoidCallback? onBack;

  const _BottomActions({
    required this.step,
    required this.loading,
    required this.onContinue,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final last = step == 3;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: loading ? null : onContinue,
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        last
                            ? Icons.check_rounded
                            : Icons.arrow_back_rounded,
                      ),
                label: Text(
                  last ? 'إرسال طلب الاستشارة' : 'متابعة',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
          if (onBack != null) ...[
            const SizedBox(width: 10),
            SizedBox(
              width: 54,
              height: 52,
              child: OutlinedButton(
                onPressed: loading ? null : onBack,
                child: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
