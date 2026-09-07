import 'package:flutter/material.dart';

/// Unified visual identity for Istishara.
/// Deep slate navy conveys trust and legal authority, muted blue adds clarity,
/// sage green is reserved for positive states, and champagne gold is a subtle accent.
class AppColors {
  static const Color primary = Color(0xFF243B53);
  static const Color primaryContainer = Color(0xFF3E5C76);
  static const Color onPrimaryContainer = Color(0xFFF7FAFC);
  static const Color primaryFixed = Color(0xFFEAF0F5);
  static const Color primaryFixedDim = Color(0xFFD3DEE8);
  static const Color primaryDark = Color(0xFF172A3A);
  static const Color primaryLight = Color(0xFF6F8FA8);

  static const Color secondary = Color(0xFF4F7896);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFE4EDF3);
  static const Color onSecondaryContainer = Color(0xFF263F52);
  static const Color secondaryDark = Color(0xFF385C76);
  static const Color secondaryLight = Color(0xFF8FAFC2);

  // Legacy semantic names retained for source compatibility.
  static const Color ctaGold = secondary;
  static const Color gold = Color(0xFFC8AD72);
  static const Color goldLight = Color(0xFFF5EEDC);
  static const Color goldDark = Color(0xFF8C7445);
  static const Color goldSoft = Color(0x24C8AD72);
  static const Color goldSoftStrong = Color(0x3DC8AD72);
  static const Color goldTransparent = goldSoft;
  static const Color goldTransparentStrong = goldSoftStrong;

  static const Color tertiary = Color(0xFF718B7A);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryLight = Color(0xFFA8B9AC);
  static const Color teal = Color(0xFF5D8587);

  static const Color background = Color(0xFFF7F8F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFE1E5E3);
  static const Color surfaceBright = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0F3F2);
  static const Color cardBackground = surface;
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF4F6F5);
  static const Color surfaceContainer = Color(0xFFEDF1F0);
  static const Color surfaceContainerHigh = Color(0xFFE6EBE9);
  static const Color surfaceContainerHighest = Color(0xFFDCE3E0);

  static const Color textPrimary = Color(0xFF1E2D38);
  static const Color textSecondary = Color(0xFF5F6E78);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnDark = Color(0xFFF7FAFC);
  static const Color onSurface = textPrimary;
  static const Color onSurfaceVariant = textSecondary;
  static const Color outline = Color(0xFF87959D);
  static const Color outlineVariant = Color(0xFFD0D8D6);
  static const Color divider = outlineVariant;

  static const Color error = Color(0xFFB2463E);
  static const Color errorContainer = Color(0xFFF8E7E5);
  static const Color success = Color(0xFF5F7F68);
  static const Color info = Color(0xFF4F7896);
  static const Color warning = Color(0xFF9A7D45);

  static const Color pendingBg = Color(0xFFF6F0E3);
  static const Color pendingText = Color(0xFF765F34);
  static const Color acceptedBg = Color(0xFFE7EFE9);
  static const Color acceptedText = Color(0xFF496553);
  static const Color cancelledBg = Color(0xFFF8E7E5);
  static const Color cancelledText = Color(0xFF8A3832);

  static const List<Color> brandGradient = [primaryDark, primary, primaryContainer];
  static const List<Color> goldGradient = [goldSoft, goldSoftStrong, goldLight];
  static const List<Color> skyGradient = [Color(0xFFF1F5F8), Color(0xFFE2EBF0)];
}
