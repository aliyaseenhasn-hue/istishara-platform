import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/config/supabase_config.dart';
import '../core/services/notification_service.dart';
import '../core/services/push_notification_service.dart';
import '../core/services/realtime_notification_service.dart';

const _buildSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _buildSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

// Supabase publishable/anon keys are safe to embed in a client application.
// Build-time values always take precedence; these defaults keep direct web
// deployments (for example Cloudflare Pages) from failing before runApp().
const _publicSupabaseUrl = 'https://iidxqrnrazkyfgzelzhb.supabase.co';
const _publicSupabaseAnonKey = 'sb_publishable_LX3dMTuEV3WKxXVEjdaDNw_O3BK-gCa';

Future<ProviderContainer> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Supabase is required by authentication/routing and therefore remains on
    // the critical startup path. Everything else is warmed up after runApp().
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      debugPrint('⚠️ .env not available; using build-time/public client configuration');
    }

    final supabaseUrl = _buildSupabaseUrl.isNotEmpty
        ? _buildSupabaseUrl
        : (dotenv.env['SUPABASE_URL']?.isNotEmpty == true
            ? dotenv.env['SUPABASE_URL']!
            : _publicSupabaseUrl);
    final supabaseAnonKey = _buildSupabaseAnonKey.isNotEmpty
        ? _buildSupabaseAnonKey
        : (dotenv.env['SUPABASE_ANON_KEY']?.isNotEmpty == true
            ? dotenv.env['SUPABASE_ANON_KEY']!
            : _publicSupabaseAnonKey);

    await SupabaseConfig.initializeWithCredentials(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  } catch (e, stackTrace) {
    debugPrint('🚨 Critical Bootstrap Error: $e');
    debugPrintStack(stackTrace: stackTrace);
    rethrow;
  }

  final container = ProviderContainer();

  // Cache, notifications, push registration and realtime are useful but are
  // not required to paint the first frame. Deferring them removes disk/plugin
  // initialization from the cold-start critical path without changing their
  // behavior once the application is running.
  unawaited(_warmUpNonCriticalServices());

  return container;
}

Future<void> _warmUpNonCriticalServices() async {
  try {
    await Hive.initFlutter();
    await Hive.openBox('app_cache');
  } catch (error, stackTrace) {
    debugPrint('⚠️ App cache unavailable: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  unawaited(
    NotificationService.initialize().catchError((error, stackTrace) {
      debugPrint('⚠️ Local notification service unavailable: $error');
      debugPrintStack(stackTrace: stackTrace);
    }),
  );

  // Native FCM is intentionally disabled on Web so the existing PWA/Web Push
  // implementation remains untouched. Android/iOS register their FCM token.
  unawaited(
    PushNotificationService.initialize().catchError((error, stackTrace) {
      debugPrint('⚠️ Native FCM unavailable: $error');
      debugPrintStack(stackTrace: stackTrace);
    }),
  );

  final realtimeService = RealtimeNotificationService();
  unawaited(
    realtimeService.start().catchError((error, stackTrace) {
      debugPrint('⚠️ Realtime notifications unavailable: $error');
      debugPrintStack(stackTrace: stackTrace);
    }),
  );
}
