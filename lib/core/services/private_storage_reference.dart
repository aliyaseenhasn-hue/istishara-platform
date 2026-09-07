import 'package:supabase_flutter/supabase_flutter.dart';

class PrivateStorageObjectRef {
  final String bucket;
  final String path;

  const PrivateStorageObjectRef({required this.bucket, required this.path});
}

class PrivateStorageReference {
  static const _prefix = 'private-storage://';

  static String encode({required String bucket, required String path}) {
    final safeBucket = bucket.trim();
    final safePath = path.trim();
    if (safeBucket.isEmpty || safePath.isEmpty) {
      throw ArgumentError('Private storage bucket and path are required');
    }
    return '$_prefix$safeBucket/$safePath';
  }

  static PrivateStorageObjectRef? tryParse(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty || !raw.startsWith(_prefix)) return null;
    final remainder = raw.substring(_prefix.length);
    final slash = remainder.indexOf('/');
    if (slash <= 0 || slash == remainder.length - 1) return null;
    final bucket = remainder.substring(0, slash);
    final path = remainder.substring(slash + 1);
    if (bucket.isEmpty || path.isEmpty || path.contains('..')) return null;
    return PrivateStorageObjectRef(bucket: bucket, path: path);
  }

  static Future<String?> resolve(
    SupabaseClient client,
    String? value, {
    int expiresIn = 300,
  }) async {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return null;
    final ref = tryParse(raw);
    if (ref == null) return raw;
    return client.storage.from(ref.bucket).createSignedUrl(ref.path, expiresIn);
  }
}
