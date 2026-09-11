import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astshara/core/config/supabase_config.dart';
import '../../data/models/booking_model.dart';
import '../../domain/entities/booking.dart';

/// Realtime for one open booking detail only.
///
/// Global bookings/availability streams were removed because the scoped
/// providers already subscribe to the signed-in user's bookings and to the
/// selected lawyer's availability. Keeping global streams duplicated network
/// traffic and caused redundant provider invalidations.
final bookingRealtimeProvider =
    StreamProvider.autoDispose.family<Booking?, String>((ref, bookingId) {
  return SupabaseConfig.client
      .from('bookings')
      .stream(primaryKey: ['id'])
      .eq('id', bookingId)
      .map((rows) {
    if (rows.isEmpty) return null;
    return BookingModel.fromJson(Map<String, dynamic>.from(rows.first)).toEntity();
  });
});
