import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:astshara/core/config/supabase_config.dart';

/// Client-facing breakdown of what a booking will cost.
///
/// Mirrors the server function `get_service_fee_preview`, which uses exactly
/// the same calculation as `create_booking`, so the amount shown before
/// confirming is the amount that will be charged.
class ServiceFeePreview {
  final String feeModel;
  final double lawyerPrice;
  final double serviceFee;
  final double clientTotal;

  const ServiceFeePreview({
    required this.feeModel,
    required this.lawyerPrice,
    required this.serviceFee,
    required this.clientTotal,
  });

  bool get hasServiceFee => serviceFee > 0;

  factory ServiceFeePreview.withoutFee(double lawyerPrice) => ServiceFeePreview(
        feeModel: 'lawyer_commission',
        lawyerPrice: lawyerPrice,
        serviceFee: 0,
        clientTotal: lawyerPrice,
      );
}

double _toDouble(dynamic value, double fallback) =>
    double.tryParse('${value ?? ''}') ?? fallback;

final serviceFeePreviewProvider =
    FutureProvider.autoDispose.family<ServiceFeePreview, double>((ref, lawyerPrice) async {
  if (lawyerPrice <= 0) return ServiceFeePreview.withoutFee(lawyerPrice);
  try {
    final response = await SupabaseConfig.client.rpc(
      'get_service_fee_preview',
      params: {'p_lawyer_price': lawyerPrice},
    );
    final row = response is List && response.isNotEmpty
        ? Map<String, dynamic>.from(response.first as Map)
        : response is Map
            ? Map<String, dynamic>.from(response)
            : null;
    if (row == null) return ServiceFeePreview.withoutFee(lawyerPrice);
    return ServiceFeePreview(
      feeModel: row['fee_model']?.toString() ?? 'lawyer_commission',
      lawyerPrice: _toDouble(row['lawyer_price'], lawyerPrice),
      serviceFee: _toDouble(row['service_fee'], 0),
      clientTotal: _toDouble(row['client_total'], lawyerPrice),
    );
  } catch (_) {
    // Older backend without the preview function: behave exactly as before.
    return ServiceFeePreview.withoutFee(lawyerPrice);
  }
});

/// Stored breakdown of an existing booking. Bookings created before the
/// service-fee model have no breakdown and return null.
class BookingFeeBreakdown {
  final double lawyerPrice;
  final double serviceFee;

  const BookingFeeBreakdown({required this.lawyerPrice, required this.serviceFee});
}

final bookingFeeBreakdownProvider =
    FutureProvider.autoDispose.family<BookingFeeBreakdown?, String>((ref, bookingId) async {
  try {
    final row = await SupabaseConfig.client
        .from('bookings')
        .select('fee_model_snapshot, lawyer_price, service_fee_amount')
        .eq('id', bookingId)
        .maybeSingle();
    if (row == null || row['fee_model_snapshot'] != 'client_service_fee') return null;
    final fee = _toDouble(row['service_fee_amount'], 0);
    final lawyerPrice = double.tryParse('${row['lawyer_price'] ?? ''}');
    if (fee <= 0 || lawyerPrice == null) return null;
    return BookingFeeBreakdown(lawyerPrice: lawyerPrice, serviceFee: fee);
  } catch (_) {
    return null;
  }
});

String formatIqd(double value) => '${value.toStringAsFixed(0)} د.ع';

/// Extra rows under the booking's price showing who gets what.
/// Renders nothing for legacy bookings, so older screens look unchanged.
class BookingFeeBreakdownRows extends ConsumerWidget {
  final String bookingId;
  final bool isLawyer;
  final Widget Function(String label, String value) rowBuilder;

  const BookingFeeBreakdownRows({
    super.key,
    required this.bookingId,
    required this.isLawyer,
    required this.rowBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakdown = ref.watch(bookingFeeBreakdownProvider(bookingId)).valueOrNull;
    if (breakdown == null) return const SizedBox.shrink();
    return Column(
      children: isLawyer
          ? [
              rowBuilder('صافي أتعابك', formatIqd(breakdown.lawyerPrice)),
              rowBuilder('رسوم المنصة', '${formatIqd(breakdown.serviceFee)} (يدفعها العميل)'),
            ]
          : [
              rowBuilder('أتعاب المحامي', formatIqd(breakdown.lawyerPrice)),
              rowBuilder('رسوم خدمة المنصة', formatIqd(breakdown.serviceFee)),
            ],
    );
  }
}

/// Conversation that belongs to a confirmed booking (created by the database
/// trigger `ensure_conversation_for_confirmed_booking`).
final bookingConversationIdProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, bookingId) async {
  try {
    final row = await SupabaseConfig.client
        .from('conversations')
        .select('id')
        .eq('booking_id', bookingId)
        .maybeSingle();
    return row?['id']?.toString();
  } catch (_) {
    return null;
  }
});

/// Primary way to hold the consultation: the in-app chat tied to the booking.
/// Renders nothing if the conversation is not available, leaving WhatsApp as
/// the fallback exactly as before.
class InAppConsultationButton extends ConsumerWidget {
  final String bookingId;

  const InAppConsultationButton({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversation = ref.watch(bookingConversationIdProvider(bookingId));
    final id = conversation.valueOrNull;
    if (id == null || id.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FilledButton.icon(
        onPressed: () => context.push('/chat/${Uri.encodeComponent(id)}'),
        icon: const Icon(Icons.forum_rounded),
        label: const Text('بدء الاستشارة داخل التطبيق'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      ),
    );
  }
}
