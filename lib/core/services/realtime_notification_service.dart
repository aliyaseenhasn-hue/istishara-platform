import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import 'notification_service.dart';

class RealtimeNotificationService {
  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _authSubscription;

  Future<void> start() async {
    await stop();
    final client = SupabaseConfig.client;
    await _bindCurrentUser(client.auth.currentUser);
    _authSubscription = client.auth.onAuthStateChange.listen((event) async {
      await _bindCurrentUser(event.session?.user);
    });
  }

  Future<void> _bindCurrentUser(User? user) async {
    await _channel?.unsubscribe();
    _channel = null;
    if (user == null) return;

    final profile = await SupabaseConfig.client
        .from('profiles')
        .select('id')
        .eq('auth_id', user.id)
        .maybeSingle();
    final profileId = profile?['id']?.toString();
    if (profileId == null) return;

    _channel = SupabaseConfig.client
        .channel('user-notifications-$profileId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: profileId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            NotificationService.showNotification(
              title: (row['title'] ?? 'إشعار جديد').toString(),
              body: (row['body'] ?? '').toString(),
              payload: row['id']?.toString(),
            );
          },
        )
        .subscribe();
  }

  Future<void> stop() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
    await _channel?.unsubscribe();
    _channel = null;
  }
}
