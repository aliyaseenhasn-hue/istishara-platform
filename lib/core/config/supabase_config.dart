import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static SupabaseClient? _testClient;

  @visibleForTesting
  static void setTestClient(SupabaseClient client) {
    _testClient = client;
  }

  @visibleForTesting
  static void clearTestClient() {
    _testClient = null;
  }

  static String get url {
    final value = dotenv.env['SUPABASE_URL'] ??
        dotenv.env['NEXT_PUBLIC_SUPABASE_URL'] ??
        '';
    if (value.isEmpty) {
      debugPrint('❌ Error: SUPABASE_URL is not set');
    }
    return value;
  }

  static String get anonKey {
    final value = dotenv.env['SUPABASE_ANON_KEY'] ??
        dotenv.env['NEXT_PUBLIC_SUPABASE_ANON_KEY'] ??
        dotenv.env['NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY'] ??
        '';
    if (value.isEmpty) {
      debugPrint('❌ Error: SUPABASE_ANON_KEY is not set');
    }
    return value;
  }

  static String get hfToken => dotenv.env['HUGGING_FACE_TOKEN'] ?? '';

  static Future<void> initializeWithCredentials({
    required String url,
    required String anonKey,
  }) async {
    if (url.isEmpty || anonKey.isEmpty) {
      throw Exception('Supabase configuration is incomplete');
    }

    try {
      await Supabase.initialize(
        url: url,
        publishableKey: anonKey,
      );
      debugPrint('✅ Supabase initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing Supabase: $e');
      rethrow;
    }
  }

  static Future<void> initialize() async {
    await initializeWithCredentials(url: url, anonKey: anonKey);
  }

  static SupabaseClient get client {
    if (_testClient != null) return _testClient!;
    return Supabase.instance.client;
  }
}
