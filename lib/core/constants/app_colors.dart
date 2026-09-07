import 'package:flutter/material.dart';

/// Unified visual identity for Istishara.
/// Olive = legal authority and maturity, green = trust and positive action,
/// sky = clarity, accessibility, and calm digital surfaces.
class AppColors {
  static const Color primary = Color(0xFF566B2F);
  static const Color primaryContainer = Color(0xFF6F8541);
  static const Color onPrimaryContainer = Color(0xFFF6FAEE);
  static const Color primaryFixed = Color(0xFFEAF0D7);
  static const Color primaryFixedDim = Color(0xFFD7E2B9);
  static const Color primaryDark = Color(0xFF34451D);
  static const Color primaryLight = Color(0xFF8EA65A);

  static const Color secondary = Color(0xFF2E7D5B);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFDDF3E8);
  static const Color onSecondaryContainer = Color(0xFF174B38);
  static const Color secondaryDark = Color(0xFF205C43);
  static const Color secondaryLight = Color(0xFF52A77E);

  // Legacy semantic names retained for source compatibility.
  static const Color ctaGold = secondary;
  static const Color gold = primaryLight;
  static const Color goldLight = Color(0xFFF0F4E5);
  static const Color goldDark = primaryDark;

  static const Color tertiary = Color(0xFF3D89A6);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryLight = Color(0xFF77B9D1);
  static const Color teal = Color(0xFF2F8C86);

  static const Color background = Color(0xFFF7FAF5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFDCE5D9);
  static const Color surfaceBright = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEAF2E8);
  static const Color cardBackground = surface;
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF3F7EF);
  static const Color surfaceContainer = Color(0xFFEAF1E5);
  static const Color surfaceContainerHigh = Color(0xFFE1EBDD);
  static const Color surfaceContainerHighest = Color(0xFFD7E4D3);

  static const Color textPrimary = Color(0xFF203023);
  static const Color textSecondary = Color(0xFF526153);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnDark = Color(0xFFF7FAF5);
  static const Color onSurface = textPrimary;
  static const Color onSurfaceVariant = textSecondary;
  static const Color outline = Color(0xFF718072);
  static const Color outlineVariant = Color(0xFFC4D0C2);
  static const Color divider = outlineVariant;

  static const Color error = Color(0xFFB42318);
  static const Color errorContainer = Color(0xFFFFE4E1);
  static const Color success = Color(0xFF1F7A4D);
  static const Color info = Color(0xFF3D89A6);
  static const Color warning = Color(0xFF8A6700);

  static const Color pendingBg = Color(0xFFFFF4D6);
  static const Color pendingText = Color(0xFF664B00);
  static const Color acceptedBg = Color(0xFFE3F5E9);
  static const Color acceptedText = Color(0xFF17603D);
  static const Color cancelledBg = Color(0xFFFFE4E1);
  static const Color cancelledText = Color(0xFF8B1A12);

  static const List<Color> brandGradient = [primaryDark, primary, primaryLight];
  static const List<Color> goldGradient = [goldLight, primaryLight];
  static const List<Color> skyGradient = [Color(0xFFEAF6FA), Color(0xFFCFEAF3)];
}
