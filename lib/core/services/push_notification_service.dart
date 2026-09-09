import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import 'notification_service.dart';

/// Handles native FCM registration while preserving the existing Supabase
/// Realtime notification channel and the existing web/PWA push flow.
class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static StreamSubscription<String>? _tokenSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedSubscription;
  static StreamSubscription<AuthState>? _authSubscription;
  static bool _initialized = false;
  static bool _registrationInProgress = false;

  static Future<void> initialize() async {
    if (kIsWeb || _initialized) return;

    await Firebase.initializeApp();

    // Subscribe before resolving the current session so an initial session
    // restored after Firebase startup cannot race past token registration.
    _authSubscription = SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed ||
          event == AuthChangeEvent.initialSession) {
        unawaited(refreshForCurrentUser());
      }
    });

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('FCM notification permission denied');
      return;
    }

    _initialized = true;

    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;

      unawaited(
        NotificationService.showNotification(
          title: notification.title ?? 'إشعار جديد',
          body: notification.body ?? '',
          payload: _notificationPayload(message),
        ),
      );
    });

    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => unawaited(NotificationService.handleExternalPayload(
        _notificationPayload(message),
      )),
    );

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      unawaited(NotificationService.handleExternalPayload(
        _notificationPayload(initialMessage),
      ));
    }

    await refreshForCurrentUser();

    _tokenSubscription = _messaging.onTokenRefresh.listen((token) {
      unawaited(_registerToken(token));
    }, onError: (Object error, StackTrace stackTrace) {
      debugPrint('FCM token refresh error: $error');
      debugPrintStack(stackTrace: stackTrace);
    });
  }

  static String _notificationPayload(RemoteMessage message) {
    final notificationId = message.data['notification_id'] ?? message.data['id'];
    if (notificationId != null) return notificationId.toString();
    return message.data['payload']?.toString() ?? '';
  }

  static Future<void> _registerToken(String? token) async {
    if (token == null || token.isEmpty || kIsWeb || _registrationInProgress) return;

    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) {
      debugPrint('FCM token available, waiting for authenticated Supabase session');
      return;
    }

    _registrationInProgress = true;
    try {
      await SupabaseConfig.client.rpc(
        'register_current_push_device_token',
        params: <String, dynamic>{
          'p_token': token,
          'p_platform': defaultTargetPlatform.name,
        },
      );

      debugPrint('FCM token registered successfully for current account');
    } catch (error, stackTrace) {
      debugPrint('FCM token registration failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _registrationInProgress = false;
    }
  }

  static Future<void> refreshForCurrentUser() async {
    if (kIsWeb || !_initialized) return;
    try {
      final token = await _messaging.getToken();
      await _registerToken(token);
    } catch (error, stackTrace) {
      debugPrint('FCM token retrieval failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Detaches this native device token from the current account before logout.
  /// The token itself remains reusable and will be rebound on the next login.
  static Future<void> releaseForCurrentUser() async {
    if (kIsWeb || !_initialized || SupabaseConfig.client.auth.currentUser == null) return;
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      await SupabaseConfig.client.rpc(
        'unregister_current_push_device_token',
        params: <String, dynamic>{'p_token': token},
      );
    } catch (error, stackTrace) {
      debugPrint('FCM token release failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _authSubscription?.cancel();
    _tokenSubscription = null;
    _foregroundSubscription = null;
    _openedSubscription = null;
    _authSubscription = null;
    _initialized = false;
    _registrationInProgress = false;
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Notification payloads are displayed by the operating system while the
  // app is backgrounded/terminated. Keep this handler lightweight.
}
