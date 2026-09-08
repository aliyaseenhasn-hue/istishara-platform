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
            _section(context, 'معلومات التواصل', Icons.contact_phone_outlined, contact.when(data: (c) => c == null ? const Text('لا توجد معلومات تواصل متاحة.') : _contactContent(context, c, isLawyer), loading: () => const LinearProgressIndicator(), error: (e, _) => Text(e.toString().replaceFirst('Exception: ', '')))),
          ],
          const SizedBox(height: 20),
          if (isOwner && booking.paymentRequired && booking.status == 'قيد انتظار الدفع') ElevatedButton.icon(onPressed: () => context.push('/upload-payment', extra: booking), icon: const Icon(Icons.payment_rounded), label: const Text('إكمال الدفع')),
          if (needsReview) ...[
            _infoCard(context, 'هذا الطلب بانتظار مراجعتك. يمكنك الموافقة أو رفض الطلب.', Icons.rule_rounded), const SizedBox(height: 10),
            Row(children: [Expanded(child: ElevatedButton.icon(onPressed: () => _review(context, ref, true), icon: const Icon(Icons.check_circle_outline), label: const Text('الموافقة'))), const SizedBox(width: 10), Expanded(child: OutlinedButton.icon(onPressed: () => _review(context, ref, false), icon: const Icon(Icons.cancel_outlined), label: const Text('رفض الطلب')))]),
          ],
          if (isLawyer && booking.status == 'مؤكد') _startButton(context, ref, details),
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
  Widget _startButton(BuildContext context, WidgetRef ref, AsyncValue<Map<String, dynamic>?> details) { final now = DateTime.now(); final duration = int.tryParse('${details.valueOrNull?['package_duration_minutes'] ?? 30}') ?? 30; final opens = booking.scheduledAt.subtract(const Duration(minutes: 5)); final closes = booking.scheduledAt.add(Duration(minutes: duration)); if (now.isAfter(closes)) return _infoCard(context, 'انتهى وقت بدء الاستشارة لهذا الموعد.', Icons.timer_off_outlined); if (now.isBefore(opens)) return _infoCard(context, 'يمكن بدء الاستشارة قبل الموعد بـ 5 دقائق.', Icons.schedule_rounded); return ElevatedButton.icon(onPressed: () => _updateStatus(context, ref, 'قيد التنفيذ'), icon: const Icon(Icons.play_arrow_rounded), label: const Text('بدء الاستشارة الآن')); }
  Future<void> _review(BuildContext context, WidgetRef ref, bool approved) async { try { await ref.read(bookingsControllerProvider.notifier).reviewBooking(booking.id, approved); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(approved ? 'تمت الموافقة على الحجز' : 'تم رفض الحجز'))); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')))); } }
  Future<void> _updateStatus(BuildContext context, WidgetRef ref, String status) async { try { await ref.read(bookingsControllerProvider.notifier).updateBookingStatus(booking.id, status); if (context.mounted) { final updated = booking.copyWith(status: status, startedAt: status == 'قيد التنفيذ' ? DateTime.now() : booking.startedAt); context.pushReplacement('/booking-details', extra: updated); } } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')))); } }
  Future<void> _reportNoShow(BuildContext context, WidgetRef ref, bool isLawyer) async { try { await ref.read(bookingsControllerProvider.notifier).reportNoShow(booking.id, isLawyer: isLawyer); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')))); } }
  Future<void> _openWhatsApp(BuildContext context, String value) async { var phone = value.replaceAll(RegExp(r'[^0-9+]'), ''); if (phone.startsWith('00')) phone = '+${phone.substring(2)}'; if (phone.startsWith('07')) phone = '+964${phone.substring(1)}'; final ok = await launchUrl(Uri.parse('https://wa.me/${phone.replaceAll('+', '')}'), mode: LaunchMode.externalApplication); if (!ok && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح واتساب'))); }
  Future<void> _openUrl(BuildContext context, String value) async { final ok = await launchUrl(Uri.parse(value), mode: LaunchMode.externalApplication); if (!ok && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح المستند'))); }
  String _consultationMethod(String? type, String? mode) { if (mode == 'في المكتب') return 'حضور في مكتب المحامي'; return switch (type) { 'نصية' => 'محادثة نصية عبر واتساب', 'صوتية' => 'تواصل صوتي عبر واتساب', 'فيديو' => 'مكالمة فيديو عبر واتساب', _ => 'عن بعد', }; }
  String _paymentStatus(String value) => switch (value) { 'pending' || 'قيد الانتظار' => 'قيد الانتظار', 'submitted' || 'قيد المعالجة' => 'قيد المعالجة', 'processing' => 'قيد المراجعة', 'approved' || 'مقبول' || 'paid' => 'تمت الموافقة', 'rejected' || 'مرفوض' => 'مرفوض', 'refunded' || 'مسترد' => 'مسترد', 'cancelled' || 'ملغي' => 'ملغي', _ => value, };
  String _paymentMethod(String value) => value.trim().isEmpty ? 'غير محددة' : value;
  Widget _section(BuildContext context, String title, IconData icon, Widget child) { final s = Theme.of(context).colorScheme; return Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: s.surfaceContainerLow, borderRadius: BorderRadius.circular(18), border: Border.all(color: s.outlineVariant)), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Row(children: [Icon(icon, color: s.primary), const SizedBox(width: 8), Expanded(child: Text(title, textAlign: TextAlign.right, style: TextStyle(color: s.onSurface, fontWeight: FontWeight.w800, fontSize: 16)))]), const SizedBox(height: 12), child])); }
  Widget _row(BuildContext context, String label, String value) { final s = Theme.of(context).colorScheme; return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Expanded(child: Text(value, textAlign: TextAlign.right, style: TextStyle(color: s.onSurface, fontWeight: FontWeight.w600))), const SizedBox(width: 12), Text(label, style: TextStyle(color: s.onSurfaceVariant))])); }
  Widget _infoCard(BuildContext context, String text, IconData icon) { final s = Theme.of(context).colorScheme; return Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: s.primaryContainer, borderRadius: BorderRadius.circular(16)), child: Row(children: [Icon(icon, color: s.primary), const SizedBox(width: 10), Expanded(child: Text(text, textAlign: TextAlign.right, style: TextStyle(color: s.onPrimaryContainer, height: 1.45)))])); }
}
