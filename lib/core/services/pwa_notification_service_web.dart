import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

import '../config/supabase_config.dart';

@JS('astsharaEnablePush')
external JSPromise<JSString?> _enablePush(JSString vapidPublicKey);

@JS('astsharaDisablePush')
external JSPromise<JSBoolean> _disablePush();

@JS('astsharaGetPushState')
external JSPromise<JSString> _getPushState();

@JS('astsharaGetExistingPushSubscription')
external JSPromise<JSString?> _getExistingPushSubscription();

@JS('astsharaGetPushDeviceKey')
external JSString _getPushDeviceKey();

class PwaNotificationService {
  static const String _vapidPublicKey = String.fromEnvironment('VAPID_PUBLIC_KEY');
  static StreamSubscription<AuthState>? _authSubscription;
  static bool _initialized = false;

  static bool get supported => _vapidPublicKey.isNotEmpty;

  static Future<void> initialize() async {
    if (!supported || _initialized) return;
    _initialized = true;

    _authSubscription = SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed ||
          event == AuthChangeEvent.initialSession) {
        unawaited(syncForCurrentUser());
      }
    });

    if (SupabaseConfig.client.auth.currentUser != null) {
      await syncForCurrentUser();
    }
  }

  static Future<bool> isEnabled() async {
    if (!supported) return false;
    try {
      final state = jsonDecode((await _getPushState().toDart).toDart) as Map<String, dynamic>;
      return state['permission'] == 'granted' && state['subscribed'] == true;
    } catch (_) {
      return false;
    }
  }

  static String? _deviceKey() {
    try {
      final value = _getPushDeviceKey().toDart.trim();
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _registerSubscription(String rawSubscription) async {
    try {
      final decoded = jsonDecode(rawSubscription) as Map<String, dynamic>;
      final subscription = Map<String, dynamic>.from(decoded);
      final rawKeys = subscription['keys'];
      if (subscription['endpoint'] is! String || rawKeys is! Map) return false;
      final keys = Map<String, dynamic>.from(rawKeys);
      if (keys['p256dh'] is! String || keys['auth'] is! String) return false;

      if (SupabaseConfig.client.auth.currentUser == null) return false;

      await SupabaseConfig.client.rpc(
        'register_current_pwa_push_subscription',
        params: <String, dynamic>{
          'p_endpoint': subscription['endpoint'],
          'p_p256dh': keys['p256dh'],
          'p_auth': keys['auth'],
          'p_user_agent': web.window.navigator.userAgent,
          'p_device_key': _deviceKey(),
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> enable() async {
    if (!supported) return false;

    try {
      final result = await _enablePush(_vapidPublicKey.toJS).toDart;
      if (result == null) return false;
      return _registerSubscription(result.toDart);
    } catch (_) {
      return false;
    }
  }

  /// Rebind an already-authorized browser subscription to the currently
  /// authenticated account without showing a permission prompt.
  static Future<bool> syncForCurrentUser() async {
    if (!supported || SupabaseConfig.client.auth.currentUser == null) return false;
    try {
      final result = await _getExistingPushSubscription().toDart;
      if (result == null) return false;
      return _registerSubscription(result.toDart);
    } catch (_) {
      return false;
    }
  }

  /// Removes the current browser/device ownership from the signed-in account
  /// while keeping the browser permission itself intact for the next login.
  static Future<void> releaseForCurrentUser() async {
    if (!supported || SupabaseConfig.client.auth.currentUser == null) return;
    try {
      String? endpoint;
      final result = await _getExistingPushSubscription().toDart;
      if (result != null) {
        final decoded = jsonDecode(result.toDart) as Map<String, dynamic>;
        endpoint = decoded['endpoint']?.toString();
      }

      await SupabaseConfig.client.rpc(
        'unregister_current_pwa_push_subscription',
        params: <String, dynamic>{
          'p_endpoint': endpoint,
          'p_device_key': _deviceKey(),
        },
      );
    } catch (_) {
      // Logout must still be able to continue if push cleanup is unavailable.
    }
  }

  static Future<bool> disable() async {
    if (!supported) return true;

    await releaseForCurrentUser();
    try {
      return (await _disablePush().toDart).toDart;
    } catch (_) {
      return false;
    }
  }
}
