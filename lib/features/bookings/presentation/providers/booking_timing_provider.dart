import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';

/// Lightweight realtime stream used by consultation timers and start actions.
/// It keeps payment confirmation/status changes visible without requiring the
/// user to leave and reopen the page.
final bookingTimingProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, bookingId) {
  return SupabaseConfig.client
      .from('bookings')
      .stream(primaryKey: const ['id'])
      .eq('id', bookingId)
      .map((rows) {
        if (rows.isEmpty) return null;
        return Map<String, dynamic>.from(rows.first);
      });
});
