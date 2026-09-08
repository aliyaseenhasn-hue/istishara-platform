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

  const CreateBookingPage({super.key, required this.lawyer, this.service, this.isCustom = false});

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(message, textAlign: TextAlign.right)));
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
      final profile = await SupabaseConfig.client.from('profiles').select('id').eq('auth_id', authUser.id).maybeSingle();
      final followerId = profile?['id']?.toString();
      if (followerId == null || followerId.isEmpty) {
        _showMessage('تعذر تحديد حساب طالب الاستشارة');
        return;
      }
      final existing = await SupabaseConfig.client
          .from('lawyer_followers')
          .select('lawyer_id')
          .eq('follower_id', followerId)
          .eq('lawyer_id', widget.lawyer.profileId)
          .maybeSingle();
      if (existing == null) {
        await SupabaseConfig.client.from('lawyer_followers').insert({'follower_id': followerId, 'lawyer_id': widget.lawyer.profileId});
      }
      if (!mounted) return;
      _showMessage('تمت متابعة المحامي. في حال توفر موعد سيتم إشعارك.');
      await Future<void>.delayed(const Duration(milliseconds: 750));
      if (mounted) context.go('/home');
    } catch (_) {
      _showMessage('تعذر متابعة المحامي حالياً. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _followingLawyer = false);
    }
  }

  bool _validateStep() {
    if (_step == 0) {
      if (!widget.isCustom && _package == null) {
        _showMessage('يرجى اختيار نوع الاستشارة');
        return false;
      }
      if (widget.isCustom && _customConsultationTypeController.text.trim().isEmpty) {
        _showMessage('يرجى كتابة نوع الاستشارة');
        return false;
      }
    }
    if (_step == 2 && _selectedSlot == null) {
      _showMessage('يرجى اختيار موعد');
      return false;
    }
    return true;
  }

  Future<void> _continue() async {
    if (!_validateStep()) return;
    if (_step < 3) {
      setState(() => _step++);
      return;
    }
    await _submitBooking();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty || result.files.single.bytes == null) return;
    setState(() {
      _fileBytes = result.files.single.bytes;
      _fileName = result.files.single.name;
    });
  }

  Future<void> _submitBooking() async {
    final user = ref.read(authStateChangesProvider).value;
    if (user == null) {
      _showMessage('يرجى تسجيل الدخول أولاً');
      return;
    }
    final type = widget.isCustom ? _customConsultationTypeController.text.trim() : _consultationType;
    final booking = await ref.read(bookingsControllerProvider.notifier).createBooking(
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
      _showMessage(error?.toString().replaceFirst('Exception: ', '') ?? 'تعذر إنشاء الحجز');
      return;
    }
    await context.push(booking.paymentRequired && _consultationMode != 'في المكتب' ? '/upload-payment' : '/booking-details', extra: booking);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookingsControllerProvider);
    final slots = ref.watch(availableSlotsProvider(widget.lawyer.profileId));
    final releaseSettings = ref.watch(appReleaseSettingsProvider);
    final hasLoadedSlots = slots.hasValue;
    final noSlots = hasLoadedSlots && (slots.valueOrNull?.isEmpty ?? true);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.background,
      appBar: AppBar(centerTitle: true, elevation: 0, title: const Text('طلب استشارة', style: TextStyle(fontWeight: FontWeight.w900))),
      body: SafeArea(
        child: slots.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _StateView(
            icon: Icons.cloud_off_outlined,
            title: 'تعذر تحميل المواعيد',
            message: 'تعذر التحقق من مواعيد المحامي حالياً. حاول مرة أخرى.',
            action: FilledButton.icon(onPressed: () => ref.invalidate(availableSlotsProvider(widget.lawyer.profileId)), icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
          ),
          data: (items) {
            if (items.isEmpty) {
              return _NoSlotsView(
                lawyer: widget.lawyer,
                loading: _followingLawyer,
                onFollow: _followLawyerAndReturnHome,
                onCancel: () => context.go('/home'),
              );
            }
            return Column(
              children: [
                _ProgressHeader(step: _step),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _LawyerSummary(lawyer: widget.lawyer),
                      const SizedBox(height: 14),
                      releaseSettings.when(
                        data: (settings) => settings['free_beta_enabled'] == true
                            ? _FreeBetaNotice(text: settings['beta_notice']?.toString() ?? 'الاستشارات مجانية خلال الفترة التجريبية، ولن يتم تحصيل أي مبلغ.')
                            : const SizedBox.shrink(),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      if (releaseSettings.valueOrNull?['free_beta_enabled'] == true) const SizedBox(height: 14),
                      _buildStepContent(items),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: !hasLoadedSlots || noSlots
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(children: [
                if (_step > 0) ...[
                  SizedBox(width: 54, height: 52, child: OutlinedButton(onPressed: state.isLoading ? null : () => setState(() => _step--), child: const Icon(Icons.arrow_back_rounded))),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: state.isLoading ? null : _continue,
                      icon: state.isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(_step == 3 ? Icons.check_rounded : Icons.arrow_forward_rounded),
                      label: Text(_step == 3 ? 'إرسال طلب الاستشارة' : 'متابعة', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                  ),
                ),
              ]),
            ),
    );
  }

  Widget _buildStepContent(List<AvailableBookingSlot> slots) {
    switch (_step) {
      case 0:
        return _StepCard(
          title: 'معلومات الاستشارة',
          subtitle: 'اختر نوع الاستشارة وطريقة تنفيذها.',
          icon: Icons.forum_outlined,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!widget.isCustom && widget.lawyer.services.isNotEmpty)
              ...widget.lawyer.services.map((service) => _SelectablePackage(service: service, selected: _package?.id == service.id, onTap: () => setState(() => _package = service)))
            else
              TextField(controller: _customConsultationTypeController, decoration: const InputDecoration(labelText: 'نوع الاستشارة', hintText: 'اكتب نوع الاستشارة', prefixIcon: Icon(Icons.balance_outlined))),
            const SizedBox(height: 14),
            _SelectField<String>(label: 'طريقة التنفيذ', value: _consultationMode, items: const ['عن بعد', 'في المكتب'], icon: Icons.location_on_outlined, onChanged: (value) => setState(() => _consultationMode = value)),
            const SizedBox(height: 12),
            _SelectField<String>(label: 'نوع التواصل', value: _consultationType, items: const ['نصية', 'صوتية', 'مرئية'], icon: Icons.chat_bubble_outline, onChanged: (value) => setState(() => _consultationType = value)),
          ]),
        );
      case 1:
        return _StepCard(
          title: 'تفاصيل الطلب',
          subtitle: 'اكتب ملخصاً واضحاً لموضوع الاستشارة.',
          icon: Icons.description_outlined,
          child: TextField(controller: _descriptionController, minLines: 6, maxLines: 9, decoration: const InputDecoration(labelText: 'تفاصيل الاستشارة', hintText: 'اكتب الوقائع أو السؤال القانوني الذي تريد مناقشته...', alignLabelWithHint: true)),
        );
      case 2:
        return _StepCard(
          title: 'اختر الموعد والمدة',
          subtitle: 'كل موعد يوضح المدة والسعر الذي حدده المحامي.',
          icon: Icons.calendar_month_outlined,
          child: Column(children: slots.map((slot) => _SelectableSlot(slot: slot, selected: _selectedSlot?.id == slot.id, onTap: () => setState(() => _selectedSlot = slot))).toList()),
        );
      case 3:
        return _StepCard(
          title: 'مراجعة الطلب',
          subtitle: 'تأكد من المعلومات قبل الإرسال.',
          icon: Icons.fact_check_outlined,
          child: Column(children: [
            _ReviewRow(label: 'المحامي', value: widget.lawyer.fullName ?? 'محامي'),
            _ReviewRow(label: 'الخدمة', value: widget.isCustom ? 'استشارة مختلفة' : (_package?.title ?? 'غير محددة')),
            _ReviewRow(label: 'نوع التواصل', value: widget.isCustom ? _customConsultationTypeController.text.trim() : _consultationType),
            _ReviewRow(label: 'طريقة التنفيذ', value: _consultationMode),
            if (_selectedSlot != null) ...[
              _ReviewRow(label: 'الموعد', value: _formatSlot(_selectedSlot!)),
              _ReviewRow(label: 'المدة', value: '${_selectedSlot!.durationMinutes} دقيقة'),
              _ReviewRow(label: 'السعر', value: _selectedSlot!.price == null ? 'حسب الباقة' : '${_selectedSlot!.price!.toStringAsFixed(0)} د.ع'),
            ],
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _pickFile, icon: const Icon(Icons.attach_file_rounded), label: Text(_fileName ?? 'إرفاق مستند (اختياري)'))),
          ]),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _formatSlot(AvailableBookingSlot slot) {
    final date = '${slot.startsAt.day}/${slot.startsAt.month}/${slot.startsAt.year}';
    final time = TimeOfDay.fromDateTime(slot.startsAt).format(context);
    return '$date $time';
  }
}

class _NoSlotsView extends StatelessWidget {
  final LawyerProfile lawyer;
  final bool loading;
  final VoidCallback onFollow;
  final VoidCallback onCancel;
  const _NoSlotsView({required this.lawyer, required this.loading, required this.onFollow, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = lawyer.fullName?.trim().isNotEmpty == true ? lawyer.fullName!.trim() : 'المحامي';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(radius: 38, backgroundColor: scheme.primaryContainer, backgroundImage: lawyer.avatarUrl?.isNotEmpty == true ? NetworkImage(lawyer.avatarUrl!) : null, child: lawyer.avatarUrl?.isNotEmpty == true ? null : Icon(Icons.person_outline_rounded, color: scheme.primary, size: 34)),
          const SizedBox(height: 14),
          Text(name, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurface, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 22),
          Icon(Icons.event_busy_outlined, size: 52, color: scheme.primary),
          const SizedBox(height: 14),
          Text('لا توجد مواعيد متاحة', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurface, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text('لا توجد مواعيد متاحة لدى هذا المحامي حالياً. يمكنك متابعة المحامي وسيتم إشعارك فور إضافة موعد جديد.', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.6)),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 50, child: FilledButton.icon(onPressed: loading ? null : onFollow, icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.notifications_active_outlined), label: const Text('تابع المحامي', style: TextStyle(fontWeight: FontWeight.w800)))),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, height: 48, child: OutlinedButton(onPressed: loading ? null : onCancel, child: const Text('إلغاء'))),
        ]),
      ),
    );
  }
}

class _StateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget action;
  const _StateView({required this.icon, required this.title, required this.message, required this.action});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 44, color: scheme.primary), const SizedBox(height: 14), Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text(message, textAlign: TextAlign.center), const SizedBox(height: 16), action])));
  }
}

class _ProgressHeader extends StatelessWidget {
  final int step;
  const _ProgressHeader({required this.step});
  @override
  Widget build(BuildContext context) {
    const labels = ['النوع', 'التفاصيل', 'الموعد', 'التأكيد'];
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(children: List.generate(labels.length, (index) {
        final active = index <= step;
        return Expanded(child: Column(children: [
          CircleAvatar(radius: 14, backgroundColor: active ? AppColors.ctaGold : scheme.surfaceContainerHighest, child: Text('${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          const SizedBox(height: 4),
          Text(labels[index], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5)),
        ]));
      })),
    );
  }
}

class _LawyerSummary extends StatelessWidget {
  final LawyerProfile lawyer;
  const _LawyerSummary({required this.lawyer});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(18), border: Border.all(color: scheme.outlineVariant)),
      child: Row(children: [
        CircleAvatar(radius: 28, backgroundImage: lawyer.avatarUrl == null ? null : NetworkImage(lawyer.avatarUrl!), child: lawyer.avatarUrl == null ? const Icon(Icons.person_outline_rounded) : null),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(lawyer.fullName ?? 'محامي', style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(lawyer.specializations.isEmpty ? 'استشارات قانونية' : lawyer.specializations.take(2).join(' • '))])),
      ]),
    );
  }
}

class _FreeBetaNotice extends StatelessWidget {
  final String text;
  const _FreeBetaNotice({required this.text});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(16)), child: Row(children: [Icon(Icons.science_outlined, color: scheme.onSecondaryContainer), const SizedBox(width: 10), Expanded(child: Text(text, textAlign: TextAlign.right, style: TextStyle(color: scheme.onSecondaryContainer, height: 1.45, fontWeight: FontWeight.w700)))]));
  }
}

class _StepCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  const _StepCard({required this.title, required this.subtitle, required this.icon, required this.child});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: scheme.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Row(children: [Icon(icon), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(subtitle)]))]), const SizedBox(height: 18), child]),
    );
  }
}

class _SelectablePackage extends StatelessWidget {
  final LawyerService service;
  final bool selected;
  final VoidCallback onTap;
  const _SelectablePackage({required this.service, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: selected ? AppColors.ctaGold : Theme.of(context).colorScheme.outlineVariant, width: selected ? 1.5 : 1)),
        child: Row(children: [Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off), const SizedBox(width: 10), Expanded(child: Text(service.title, style: const TextStyle(fontWeight: FontWeight.w800))), Text('${service.price.toStringAsFixed(0)} د.ع')]),
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
  const _SelectField({required this.label, required this.value, required this.items, required this.icon, required this.onChanged});
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(initialValue: value, isExpanded: true, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)), items: items.map((item) => DropdownMenuItem<T>(value: item, child: Text('$item'))).toList(), onChanged: (next) { if (next != null) onChanged(next); });
}

class _SelectableSlot extends StatelessWidget {
  final AvailableBookingSlot slot;
  final bool selected;
  final VoidCallback onTap;
  const _SelectableSlot({required this.slot, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(slot.startsAt).format(context);
    final date = '${slot.startsAt.day}/${slot.startsAt.month}/${slot.startsAt.year}';
    final priceText = slot.price == null ? 'حسب الباقة' : '${slot.price!.toStringAsFixed(0)} د.ع';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: selected ? AppColors.ctaGold : Theme.of(context).colorScheme.outlineVariant, width: selected ? 1.5 : 1)),
        child: Row(children: [
          Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$date • $time', style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text('${slot.durationMinutes} دقيقة • $priceText', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12))])),
        ]),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReviewRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [SizedBox(width: 105, child: Text(label)), Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700)))]));
}
