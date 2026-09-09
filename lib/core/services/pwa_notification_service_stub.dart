class PwaNotificationService {
  static bool get supported => false;

  static Future<void> initialize() async {}

  static Future<bool> isEnabled() async => false;

  static Future<bool> enable() async => false;

  static Future<bool> syncForCurrentUser() async => false;

  static Future<void> releaseForCurrentUser() async {}

  static Future<bool> disable() async => true;
}
