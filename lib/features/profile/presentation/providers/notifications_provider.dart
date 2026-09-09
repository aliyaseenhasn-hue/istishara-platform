import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/supabase_config.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final String? referenceId;
  final String? referenceType;

  const AppNotification({required this.id, required this.title, required this.body, required this.type, required this.isRead, required this.createdAt, this.referenceId, this.referenceType});
  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(id: map['id'].toString(), title: (map['title'] ?? 'إشعار جديد').toString(), body: (map['body'] ?? '').toString(), type: (map['type'] ?? 'system').toString(), isRead: map['is_read'] == true, createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ?? DateTime.now(), referenceId: map['reference_id']?.toString(), referenceType: map['reference_type']?.toString());
}

/// Returns null when Supabase has not been initialized yet (for example during
/// an isolated Flutter widget test). The app can then render without requiring
/// a live backend connection.
SupabaseClient? _clientOrNull() {
  try {
    return SupabaseConfig.client;
  } on AssertionError {
    return null;
  } catch (_) {
    return null;
  }
}

Future<String?> _currentProfileId() async {
  final client = _clientOrNull();
  if (client == null) return null;
  try {
    final user = client.auth.currentUser;
    if (user == null) return null;
    final profile = await client.from('profiles').select('id').eq('auth_id', user.id).maybeSingle();
    return profile?['id']?.toString();
  } catch (_) {
    return null;
  }
}

final notificationsProvider = FutureProvider<List<AppNotification>>((ref) async {
  final client = _clientOrNull();
  if (client == null) return const [];
  final profileId = await _currentProfileId();
  if (profileId == null) return const [];
  try {
    final rows = await client.from('notifications').select('id,title,body,type,is_read,created_at,reference_id,reference_type').eq('user_id', profileId).order('created_at', ascending: false).limit(100);
    return (rows as List).map((row) => AppNotification.fromMap(Map<String, dynamic>.from(row as Map))).toList();
  } catch (_) {
    return const [];
  }
});

/// Emits only newly-created notifications for the signed-in profile.
final realtimeNotificationsProvider = StreamProvider.autoDispose<AppNotification>((ref) {
  late final StreamController<AppNotification> controller;
  RealtimeChannel? channel;
  String? profileId;

  Future<void> start() async {
    final client = _clientOrNull();
    if (client == null) return;
    profileId = await _currentProfileId();
    if (profileId == null || controller.isClosed) return;
    try {
      channel = client
          .channel('notifications:${profileId!}')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: profileId!,
            ),
            callback: (payload) {
              if (controller.isClosed) return;
              controller.add(AppNotification.fromMap(Map<String, dynamic>.from(payload.newRecord)));
            },
          )
          .subscribe();
    } catch (_) {
      // Realtime is optional for initial rendering; avoid breaking the app
      // when the backend is unavailable or not initialized yet.
    }
  }

  controller = StreamController<AppNotification>(onListen: start);
  ref.onDispose(() async {
    await channel?.unsubscribe();
    if (!controller.isClosed) await controller.close();
  });
  return controller.stream;
});

final unreadNotificationsCountProvider = FutureProvider<int>((ref) async {
  final client = _clientOrNull();
  if (client == null) return 0;
  final profileId = await _currentProfileId();
  if (profileId == null) return 0;
  try {
    final rows = await client.from('notifications').select('id').eq('user_id', profileId).eq('is_read', false);
    return (rows as List).length;
  } catch (_) {
    return 0;
  }
});

Future<void> markNotificationAsRead(String id) async {
  final client = _clientOrNull();
  if (client == null) return;
  final profileId = await _currentProfileId();
  if (profileId == null) return;
  await client.from('notifications').update({'is_read': true}).eq('id', id).eq('user_id', profileId);
}

Future<void> markAllNotificationsAsRead() async {
  final client = _clientOrNull();
  if (client == null) return;
  final profileId = await _currentProfileId();
  if (profileId == null) return;
  await client.from('notifications').update({'is_read': true}).eq('user_id', profileId).eq('is_read', false);
}

Future<void> deleteNotification(String id) async {
  final client = _clientOrNull();
  if (client == null) {
    throw StateError('Supabase is not available');
  }
  final profileId = await _currentProfileId();
  if (profileId == null) {
    throw StateError('No signed-in profile');
  }

  final deleted = await client
      .from('notifications')
      .delete()
      .eq('id', id)
      .eq('user_id', profileId)
      .select('id');

  if ((deleted as List).isEmpty) {
    throw StateError('Notification was not deleted');
  }
}
