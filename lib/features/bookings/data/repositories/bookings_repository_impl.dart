import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/booking.dart';
import '../../domain/repositories/bookings_repository.dart';
import '../models/booking_model.dart';

class BookingsRepositoryImpl implements BookingsRepository {
  final SupabaseClient _supabase;
  BookingsRepositoryImpl(this._supabase);

  static const _cachePrefix = 'bookings_';
  static const _cacheTtl = Duration(minutes: 15);
  static const _backgroundRefreshAfter = Duration(minutes: 2);
  static final Map<String, _BookingCache> _memoryCache = {};
  static final Set<String> _refreshing = <String>{};

  String _cacheKey(String role, String profileId) => '$_cachePrefix${role}_$profileId';
  String _timeKey(String role, String profileId) => '${_cacheKey(role, profileId)}_time';

  Future<List<Booking>?> _readCached(String role, String profileId) async {
    final key = _cacheKey(role, profileId);
    final memory = _memoryCache[key];
    if (memory != null) {
      final age = DateTime.now().difference(memory.timestamp);
      if (age <= _cacheTtl) return memory.bookings;
      _memoryCache.remove(key);
    }
    try {
      final box = Hive.box('app_cache');
      final timestamp = box.get(_timeKey(role, profileId)) as int?;
      final raw = box.get(key);
      if (timestamp == null || raw is! List) return null;
      final cachedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(cachedAt) > _cacheTtl) return null;
      final bookings = raw
          .map((item) => BookingModel.fromJson(Map<String, dynamic>.from(item as Map)).toEntity())
          .toList();
      _memoryCache[key] = _BookingCache(bookings, cachedAt);
      return bookings;
    } catch (e) {
      debugPrint('⚠️ BookingsRepo: cache read error: $e');
      return null;
    }
  }

  Future<void> _writeCached(String role, String profileId, List<Booking> bookings) async {
    final key = _cacheKey(role, profileId);
    final now = DateTime.now();
    _memoryCache[key] = _BookingCache(bookings, now);
    try {
      final box = Hive.box('app_cache');
      await box.put(key, bookings.map(_bookingToJson).toList());
      await box.put(_timeKey(role, profileId), now.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('⚠️ BookingsRepo: cache write error: $e');
    }
  }

  Map<String, dynamic> _bookingToJson(Booking booking) => {
        'id': booking.id,
        'user_id': booking.userId,
        'lawyer_id': booking.lawyerId,
        'status': booking.status,
        'scheduled_at': booking.scheduledAt.toIso8601String(),
        'price': booking.price,
        'created_at': booking.createdAt?.toIso8601String(),
        'started_at': booking.startedAt?.toIso8601String(),
        'whatsapp_number': booking.whatsappNumber,
        'lawyer_approved': booking.lawyerApproved,
        'consultation_mode': booking.consultationMode,
        'manual_payment_required': booking.manualPaymentRequired,
        'manual_received_amount': booking.manualReceivedAmount,
        'manual_received_at': booking.manualReceivedAt?.toIso8601String(),
      };

  void _scheduleRefresh(String role, String profileId) {
    final key = _cacheKey(role, profileId);
    if (!_refreshing.add(key)) return;
    Future<void>(() async {
      try {
        if (role == 'client') {
          await _fetchUserBookings(profileId, writeCache: true);
        } else {
          await _fetchLawyerBookings(profileId, writeCache: true);
        }
      } finally {
        _refreshing.remove(key);
      }
    });
  }

  Future<List<Booking>> _fetchUserBookings(String userId, {required bool writeCache}) async {
    final response = await _supabase.from('bookings').select().eq('user_id', userId).order('created_at', ascending: false);
    final bookings = (response as List)
        .map((json) => BookingModel.fromJson(Map<String, dynamic>.from(json as Map)).toEntity())
        .toList();
    if (writeCache) await _writeCached('client', userId, bookings);
    return bookings;
  }

  Future<List<Booking>> _fetchLawyerBookings(String lawyerId, {required bool writeCache}) async {
    final response = await _supabase.from('bookings').select().eq('lawyer_id', lawyerId).isFilter('deleted_by_lawyer_at', null).order('created_at', ascending: false);
    final bookings = (response as List)
        .map((json) => BookingModel.fromJson(Map<String, dynamic>.from(json as Map)).toEntity())
        .toList();
    if (writeCache) await _writeCached('lawyer', lawyerId, bookings);
    return bookings;
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
    final booking = BookingModel.fromJson(Map<String, dynamic>.from(response as Map)).toEntity();
    final profileRow = await _supabase.from('profiles').select('id').eq('auth_id', user.id).maybeSingle();
    final profileId = profileRow?['id']?.toString();
    if (profileId != null) _memoryCache.remove(_cacheKey('client', profileId));
    _memoryCache.remove(_cacheKey('lawyer', lawyerId));
    return booking;
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
    final cached = await _readCached('client', userId);
    if (cached != null) {
      final entry = _memoryCache[_cacheKey('client', userId)];
      if (entry != null && DateTime.now().difference(entry.timestamp) >= _backgroundRefreshAfter) {
        _scheduleRefresh('client', userId);
      }
      return cached;
    }
    return _fetchUserBookings(userId, writeCache: true);
  }

  @override
  Future<List<Booking>> getLawyerBookings(String lawyerId) async {
    final cached = await _readCached('lawyer', lawyerId);
    if (cached != null) {
      final entry = _memoryCache[_cacheKey('lawyer', lawyerId)];
      if (entry != null && DateTime.now().difference(entry.timestamp) >= _backgroundRefreshAfter) {
        _scheduleRefresh('lawyer', lawyerId);
      }
      return cached;
    }
    return _fetchLawyerBookings(lawyerId, writeCache: true);
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

class _BookingCache {
  final List<Booking> bookings;
  final DateTime timestamp;
  const _BookingCache(this.bookings, this.timestamp);
}
