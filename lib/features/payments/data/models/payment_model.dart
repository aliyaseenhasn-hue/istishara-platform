import '../../domain/entities/payment.dart';

class PaymentModel {
  final String id;
  final String bookingId;
  final double amount;
  final String paymentMethod;
  final String? transactionNumber;
  final String? receiptUrl;
  final String status;
  final DateTime? createdAt;

  const PaymentModel({
    required this.id,
    required this.bookingId,
    required this.amount,
    required this.paymentMethod,
    this.transactionNumber,
    this.receiptUrl,
    required this.status,
    this.createdAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as String? ?? '',
      bookingId: json['booking_id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method'] as String? ?? '',
      transactionNumber: json['transaction_number'] as String?,
      receiptUrl: json['receipt_url'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Payment toEntity() => Payment(
        id: id,
        bookingId: bookingId,
        amount: amount,
        paymentMethod: paymentMethod,
        transactionNumber: transactionNumber,
        receiptUrl: receiptUrl,
        status: status,
        createdAt: createdAt,
      );
}
