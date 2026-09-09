import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:astshara/core/config/supabase_config.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/repositories/bookings_repository_impl.dart';
import '../../domain/entities/booking.dart';
import '../../domain/repositories/bookings_repository.dart';
part 'bookings_provider.g.dart';

class AvailableBookingSlot {
  final String id;
  final DateTime startsAt;
  final int durationMinutes;
  final double? price;
  const AvailableBookingSlot({required this.id, required this.startsAt, required this.durationMinutes, this.price});
}

@riverpod
BookingsRepository bookingsRepository(BookingsRepositoryRef ref) => BookingsRepositoryImpl(SupabaseConfig.client);

Future<String?> _getProfileId(String authUid) async {
  final row = await SupabaseConfig.client.from('profiles').select('id').eq('auth_id', authUid).maybeSingle();
  return row?['id'] as String?;
}

@Riverpod(keepAlive: true)
Future<List<Booking>> userBookings(UserBookingsRef ref) async {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return [];
  final id = await _getProfileId(user.id);
  if (id == null) return [];
  return ref.read(bookingsRepositoryProvider).getUserBookings(id);
}

@Riverpod(keepAlive: true)
Future<List<Booking>> lawyerBookings(LawyerBookingsRef ref) async {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return [];
  final id = await _getProfileId(user.id);
  if (id == null) return [];
  return ref.read(bookingsRepositoryProvider).getLawyerBookings(id);
}

final bookingLawyerInfoProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, bookingId) async {
  final response = await SupabaseConfig.client.rpc('get_booking_lawyer_info', params: {'p_booking_id': bookingId});
  Map<String, dynamic>? row;
  if (response is List && response.isNotEmpty) row = Map<String, dynamic>.from(response.first as Map);
  else if (response is Map) row = Map<String, dynamic>.from(response);
  final name = row?['full_name']?.toString().trim();
  return {'full_name': name == null || name.isEmpty ? 'اسم المحامي غير متوفر' : name, 'avatar_url': row?['avatar_url']?.toString()};
});

final availableSlotsProvider = FutureProvider.family<List<AvailableBookingSlot>, String>((ref, lawyerId) async {
  final rows = await SupabaseConfig.client
      .from('lawyer_availability_slots')
      .select('id, starts_at, duration_minutes, price')
      .eq('lawyer_id', lawyerId)
      .eq('is_available', true)
      .gt('starts_at', DateTime.now().toUtc().toIso8601String())
      .order('starts_at');
  return (rows as List).map((row) {
    final m = Map<String, dynamic>.from(row as Map);
    return AvailableBookingSlot(
      id: m['id'] as String,
      startsAt: DateTime.parse(m['starts_at'] as String).toLocal(),
      durationMinutes: int.tryParse('${m['duration_minutes'] ?? 30}') ?? 30,
      price: m['price'] == null ? null : double.tryParse('${m['price']}'),
    );
  }).toList();
});

final bookingDetailsProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, bookingId) async {
  final booking = await SupabaseConfig.client.from('bookings').select('user_id,lawyer_id, consultation_type, consultation_mode, payment_required, payment_waived_at, payment_waiver_reason, manual_payment_required, manual_received_amount, description, document_url, package_name, package_description, package_duration_minutes').eq('id', bookingId).maybeSingle();
  if (booking == null) return null;
  final result = Map<String, dynamic>.from(booking);
  final clientResult = await SupabaseConfig.client.rpc('get_booking_client_name', params: {'p_booking_id': bookingId});
  Map<String, dynamic>? client;
  if (clientResult is List && clientResult.isNotEmpty) client = Map<String, dynamic>.from(clientResult.first as Map);
  else if (clientResult is Map) client = Map<String, dynamic>.from(clientResult);
  final lawyerInfo = await ref.read(bookingLawyerInfoProvider(bookingId).future);
  result['client_name'] = (client?['full_name'] ?? 'غير متوفر').toString();
  result['lawyer_name'] = lawyerInfo?['full_name']?.toString() ?? 'اسم المحامي غير متوفر';
  result['lawyer_avatar_url'] = lawyerInfo?['avatar_url'];
  return result;
});

final appReleaseSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final row = await SupabaseConfig.client.from('app_release_settings').select('release_channel, free_beta_enabled, payments_enabled, beta_notice').eq('id', true).single();
  return Map<String, dynamic>.from(row);
});

final bookingClientNameProvider = FutureProvider.family<String?, String>((ref, bookingId) async {
  final result = await SupabaseConfig.client.rpc('get_booking_client_name', params: {'p_booking_id': bookingId});
  if (result is List && result.isNotEmpty) {
    final row = Map<String, dynamic>.from(result.first as Map);
    final name = row['full_name']?.toString().trim();
    return name == null || name.isEmpty ? null : name;
  }
  if (result is Map) {
    final name = result['full_name']?.toString().trim();
    return name == null || name.isEmpty ? null : name;
  }
  return null;
});

final bookingContactProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, bookingId) async {
  final response = await SupabaseConfig.client.rpc('get_booking_contact_info', params: {'p_booking_id': bookingId});
  if (response is List && response.isNotEmpty) return Map<String, dynamic>.from(response.first as Map);
  return null;
});

final bookingParticipantContactProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, bookingId) async {
  final response = await SupabaseConfig.client.rpc('get_booking_participant_contact_info', params: {'p_booking_id': bookingId});
  if (response is List && response.isNotEmpty) return Map<String, dynamic>.from(response.first as Map);
  return null;
});

final lawyerAcceptedWhatsAppProvider = FutureProvider.family<String?, String>((ref, lawyerId) async {
  final result = await SupabaseConfig.client.rpc('get_lawyer_whatsapp_after_accepted', params: {'p_lawyer_id': lawyerId});
  final value = result?.toString().trim();
  return value == null || value.isEmpty ? null : value;
});

final currentUserWhatsAppProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return null;
  final row = await SupabaseConfig.client.from('profiles').select('whatsapp_number').eq('auth_id', user.id).maybeSingle();
  final value = row?['whatsapp_number']?.toString().trim();
  return value == null || value.isEmpty ? null : value;
});

@riverpod
class BookingsController extends _$BookingsController {
  @override
  FutureOr<void> build() {}

  Future<Booking?> requestBooking({required String lawyerId, required DateTime scheduledAt, String? slotId, required String packageName, required String consultationType, String? description, dynamic documentBytes, String? documentName, String? consultationMode}) async {
    state = const AsyncLoading();
    Booking? createdBooking;
    state = await AsyncValue.guard(() async {
      final user = ref.read(authStateChangesProvider).value;
      if (user == null) throw Exception('يجب تسجيل الدخول أولاً');
      if (!(user.role == 'user' || user.role == 'client')) throw Exception('فقط طالب الخدمة يمكنه طلب حجز استشارة');
      final whatsapp = await ref.read(currentUserWhatsAppProvider.future);
      if (whatsapp == null) throw Exception('يجب إضافة رقم واتساب في الإعدادات قبل طلب الاستشارة');
      final repo = ref.read(bookingsRepositoryProvider);
      String? documentUrl;
      if (documentBytes != null && documentName != null) documentUrl = await repo.uploadDocument(documentBytes, documentName);
      createdBooking = await repo.createBooking(lawyerId: lawyerId, scheduledAt: scheduledAt, slotId: slotId, packageName: packageName, consultationType: consultationType, description: description, documentUrl: documentUrl, consultationMode: consultationMode);
      ref.invalidate(userBookingsProvider);
    });
    ref.invalidate(availableSlotsProvider(lawyerId));
    if (state.hasError) return null;
    return createdBooking;
  }

  Future<Booking?> createBooking({required String lawyerId, String? serviceId, DateTime? scheduledAt, String? slotId, required String consultationType, String? consultationMode, String? description, dynamic documentBytes, String? documentName}) async {
    final when = scheduledAt;
    if (when == null) {
      state = AsyncError(Exception('يرجى اختيار موعد متاح'), StackTrace.current);
      ref.invalidate(availableSlotsProvider(lawyerId));
      return null;
    }
    final packageName = serviceId == null || serviceId.trim().isEmpty ? 'استشارة مختلفة' : serviceId;
    return requestBooking(lawyerId: lawyerId, scheduledAt: when, slotId: slotId, packageName: packageName, consultationType: consultationType, consultationMode: consultationMode, description: description, documentBytes: documentBytes, documentName: documentName);
  }

  Future<Booking?> recordManualPayment({required String bookingId, required double amount}) async {
    state = const AsyncLoading();
    Booking? updated;
    state = await AsyncValue.guard(() async {
      updated = await ref.read(bookingsRepositoryProvider).recordManualPayment(bookingId, amount);
      ref.invalidate(lawyerBookingsProvider);
      ref.invalidate(userBookingsProvider);
      ref.invalidate(bookingDetailsProvider(bookingId));
    });
    return state.hasError ? null : updated;
  }

  Future<void> reviewBooking(String bookingId, bool approved) async {
    await ref.read(bookingsRepositoryProvider).reviewBooking(bookingId, approved);
    ref.invalidate(userBookingsProvider);
    ref.invalidate(lawyerBookingsProvider);
    ref.invalidate(bookingDetailsProvider(bookingId));
  }

  Future<void> updateBookingStatus(String bookingId, String status) async {
    await ref.read(bookingsRepositoryProvider).updateBookingStatus(bookingId, status);
    ref.invalidate(userBookingsProvider);
    ref.invalidate(lawyerBookingsProvider);
    ref.invalidate(bookingDetailsProvider(bookingId));
  }

  Future<void> reportNoShow(String bookingId, {required bool isLawyer}) async {
    // report_booking_no_show changes the booking and emits Realtime updates.
    // Do not invalidate the same FutureProviders here as well: that can race
    // with the Realtime listener and complete Riverpod's internal future twice.
    await ref.read(bookingsRepositoryProvider).reportNoShow(bookingId, isLawyer);
  }

  Future<void> archiveBooking(String bookingId, {required bool isLawyer}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(bookingsRepositoryProvider);
      if (isLawyer) await repo.archiveBookingForLawyer(bookingId); else await repo.archiveBookingForUser(bookingId);
      ref.invalidate(userBookingsProvider);
      ref.invalidate(lawyerBookingsProvider);
      ref.invalidate(bookingDetailsProvider(bookingId));
    });
  }

  Future<void> restoreBooking(String bookingId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(bookingsRepositoryProvider).restoreBookingFromArchive(bookingId);
      ref.invalidate(userBookingsProvider);
      ref.invalidate(lawyerBookingsProvider);
      ref.invalidate(bookingDetailsProvider(bookingId));
    });
  }
}
