import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../shared/providers/global_loading_provider.dart';
import '../../../payments/data/models/payment_model.dart';
import '../../../payments/domain/entities/payment.dart';

part 'payment_management_provider.g.dart';

@riverpod
class PaymentManagement extends _$PaymentManagement {
  Future<List<Payment>> _fetchPendingPayments() async {
    final response = await SupabaseConfig.client
        .from('payments')
        .select()
        .eq('status', 'قيد معالجة الدفع')
        .eq('payment_method', 'bank_transfer')
        .order('created_at');

    return (response as List)
        .map((json) => PaymentModel.fromJson(Map<String, dynamic>.from(json as Map)).toEntity())
        .toList();
  }

  @override
  FutureOr<List<Payment>> build() async => _fetchPendingPayments();

  Future<void> approvePayment(Payment payment, {String? note}) async {
    ref.read(globalLoadingProvider.notifier).setLoading(true);
    state = const AsyncLoading();
    try {
      await SupabaseConfig.client.rpc(
        'admin_review_manual_payment',
        params: {
          'p_payment_id': payment.id,
          'p_approved': true,
          'p_note': note?.trim().isEmpty == true ? null : note?.trim(),
        },
      );
      state = AsyncData(await _fetchPendingPayments());
    } catch (e, st) {
      state = AsyncError(e, st);
    } finally {
      ref.read(globalLoadingProvider.notifier).setLoading(false);
    }
  }

  Future<void> rejectPayment(Payment payment, {String? note}) async {
    ref.read(globalLoadingProvider.notifier).setLoading(true);
    state = const AsyncLoading();
    try {
      await SupabaseConfig.client.rpc(
        'admin_review_manual_payment',
        params: {
          'p_payment_id': payment.id,
          'p_approved': false,
          'p_note': note?.trim().isEmpty == true ? null : note?.trim(),
        },
      );
      state = AsyncData(await _fetchPendingPayments());
    } catch (e, st) {
      state = AsyncError(e, st);
    } finally {
      ref.read(globalLoadingProvider.notifier).setLoading(false);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchPendingPayments);
  }
}
