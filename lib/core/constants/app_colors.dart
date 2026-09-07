import 'package:flutter/material.dart';

/// Unified premium visual identity for Istishara.
/// Navy = trust and legal authority, blue-grey = formal supporting actions,
/// teal = digital guidance and positive information.
class AppColors {
  static const Color primary = Color(0xFF082B49);
  static const Color primaryContainer = Color(0xFF123F63);
  static const Color onPrimaryContainer = Color(0xFFD9ECFF);
  static const Color primaryFixed = Color(0xFFD9ECFF);
  static const Color primaryFixedDim = Color(0xFFBBD8F2);
  static const Color primaryDark = Color(0xFF061F35);
  static const Color primaryLight = Color(0xFF2B628D);

  // Formal secondary palette. Legacy names are retained for source compatibility,
  // but no yellow/gold is used for brand or interaction surfaces.
  static const Color secondary = Color(0xFF315A78);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFDCE9F2);
  static const Color onSecondaryContainer = Color(0xFF17384F);
  static const Color secondaryDark = Color(0xFF23465F);
  static const Color secondaryLight = Color(0xFF5E8199);

  static const Color ctaGold = primary;
  static const Color gold = secondaryLight;
  static const Color goldLight = Color(0xFFE7F0F6);
  static const Color goldDark = secondaryDark;

  static const Color tertiary = Color(0xFF075E66);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryLight = Color(0xFF4FAEB5);
  static const Color teal = Color(0xFF087C86);

  static const Color background = Color(0xFFF5F8FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFD9E0E6);
  static const Color surfaceBright = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFE7EDF2);
  static const Color cardBackground = surface;
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF4F7FA);
  static const Color surfaceContainer = Color(0xFFECF2F6);
  static const Color surfaceContainerHigh = Color(0xFFE3EBF1);
  static const Color surfaceContainerHighest = Color(0xFFDCE5EC);

  // High-contrast text: intentionally separated from light surfaces.
  static const Color textPrimary = Color(0xFF122333);
  static const Color textSecondary = Color(0xFF435566);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnDark = Color(0xFFF5F8FB);
  static const Color onSurface = textPrimary;
  static const Color onSurfaceVariant = textSecondary;
  static const Color outline = Color(0xFF657789);
  static const Color outlineVariant = Color(0xFFB9C6D1);
  static const Color divider = outlineVariant;

  static const Color error = Color(0xFFB42318);
  static const Color errorContainer = Color(0xFFFFE4E1);
  static const Color success = Color(0xFF16794A);
  static const Color info = Color(0xFF087C86);
  static const Color warning = Color(0xFF8A6700);

  // Semantic statuses remain distinct; these are not brand/hover colors.
  static const Color pendingBg = Color(0xFFFFF4D6);
  static const Color pendingText = Color(0xFF664B00);
  static const Color acceptedBg = Color(0xFFE5F6EC);
  static const Color acceptedText = Color(0xFF17603D);
  static const Color cancelledBg = Color(0xFFFFE4E1);
  static const Color cancelledText = Color(0xFF8B1A12);

  static const List<Color> brandGradient = [primary, primaryContainer];
  static const List<Color> goldGradient = [goldLight, primaryLight];
  static const List<Color> skyGradient = [Color(0xFFEAF5F7), Color(0xFFC9E4E7)];
}
