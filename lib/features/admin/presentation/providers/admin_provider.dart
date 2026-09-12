import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:astshara/core/config/supabase_config.dart';

part 'admin_provider.g.dart';

@riverpod
class AdminStats extends _$AdminStats {
  @override
  Future<Map<String, dynamic>> build() async {
    final client = SupabaseConfig.client;

    try {
      final usersRes = await client.from('profiles').select('id');
      final totalUsers = (usersRes as List).length;

      final lawyersRes = await client
          .from('lawyer_profiles')
          .select('id')
          .eq('verified', true);
      final totalLawyers = (lawyersRes as List).length;

      final pendingVerificationsRes = await client
          .from('lawyer_profiles')
          .select('id')
          .eq('verified', false)
          .eq('verification_status', 'pending');
      final pendingVerifications = (pendingVerificationsRes as List).length;

      final activeBookingsRes = await client
          .from('bookings')
          .select('id')
          .inFilter('status', ['مؤكد', 'قيد التنفيذ']);
      final activeBookings = (activeBookingsRes as List).length;

      final paymentsRes = await client.from('payments').select('amount, status');

      double totalRevenue = 0;
      int pendingPaymentsCount = 0;

      final paymentsList = paymentsRes as List;
      for (final raw in paymentsList) {
        final row = Map<String, dynamic>.from(raw as Map);
        final status = row['status']?.toString();
        if (status == 'تم الدفع') {
          totalRevenue += (row['amount'] as num?)?.toDouble() ?? 0;
        } else if (status == 'قيد معالجة الدفع' || status == 'بانتظار الدفع') {
          pendingPaymentsCount++;
        }
      }

      return {
        'total_users': totalUsers,
        'total_lawyers': totalLawyers,
        'pending_verifications': pendingVerifications,
        'active_bookings': activeBookings,
        'total_revenue': totalRevenue,
        'pending_payments': pendingPaymentsCount,
      };
    } catch (e, stackTrace) {
      debugPrint('Error fetching admin stats: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}
