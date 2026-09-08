import 'package:flutter/material.dart';

/// Unified visual identity for Istishara.
/// Crisp white keeps the product calm, sky blue adds freshness and clarity,
/// deep blue preserves legal authority, and soft gold is used as a restrained accent.
class AppColors {
  static const Color primary = Color(0xFF245A78);
  static const Color primaryContainer = Color(0xFF5E9FC3);
  static const Color onPrimaryContainer = Color(0xFFFFFFFF);
  static const Color primaryFixed = Color(0xFFEAF7FD);
  static const Color primaryFixedDim = Color(0xFFCDEAF7);
  static const Color primaryDark = Color(0xFF173F58);
  static const Color primaryLight = Color(0xFF86C7E8);

  static const Color secondary = Color(0xFF3E91BC);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFDDF3FC);
  static const Color onSecondaryContainer = Color(0xFF17445C);
  static const Color secondaryDark = Color(0xFF276C91);
  static const Color secondaryLight = Color(0xFF8BD0EF);

  // Legacy semantic names retained for source compatibility.
  static const Color ctaGold = secondary;
  static const Color gold = Color(0xFFD8B45C);
  static const Color goldLight = Color(0xFFFFF5D8);
  static const Color goldDark = Color(0xFF8A681C);
  static const Color goldSoft = Color(0x2ED8B45C);
  static const Color goldSoftStrong = Color(0x52E2C36F);
  static const Color goldTransparent = goldSoft;
  static const Color goldTransparentStrong = goldSoftStrong;

  static const Color tertiary = goldDark;
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryLight = Color(0xFFE7CA7A);
  static const Color teal = Color(0xFF47A8B5);

  static const Color background = Color(0xFFFCFEFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFE6F2F7);
  static const Color surfaceBright = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF4FAFD);
  static const Color cardBackground = surface;
  static const Color surfaceContainerLowest = Color(0xFFF3FAFE);
  static const Color surfaceContainerLow = Color(0xFFF8FCFE);
  static const Color surfaceContainer = Color(0xFFEEF8FC);
  static const Color surfaceContainerHigh = Color(0xFFE3F3FA);
  static const Color surfaceContainerHighest = Color(0xFFD6ECF6);

  static const Color textPrimary = Color(0xFF173246);
  static const Color textSecondary = Color(0xFF516B7A);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color onSurface = textPrimary;
  static const Color onSurfaceVariant = textSecondary;
  static const Color outline = Color(0xFF7695A5);
  static const Color outlineVariant = Color(0xFFC8E1EC);
  static const Color divider = outlineVariant;

  static const Color error = Color(0xFFB2463E);
  static const Color errorContainer = Color(0xFFFFEAE7);
  static const Color success = Color(0xFF347A5A);
  static const Color info = Color(0xFF3E91BC);
  static const Color warning = goldDark;

  static const Color pendingBg = Color(0xFFFFF5D8);
  static const Color pendingText = Color(0xFF735617);
  static const Color acceptedBg = Color(0xFFE8F6EE);
  static const Color acceptedText = Color(0xFF285F46);
  static const Color cancelledBg = Color(0xFFFFEAE7);
  static const Color cancelledText = Color(0xFF8A3832);

  static const List<Color> brandGradient = [primaryDark, primary, primaryContainer];
  static const List<Color> goldGradient = [goldSoft, goldSoftStrong, goldLight];
  static const List<Color> skyGradient = [Color(0xFFF4FBFE), Color(0xFFDDF3FC)];
}
