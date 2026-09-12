import '../entities/booking.dart';

abstract class BookingsRepository {
  Future<Booking> createBooking({
    required String lawyerId,
    required DateTime scheduledAt,
    String? slotId,
    required String packageName,
    required String consultationType,
    String? description,
    String? documentUrl,
    String? consultationMode,
  });

  Future<List<Booking>> getUserBookings(String userId);
  Future<List<Booking>> getLawyerBookings(String lawyerId);
  Future<void> updateBookingStatus(String bookingId, String status);
  Future<Booking> reviewBooking(String bookingId, bool approved);
  Future<Booking> recordManualPayment(String bookingId, double amount);
  Future<void> archiveBookingForUser(String bookingId);
  Future<void> archiveBookingForLawyer(String bookingId);
  Future<void> restoreBookingFromArchive(String bookingId);
  Future<void> reportNoShow(String bookingId, [bool? isLawyer]);
  Future<String> uploadDocument(dynamic fileBytes, String fileName);
}
