class BookingCancellationPolicy {
  const BookingCancellationPolicy._();

  static bool canRequest({required String status, required DateTime scheduledAt, required bool pendingReview}) {
    if (pendingReview) return false;
    if (scheduledAt.isBefore(DateTime.now())) return false;
    if (status == 'ملغي' || status == 'مسترد' || status == 'مكتمل' || status == 'قيد التنفيذ') return false;
    return ['قيد انتظار الدفع', 'قيد معالجة الدفع', 'بانتظار التأكيد', 'قيد مراجعة المحامي', 'مؤكد'].contains(status);
  }
}
