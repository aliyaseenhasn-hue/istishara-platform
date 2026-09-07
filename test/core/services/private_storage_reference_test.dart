import 'package:astshara/core/services/private_storage_reference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrivateStorageReference', () {
    test('encodes and parses a durable private storage reference', () {
      final value = PrivateStorageReference.encode(
        bucket: 'lawyer_documents',
        path: 'auth-id/document.jpg',
      );

      expect(value, 'private-storage://lawyer_documents/auth-id/document.jpg');
      final parsed = PrivateStorageReference.tryParse(value);
      expect(parsed, isNotNull);
      expect(parsed!.bucket, 'lawyer_documents');
      expect(parsed.path, 'auth-id/document.jpg');
    });

    test('does not interpret ordinary or malformed URLs as storage refs', () {
      expect(
        PrivateStorageReference.tryParse('https://example.com/file.jpg'),
        isNull,
      );
      expect(
        PrivateStorageReference.tryParse('private-storage://bucket/../secret'),
        isNull,
      );
      expect(
        PrivateStorageReference.tryParse('private-storage://bucket'),
        isNull,
      );
    });
  });
}
