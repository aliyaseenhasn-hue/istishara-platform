import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _validateStep() {
    switch (_step) {
      case 0:
        if (!widget.isCustom && _package == null) {
          _showMessage('يرجى اختيار نوع الاستشارة');
          return false;
        }
        if (widget.isCustom && _customConsultationTypeController.text.trim().isEmpty) {
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
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text('طلب استشارة')),
      body: SafeArea(
        child: Column(
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
                      data: (settings) => settings['free_beta_enabled'] == true
                          ? _FreeBetaNotice(
                              text: settings['beta_notice']?.toString() ??
                                  'الاستشارات مجانية خلال الفترة التجريبية، ولن يتم تحصيل أي مبلغ.',
                            )
                          : const SizedBox.shrink(),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    if (releaseSettings.valueOrNull?['free_beta_enabled'] == true)
                      const SizedBox(height: 14),
                    _buildStepContent(slots),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
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
          title: 'نوع الاستشارة',
          subtitle: 'حدد طريقة التواصل وطريقة تنفيذ الموعد.',
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
                  decoration: const InputDecoration(labelText: 'نوع الاستشارة', hintText: 'اكتب نوع الاستشارة'),
                ),
              const SizedBox(height: 12),
              const _InfoBox(icon: Icons.info_outline, title: 'نوع التواصل', text: 'اختر طريقة التواصل المناسبة لك.'),
              const SizedBox(height: 12),
              _SelectField<String>(
                label: 'طريقة التنفيذ',
                value: _consultationMode,
                items: const ['عن بعد', 'في المكتب'],
                icon: Icons.location_on_outlined,
                onChanged: (value) => setState(() => _consultationMode = value),
              ),
              const SizedBox(height: 12),
              _SelectField<String>(
                label: 'نوع الاستشارة',
                value: _consultationType,
                items: const ['نصية', 'صوتية', 'مرئية'],
                icon: Icons.chat_bubble_outline,
                onChanged: (value) => setState(() => _consultationType = value),
              ),
            ],
          ),
        );
      case 1:
        return _StepCard(
          title: 'التفاصيل',
          subtitle: 'أضف تفاصيل طلبك للمحامي.',
          icon: Icons.description_outlined,
          child: TextField(
            controller: _descriptionController,
            minLines: 5,
            maxLines: 8,
            decoration: const InputDecoration(labelText: 'تفاصيل الاستشارة', hintText: 'اكتب تفاصيل طلبك هنا...', alignLabelWithHint: true),
          ),
        );
      case 2:
        return _StepCard(
          title: 'الموعد',
          subtitle: 'اختر الموعد المناسب لك.',
          icon: Icons.calendar_month_outlined,
          child: slots.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('تعذر تحميل المواعيد: $error'),
            data: (items) => items.isEmpty
                ? const _InfoBox(icon: Icons.event_busy_outlined, title: 'لا توجد مواعيد', text: 'لا توجد مواعيد متاحة حالياً لهذا المحامي.')
                : Column(
                    children: items.map((slot) => _SelectableSlot(
                      slot: slot,
                      selected: _selectedSlot?.id == slot.id,
                      onTap: () => setState(() => _selectedSlot = slot),
                    )).toList(),
                  ),
          ),
        );
      case 3:
        return _StepCard(
          title: 'مراجعة الطلب',
          subtitle: 'راجع البيانات قبل إرسال طلب الاستشارة.',
          icon: Icons.fact_check_outlined,
          child: Column(
            children: [
              _ReviewRow(label: 'المحامي', value: widget.lawyer.fullName ?? 'محامي'),
              _ReviewRow(label: 'الباقة', value: widget.isCustom ? 'استشارة مختلفة' : (_package?.title ?? 'غير محددة')),
              _ReviewRow(label: 'نوع الاستشارة', value: widget.isCustom ? _customConsultationTypeController.text.trim() : _consultationType),
              _ReviewRow(label: 'طريقة التنفيذ', value: _consultationMode),
              if (_selectedSlot != null) _ReviewRow(label: 'الموعد', value: _formatSlot(_selectedSlot!)),
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: _pickFile, icon: const Icon(Icons.attach_file_rounded), label: Text(_fileName ?? 'إرفاق مستند (اختياري)')),
            ],
          ),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, color: scheme.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.right,
              style: TextStyle(color: scheme.onSecondaryContainer, height: 1.45, fontWeight: FontWeight.w700),
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
    const labels = ['الباقة', 'التفاصيل', 'الموعد', 'التأكيد'];
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(children: List.generate(labels.length, (index) {
        final active = index <= step;
        return Expanded(child: Row(children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: active ? AppColors.ctaGold : scheme.surfaceContainerHighest,
            foregroundColor: active ? AppColors.primary : scheme.onSurfaceVariant,
            child: Text('${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 5),
          Expanded(child: Text(labels[index], overflow: TextOverflow.ellipsis)),
          if (index < labels.length - 1) Expanded(child: Divider(color: index < step ? AppColors.ctaGold : scheme.outlineVariant)),
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
        CircleAvatar(
          radius: 28,
          backgroundImage: lawyer.avatarUrl == null ? null : NetworkImage(lawyer.avatarUrl!),
          child: lawyer.avatarUrl == null ? const Icon(Icons.person_outline_rounded) : null,
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(lawyer.fullName ?? 'محامي', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(lawyer.specializations.isEmpty ? 'استشارات قانونية' : lawyer.specializations.take(2).join(' • ')),
        ])),
      ]),
    );
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [Icon(icon), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(subtitle)]))]),
        const SizedBox(height: 18),
        child,
      ]),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(text)]))]),
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
      borderRadius: BorderRadius.circular(16),
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
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      items: items.map((item) => DropdownMenuItem<T>(value: item, child: Text('$item'))).toList(),
      onChanged: (next) { if (next != null) onChanged(next); },
    );
  }
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: selected ? AppColors.ctaGold : Theme.of(context).colorScheme.outlineVariant, width: selected ? 1.5 : 1)),
        child: Row(children: [Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded), const SizedBox(width: 10), Expanded(child: Text(date)), Text(time, style: const TextStyle(fontWeight: FontWeight.w800))]),
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
    return Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [SizedBox(width: 105, child: Text(label)), Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700)))]));
  }
}

class _BottomActions extends StatelessWidget {
  final int step;
  final bool loading;
  final VoidCallback onContinue;
  final VoidCallback? onBack;
  const _BottomActions({required this.step, required this.loading, required this.onContinue, required this.onBack});
  @override
  Widget build(BuildContext context) {
    final last = step == 3;
    return Row(children: [
      if (onBack != null) ...[
        SizedBox(width: 54, height: 52, child: OutlinedButton(onPressed: loading ? null : onBack, child: const Icon(Icons.arrow_back_rounded))),
        const SizedBox(width: 10),
      ],
      Expanded(child: SizedBox(height: 52, child: FilledButton.icon(
        onPressed: loading ? null : onContinue,
        icon: loading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
            : Icon(last ? Icons.check_rounded : Icons.arrow_forward_rounded),
        label: Text(last ? 'إرسال طلب الاستشارة' : 'متابعة', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ))),
    ]);
  }
}
