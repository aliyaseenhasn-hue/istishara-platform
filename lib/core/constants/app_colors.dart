import 'package:flutter/material.dart';

/// Unified visual identity for Istishara.
/// Lively olive = legal authority, emerald = trust and positive action,
/// sky = clarity, and soft translucent gold = premium highlights.
class AppColors {
  static const Color primary = Color(0xFF667F2F);
  static const Color primaryContainer = Color(0xFF87A647);
  static const Color onPrimaryContainer = Color(0xFFF9FCEB);
  static const Color primaryFixed = Color(0xFFF0F6D8);
  static const Color primaryFixedDim = Color(0xFFDCE9B3);
  static const Color primaryDark = Color(0xFF3E5518);
  static const Color primaryLight = Color(0xFFA9C763);

  static const Color secondary = Color(0xFF1F9D68);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFD8F7E8);
  static const Color onSecondaryContainer = Color(0xFF0C5536);
  static const Color secondaryDark = Color(0xFF14734A);
  static const Color secondaryLight = Color(0xFF59C996);

  // Legacy semantic names retained for source compatibility.
  // CTA stays emerald for contrast; gold is reserved for premium highlights.
  static const Color ctaGold = secondary;
  static const Color gold = Color(0xFFD9B95F);
  static const Color goldLight = Color(0xFFFFF3CC);
  static const Color goldDark = Color(0xFF9A7420);
  static const Color goldSoft = Color(0x33E7C866);
  static const Color goldSoftStrong = Color(0x66F0D47C);

  static const Color tertiary = Color(0xFF3CA4D3);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryLight = Color(0xFF83D3F0);
  static const Color teal = Color(0xFF25A39A);

  static const Color background = Color(0xFFF8FBF4);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFDCE7D8);
  static const Color surfaceBright = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEDF5E8);
  static const Color cardBackground = surface;
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF4F9EE);
  static const Color surfaceContainer = Color(0xFFECF4E5);
  static const Color surfaceContainerHigh = Color(0xFFE3EFDA);
  static const Color surfaceContainerHighest = Color(0xFFD9E9CE);

  static const Color textPrimary = Color(0xFF1E3020);
  static const Color textSecondary = Color(0xFF526354);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnDark = Color(0xFFF8FBF4);
  static const Color onSurface = textPrimary;
  static const Color onSurfaceVariant = textSecondary;
  static const Color outline = Color(0xFF71836F);
  static const Color outlineVariant = Color(0xFFC4D3C0);
  static const Color divider = outlineVariant;

  static const Color error = Color(0xFFB42318);
  static const Color errorContainer = Color(0xFFFFE4E1);
  static const Color success = Color(0xFF178653);
  static const Color info = Color(0xFF278DBB);
  static const Color warning = Color(0xFF947019);

  static const Color pendingBg = Color(0xFFFFF4D1);
  static const Color pendingText = Color(0xFF705300);
  static const Color acceptedBg = Color(0xFFDDF7E8);
  static const Color acceptedText = Color(0xFF12613D);
  static const Color cancelledBg = Color(0xFFFFE4E1);
  static const Color cancelledText = Color(0xFF8B1A12);

  static const List<Color> brandGradient = [primaryDark, primary, primaryLight];
  static const List<Color> goldGradient = [goldSoft, goldSoftStrong, goldLight];
  static const List<Color> skyGradient = [Color(0xFFE8F8FE), Color(0xFFC9ECF8)];
}
