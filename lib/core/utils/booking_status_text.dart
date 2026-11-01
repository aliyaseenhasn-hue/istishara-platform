/// Plain-language booking statuses for display only.
///
/// The database keeps its detailed internal statuses; screens show these
/// simpler labels so users see a handful of clear states, plus one line that
/// says what happens next. Logic must keep comparing the raw status values.
class BookingStatusText {
  const BookingStatusText._();

  static String label(String status, {bool forLawyer = false}) {
    final value = status.trim();
    switch (value) {
      case 'قيد انتظار الدفع':
        return 'بانتظار الدفع';
      case 'قيد معالجة الدفع':
        return 'جارٍ التحقق من الدفع';
      case 'قيد مراجعة المحامي':
      case 'بانتظار التأكيد':
        return forLawyer ? 'بانتظار موافقتك' : 'بانتظار موافقة المحامي';
      case 'مؤكد':
      case 'مقبول':
        return 'مؤكدة';
      case 'قيد التنفيذ':
        return 'جارية الآن';
      case 'مكتمل':
        return 'مكتملة';
      case 'بانتظار مراجعة الإدارة':
      case 'بانتظار مراجعة عدم الحضور':
        return 'قيد مراجعة الإدارة';
      case 'بانتظار الاسترداد':
        return 'جارٍ الاسترداد';
      case 'مسترد':
        return 'تم الاسترداد';
      case 'ملغي':
        return 'ملغاة';
      case 'مرفوض':
        return 'مرفوضة';
      case '':
        return 'بانتظار المراجعة';
      default:
        return value;
    }
  }

  /// One short line telling the user what happens next, or null.
  static String? nextStep(String status, {bool forLawyer = false}) {
    switch (status.trim()) {
      case 'قيد انتظار الدفع':
        return forLawyer
            ? 'ننتظر إكمال طالب الاستشارة للدفع.'
            : 'أكمل الدفع لتثبيت موعدك.';
      case 'قيد معالجة الدفع':
        return 'تراجع الإدارة إيصال الدفع، وسيصلك إشعار عند الاعتماد.';
      case 'قيد مراجعة المحامي':
      case 'بانتظار التأكيد':
        return forLawyer
            ? 'راجع الطلب ثم وافق عليه أو ارفضه.'
            : 'سيصلك إشعار عند موافقة المحامي.';
      case 'مؤكد':
      case 'مقبول':
        return 'ادخل في موعد الاستشارة، وتبدأ المحادثة داخل التطبيق.';
      case 'قيد التنفيذ':
        return 'الاستشارة جارية الآن داخل التطبيق.';
      case 'مكتمل':
        return forLawyer
            ? 'اكتملت الاستشارة، وتُضاف مستحقاتك بعد مدة الحجز.'
            : 'اكتملت الاستشارة. يسعدنا تقييمك للمحامي.';
      case 'بانتظار مراجعة الإدارة':
      case 'بانتظار مراجعة عدم الحضور':
        return 'تراجع الإدارة الحالة، وسيصلك إشعار بالنتيجة.';
      case 'بانتظار الاسترداد':
        return 'المبلغ قيد الإرجاع، وستجده في محفظتك أو حساب الاستلام.';
      case 'مسترد':
        return 'أُعيد المبلغ.';
      default:
        return null;
    }
  }

  /// Statuses of a consultation that is still ahead or happening.
  static bool isActive(String status) => const {
        'قيد انتظار الدفع',
        'قيد معالجة الدفع',
        'قيد مراجعة المحامي',
        'بانتظار التأكيد',
        'مؤكد',
        'مقبول',
        'قيد التنفيذ',
      }.contains(status.trim());
}
