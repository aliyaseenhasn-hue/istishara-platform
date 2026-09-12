import 'package:flutter_test/flutter_test.dart';
import 'package:astshara/features/bookings/domain/entities/booking.dart';

void main() {
  final scheduled = DateTime(2026, 8, 11, 12);

  test('office booking requires manual payment only when configured', () {
    final pending = Booking(
      id: 'b1',
      userId: 'u1',
      lawyerId: 'l1',
      scheduledAt: scheduled,
      price: 100,
      consultationMode: 'في المكتب',
      manualPaymentRequired: true,
    );

    expect(pending.isInOffice, isTrue);
    expect(pending.isManualPaymentPending, isTrue);

    final paid = pending.copyWith(manualReceivedAmount: 100);
    expect(paid.isManualPaymentPending, isFalse);
  });

  test('remote booking is not treated as office/manual payment', () {
    final booking = Booking(
      id: 'b2',
      userId: 'u1',
      lawyerId: 'l1',
      scheduledAt: scheduled,
      price: 100,
      consultationMode: 'عن بعد',
      manualPaymentRequired: false,
    );

    expect(booking.isInOffice, isFalse);
    expect(booking.isManualPaymentPending, isFalse);
  });

  test('free beta booking never requires electronic or manual payment', () {
    final booking = Booking(
      id: 'beta-1',
      userId: 'u1',
      lawyerId: 'l1',
      scheduledAt: scheduled,
      price: 100,
      consultationMode: 'في المكتب',
      paymentRequired: false,
      paymentWaivedAt: scheduled,
      paymentWaiverReason: 'free_beta',
      manualPaymentRequired: false,
    );

    expect(booking.isFreeBeta, isTrue);
    expect(booking.isManualPaymentPending, isFalse);
  });

  test('copyWith preserves booking identity and required fields', () {
    final booking = Booking(
      id: 'b3',
      userId: 'u1',
      lawyerId: 'l1',
      scheduledAt: scheduled,
      price: 75,
    );

    final updated = booking.copyWith(status: 'قيد التنفيذ');

    expect(updated.id, 'b3');
    expect(updated.userId, 'u1');
    expect(updated.lawyerId, 'l1');
    expect(updated.price, 75);
    expect(updated.status, 'قيد التنفيذ');
  });
}
