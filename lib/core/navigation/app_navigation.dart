import 'package:flutter/material.dart';

/// Shared navigator key used by services that need to navigate without a BuildContext,
/// such as native notification tap callbacks.
class AppNavigation {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  const AppNavigation._();
}
