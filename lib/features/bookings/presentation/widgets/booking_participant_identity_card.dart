import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:astshara/core/config/supabase_config.dart';

final bookingParticipantIdentityProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, bookingId) async {
  final response = await SupabaseConfig.client.rpc(
    'get_booking_participant_identity',
    params: {'p_booking_id': bookingId},
  );

  if (response is List && response.isNotEmpty) {
    return Map<String, dynamic>.from(response.first as Map);
  }
  if (response is Map && response.isNotEmpty) {
    return Map<String, dynamic>.from(response);
  }
  return null;
});

final _bookingWhatsappContextProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, bookingId) async {
  final row = await SupabaseConfig.client
      .from('bookings')
      .select(
        'lawyer_id, scheduled_at, status, lawyer_approved, package_duration_minutes',
      )
      .eq('id', bookingId)
      .maybeSingle();

  return row == null ? null : Map<String, dynamic>.from(row);
});

final _lawyerWhatsappForActiveConsultationProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, lawyerId) async {
  final response = await SupabaseConfig.client.rpc(
    'get_lawyer_whatsapp_after_accepted',
    params: {'p_lawyer_id': lawyerId},
  );
  final value = response?.toString().trim();
  return value == null || value.isEmpty ? null : value;
});

class BookingParticipantIdentityCard extends ConsumerWidget {
  final String bookingId;
  final bool isLawyer;
  final String? clientFallbackName;
  final String? lawyerFallbackName;

  const BookingParticipantIdentityCard({
    super.key,
    required this.bookingId,
    required this.isLawyer,
    this.clientFallbackName,
    this.lawyerFallbackName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final identity = ref.watch(bookingParticipantIdentityProvider(bookingId));

    return identity.when(
      loading: () => Container(
        height: 76,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => _card(context, null),
      data: (data) => _card(context, data),
    );
  }

  String? _cleanValue(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  Widget _card(BuildContext context, Map<String, dynamic>? data) {
    final scheme = Theme.of(context).colorScheme;
    final clientName = _cleanValue(data?['client_name']);
    final lawyerName = _cleanValue(data?['lawyer_name']);
    final clientFallback = _cleanValue(clientFallbackName);
    final lawyerFallback = _cleanValue(lawyerFallbackName);

    final name = isLawyer
        ? (clientName ?? clientFallback ?? 'طالب استشارة')
        : (lawyerName ?? lawyerFallback ?? 'المحامي');
    final avatarUrl = isLawyer
        ? _cleanValue(data?['client_avatar_url'])
        : _cleanValue(data?['lawyer_avatar_url']);
    final label = isLawyer ? 'طالب الاستشارة' : 'المحامي';
    final initial = name.isNotEmpty ? name.substring(0, 1) : (isLawyer ? 'ط' : 'م');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: scheme.primaryContainer,
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(
                        initial,
                        style: TextStyle(
                          color: scheme.onPrimaryContainer,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      label,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isLawyer) ...[
            const SizedBox(height: 12),
            _ClientConsultationWhatsAppAction(bookingId: bookingId),
          ],
        ],
      ),
    );
  }
}

class _ClientConsultationWhatsAppAction extends ConsumerStatefulWidget {
  final String bookingId;

  const _ClientConsultationWhatsAppAction({required this.bookingId});

  @override
  ConsumerState<_ClientConsultationWhatsAppAction> createState() =>
      _ClientConsultationWhatsAppActionState();
}

class _ClientConsultationWhatsAppActionState
    extends ConsumerState<_ClientConsultationWhatsAppAction> {
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
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookingContext = ref.watch(
      _bookingWhatsappContextProvider(widget.bookingId),
    );

    return bookingContext.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        if (data == null || data['lawyer_approved'] != true) {
          return const SizedBox.shrink();
        }

        final status = data['status']?.toString().trim() ?? '';
        if (status != 'مؤكد' && status != 'قيد التنفيذ') {
          return const SizedBox.shrink();
        }

        final scheduledAt = DateTime.tryParse(
          data['scheduled_at']?.toString() ?? '',
        )?.toLocal();
        final lawyerId = data['lawyer_id']?.toString().trim();
        final duration = int.tryParse(
              '${data['package_duration_minutes'] ?? 30}',
            ) ??
            30;

        if (scheduledAt == null || lawyerId == null || lawyerId.isEmpty) {
          return const SizedBox.shrink();
        }

        final opensAt = scheduledAt.subtract(const Duration(minutes: 5));
        final closesAt = scheduledAt.add(
          Duration(minutes: duration > 0 ? duration : 30),
        );

        if (_now.isBefore(opensAt) || _now.isAfter(closesAt)) {
          return const SizedBox.shrink();
        }

        final whatsapp = ref.watch(
          _lawyerWhatsappForActiveConsultationProvider(lawyerId),
        );

        return whatsapp.when(
          loading: () => const SizedBox(
            height: 44,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (number) {
            if (number == null || number.isEmpty) {
              return const SizedBox.shrink();
            }

            return FilledButton.icon(
              onPressed: () => _openWhatsApp(context, number),
              icon: const Icon(Icons.chat_rounded),
              label: const Text('بدء الاستشارة عبر واتساب'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openWhatsApp(BuildContext context, String value) async {
    var phone = value.replaceAll(RegExp(r'[^0-9+]'), '');
    if (phone.startsWith('00')) phone = '+${phone.substring(2)}';
    if (phone.startsWith('07')) phone = '+964${phone.substring(1)}';

    final opened = await launchUrl(
      Uri.parse('https://wa.me/${phone.replaceAll('+', '')}'),
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح واتساب')),
      );
    }
  }
}
