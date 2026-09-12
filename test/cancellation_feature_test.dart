import 'package:flutter_test/flutter_test.dart';
import 'package:astshara/features/bookings/domain/cancellation_policy.dart';

void main() {
  group('BookingCancellationPolicy', () {
    test('allows an eligible future confirmed booking', () {
      expect(
        BookingCancellationPolicy.canRequest(
          status: 'مؤكد',
          scheduledAt: DateTime.now().add(const Duration(hours: 2)),
          pendingReview: false,
        ),
        isTrue,
      );
    });

    test('hides the action while a request is pending', () {
      expect(
        BookingCancellationPolicy.canRequest(
          status: 'مؤكد',
          scheduledAt: DateTime.now().add(const Duration(hours: 2)),
          pendingReview: true,
        ),
        isFalse,
      );
    });

    test('rejects completed and in-progress bookings', () {
      for (final status in ['مكتمل', 'قيد التنفيذ', 'ملغي', 'مسترد']) {
        expect(
          BookingCancellationPolicy.canRequest(
            status: status,
            scheduledAt: DateTime.now().add(const Duration(hours: 2)),
            pendingReview: false,
          ),
          isFalse,
          reason: status,
        );
      }
    });

    test('rejects a booking whose appointment has passed', () {
      expect(
        BookingCancellationPolicy.canRequest(
          status: 'مؤكد',
          scheduledAt: DateTime.now().subtract(const Duration(minutes: 1)),
          pendingReview: false,
        ),
        isFalse,
      );
    });
  });
}
