import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/utils/app_time_format.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../payments/presentation/providers/payments_provider.dart';
import '../../../reviews/presentation/widgets/review_dialog.dart';
import '../../domain/entities/booking.dart';
import '../providers/bookings_provider.dart';
import '../widgets/booking_participant_identity_card.dart';

class BookingDetailsPage extends ConsumerWidget {
  final Booking booking;
  const BookingDetailsPage({super.key, required this.booking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final details = ref.watch(bookingDetailsProvider(booking.id));
    final payment = ref.watch(bookingPaymentProvider(booking.id));
    final owner = ref.watch(authStateChangesProvider).value;
    final isLawyer = owner?.role == 'lawyer';
    final isOwner = !isLawyer && owner?.id == booking.userId;
    final clientName = isLawyer ? ref.watch(bookingClientNameProvider(booking.id)) : const AsyncValue<String?>.data(null);
    final contact = ['مؤكد', 'قيد التنفيذ', 'مكتمل'].contains(booking.status)
        ? ref.watch(bookingParticipantContactProvider(booking.id))
        : const AsyncValue<Map<String, dynamic>?>.data(null);
    final needsReview = isLawyer && !booking.lawyerApproved && ['قيد انتظار الدفع', 'قيد معالجة الدفع', 'قيد مراجعة المحامي'].contains(booking.status);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: const Text('تفاصيل الاستشارة'), leading: IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_forward_rounded))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _hero(context),
          const SizedBox(height: 14),
          BookingParticipantIdentityCard(
            bookingId: booking.id,
            isLawyer: isLawyer,
            clientFallbackName: booking.userName,
            lawyerFallbackName: details.valueOrNull?['lawyer_name']?.toString() ?? booking.lawyerName,
          ),
          const SizedBox(height: 14),
          if (isLawyer) ...[
            _section(context, 'بيانات طالب الاستشارة', Icons.person_outline_rounded, clientName.when(
              data: (name) => Column(children: [_row(context, 'اسم طالب الاستشارة', name?.trim().isNotEmpty == true ? name!.trim() : (booking.userName?.trim().isNotEmpty == true ? booking.userName! : 'غير متوفر')), _row(context, 'نوع الحساب', 'طالب استشارة')]),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => _row(context, 'اسم طالب الاستشارة', booking.userName?.trim().isNotEmpty == true ? booking.userName! : 'غير متوفر'),
            )),
            const SizedBox(height: 12),
          ],
          _section(context, 'بيانات الحجز', Icons.calendar_month_outlined, details.when(
            data: (d) => Column(children: [
              if (isOwner) _row(context, 'اسم المحامي', d?['lawyer_name']?.toString() ?? booking.lawyerName ?? 'غير متوفر'),
              _row(context, 'الباقة', d?['package_name']?.toString() ?? 'استشارة قانونية'),
              _row(context, 'نوع الاستشارة', d?['consultation_type']?.toString() ?? booking.consultationType ?? 'غير محددة'),
              _row(context, 'طريقة التنفيذ', _consultationMethod(d?['consultation_type']?.toString() ?? booking.consultationType, d?['consultation_mode']?.toString() ?? booking.consultationMode)),
              _row(context, 'التاريخ', DateFormat('yyyy/MM/dd').format(booking.scheduledAt)),
              _row(context, 'الوقت', AppTimeFormat.time12(booking.scheduledAt)),
              _row(context, 'المدة', '${d?['package_duration_minutes'] ?? 30} دقيقة'),
              _row(context, booking.isFreeBeta ? 'السعر الأصلي' : 'الرسوم', '${booking.price.toStringAsFixed(0)} د.ع'),
              if (booking.isFreeBeta) _row(context, 'المبلغ المستحق', '0 د.ع — نسخة تجريبية مجانية'),
            ]),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => Column(children: [_row(context, 'التاريخ', DateFormat('yyyy/MM/dd').format(booking.scheduledAt)), _row(context, 'الوقت', AppTimeFormat.time12(booking.scheduledAt)), _row(context, 'الرسوم', '${booking.price.toStringAsFixed(0)} د.ع')]),
          )),
          const SizedBox(height: 12),
          _section(context, 'وصف الموضوع', Icons.description_outlined, details.when(
            data: (d) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(d?['description']?.toString() ?? booking.description ?? 'لا يوجد وصف متاح.', textAlign: TextAlign.right, style: TextStyle(color: scheme.onSurface, height: 1.6)), if (d?['document_url'] != null || booking.documentUrl != null) ...[const SizedBox(height: 10), OutlinedButton.icon(onPressed: () => _openUrl(context, (d?['document_url'] ?? booking.documentUrl).toString()), icon: const Icon(Icons.file_present_outlined), label: const Text('فتح المستند المرفق'))]]),
            loading: () => const Text('جاري التحميل...'),
            error: (_, __) => Text(booking.description ?? 'لا يوجد وصف متاح.'),
          )),
          const SizedBox(height: 12),
          if (booking.isFreeBeta)
            _section(context, 'الفترة التجريبية', Icons.science_outlined, const Text('هذه الاستشارة مجانية ضمن النسخة التجريبية، ولن يتم تحصيل أي مبلغ أو إنشاء معاملة دفع.'))
          else
            _section(context, 'حالة الدفع', Icons.receipt_long_outlined, payment.when(
              data: (p) => p == null ? const Text('لم يتم إرسال الدفع بعد.') : Column(children: [_row(context, 'الوسيلة', _paymentMethod(p.paymentMethod)), _row(context, 'حالة الدفع', _paymentStatus(p.status)), if (p.transactionNumber != null) _row(context, 'رقم العملية', p.transactionNumber!)]),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('تعذر تحميل بيانات الدفع'),
            )),
          if (['مؤكد', 'قيد التنفيذ', 'مكتمل'].contains(booking.status)) ...[
            const SizedBox(height: 12),
            _section(context, 'معلومات التواصل', Icons.contact_phone_outlined, contact.when(data: (c) => c == null ? const Text('لا توجد معلومات تواصل متاحة.') : _contactContent(context, c, isLawyer), loading: () => const LinearProgressIndicator(), error: (e, _) => Text(_friendlyError(e)))),
          ],
          const SizedBox(height: 20),
          if (isOwner && booking.paymentRequired && booking.status == 'قيد انتظار الدفع') ElevatedButton.icon(onPressed: () => context.push('/upload-payment', extra: booking), icon: const Icon(Icons.payment_rounded), label: const Text('إكمال الدفع')),
          if (needsReview) ...[
            _infoCard(context, 'هذا الطلب بانتظار مراجعتك. يمكنك الموافقة أو رفض الطلب.', Icons.rule_rounded), const SizedBox(height: 10),
            Row(children: [Expanded(child: ElevatedButton.icon(onPressed: () => _review(context, ref, true), icon: const Icon(Icons.check_circle_outline), label: const Text('الموافقة'))), const SizedBox(width: 10), Expanded(child: OutlinedButton.icon(onPressed: () => _review(context, ref, false), icon: const Icon(Icons.cancel_outlined), label: const Text('رفض الطلب')))]),
          ],
          if (booking.status == 'مؤكد')
            _ConsultationStartCountdown(
              scheduledAt: booking.scheduledAt,
              durationMinutes: int.tryParse('${details.valueOrNull?['package_duration_minutes'] ?? 30}') ?? 30,
              canStart: isLawyer,
              onStart: isLawyer ? () => _updateStatus(context, ref, 'قيد التنفيذ') : null,
            ),
          if (isLawyer && booking.status == 'قيد التنفيذ') ElevatedButton.icon(onPressed: () => _updateStatus(context, ref, 'مكتمل'), icon: const Icon(Icons.check_circle_outline), label: const Text('إنهاء الاستشارة')),
          if (_canReportNoShow(isLawyer)) OutlinedButton.icon(onPressed: () => _reportNoShow(context, ref, isLawyer), icon: const Icon(Icons.report_problem_outlined), label: Text(isLawyer ? 'الإبلاغ عن عدم حضور طالب الاستشارة' : 'الإبلاغ عن عدم حضور المحامي')),
          if (isOwner && booking.status == 'مكتمل') ElevatedButton.icon(onPressed: () => showDialog(context: context, builder: (_) => ReviewDialog(bookingId: booking.id, lawyerId: booking.lawyerId)), icon: const Icon(Icons.star_outline_rounded), label: const Text('تقييم الاستشارة')),
        ]),
      ),
    );
  }

  Widget _hero(BuildContext context) { final s = Theme.of(context).colorScheme; return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(colors: [s.primaryContainer, s.surfaceContainerHighest]), borderRadius: BorderRadius.circular(22), border: Border.all(color: s.outlineVariant)), child: Row(children: [Container(width: 52, height: 52, decoration: BoxDecoration(color: s.surface, borderRadius: BorderRadius.circular(16)), child: Icon(Icons.gavel_rounded, color: s.primary, size: 28)), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('استشارة قانونية', style: TextStyle(color: s.onSurface, fontSize: 19, fontWeight: FontWeight.w800)), const SizedBox(height: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: s.surface, borderRadius: BorderRadius.circular(30)), child: Text(booking.status, style: TextStyle(color: s.primary, fontWeight: FontWeight.bold, fontSize: 12))) ]))])); }

  Widget _contactContent(BuildContext context, Map<String, dynamic> c, bool isLawyer) { final s = Theme.of(context).colorScheme; final name = isLawyer ? c['client_name'] ?? 'طالب استشارة' : c['lawyer_name'] ?? 'المحامي'; final phone = isLawyer ? c['client_phone'] : c['lawyer_phone']; final whatsapp = isLawyer ? c['client_whatsapp'] : c['lawyer_whatsapp']; return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(name.toString(), style: TextStyle(fontWeight: FontWeight.bold, color: s.onSurface)), if (phone != null) _row(context, 'رقم الهاتف', phone.toString()), if (whatsapp != null && booking.status == 'قيد التنفيذ') ElevatedButton.icon(onPressed: () => _openWhatsApp(context, whatsapp.toString()), icon: const Icon(Icons.chat_rounded), label: const Text('بدء الاستشارة عبر واتساب'))]); }
  bool _canReportNoShow(bool isLawyer) { final now = DateTime.now(); if (isLawyer) { if (booking.status == 'مؤكد') return !now.isBefore(booking.scheduledAt.add(const Duration(minutes: 10))); if (booking.status == 'قيد التنفيذ' && booking.startedAt != null) return !now.isBefore(booking.startedAt!.add(const Duration(minutes: 10))); return false; } return booking.status == 'مؤكد' && booking.startedAt == null && !now.isBefore(booking.scheduledAt.add(const Duration(minutes: 10))); }
  Future<void> _review(BuildContext context, WidgetRef ref, bool approved) async { try { await ref.read(bookingsControllerProvider.notifier).reviewBooking(booking.id, approved); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(approved ? 'تمت الموافقة على الحجز' : 'تم رفض الحجز'))); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(e)))); } }
  Future<void> _updateStatus(BuildContext context, WidgetRef ref, String status) async { try { await ref.read(bookingsControllerProvider.notifier).updateBookingStatus(booking.id, status); if (context.mounted) { final updated = booking.copyWith(status: status, startedAt: status == 'قيد التنفيذ' ? DateTime.now() : booking.startedAt); context.pushReplacement('/booking-details', extra: updated); } } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(e)))); } }
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
  Future<void> _openWhatsApp(BuildContext context, String value) async { var phone = value.replaceAll(RegExp(r'[^0-9+]'), ''); if (phone.startsWith('00')) phone = '+${phone.substring(2)}'; if (phone.startsWith('07')) phone = '+964${phone.substring(1)}'; final ok = await launchUrl(Uri.parse('https://wa.me/${phone.replaceAll('+', '')}'), mode: LaunchMode.externalApplication); if (!ok && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح واتساب'))); }
  Future<void> _openUrl(BuildContext context, String value) async { final ok = await launchUrl(Uri.parse(value), mode: LaunchMode.externalApplication); if (!ok && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح المستند'))); }
  String _consultationMethod(String? type, String? mode) { if (mode == 'في المكتب') return 'حضور في مكتب المحامي'; return switch (type) { 'نصية' => 'محادثة نصية عبر واتساب', 'صوتية' => 'تواصل صوتي عبر واتساب', 'فيديو' => 'مكالمة فيديو عبر واتساب', _ => 'عن بعد', }; }
  String _paymentStatus(String value) => switch (value) { 'pending' || 'قيد الانتظار' => 'قيد الانتظار', 'submitted' || 'قيد المعالجة' => 'قيد المعالجة', 'processing' => 'قيد المراجعة', 'approved' || 'مقبول' || 'paid' => 'تمت الموافقة', 'rejected' || 'مرفوض' => 'مرفوض', 'refunded' || 'مسترد' => 'مسترد', 'cancelled' || 'ملغي' => 'ملغي', _ => value, };
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
      if (message != null && message.isNotEmpty && !message.toLowerCase().contains('null')) return message;
      return 'تعذر تنفيذ العملية حالياً. يرجى المحاولة مرة أخرى.';
    }
    final cleaned = raw.replaceFirst('Exception: ', '').trim();
    if (cleaned.isEmpty) return 'تعذر تنفيذ العملية حالياً. يرجى المحاولة مرة أخرى.';
    return cleaned;
  }
  Widget _section(BuildContext context, String title, IconData icon, Widget child) { final s = Theme.of(context).colorScheme; return Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: s.surfaceContainerLow, borderRadius: BorderRadius.circular(18), border: Border.all(color: s.outlineVariant)), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Row(children: [Icon(icon, color: s.primary), const SizedBox(width: 8), Expanded(child: Text(title, textAlign: TextAlign.right, style: TextStyle(color: s.onSurface, fontWeight: FontWeight.w800, fontSize: 16)))]), const SizedBox(height: 12), child])); }
  Widget _row(BuildContext context, String label, String value) { final s = Theme.of(context).colorScheme; return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Expanded(child: Text(value, textAlign: TextAlign.right, style: TextStyle(color: s.onSurface, fontWeight: FontWeight.w600))), const SizedBox(width: 12), Text(label, style: TextStyle(color: s.onSurfaceVariant))])); }
  Widget _infoCard(BuildContext context, String text, IconData icon) { final s = Theme.of(context).colorScheme; return Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: s.primaryContainer, borderRadius: BorderRadius.circular(16)), child: Row(children: [Icon(icon, color: s.primary), const SizedBox(width: 10), Expanded(child: Text(text, textAlign: TextAlign.right, style: TextStyle(color: s.onPrimaryContainer, height: 1.45)))])); }
}

class _ConsultationStartCountdown extends StatefulWidget {
  final DateTime scheduledAt;
  final int durationMinutes;
  final bool canStart;
  final VoidCallback? onStart;

  const _ConsultationStartCountdown({
    required this.scheduledAt,
    required this.durationMinutes,
    required this.canStart,
    required this.onStart,
  });

  @override
  State<_ConsultationStartCountdown> createState() => _ConsultationStartCountdownState();
}

class _ConsultationStartCountdownState extends State<_ConsultationStartCountdown> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final opensAt = widget.scheduledAt.subtract(const Duration(minutes: 5));
    final closesAt = widget.scheduledAt.add(Duration(minutes: widget.durationMinutes));

    if (_now.isAfter(closesAt)) {
      return _messageCard(
        context,
        'انتهى وقت بدء الاستشارة لهذا الموعد.',
        Icons.timer_off_outlined,
      );
    }

    if (!_now.isBefore(opensAt)) {
      if (widget.canStart && widget.onStart != null) {
        return FilledButton.icon(
          onPressed: widget.onStart,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('بدء الاستشارة الآن'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
        );
      }
      return _messageCard(
        context,
        'أصبح وقت بدء الاستشارة متاحاً الآن. بانتظار المحامي لبدء الاستشارة.',
        Icons.notifications_active_outlined,
      );
    }

    final remaining = opensAt.difference(_now);
    final totalMinutes = remaining.inMinutes;
    final days = totalMinutes ~/ (24 * 60);
    final hours = (totalMinutes % (24 * 60)) ~/ 60;
    final minutes = totalMinutes % 60;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.primary.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'الوقت المتبقي لإتاحة بدء الاستشارة',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _timeBox(context, '$minutes', 'دقيقة')),
              const SizedBox(width: 8),
              Expanded(child: _timeBox(context, '$hours', 'ساعة')),
              const SizedBox(width: 8),
              Expanded(child: _timeBox(context, '$days', 'يوم')),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'سيتاح زر بدء الاستشارة قبل الموعد بـ 5 دقائق.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _timeBox(BuildContext context, String value, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .82),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: scheme.primary, fontSize: 23, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _messageCard(BuildContext context, String text, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.right,
              style: TextStyle(color: scheme.onPrimaryContainer, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
