import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/supabase_config.dart';

class PaymentResultPage extends ConsumerStatefulWidget {
  final String? status;
  final String? bookingId;

  const PaymentResultPage({super.key, this.status, this.bookingId});

  @override
  ConsumerState<PaymentResultPage> createState() => _PaymentResultPageState();
}

class _PaymentResultPageState extends ConsumerState<PaymentResultPage> {
  Timer? _pollTimer;
  bool _checking = false;
  String? _checkedStatus;
  String? _bookingStatus;
  String? _error;

  bool _isSuccess(String? value) {
    final status = value?.trim().toLowerCase();
    return status == 'success' ||
        status == 'successful' ||
        status == 'paid' ||
        status == 'completed' ||
        status == 'تم الدفع' ||
        status == 'قيد مراجعة المحامي' ||
        status == 'مؤكد';
  }

  bool _isFailed(String? value) {
    final status = value?.trim().toLowerCase();
    return status == 'failed' ||
        status == 'authentication_failed' ||
        status == 'فشل الدفع';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPaymentStatus();
      _startPolling();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    if (widget.bookingId == null || widget.bookingId!.isEmpty) return;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final status = _checkedStatus;
      if (_isSuccess(status) || _isFailed(status)) {
        _pollTimer?.cancel();
        return;
      }
      _checkPaymentStatus();
    });
  }

  Future<void> _checkPaymentStatus() async {
    final id = widget.bookingId;
    if (id == null || id.isEmpty || _checking || !mounted) return;

    setState(() {
      _checking = true;
      _error = null;
    });

    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'qicard-check-payment-status',
        body: {'booking_id': id},
      );
      final data = response.data;
      if (data is! Map) {
        throw Exception('تعذر التحقق من حالة الدفع');
      }
      if (data['error'] != null) {
        throw Exception(data['error'].toString());
      }
      if (!mounted) return;

      final paymentStatus = data['payment_status']?.toString();
      final bookingStatus = data['booking_status']?.toString();
      setState(() {
        _checkedStatus = paymentStatus;
        _bookingStatus = bookingStatus;
      });

      if (_isSuccess(paymentStatus) || _isFailed(paymentStatus)) {
        _pollTimer?.cancel();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = _checkedStatus ?? widget.status;
    final success = _isSuccess(status);
    final failed = _isFailed(status);

    String title;
    String message;
    IconData icon;
    Color iconColor;
    Color statusColor;

    if (success) {
      title = 'تم الدفع بنجاح';
      message = _bookingStatus == 'مؤكد'
          ? 'تم تأكيد الحجز بنجاح.'
          : 'تم استلام الدفع بنجاح، والحجز بانتظار إجراءات المحامي.';
      icon = Icons.check_circle_outline_rounded;
      iconColor = scheme.primary;
      statusColor = scheme.primary;
    } else if (failed) {
      title = 'لم تكتمل عملية الدفع';
      message = 'لم يتم اعتماد الدفع. يمكنك العودة إلى حجوزاتك لمعرفة الحالة.';
      icon = Icons.cancel_outlined;
      iconColor = scheme.error;
      statusColor = scheme.error;
    } else {
      title = 'التحقق من نتيجة الدفع';
      message = _checking
          ? 'جاري التحقق من حالة العملية لدى كي كارد...'
          : 'لم نتمكن من تأكيد النتيجة بعد. سيستمر التحقق تلقائياً.';
      icon = Icons.info_outline_rounded;
      iconColor = scheme.primary;
      statusColor = scheme.secondary;
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('نتيجة الدفع'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(22, 30, 22, 26),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [scheme.primaryContainer, scheme.secondaryContainer],
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: .82),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 54, color: iconColor),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        height: 1.55,
                        color: scheme.onPrimaryContainer.withValues(alpha: .82),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (widget.bookingId != null && widget.bookingId!.isNotEmpty)
                Card(
                  elevation: 0,
                  color: scheme.surfaceContainerLowest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long_outlined, color: scheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'رقم الحجز',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.bookingId!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline_rounded, color: scheme.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: scheme.onErrorContainer,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              if (!success && !failed && !_checking && widget.bookingId != null)
                OutlinedButton.icon(
                  onPressed: _checkPaymentStatus,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة التحقق من الدفع'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              if (!success && !failed && !_checking && widget.bookingId != null)
                const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => context.go('/bookings'),
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('الانتقال إلى حجوزاتي'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: statusColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              if (_checking) ...[
                const SizedBox(height: 14),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 9),
                      const Text(
                        'جاري التحقق من حالة الدفع...',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
