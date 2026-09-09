import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/booking.dart';
import '../../domain/repositories/bookings_repository.dart';
import '../models/booking_model.dart';

class BookingsRepositoryImpl implements BookingsRepository {
  final SupabaseClient _supabase;
  BookingsRepositoryImpl(this._supabase);

  static bool _isTerminalStatus(String status) {
    final value = status.trim();
    return const {'مكتمل', 'ملغي', 'مسترد', 'مرفوض'}.contains(value);
  }

  static List<Booking> _sortBookings(List<Booking> items) {
    items.sort((a, b) {
      final aTerminal = _isTerminalStatus(a.status);
      final bTerminal = _isTerminalStatus(b.status);

      // الاستشارات غير المنتهية تظهر أولاً حسب أقرب موعد استحقاق.
      if (aTerminal != bTerminal) return aTerminal ? 1 : -1;
      if (!aTerminal) return a.scheduledAt.compareTo(b.scheduledAt);

      // الاستشارات المنتهية تظهر من الأحدث إلى الأقدم.
      return b.scheduledAt.compareTo(a.scheduledAt);
    });
    return items;
  }

  @override
  Future<Booking> createBooking({
    required String lawyerId,
    required DateTime scheduledAt,
    String? slotId,
    required String packageName,
    required String consultationType,
    String? description,
    String? documentUrl,
    String? consultationMode,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول أولاً');
    final profile = await _supabase.from('profiles').select('whatsapp_number').eq('auth_id', user.id).maybeSingle();
    final whatsapp = profile?['whatsapp_number']?.toString().trim();
    final response = await _supabase.rpc('create_booking', params: {
      'p_lawyer_id': lawyerId,
      'p_scheduled_at': scheduledAt.toIso8601String(),
      'p_slot_id': slotId,
      'p_package_name': packageName,
      'p_consultation_type': consultationType,
      'p_description': description,
      'p_document_url': documentUrl,
      'p_client_whatsapp': whatsapp?.isEmpty == true ? null : whatsapp,
      'p_consultation_mode': consultationMode ?? 'عن بعد',
    });
    return BookingModel.fromJson(Map<String, dynamic>.from(response as Map)).toEntity();
  }

  @override
  Future<String> uploadDocument(dynamic fileBytes, String fileName) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('المستخدم غير مسجل دخول');
    final safeFileName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final filePath = '${user.id}/docs/${DateTime.now().microsecondsSinceEpoch}_$safeFileName';
    await _supabase.storage.from('lawyer_documents').uploadBinary(filePath, fileBytes, fileOptions: const FileOptions(upsert: false));
    return _supabase.storage.from('lawyer_documents').createSignedUrl(filePath, 3600);
  }

  @override
  Future<List<Booking>> getUserBookings(String userId) async {
    final response = await _supabase
        .from('bookings')
        .select()
        .eq('user_id', userId)
        .isFilter('archived_by_user_at', null)
        .order('created_at', ascending: false);
    final items = (response as List)
        .map((json) => BookingModel.fromJson(Map<String, dynamic>.from(json as Map)).toEntity())
        .toList();
    return _sortBookings(items);
  }

  @override
  Future<List<Booking>> getLawyerBookings(String lawyerId) async {
    final response = await _supabase
        .from('bookings')
        .select()
        .eq('lawyer_id', lawyerId)
        .isFilter('archived_by_lawyer_at', null)
        .isFilter('deleted_by_lawyer_at', null)
        .order('created_at', ascending: false);
    final items = (response as List)
        .map((json) => BookingModel.fromJson(Map<String, dynamic>.from(json as Map)).toEntity())
        .toList();
    return _sortBookings(items);
  }

  @override
  Future<void> updateBookingStatus(String bookingId, String status) async {
    await _supabase.rpc('change_booking_status', params: {'p_booking_id': bookingId, 'p_new_status': status});
  }

  @override
  Future<Booking> reviewBooking(String bookingId, bool approved) async {
    final response = await _supabase.rpc('review_booking', params: {'p_booking_id': bookingId, 'p_approved': approved});
    return BookingModel.fromJson(Map<String, dynamic>.from(response as Map)).toEntity();
  }

  @override
  Future<Booking> recordManualPayment(String bookingId, double amount) async {
    final response = await _supabase.rpc('record_manual_payment', params: {'p_booking_id': bookingId, 'p_received_amount': amount});
    return BookingModel.fromJson(Map<String, dynamic>.from(response as Map)).toEntity();
  }

  @override
  Future<void> archiveBookingForUser(String bookingId) async {
    await _supabase.rpc('archive_booking_for_user', params: {'p_booking_id': bookingId});
  }

  @override
  Future<void> archiveBookingForLawyer(String bookingId) async {
    await _supabase.rpc('archive_booking_for_lawyer', params: {'p_booking_id': bookingId});
  }

  @override
  Future<void> restoreBookingFromArchive(String bookingId) async {
    await _supabase.rpc('restore_booking_from_archive', params: {'p_booking_id': bookingId});
  }

  @override
  Future<void> reportNoShow(String bookingId, [bool? isLawyer]) async {
    await _supabase.rpc('report_booking_no_show', params: {'p_booking_id': bookingId});
  }
}
