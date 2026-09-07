import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:astshara/core/config/supabase_config.dart';
import 'package:astshara/core/navigation/app_navigation.dart';
import '../../features/bookings/data/models/booking_model.dart';

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

  /// Handles a push payload received from FCM when the app is backgrounded or
  /// terminated and subsequently opened by the user.
  static Future<void> handleExternalPayload(String payload) async {
    if (payload.trim().isEmpty) return;
    _pendingPayload = payload;
    _schedulePendingNavigation();
  }

  static void _schedulePendingNavigation() {
    _pendingNavigationTimer?.cancel();
    _pendingNavigationTimer = Timer.periodic(const Duration(milliseconds: 350),
        (timer) async {
      if (_pendingPayload == null) {
        timer.cancel();
        return;
      }
      final context = AppNavigation.navigatorKey.currentContext;
      if (context == null) return;
      final payload = _pendingPayload;
      _pendingPayload = null;
      timer.cancel();
      try {
        await _navigateFromNotification(context, payload!);
      } catch (e, stack) {
        debugPrint('Notification navigation error: $e');
        debugPrintStack(stackTrace: stack);
      }
    });
  }

  static Future<void> _navigateFromNotification(
      BuildContext context, String payload) async {
    final notificationId = _decodeNotificationId(payload);
    if (notificationId == null) {
      if (context.mounted) GoRouter.of(context).push('/notifications');
      return;
    }

    final notification = await SupabaseConfig.client
        .from('notifications')
        .select('type,reference_id,reference_type')
        .eq('id', notificationId)
        .maybeSingle();

    if (notification == null) {
      if (context.mounted) GoRouter.of(context).push('/notifications');
      return;
    }

    final type = notification['type']?.toString();
    final referenceId = notification['reference_id']?.toString();
    final referenceType = notification['reference_type']?.toString();

    if (referenceId != null &&
        (referenceType == 'booking' || type == 'booking' || type == 'payment')) {
      final response = await SupabaseConfig.client.rpc(
        'get_booking_for_notification',
        params: {'p_booking_id': referenceId},
      );
      Map<String, dynamic>? row;
      if (response is List && response.isNotEmpty) {
        row = Map<String, dynamic>.from(response.first as Map);
      } else if (response is Map && response.isNotEmpty) {
        row = Map<String, dynamic>.from(response);
      }
      if (row != null && context.mounted) {
        final booking = BookingModel.fromJson(row).toEntity();
        GoRouter.of(context).push('/booking-details', extra: booking);
        return;
      }
    }

    if (referenceId != null &&
        (referenceType == 'conversation' || referenceType == 'chat' || type == 'chat')) {
      if (context.mounted) {
        GoRouter.of(context).push('/chat/$referenceId');
        return;
      }
    }

    if (referenceId != null &&
        (referenceType == 'lawyer' || referenceType == 'lawyer_profile')) {
      if (context.mounted) {
        GoRouter.of(context).push('/lawyer-details/$referenceId');
        return;
      }
    }

    if (context.mounted) GoRouter.of(context).push('/notifications');
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
        sound: 'notification.caf',
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
