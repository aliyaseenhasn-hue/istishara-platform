import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/private_storage_reference.dart';
import '../../domain/entities/lawyer_profile.dart';
import '../../domain/repositories/lawyers_repository.dart';
import '../models/lawyer_profile_model.dart';

class LawyersRepositoryImpl implements LawyersRepository {
  final SupabaseClient _supabase;
  LawyersRepositoryImpl(this._supabase);

  static const _cachePrefix = 'public_lawyers_page_';
  static const _cacheTtl = Duration(minutes: 10);
  static const _backgroundRefreshAfter = Duration(minutes: 2);
  static final Map<String, _MemoryPage> _memoryCache = {};
  static final Map<String, _MemoryProfile> _profileMemoryCache = {};
  static final Set<String> _refreshingPages = <String>{};

  String _cacheKey(int limit, int offset) => '$_cachePrefix${limit}_$offset';
  String _cacheTimeKey(int limit, int offset) => '${_cacheKey(limit, offset)}_time';

  Future<List<dynamic>?> _readCachedPage(int limit, int offset) async {
    final key = _cacheKey(limit, offset);
    final memory = _memoryCache[key];
    if (memory != null) {
      final age = DateTime.now().difference(memory.timestamp);
      if (age <= _cacheTtl) return memory.rows;
      _memoryCache.remove(key);
    }
    try {
      final box = Hive.box('app_cache');
      final timestamp = box.get(_cacheTimeKey(limit, offset)) as int?;
      final raw = box.get(key);
      if (timestamp == null || raw is! List) return null;
      final cachedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(cachedAt) > _cacheTtl) return null;
      final rows = List<dynamic>.from(raw);
      _memoryCache[key] = _MemoryPage(rows, cachedAt);
      return rows;
    } catch (e) {
      debugPrint('⚠️ LawyersRepo: Cache read error: $e');
      return null;
    }
  }

  Future<void> _writeCachedPage(int limit, int offset, List<dynamic> rows) async {
    final key = _cacheKey(limit, offset);
    _memoryCache[key] = _MemoryPage(rows, DateTime.now());
    try {
      final box = Hive.box('app_cache');
      await box.put(key, rows.map((e) => Map<String, dynamic>.from(e as Map)).toList());
      await box.put(_cacheTimeKey(limit, offset), DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('⚠️ LawyersRepo: Cache write error: $e');
    }
  }

  List<LawyerProfile> _parseRows(Iterable<dynamic> rows) {
    final result = <LawyerProfile>[];
    for (final item in rows) {
      try {
        final json = Map<String, dynamic>.from(item as Map);
        final model = LawyerProfileModel.fromJson(json);
        result.add(model.toEntity().copyWith(
              fullName: model.fullName ?? 'محامي استشارة',
              avatarUrl: json['avatar_url'] as String?,
            ));
      } catch (e) {
        debugPrint('❌ LawyersRepo: Record error: $e');
      }
    }
    return result;
  }

  void _scheduleBackgroundRefresh(int limit, int offset) {
    final key = _cacheKey(limit, offset);
    if (!_refreshingPages.add(key)) return;
    Future<void>(() async {
      try {
        await refreshLawyersPage(limit: limit, offset: offset);
      } finally {
        _refreshingPages.remove(key);
      }
    });
  }

  @override
  Future<List<LawyerProfile>> getLawyers({int limit = 20, int offset = 0}) async {
    final safeLimit = limit.clamp(1, 100);
    final safeOffset = offset < 0 ? 0 : offset;
    final cached = await _readCachedPage(safeLimit, safeOffset);
    if (cached != null) {
      final page = _memoryCache[_cacheKey(safeLimit, safeOffset)];
      if (page != null && DateTime.now().difference(page.timestamp) >= _backgroundRefreshAfter) {
        _scheduleBackgroundRefresh(safeLimit, safeOffset);
      }
      return _parseRows(cached);
    }

    try {
      final response = await _supabase.rpc('get_public_lawyers');
      final allRows = List<dynamic>.from(response as List);
      final start = safeOffset.clamp(0, allRows.length);
      final end = (start + safeLimit).clamp(start, allRows.length);
      final rows = allRows.sublist(start, end);
      await _writeCachedPage(safeLimit, safeOffset, rows);
      return _parseRows(rows);
    } catch (e) {
      debugPrint('❌ LawyersRepo: Fetch error: $e');
      return <LawyerProfile>[];
    }
  }

  Future<List<LawyerProfile>> refreshLawyersPage({int limit = 20, int offset = 0}) async {
    final safeLimit = limit.clamp(1, 100);
    final safeOffset = offset < 0 ? 0 : offset;
    try {
      final response = await _supabase.rpc('get_public_lawyers');
      final allRows = List<dynamic>.from(response as List);
      final start = safeOffset.clamp(0, allRows.length);
      final end = (start + safeLimit).clamp(start, allRows.length);
      final rows = allRows.sublist(start, end);
      await _writeCachedPage(safeLimit, safeOffset, rows);
      return _parseRows(rows);
    } catch (e) {
      debugPrint('❌ LawyersRepo: Background refresh error: $e');
      return <LawyerProfile>[];
    }
  }

  @override
  Future<LawyerProfile?> getLawyerProfile(String profileId) async {
    final key = profileId.trim();
    if (key.isEmpty) return null;
    final cached = _profileMemoryCache[key];
    if (cached != null && DateTime.now().difference(cached.timestamp) <= _cacheTtl) return cached.profile;
    try {
      final response = await _supabase.rpc('get_public_lawyer', params: {'p_profile_id': key});
      final rows = response as List;
      if (rows.isEmpty) return null;
      final json = Map<String, dynamic>.from(rows.first as Map);
      final model = LawyerProfileModel.fromJson(json);
      final profile = model.toEntity().copyWith(fullName: model.fullName ?? 'محامي', avatarUrl: json['avatar_url'] as String?);
      _profileMemoryCache[key] = _MemoryProfile(profile, DateTime.now());
      return profile;
    } catch (e) {
      debugPrint('❌ LawyersRepo: Profile fetch error: $e');
      return null;
    }
  }

  @override
  Future<LawyerProfile?> getOwnLawyerProfile(String profileId) async {
    final key = profileId.trim();
    if (key.isEmpty) return null;
    try {
      final row = await _supabase
          .from('lawyer_profiles')
          .select()
          .eq('profile_id', key)
          .maybeSingle();
      if (row == null) return null;
      final json = Map<String, dynamic>.from(row);
      final model = LawyerProfileModel.fromJson(json);
      return model.toEntity().copyWith(
            fullName: json['full_name'] as String? ?? 'محامي',
            avatarUrl: json['avatar_url'] as String?,
          );
    } catch (e) {
      debugPrint('❌ LawyersRepo: Own profile fetch error: $e');
      return null;
    }
  }

  @override
  Future<void> updateLawyerProfile(LawyerProfile profile) async {
    final data = <String, dynamic>{
      'profile_id': profile.profileId,
      'license_number': profile.licenseNumber,
      'practice_license_class': profile.practiceLicenseClass,
      'bio': profile.bio,
      'years_experience': profile.yearsExperience,
      'consultation_price': profile.consultationPrice,
      'whatsapp': profile.whatsapp,
      'id_card_url': profile.idCardUrl,
      'availability': profile.availability,
      'services': profile.services.map((s) => s.toJson()).toList(),
    };
    if (profile.specializations.isNotEmpty) data['specialization'] = profile.specializations;
    await _supabase.from('lawyer_profiles').upsert(data, onConflict: 'profile_id');
    try {
      _memoryCache.clear();
      _profileMemoryCache.remove(profile.profileId);
      final box = Hive.box('app_cache');
      final keys = box.keys.where((key) => key.toString().startsWith(_cachePrefix)).toList();
      await box.deleteAll(keys);
    } catch (_) {}
  }

  @override
  Future<String> uploadFile(Uint8List bytes, String fileName, String bucket) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('المستخدم غير مسجل دخول');
    final leafName = fileName.split(RegExp(r'[/\\]')).last;
    final safe = leafName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final safeName = safe.isEmpty ? 'upload.bin' : safe;
    final path = '${user.id}/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    final ext = safeName.contains('.') ? safeName.split('.').last.toLowerCase() : '';
    final contentType = switch (ext) {'png' => 'image/png', 'webp' => 'image/webp', 'pdf' => 'application/pdf', 'jpg' || 'jpeg' => 'image/jpeg', _ => 'application/octet-stream'};
    await _supabase.storage.from(bucket).uploadBinary(path, bytes, fileOptions: FileOptions(upsert: false, contentType: contentType));
    if (bucket == 'avatars') {
      return _supabase.storage.from(bucket).getPublicUrl(path);
    }
    return PrivateStorageReference.encode(bucket: bucket, path: path);
  }

  @override
  Future<void> requestSpecializationChange(List<String> specializations, {String? unionIdCardUrl}) async {
    final normalized = specializations.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList(growable: false);
    if (normalized.isEmpty) throw Exception('اختر تخصصاً واحداً على الأقل');
    final document = unionIdCardUrl?.trim();
    if (document == null || document.isEmpty) throw Exception('هوية النقابة مطلوبة لمراجعة تغيير التخصص');

    await _supabase.rpc(
      'request_specialization_change',
      params: {
        'p_requested_specializations': normalized,
        'p_union_id_card_url': document,
      },
    );
  }
}

class _MemoryPage {
  final List<dynamic> rows;
  final DateTime timestamp;
  const _MemoryPage(this.rows, this.timestamp);
}

class _MemoryProfile {
  final LawyerProfile profile;
  final DateTime timestamp;
  const _MemoryProfile(this.profile, this.timestamp);
}
