import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astshara/core/config/supabase_config.dart';
import '../../data/models/booking_model.dart';
import '../../domain/entities/booking.dart';
import 'bookings_provider.dart';

final bookingsRealtimePulseProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return SupabaseConfig.client
      .from('bookings')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((rows) => rows.map((row) => Map<String, dynamic>.from(row)).toList());
});

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

final availabilityRealtimePulseProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return SupabaseConfig.client
      .from('lawyer_availability_slots')
      .stream(primaryKey: ['id'])
      .order('starts_at', ascending: true)
      .map((rows) => rows.map((row) => Map<String, dynamic>.from(row)).toList());
});

final bookingsRealtimeSyncProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<List<Map<String, dynamic>>>>(
    bookingsRealtimePulseProvider,
    (previous, next) {
      if (!next.hasValue) return;
      ref.invalidate(userBookingsProvider);
      ref.invalidate(lawyerBookingsProvider);
    },
  );

  ref.listen<AsyncValue<List<Map<String, dynamic>>>>(
    availabilityRealtimePulseProvider,
    (previous, next) {
      if (!next.hasValue) return;
      ref.invalidate(availableSlotsProvider);
    },
  );
});
