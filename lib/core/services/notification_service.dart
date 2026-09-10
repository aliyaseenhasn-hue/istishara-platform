import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:astshara/core/config/supabase_config.dart';
import 'package:astshara/core/navigation/app_navigation.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static String? _pendingPayload;
  static Timer? _pendingNavigationTimer;

  static Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _notificationsPlugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final launchDetails =
        await _notificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _pendingPayload = launchDetails?.notificationResponse?.payload;
      _schedulePendingNavigation();
    }

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'law_connect_channel',
        'إشعارات استشارة',
        description: 'إشعارات الحجوزات والدفع والمحادثات والموافقات',
        importance: Importance.max,
        playSound: true,
      ),
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    _pendingPayload = payload;
    _schedulePendingNavigation();
  }

  static Future<void> handleExternalPayload(String payload) async {
    if (payload.trim().isEmpty) return;
    _pendingPayload = payload;
    _schedulePendingNavigation();
  }

  static void _schedulePendingNavigation() {
    _pendingNavigationTimer?.cancel();
    var attempts = 0;
    _pendingNavigationTimer = Timer.periodic(
      const Duration(milliseconds: 350),
      (timer) async {
        attempts += 1;
        final payload = _pendingPayload;
        if (payload == null) {
          timer.cancel();
          return;
        }

        final context = AppNavigation.navigatorKey.currentContext;
        final sessionReady = SupabaseConfig.client.auth.currentUser != null;
        if (context == null || !sessionReady) {
          if (attempts >= 60) {
            timer.cancel();
          }
          return;
        }

        try {
          final navigated = await _navigateFromNotification(context, payload);
          if (navigated) {
            _pendingPayload = null;
            timer.cancel();
          } else if (attempts >= 60) {
            if (context.mounted) GoRouter.of(context).push('/notifications');
            _pendingPayload = null;
            timer.cancel();
          }
        } catch (e, stack) {
          debugPrint('Notification navigation error: $e');
          debugPrintStack(stackTrace: stack);
          if (attempts >= 60) {
            if (context.mounted) GoRouter.of(context).push('/notifications');
            _pendingPayload = null;
            timer.cancel();
          }
        }
      },
    );
  }

  static Future<bool> _navigateFromNotification(
      BuildContext context, String payload) async {
    final notificationId = _decodeNotificationId(payload);
    if (notificationId == null) return false;

    final notification = await SupabaseConfig.client
        .from('notifications')
        .select('type,reference_id,reference_type')
        .eq('id', notificationId)
        .maybeSingle();

    if (notification == null) return false;

    final type = notification['type']?.toString();
    final referenceId = notification['reference_id']?.toString();
    final referenceType = notification['reference_type']?.toString();

    if (referenceType == 'wallet_topup') {
      final authId = SupabaseConfig.client.auth.currentUser?.id;
      String? role;
      if (authId != null) {
        final profile = await SupabaseConfig.client
            .from('profiles')
            .select('role')
            .eq('auth_id', authId)
            .maybeSingle();
        role = profile?['role']?.toString();
      }
      if (context.mounted) {
        GoRouter.of(context).push(role == 'admin' ? '/admin/payments' : '/client-wallet');
        return true;
      }
    }

    if (referenceType == 'appointment_request') {
      if (context.mounted) {
        GoRouter.of(context).push('/appointment-requests');
        return true;
      }
    }

    if (referenceId != null && referenceId.isNotEmpty &&
        (referenceType == 'booking' || type == 'booking' || type == 'payment')) {
      if (context.mounted) {
        GoRouter.of(context).push(
          '/booking-details?booking_id=${Uri.encodeQueryComponent(referenceId)}',
        );
        return true;
      }
    }

    if (referenceId != null && referenceId.isNotEmpty &&
        (referenceType == 'conversation' || referenceType == 'chat' || type == 'chat')) {
      if (context.mounted) {
        GoRouter.of(context).push('/chat/${Uri.encodeComponent(referenceId)}');
        return true;
      }
    }

    if (referenceId != null && referenceId.isNotEmpty &&
        (referenceType == 'lawyer' || referenceType == 'lawyer_profile')) {
      if (context.mounted) {
        GoRouter.of(context).push('/lawyer-details/${Uri.encodeComponent(referenceId)}');
        return true;
      }
    }

    if (context.mounted) {
      GoRouter.of(context).push('/notifications');
      return true;
    }
    return false;
  }

  static String? _decodeNotificationId(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map && decoded['notification_id'] != null) {
        return decoded['notification_id'].toString();
      }
    } catch (_) {
      // Existing notifications use the notification UUID directly as payload.
    }
    return payload.trim().isEmpty ? null : payload.trim();
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final soundType = prefs.getString('notification_sound') ?? 'default';

      if (soundType != 'default') {
        await _playCustomSound(soundType);
      }

      const androidDetails = AndroidNotificationDetails(
        'law_connect_channel',
        'إشعارات استشارة',
        channelDescription: 'إشعارات الحجوزات والدفع والمحادثات والموافقات',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _notificationsPlugin.show(
        DateTime.now().microsecondsSinceEpoch.remainder(2147483647),
        title,
        body,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: payload,
      );
    } catch (e, stack) {
      debugPrint('Error showing notification: $e');
      debugPrintStack(stackTrace: stack);
    }
  }

  static Future<void> _playCustomSound(String soundName) async {
    try {
      await _audioPlayer.play(AssetSource('sounds/$soundName.mp3'));
    } catch (e, stack) {
      debugPrint('Warning: Failed to play custom sound: $e');
      debugPrintStack(stackTrace: stack);
    }
  }

  static Future<void> dispose() async {
    _pendingNavigationTimer?.cancel();
    await _audioPlayer.dispose();
  }

  static Future<void> setNotificationSound(String soundName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notification_sound', soundName);
  }
}
