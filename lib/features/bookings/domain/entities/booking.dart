class Booking {
  final String id;
  final String userId;
  final String lawyerId;
  final String status;
  final DateTime scheduledAt;
  final double price;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final String? lawyerName;
  final String? userName;
  final String? consultationType;
  final String? consultationMode;
  final String? description;
  final String? documentUrl;
  final String? whatsappNumber;
  final bool lawyerApproved;
  final bool paymentRequired;
  final DateTime? paymentWaivedAt;
  final String? paymentWaiverReason;
  final bool manualPaymentRequired;
  final double? manualReceivedAmount;
  final DateTime? manualReceivedAt;

  const Booking({
    required this.id,
    required this.userId,
    required this.lawyerId,
    this.status = 'قيد انتظار الدفع',
    required this.scheduledAt,
    required this.price,
    this.createdAt,
    this.startedAt,
    this.lawyerName,
    this.userName,
    this.consultationType,
    this.consultationMode,
    this.description,
    this.documentUrl,
    this.whatsappNumber,
    this.lawyerApproved = false,
    this.paymentRequired = true,
    this.paymentWaivedAt,
    this.paymentWaiverReason,
    this.manualPaymentRequired = false,
    this.manualReceivedAmount,
    this.manualReceivedAt,
  });

  bool get isInOffice => consultationMode == 'في المكتب';
  bool get isFreeBeta => !paymentRequired && paymentWaiverReason == 'free_beta';
  bool get isManualPaymentPending => isInOffice &&
      paymentRequired &&
      manualPaymentRequired &&
      (manualReceivedAmount == null || manualReceivedAmount! <= 0);

  Booking copyWith({
    String? id, String? userId, String? lawyerId, String? status,
    DateTime? scheduledAt, double? price, DateTime? createdAt,
    DateTime? startedAt, String? lawyerName, String? userName,
    String? consultationType, String? consultationMode, String? description,
    String? documentUrl, String? whatsappNumber, bool? lawyerApproved,
    bool? paymentRequired, DateTime? paymentWaivedAt,
    String? paymentWaiverReason,
    bool? manualPaymentRequired, double? manualReceivedAmount,
    DateTime? manualReceivedAt,
  }) {
    return Booking(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      lawyerId: lawyerId ?? this.lawyerId,
      status: status ?? this.status,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      price: price ?? this.price,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      lawyerName: lawyerName ?? this.lawyerName,
      userName: userName ?? this.userName,
      consultationType: consultationType ?? this.consultationType,
      consultationMode: consultationMode ?? this.consultationMode,
      description: description ?? this.description,
      documentUrl: documentUrl ?? this.documentUrl,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      lawyerApproved: lawyerApproved ?? this.lawyerApproved,
      paymentRequired: paymentRequired ?? this.paymentRequired,
      paymentWaivedAt: paymentWaivedAt ?? this.paymentWaivedAt,
      paymentWaiverReason: paymentWaiverReason ?? this.paymentWaiverReason,
      manualPaymentRequired: manualPaymentRequired ?? this.manualPaymentRequired,
      manualReceivedAmount: manualReceivedAmount ?? this.manualReceivedAmount,
      manualReceivedAt: manualReceivedAt ?? this.manualReceivedAt,
    );
  }
}
