import 'package:supabase_flutter/supabase_flutter.dart';

class QiCardPaymentService {
  final SupabaseClient _supabase;

  QiCardPaymentService(this._supabase);

  Future<String> createPayment({required String bookingId}) async {
    final response = await _supabase.functions.invoke(
      'qicard-create-payment',
      body: {'booking_id': bookingId},
    );

    final data = response.data;
    if (data is! Map) {
      throw Exception('تعذر إنشاء عملية الدفع');
    }

    final error = data['error'];
    if (error != null) throw Exception(error.toString());

    final formUrl = data['formUrl'];
    if (formUrl is! String || formUrl.isEmpty) {
      throw Exception('لم يتم استلام رابط الدفع');
    }

    return formUrl;
  }

  Future<Map<String, dynamic>> checkPaymentStatus({required String bookingId}) async {
    final response = await _supabase.functions.invoke(
      'qicard-check-payment-status',
      body: {'booking_id': bookingId},
    );

    final data = response.data;
    if (data is! Map) {
      throw Exception('تعذر التحقق من حالة الدفع');
    }

    final error = data['error'];
    if (error != null) throw Exception(error.toString());

    return Map<String, dynamic>.from(data);
  }
}
