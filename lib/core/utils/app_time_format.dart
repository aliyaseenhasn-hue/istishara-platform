import 'package:intl/intl.dart';

/// Centralized Arabic 12-hour time formatting used throughout the app.
class AppTimeFormat {
  AppTimeFormat._();

  static String time12(DateTime dateTime) {
    return DateFormat('hh:mm a', 'ar_IQ').format(dateTime.toLocal());
  }
}
