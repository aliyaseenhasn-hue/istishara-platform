import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/supabase_config.dart';
import '../../data/models/booking_model.dart';
import '../../domain/entities/booking.dart';
import 'booking_cancellation_overlay.dart';

class BookingNotificationTargetPage extends ConsumerStatefulWidget {
  final String bookingId;

  const BookingNotificationTargetPage({
    super.key,
    required this.bookingId,
  });

  @override
  ConsumerState<BookingNotificationTargetPage> createState() =>
      _BookingNotificationTargetPageState();
}

class _BookingNotificationTargetPageState
    extends ConsumerState<BookingNotificationTargetPage> {
  late Future<Booking?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Booking?> _load() async {
    final response = await SupabaseConfig.client.rpc(
      'get_booking_for_notification',
      params: {'p_booking_id': widget.bookingId},
    );

    Map<String, dynamic>? row;
    if (response is List && response.isNotEmpty) {
      row = Map<String, dynamic>.from(response.first as Map);
    } else if (response is Map && response.isNotEmpty) {
      row = Map<String, dynamic>.from(response);
    }

    if (row == null) return null;
    return BookingModel.fromJson(row).toEntity();
  }

  void _retry() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Booking?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('تفاصيل الاستشارة')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event_busy_outlined, size: 52),
                    const SizedBox(height: 14),
                    const Text(
                      'تعذر فتح الاستشارة المرتبطة بهذا الإشعار.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('إعادة المحاولة'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.go('/bookings'),
                      child: const Text('الذهاب إلى الاستشارات'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return BookingDetailsWithCancellation(booking: snapshot.data!);
      },
    );
  }
}
