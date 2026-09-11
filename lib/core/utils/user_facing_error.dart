class UserFacingError {
  const UserFacingError._();

  static String text(
    Object error, {
    String fallback = 'تعذر إكمال العملية. يرجى المحاولة مرة أخرى.',
  }) {
    var value = error.toString().trim();
    if (value.isEmpty) return fallback;

    final lower = value.toLowerCase();
    if (lower.contains('realtimesubscribeexception') ||
        lower.contains('channelerror') ||
        lower.contains('websocket')) {
      return 'تعذر التحديث اللحظي مؤقتاً. تحقق من الاتصال واضغط تحديث، وسيحاول التطبيق الاتصال تلقائياً.';
    }

    if (lower.contains('future already completed') ||
        lower.contains('bad state') ||
        lower.contains('completer') && lower.contains('completed')) {
      return 'تم تحديث الحالة في نفس اللحظة أكثر من مرة. تحقق من الحالة الحالية، وإن لم تتغير انتظر لحظة ثم أعد المحاولة.';
    }

    value = value.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();

    final messageMatch = RegExp(
      r'PostgrestException\(message:\s*(.*?)(?:,\s*code:|,\s*details:|,\s*hint:|\)$)',
      dotAll: true,
    ).firstMatch(value);
    if (messageMatch != null) {
      final message = (messageMatch.group(1) ?? '').trim();
      if (message.isNotEmpty && message.toLowerCase() != 'null') {
        return _clean(message);
      }
    }

    value = value
        .replaceAll(RegExp(r'PostgrestException\(message:\s*'), '')
        .replaceAll(RegExp(r',\s*code:\s*[^,\)]+'), '')
        .replaceAll(
          RegExp(r',\s*details:\s*.*?(?=,\s*hint:|\)$)', dotAll: true),
          '',
        )
        .replaceAll(RegExp(r',\s*hint:\s*.*?\)$', dotAll: true), '')
        .replaceAll(RegExp(r'\)$'), '')
        .trim();

    if (value.isEmpty || value.toLowerCase() == 'null') return fallback;
    if (RegExp(r'\b(23502|23503|23505|P0001|42P01|42703)\b').hasMatch(value)) {
      return fallback;
    }
    return _clean(value);
  }

  static String _clean(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('null', '')
        .trim();
  }
}
