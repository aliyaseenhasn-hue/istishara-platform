import '../../domain/entities/booking.dart';

class BookingModel {
  final String id;
  final String userId;
  final String lawyerId;
  final String status;
  final DateTime scheduledAt;
  final double price;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final String? whatsappNumber;
  final bool lawyerApproved;
  final bool paymentRequired;
  final DateTime? paymentWaivedAt;
  final String? paymentWaiverReason;
  final String? consultationMode;
  final bool manualPaymentRequired;
  final double? manualReceivedAmount;
  final DateTime? manualReceivedAt;

  const BookingModel({
    required this.id,
    required this.userId,
    required this.lawyerId,
    required this.status,
    required this.scheduledAt,
    required this.price,
    this.createdAt,
    this.startedAt,
    this.whatsappNumber,
    this.lawyerApproved = false,
    this.paymentRequired = true,
    this.paymentWaivedAt,
    this.paymentWaiverReason,
    this.consultationMode,
    this.manualPaymentRequired = false,
    this.manualReceivedAmount,
    this.manualReceivedAt,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) => BookingModel(
        id: json['id'] as String? ?? '',
        userId: json['user_id'] as String? ?? '',
        lawyerId: json['lawyer_id'] as String? ?? '',
        status: json['status'] as String? ?? 'قيد انتظار الدفع',
        scheduledAt: json['scheduled_at'] != null
            ? DateTime.parse(json['scheduled_at'] as String)
            : DateTime.now(),
        price: (json['price'] as num?)?.toDouble() ?? 0,
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
        startedAt: json['started_at'] != null ? DateTime.parse(json['started_at'] as String) : null,
        whatsappNumber: json['whatsapp_number'] as String?,
        lawyerApproved: json['lawyer_approved'] as bool? ?? false,
        paymentRequired: json['payment_required'] as bool? ?? true,
        paymentWaivedAt: json['payment_waived_at'] != null ? DateTime.parse(json['payment_waived_at'] as String) : null,
        paymentWaiverReason: json['payment_waiver_reason'] as String?,
        consultationMode: json['consultation_mode'] as String?,
        manualPaymentRequired: json['manual_payment_required'] as bool? ?? false,
        manualReceivedAmount: (json['manual_received_amount'] as num?)?.toDouble(),
        manualReceivedAt: json['manual_received_at'] != null ? DateTime.parse(json['manual_received_at'] as String) : null,
      );

  Booking toEntity() => Booking(
        id: id,
        userId: userId,
        lawyerId: lawyerId,
        status: status,
        scheduledAt: scheduledAt,
        price: price,
        createdAt: createdAt,
        startedAt: startedAt,
        whatsappNumber: whatsappNumber,
        lawyerApproved: lawyerApproved,
        paymentRequired: paymentRequired,
        paymentWaivedAt: paymentWaivedAt,
        paymentWaiverReason: paymentWaiverReason,
        consultationMode: consultationMode,
        manualPaymentRequired: manualPaymentRequired,
        manualReceivedAmount: manualReceivedAmount,
        manualReceivedAt: manualReceivedAt,
      );
}
