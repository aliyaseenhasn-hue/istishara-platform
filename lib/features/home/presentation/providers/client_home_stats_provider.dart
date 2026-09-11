import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Lightweight counters for the client home screen. The full bookings list and
/// its Realtime channel are intentionally left for the bookings tab.
final clientHomeBookingStatsProvider =
    FutureProvider<ClientHomeBookingStats>((ref) async {
  final user = ref.watch(authStateChangesProvider).valueOrNull;
  if (user == null || (user.role != 'user' && user.role != 'client')) {
    return ClientHomeBookingStats.empty;
  }

  final response = await SupabaseConfig.client.rpc('get_my_booking_stats');
  if (response is! Map) return ClientHomeBookingStats.empty;
  final data = Map<String, dynamic>.from(response);
  return ClientHomeBookingStats(
    total: int.tryParse('${data['total'] ?? 0}') ?? 0,
    completed: int.tryParse('${data['completed'] ?? 0}') ?? 0,
  );
});
