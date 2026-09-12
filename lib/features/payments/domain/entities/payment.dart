class Payment {
  final String id;
  final String bookingId;
  final double amount;
  final String paymentMethod;
  final String? transactionNumber;
  final String? receiptUrl;
  final String status;
  final DateTime? createdAt;

  const Payment({
    required this.id,
    required this.bookingId,
    required this.amount,
    required this.paymentMethod,
    this.transactionNumber,
    this.receiptUrl,
    this.status = 'قيد معالجة الدفع',
    this.createdAt,
  });

  Payment copyWith({
    String? id,
    String? bookingId,
    double? amount,
    String? paymentMethod,
    String? transactionNumber,
    String? receiptUrl,
    String? status,
    DateTime? createdAt,
  }) {
    return Payment(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionNumber: transactionNumber ?? this.transactionNumber,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
