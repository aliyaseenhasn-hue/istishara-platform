import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  Widget _card(BuildContext context, Map<String, dynamic>? data) {
    final scheme = Theme.of(context).colorScheme;
    final name = isLawyer
        ? (data?['client_name']?.toString().trim().isNotEmpty == true
            ? data!['client_name'].toString().trim()
            : (clientFallbackName?.trim().isNotEmpty == true ? clientFallbackName!.trim() : 'طالب استشارة'))
        : (data?['lawyer_name']?.toString().trim().isNotEmpty == true
            ? data!['lawyer_name'].toString().trim()
            : (lawyerFallbackName?.trim().isNotEmpty == true ? lawyerFallbackName!.trim() : 'المحامي'));
    final avatarUrl = isLawyer
        ? data?['client_avatar_url']?.toString().trim()
        : data?['lawyer_avatar_url']?.toString().trim();
    final label = isLawyer ? 'طالب الاستشارة' : 'المحامي';
    final initial = name.isNotEmpty ? name.substring(0, 1) : (isLawyer ? 'ط' : 'م');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: scheme.primaryContainer,
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null || avatarUrl.isEmpty
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
    );
  }
}
