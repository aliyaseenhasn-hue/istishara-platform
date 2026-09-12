import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_time_format.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../payments/presentation/providers/payments_provider.dart';
import '../../../reviews/presentation/widgets/review_dialog.dart';
import '../../domain/entities/booking.dart';
import '../providers/booking_timing_provider.dart';
import '../providers/bookings_provider.dart';
import '../widgets/booking_participant_identity_card.dart';

class BookingDetailsPage extends ConsumerWidget {
  final Booking booking;

  const BookingDetailsPage({super.key, required this.booking});

  DateTime? _dateFrom(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final details = ref.watch(bookingDetailsProvider(booking.id));
    final payment = ref.watch(bookingPaymentProvider(booking.id));
    final liveTiming = ref.watch(bookingTimingProvider(booking.id)).valueOrNull;
    final owner = ref.watch(authStateChangesProvider).value;
    final isLawyer = owner?.role == 'lawyer';
    final isOwner = !isLawyer && owner?.id == booking.userId;

    final currentStatus = liveTiming?['status']?.toString() ?? booking.status;
    final currentScheduledAt = _dateFrom(liveTiming?['scheduled_at']) ?? booking.scheduledAt;
    final currentStartedAt = _dateFrom(liveTiming?['started_at']) ?? booking.startedAt;
    final currentPaymentConfirmedAt =
        _dateFrom(liveTiming?['payment_confirmed_at']) ?? booking.paymentConfirmedAt;
    final currentDuration = int.tryParse(
          '${liveTiming?['package_duration_minutes'] ?? details.valueOrNull?['package_duration_minutes'] ?? booking.packageDurationMinutes}',
        ) ??
        booking.packageDurationMinutes;
    final currentPaymentRequired =
        liveTiming?['payment_required'] is bool ? liveTiming!['payment_required'] as bool : booking.paymentRequired;
    final currentLawyerApproved =
        liveTiming?['lawyer_approved'] is bool ? liveTiming!['lawyer_approved'] as bool : booking.lawyerApproved;

    final currentBooking = booking.copyWith(
      status: currentStatus,
      scheduledAt: currentScheduledAt,
      startedAt: currentStartedAt,
      paymentConfirmedAt: currentPaymentConfirmedAt,
      packageDurationMinutes: currentDuration,
      paymentRequired: currentPaymentRequired,
      lawyerApproved: currentLawyerApproved,
    );

    final clientName = isLawyer
        ? ref.watch(bookingClientNameProvider(booking.id))
        : const AsyncValue<String?>.data(null);
    final contact = ['مؤكد', 'قيد التنفيذ', 'مكتمل'].contains(currentStatus)
        ? ref.watch(bookingParticipantContactProvider(booking.id))
        : const AsyncValue<Map<String, dynamic>?>.data(null);
    final needsReview = isLawyer &&
        !currentLawyerApproved &&
        ['قيد انتظار الدفع', 'قيد معالجة الدفع', 'قيد مراجعة المحامي'].contains(currentStatus);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('تفاصيل الاستشارة'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _hero(context, currentStatus),
            const SizedBox(height: 12),
            _ConsultationTimingPanel(
              status: currentStatus,
              scheduledAt: currentScheduledAt,
              durationMinutes: currentDuration,
              startedAt: currentStartedAt,
              paymentRequired: currentPaymentRequired,
              paymentConfirmedAt: currentPaymentConfirmedAt,
              canStart: isLawyer,
              onStart: isLawyer
                  ? () => _updateStatus(context, ref, currentBooking, 'قيد التنفيذ')
                  : null,
            ),
            const SizedBox(height: 14),
            BookingParticipantIdentityCard(
              bookingId: booking.id,
              isLawyer: isLawyer,
              clientFallbackName: booking.userName,
              lawyerFallbackName: details.valueOrNull?['lawyer_name']?.toString() ?? booking.lawyerName,
            ),
            const SizedBox(height: 14),
            if (isLawyer) ...[
              _section(
                context,
                'بيانات طالب الاستشارة',
                Icons.person_outline_rounded,
                clientName.when(
                  data: (name) => Column(
                    children: [
                      _row(
                        context,
                        'اسم طالب الاستشارة',
                        name?.trim().isNotEmpty == true
                            ? name!.trim()
                            : (booking.userName?.trim().isNotEmpty == true
                                ? booking.userName!
                                : 'غير متوفر'),
                      ),
                      _row(context, 'نوع الحساب', 'طالب استشارة'),
                    ],
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => _row(
                    context,
                    'اسم طالب الاستشارة',
                    booking.userName?.trim().isNotEmpty == true ? booking.userName! : 'غير متوفر',
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            _section(
              context,
              'بيانات الحجز',
              Icons.calendar_month_outlined,
              details.when(
                data: (d) => Column(
                  children: [
                    if (isOwner)
                      _row(
                        context,
                        'اسم المحامي',
                        d?['lawyer_name']?.toString() ?? booking.lawyerName ?? 'غير متوفر',
                      ),
                    _row(context, 'الباقة', d?['package_name']?.toString() ?? 'استشارة قانونية'),
                    _row(
                      context,
                      'نوع الاستشارة',
                      d?['consultation_type']?.toString() ?? booking.consultationType ?? 'غير محددة',
                    ),
                    _row(
                      context,
                      'طريقة التنفيذ',
                      _consultationMethod(
                        d?['consultation_type']?.toString() ?? booking.consultationType,
                        d?['consultation_mode']?.toString() ?? booking.consultationMode,
                      ),
                    ),
                    _row(context, 'التاريخ', DateFormat('yyyy/MM/dd').format(currentScheduledAt)),
                    _row(context, 'الوقت', AppTimeFormat.time12(currentScheduledAt)),
                    _row(context, 'المدة', '$currentDuration دقيقة'),
                    _row(
                      context,
                      currentBooking.isFreeBeta ? 'السعر الأصلي' : 'الرسوم',
                      '${booking.price.toStringAsFixed(0)} د.ع',
                    ),
                    if (currentBooking.isFreeBeta)
                      _row(context, 'المبلغ المستحق', '0 د.ع — نسخة تجريبية مجانية'),
                  ],
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => Column(
                  children: [
                    _row(context, 'التاريخ', DateFormat('yyyy/MM/dd').format(currentScheduledAt)),
                    _row(context, 'الوقت', AppTimeFormat.time12(currentScheduledAt)),
                    _row(context, 'الرسوم', '${booking.price.toStringAsFixed(0)} د.ع'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _section(
              context,
              'وصف الموضوع',
              Icons.description_outlined,
              details.when(
                data: (d) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      d?['description']?.toString() ?? booking.description ?? 'لا يوجد وصف متاح.',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: scheme.onSurface, height: 1.6),
                    ),
                    if (d?['document_url'] != null || booking.documentUrl != null) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => _openUrl(
                          context,
                          (d?['document_url'] ?? booking.documentUrl).toString(),
                        ),
                        icon: const Icon(Icons.file_present_outlined),
                        label: const Text('فتح المستند المرفق'),
                      ),
                    ],
                  ],
                ),
                loading: () => const Text('جاري التحميل...'),
                error: (_, __) => Text(booking.description ?? 'لا يوجد وصف متاح.'),
              ),
            ),
            const SizedBox(height: 12),
            if (currentBooking.isFreeBeta)
              _section(
                context,
                'الفترة التجريبية',
                Icons.science_outlined,
                const Text('هذه الاستشارة مجانية ضمن النسخة التجريبية، ولن يتم تحصيل أي مبلغ أو إنشاء معاملة دفع.'),
              )
            else
              _section(
                context,
                'حالة الدفع',
                Icons.receipt_long_outlined,
                payment.when(
                  data: (p) => p == null
                      ? const Text('لم يتم إرسال الدفع بعد.')
                      : Column(
                          children: [
                            _row(context, 'الوسيلة', _paymentMethod(p.paymentMethod)),
                            _row(context, 'حالة الدفع', _paymentStatus(p.status)),
                            if (p.transactionNumber != null)
                              _row(context, 'رقم العملية', p.transactionNumber!),
                          ],
                        ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('تعذر تحميل بيانات الدفع'),
                ),
              ),
            if (['مؤكد', 'قيد التنفيذ', 'مكتمل'].contains(currentStatus)) ...[
              const SizedBox(height: 12),
              _section(
                context,
                'معلومات التواصل',
                Icons.contact_phone_outlined,
                contact.when(
                  data: (c) => c == null
                      ? const Text('لا توجد معلومات تواصل متاحة.')
                      : _contactContent(context, c, isLawyer, currentStatus),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(_friendlyError(e)),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (isOwner && currentPaymentRequired && currentStatus == 'قيد انتظار الدفع')
              ElevatedButton.icon(
                onPressed: () => context.push('/upload-payment', extra: currentBooking),
                icon: const Icon(Icons.payment_rounded),
                label: const Text('إكمال الدفع'),
              ),
            if (needsReview) ...[
              _infoCard(
                context,
                'هذا الطلب بانتظار مراجعتك. يمكنك الموافقة أو رفض الطلب.',
                Icons.rule_rounded,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _review(context, ref, true),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('الموافقة'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _review(context, ref, false),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('رفض الطلب'),
                    ),
                  ),
                ],
              ),
            ],
            if (isLawyer && currentStatus == 'قيد التنفيذ')
              ElevatedButton.icon(
                onPressed: () => _updateStatus(context, ref, currentBooking, 'مكتمل'),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('إنهاء الاستشارة'),
              ),
            if (_canPotentiallyReportNoShow(isLawyer, currentBooking))
              _NoShowReportAction(
                isLawyer: isLawyer,
                booking: currentBooking,
                onReport: () => _reportNoShow(context, ref, isLawyer),
              ),
            if (isOwner && currentStatus == 'مكتمل')
              ElevatedButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => ReviewDialog(bookingId: booking.id, lawyerId: booking.lawyerId),
                ),
                icon: const Icon(Icons.star_outline_rounded),
                label: const Text('تقييم الاستشارة'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, String status) {
    final s = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [s.primaryContainer, s.surfaceContainerHighest]),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: s.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: s.surface, borderRadius: BorderRadius.circular(16)),
            child: Icon(Icons.gavel_rounded, color: s.primary, size: 28),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'استشارة قانونية',
                  style: TextStyle(color: s.onSurface, fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: s.surface, borderRadius: BorderRadius.circular(30)),
                  child: Text(
                    status,
                    style: TextStyle(color: s.primary, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactContent(
    BuildContext context,
    Map<String, dynamic> c,
    bool isLawyer,
    String status,
  ) {
    final s = Theme.of(context).colorScheme;
    final name = isLawyer ? c['client_name'] ?? 'طالب استشارة' : c['lawyer_name'] ?? 'المحامي';
    final phone = isLawyer ? c['client_phone'] : c['lawyer_phone'];
    final whatsapp = isLawyer ? c['client_whatsapp'] : c['lawyer_whatsapp'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(name.toString(), style: TextStyle(fontWeight: FontWeight.bold, color: s.onSurface)),
        if (phone != null) _row(context, 'رقم الهاتف', phone.toString()),
        if (whatsapp != null && status == 'قيد التنفيذ')
          ElevatedButton.icon(
            onPressed: () => _openWhatsApp(context, whatsapp.toString()),
            icon: const Icon(Icons.chat_rounded),
            label: const Text('بدء الاستشارة عبر واتساب'),
          ),
      ],
    );
  }

  bool _canPotentiallyReportNoShow(bool isLawyer, Booking current) {
    if (isLawyer) {
      return current.status == 'مؤكد' ||
          (current.status == 'قيد التنفيذ' && current.startedAt != null);
    }
    return current.status == 'مؤكد' && current.startedAt == null;
  }

  Future<void> _review(BuildContext context, WidgetRef ref, bool approved) async {
    try {
      await ref.read(bookingsControllerProvider.notifier).reviewBooking(booking.id, approved);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approved ? 'تمت الموافقة على الحجز' : 'تم رفض الحجز')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
      }
    }
  }

  Future<void> _updateStatus(
    BuildContext context,
    WidgetRef ref,
    Booking current,
    String status,
  ) async {
    try {
      await ref.read(bookingsControllerProvider.notifier).updateBookingStatus(booking.id, status);
      if (context.mounted) {
        final updated = current.copyWith(
          status: status,
          startedAt: status == 'قيد التنفيذ' ? DateTime.now() : current.startedAt,
        );
        context.pushReplacement('/booking-details', extra: updated);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
      }
    }
  }

  Future<void> _reportNoShow(BuildContext context, WidgetRef ref, bool isLawyer) async {
    try {
      await ref.read(bookingsControllerProvider.notifier).reportNoShow(booking.id, isLawyer: isLawyer);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال بلاغ عدم الحضور إلى الإدارة للمراجعة.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
      }
    }
  }

  Future<void> _openWhatsApp(BuildContext context, String value) async {
    var phone = value.replaceAll(RegExp(r'[^0-9+]'), '');
    if (phone.startsWith('00')) phone = '+${phone.substring(2)}';
    if (phone.startsWith('07')) phone = '+964${phone.substring(1)}';
    final ok = await launchUrl(
      Uri.parse('https://wa.me/${phone.replaceAll('+', '')}'),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح واتساب')));
    }
  }

  Future<void> _openUrl(BuildContext context, String value) async {
    final ok = await launchUrl(Uri.parse(value), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح المستند')));
    }
  }

  String _consultationMethod(String? type, String? mode) {
    if (mode == 'في المكتب') return 'حضور في مكتب المحامي';
    return switch (type) {
      'نصية' => 'محادثة نصية عبر واتساب',
      'صوتية' => 'تواصل صوتي عبر واتساب',
      'فيديو' => 'مكالمة فيديو عبر واتساب',
      _ => 'عن بعد',
    };
  }

  String _paymentStatus(String value) => switch (value) {
        'pending' || 'قيد الانتظار' => 'قيد الانتظار',
        'submitted' || 'قيد المعالجة' => 'قيد المعالجة',
        'processing' => 'قيد المراجعة',
        'approved' || 'مقبول' || 'paid' => 'تمت الموافقة',
        'rejected' || 'مرفوض' => 'مرفوض',
        'refunded' || 'مسترد' => 'مسترد',
        'cancelled' || 'ملغي' => 'ملغي',
        _ => value,
      };

  String _paymentMethod(String value) => value.trim().isEmpty ? 'غير محددة' : value;

  String _friendlyError(Object error) {
    final raw = error.toString().trim();
    final lower = raw.toLowerCase();
    if (lower.contains('future already completed') || lower.contains('bad state')) {
      return 'تعذر إكمال العملية بسبب تزامن تحديث الحالة. انتظر لحظة ثم أعد المحاولة.';
    }
    if (lower.contains('postgrestexception')) {
      final match = RegExp(r'message:\s*([^,\)]+)', caseSensitive: false).firstMatch(raw);
      final message = match?.group(1)?.trim();
      if (message != null && message.isNotEmpty && !message.toLowerCase().contains('null')) {
        return message;
      }
      return 'تعذر تنفيذ العملية حالياً. يرجى المحاولة مرة أخرى.';
    }
    final cleaned = raw.replaceFirst('Exception: ', '').trim();
    if (cleaned.isEmpty) return 'تعذر تنفيذ العملية حالياً. يرجى المحاولة مرة أخرى.';
    return cleaned;
  }

  Widget _section(BuildContext context, String title, IconData icon, Widget child) {
    final s = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: s.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: s.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: s.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.right,
                  style: TextStyle(color: s.onSurface, fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final s = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(color: s.onSurface, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: s.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _infoCard(BuildContext context, String text, IconData icon) {
    final s = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: s.primaryContainer, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, color: s.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.right,
              style: TextStyle(color: s.onPrimaryContainer, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoShowReportAction extends StatefulWidget {
  final bool isLawyer;
  final Booking booking;
  final VoidCallback onReport;

  const _NoShowReportAction({
    required this.isLawyer,
    required this.booking,
    required this.onReport,
  });

  @override
  State<_NoShowReportAction> createState() => _NoShowReportActionState();
}

class _NoShowReportActionState extends State<_NoShowReportAction> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void didUpdateWidget(covariant _NoShowReportAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.booking.status != widget.booking.status ||
        oldWidget.booking.startedAt != widget.booking.startedAt ||
        oldWidget.booking.scheduledAt != widget.booking.scheduledAt ||
        oldWidget.booking.paymentConfirmedAt != widget.booking.paymentConfirmedAt ||
        oldWidget.booking.packageDurationMinutes != widget.booking.packageDurationMinutes) {
      _now = DateTime.now();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int get _duration => widget.booking.packageDurationMinutes > 0
      ? widget.booking.packageDurationMinutes
      : 30;

  DateTime get _eligibleAt {
    final booking = widget.booking;
    if (booking.status == 'قيد التنفيذ' && booking.startedAt != null) {
      return booking.startedAt!.add(Duration(minutes: _duration));
    }

    var eligibleAt = booking.scheduledAt.add(Duration(minutes: _duration));
    final confirmedAt = booking.paymentConfirmedAt;
    if (booking.paymentRequired &&
        confirmedAt != null &&
        confirmedAt.isAfter(booking.scheduledAt)) {
      final delayedStartDeadline = confirmedAt.add(const Duration(hours: 1));
      if (delayedStartDeadline.isAfter(eligibleAt)) {
        eligibleAt = delayedStartDeadline;
      }
    }
    return eligibleAt;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !_now.isBefore(_eligibleAt);
    final scheme = Theme.of(context).colorScheme;
    final label = widget.isLawyer
        ? 'الإبلاغ عن عدم حضور طالب الاستشارة'
        : 'الإبلاغ عن عدم حضور المحامي';

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: enabled ? widget.onReport : null,
            icon: const Icon(Icons.report_problem_outlined),
            label: Text(label),
          ),
          if (!enabled) ...[
            const SizedBox(height: 6),
            Text(
              'يتاح الإبلاغ عن عدم الحضور بعد انتهاء وقت الاستشارة عند ${AppTimeFormat.time12(_eligibleAt)}.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConsultationTimingPanel extends StatefulWidget {
  final String status;
  final DateTime scheduledAt;
  final int durationMinutes;
  final DateTime? startedAt;
  final bool paymentRequired;
  final DateTime? paymentConfirmedAt;
  final bool canStart;
  final VoidCallback? onStart;

  const _ConsultationTimingPanel({
    required this.status,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.startedAt,
    required this.paymentRequired,
    required this.paymentConfirmedAt,
    required this.canStart,
    required this.onStart,
  });

  @override
  State<_ConsultationTimingPanel> createState() => _ConsultationTimingPanelState();
}

class _ConsultationTimingPanelState extends State<_ConsultationTimingPanel> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void didUpdateWidget(covariant _ConsultationTimingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status ||
        oldWidget.startedAt != widget.startedAt ||
        oldWidget.paymentConfirmedAt != widget.paymentConfirmedAt ||
        oldWidget.scheduledAt != widget.scheduledAt) {
      _now = DateTime.now();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int get _duration => widget.durationMinutes > 0 ? widget.durationMinutes : 30;

  DateTime get _startDeadline {
    var deadline = widget.scheduledAt.add(Duration(minutes: _duration));
    final confirmedAt = widget.paymentConfirmedAt;
    if (widget.paymentRequired &&
        confirmedAt != null &&
        confirmedAt.isAfter(widget.scheduledAt)) {
      final delayedDeadline = confirmedAt.add(const Duration(hours: 1));
      if (delayedDeadline.isAfter(deadline)) deadline = delayedDeadline;
    }
    return deadline;
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status.trim();

    if (status == 'قيد التنفيذ' && widget.startedAt != null) {
      final endsAt = widget.startedAt!.add(Duration(minutes: _duration));
      final remaining = endsAt.difference(_now);
      if (remaining.inSeconds <= 0) {
        return _messageCard(
          context,
          title: 'انتهى الوقت المحدد للاستشارة',
          text: 'اكتملت المدة المحجوزة. يمكن للمحامي إنهاء الاستشارة من أسفل الصفحة.',
          icon: Icons.timer_off_outlined,
          success: false,
        );
      }
      return _countdownCard(
        context,
        title: 'الوقت المتبقي للاستشارة',
        remaining: remaining,
        subtitle: 'يُحسب الوقت من لحظة بدء الاستشارة الفعلية، وليس من الموعد الأصلي.',
        active: true,
      );
    }

    if (status == 'مؤكد') {
      final opensAt = widget.scheduledAt.subtract(const Duration(minutes: 5));
      if (_now.isBefore(opensAt)) {
        return _countdownCard(
          context,
          title: 'الوقت المتبقي لفتح الاستشارة',
          remaining: opensAt.difference(_now),
          subtitle: 'سيظهر زر البدء قبل الموعد بخمس دقائق.',
          active: false,
        );
      }

      final deadline = _startDeadline;
      if (!_now.isAfter(deadline)) {
        return _readyCard(context, deadline.difference(_now));
      }

      return _messageCard(
        context,
        title: 'انتهت نافذة بدء الاستشارة',
        text: widget.paymentRequired && widget.paymentConfirmedAt != null
            ? 'بعد تأكيد الدفع المتأخر يمنح النظام ساعة كاملة لبدء الاستشارة.'
            : 'انتهت نافذة البدء المحددة لهذا الموعد.',
        icon: Icons.timer_off_outlined,
        success: false,
      );
    }

    if (status == 'قيد انتظار الدفع' ||
        status == 'قيد معالجة الدفع' ||
        status == 'قيد مراجعة المحامي' ||
        status == 'بانتظار التأكيد') {
      if (_now.isBefore(widget.scheduledAt)) {
        return _countdownCard(
          context,
          title: 'الوقت المتبقي لموعد الاستشارة',
          remaining: widget.scheduledAt.difference(_now),
          subtitle: widget.paymentRequired
              ? 'الحجز محفوظ، ومدة الاستشارة لن تضيع إذا تأخر تأكيد الدفع من الإدارة.'
              : 'الحجز بانتظار اكتمال المراجعة.',
          active: false,
        );
      }
      return _messageCard(
        context,
        title: 'حان موعد الاستشارة',
        text: widget.paymentRequired
            ? 'بانتظار تأكيد الدفع. بعد التأكيد ستفتح نافذة بدء جديدة، وتبدأ مدة الاستشارة كاملة من لحظة الضغط على «بدء الاستشارة».'
            : 'بانتظار اكتمال مراجعة الحجز حتى يمكن بدء الاستشارة.',
        icon: Icons.hourglass_top_rounded,
        success: false,
      );
    }

    if (status == 'مكتمل') {
      return _messageCard(
        context,
        title: 'اكتملت الاستشارة',
        text: 'تم إنهاء هذه الاستشارة بنجاح.',
        icon: Icons.check_circle_outline_rounded,
        success: true,
      );
    }

    if (status == 'ملغي' || status == 'مسترد' || status.contains('رفض')) {
      return _messageCard(
        context,
        title: 'الاستشارة غير نشطة',
        text: status,
        icon: Icons.event_busy_outlined,
        success: false,
      );
    }

    return _messageCard(
      context,
      title: 'حالة الاستشارة',
      text: status.isEmpty ? 'بانتظار تحديث الحالة.' : status,
      icon: Icons.info_outline_rounded,
      success: false,
    );
  }

  Widget _readyCard(BuildContext context, Duration remainingWindow) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.acceptedBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.success.withValues(alpha: .42), width: 1.4),
        boxShadow: const [
          BoxShadow(color: Color(0x12000000), blurRadius: 16, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.play_circle_fill_rounded, color: AppColors.success, size: 27),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'الاستشارة متاحة للبدء الآن',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: AppColors.acceptedText,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _timeBoxes(context, remainingWindow, active: true),
          const SizedBox(height: 8),
          Text(
            'الوقت أعلاه هو المدة المتبقية لبدء الاستشارة. بعد البدء يبدأ عداد مدة الاستشارة الكامل من الصفر.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5, height: 1.4),
          ),
          if (widget.canStart && widget.onStart != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: widget.onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('بدء الاستشارة الآن'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            ),
          ] else ...[
            const SizedBox(height: 12),
            const Text(
              'بانتظار المحامي لبدء الاستشارة.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.acceptedText, fontWeight: FontWeight.w800),
            ),
          ],
        ],
      ),
    );
  }

  Widget _countdownCard(
    BuildContext context, {
    required String title,
    required Duration remaining,
    required String subtitle,
    required bool active,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: active ? AppColors.acceptedBg : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? AppColors.success.withValues(alpha: .38) : scheme.primary.withValues(alpha: .18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                active ? Icons.timer_rounded : Icons.timer_outlined,
                color: active ? AppColors.success : scheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: active ? AppColors.acceptedText : scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w900,
                    fontSize: 15.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _timeBoxes(context, remaining, active: active),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? AppColors.acceptedText : scheme.onPrimaryContainer,
              fontSize: 11.8,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeBoxes(BuildContext context, Duration duration, {required bool active}) {
    final safeSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
    final hours = safeSeconds ~/ 3600;
    final minutes = (safeSeconds % 3600) ~/ 60;
    final seconds = safeSeconds % 60;

    return Row(
      children: [
        Expanded(child: _timeBox(context, seconds.toString().padLeft(2, '0'), 'ثانية', active)),
        const SizedBox(width: 7),
        Expanded(child: _timeBox(context, minutes.toString().padLeft(2, '0'), 'دقيقة', active)),
        const SizedBox(width: 7),
        Expanded(child: _timeBox(context, hours.toString().padLeft(2, '0'), 'ساعة', active)),
      ],
    );
  }

  Widget _timeBox(
    BuildContext context,
    String value,
    String label,
    bool active,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .7)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: active ? AppColors.success : scheme.primary,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10.5)),
        ],
      ),
    );
  }

  Widget _messageCard(
    BuildContext context, {
    required String title,
    required String text,
    required IconData icon,
    required bool success,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: success ? AppColors.acceptedBg : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: success ? AppColors.success.withValues(alpha: .28) : scheme.primary.withValues(alpha: .14),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: success ? AppColors.success : scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: success ? AppColors.acceptedText : scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: success ? AppColors.acceptedText : scheme.onPrimaryContainer,
                    height: 1.45,
                    fontSize: 12.2,
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
