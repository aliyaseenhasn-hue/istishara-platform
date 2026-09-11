import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';

class ClientHomeBookingStats {
  final int total;
  final int completed;

  const ClientHomeBookingStats({
    required this.total,
    required this.completed,
  });

  static const empty = ClientHomeBookingStats(total: 0, completed: 0);
}

/// Lightweight counters for the client home screen. The full bookings list is
/// left for the bookings tab; this provider only keeps one filtered Realtime
/// listener so the two counters remain current while the cached home tab stays
/// mounted.
final clientHomeBookingStatsProvider =
    FutureProvider.autoDispose<ClientHomeBookingStats>((ref) async {
  final user = ref.watch(authStateChangesProvider).valueOrNull;
  if (user == null || (user.role != 'user' && user.role != 'client')) {
    return ClientHomeBookingStats.empty;
  }

  final profileId = await ref.watch(currentProfileIdProvider.future);
  if (profileId == null || profileId.isEmpty) {
    return ClientHomeBookingStats.empty;
  }

  final channel = SupabaseConfig.client
      .channel('home-booking-stats-$profileId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'bookings',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: profileId,
        ),
        callback: (_) => ref.invalidateSelf(),
      )
      .subscribe();
  ref.onDispose(() {
    unawaited(SupabaseConfig.client.removeChannel(channel));
  });

  final response = await SupabaseConfig.client.rpc('get_my_booking_stats');
  if (response is! Map) return ClientHomeBookingStats.empty;
  final data = Map<String, dynamic>.from(response);
  return ClientHomeBookingStats(
    total: int.tryParse('${data['total'] ?? 0}') ?? 0,
    completed: int.tryParse('${data['completed'] ?? 0}') ?? 0,
  );
});
