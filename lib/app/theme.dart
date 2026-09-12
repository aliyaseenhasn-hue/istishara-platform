import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';

class AppTheme {
  static const double _cardRadius = 16.0;

  static TextTheme _arabicTextTheme(TextTheme base, Color color) {
    return GoogleFonts.ibmPlexSansArabicTextTheme(base).copyWith(
      displayLarge: GoogleFonts.ibmPlexSansArabic(fontSize: 48, height: 60 / 48, fontWeight: FontWeight.w700, letterSpacing: -.96, color: color),
      headlineLarge: GoogleFonts.ibmPlexSansArabic(fontSize: 32, height: 44 / 32, fontWeight: FontWeight.w600, color: color),
      headlineMedium: GoogleFonts.ibmPlexSansArabic(fontSize: 24, height: 32 / 24, fontWeight: FontWeight.w600, color: color),
      titleLarge: GoogleFonts.ibmPlexSansArabic(fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w600, color: color),
      titleMedium: GoogleFonts.ibmPlexSansArabic(fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w500, color: color),
      bodyLarge: GoogleFonts.ibmPlexSansArabic(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400, color: color),
      bodyMedium: GoogleFonts.ibmPlexSansArabic(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400, color: color),
      labelLarge: GoogleFonts.ibmPlexSansArabic(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600, letterSpacing: .14, color: color),
      labelSmall: GoogleFonts.ibmPlexSansArabic(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500, color: color),
    );
  }

  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.textOnPrimary,
      primaryContainer: AppColors.primaryFixed,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      tertiary: AppColors.tertiary,
      onTertiary: AppColors.onTertiary,
      tertiaryContainer: AppColors.goldLight,
      onTertiaryContainer: AppColors.goldDark,
      surface: AppColors.background,
      surfaceDim: AppColors.surfaceDim,
      surfaceBright: AppColors.surfaceBright,
      surfaceContainerLowest: AppColors.surfaceContainerLowest,
      surfaceContainerLow: AppColors.surfaceContainerLow,
      surfaceContainer: AppColors.surfaceContainer,
      surfaceContainerHigh: AppColors.surfaceContainerHigh,
      surfaceContainerHighest: AppColors.surfaceContainerHighest,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.outline,
      outlineVariant: AppColors.divider,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.cancelledText,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      dividerColor: AppColors.divider,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primaryDark,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shadowColor: AppColors.primary.withValues(alpha: .04),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius), side: const BorderSide(color: AppColors.divider)),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return AppColors.surfaceDim;
            if (states.contains(WidgetState.pressed) || states.contains(WidgetState.hovered)) return AppColors.secondaryDark;
            return AppColors.secondary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.disabled) ? AppColors.textSecondary : Colors.white),
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 24)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          elevation: const WidgetStatePropertyAll(0),
          textStyle: WidgetStatePropertyAll(GoogleFonts.ibmPlexSansArabic(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w700)),
          overlayColor: const WidgetStatePropertyAll(Color(0x14FFFFFF)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.disabled) ? AppColors.textSecondary : AppColors.primary),
          side: WidgetStateProperty.resolveWith((states) => BorderSide(color: states.contains(WidgetState.disabled) ? AppColors.outline : AppColors.primary, width: states.contains(WidgetState.focused) ? 2 : 1)),
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          textStyle: WidgetStatePropertyAll(GoogleFonts.ibmPlexSansArabic(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w700)),
          overlayColor: const WidgetStatePropertyAll(Color(0x14245A78)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.disabled) ? AppColors.textSecondary : AppColors.primary),
          textStyle: WidgetStatePropertyAll(GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.w700)),
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(44)),
          overlayColor: const WidgetStatePropertyAll(Color(0x14245A78)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.secondary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error, width: 2)),
        labelStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 14, height: 20 / 14, color: AppColors.textSecondary),
        prefixIconColor: AppColors.secondary,
        suffixIconColor: AppColors.secondary,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: AppColors.surface,
        iconColor: AppColors.primary,
        titleTextStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        subtitleTextStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 14, height: 20 / 14, color: AppColors.textSecondary),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.secondary, linearTrackColor: AppColors.secondaryContainer),
      checkboxTheme: CheckboxThemeData(fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? AppColors.secondary : Colors.transparent), checkColor: const WidgetStatePropertyAll(Colors.white)),
      radioTheme: const RadioThemeData(fillColor: WidgetStatePropertyAll(AppColors.primary)),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? AppColors.secondary : AppColors.outline),
        trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? AppColors.secondaryContainer : AppColors.surfaceContainerHigh),
      ),
      iconTheme: const IconThemeData(color: AppColors.primary),
      dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: AppColors.secondary, foregroundColor: Colors.white),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.goldLight,
        labelTextStyle: WidgetStatePropertyAll(GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.w600)),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(color: states.contains(WidgetState.selected) ? AppColors.primaryDark : AppColors.textSecondary)),
      ),
    );

    return base.copyWith(textTheme: _arabicTextTheme(base.textTheme, AppColors.textPrimary));
  }

  static ThemeData get dark {
    const darkBackground = Color(0xFF111820);
    const darkSurface = Color(0xFF18222C);
    const darkText = Color(0xFFF2F5F7);
    const darkVariant = Color(0xFFBBC5CC);
    const navy = Color(0xFFA9BED0);
    const blue = Color(0xFF8FB0C8);
    const sage = Color(0xFFA4B6A8);

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: navy,
        onPrimary: Color(0xFF172A3A),
        primaryContainer: Color(0xFF2A4255),
        onPrimaryContainer: Color(0xFFEAF0F5),
        secondary: blue,
        onSecondary: Color(0xFF183142),
        secondaryContainer: Color(0xFF29475C),
        onSecondaryContainer: Color(0xFFDDE9F0),
        tertiary: sage,
        onTertiary: Color(0xFF27382D),
        tertiaryContainer: Color(0xFF3D5144),
        onTertiaryContainer: Color(0xFFE3EAE5),
        surface: darkBackground,
        onSurface: darkText,
        surfaceContainerLowest: Color(0xFF0C1218),
        surfaceContainerLow: Color(0xFF141D25),
        surfaceContainer: darkSurface,
        surfaceContainerHigh: Color(0xFF202D38),
        surfaceContainerHighest: Color(0xFF2A3945),
        onSurfaceVariant: darkVariant,
        outline: Color(0xFF82909A),
        outlineVariant: Color(0xFF3C4A54),
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
      ),
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: AppBarTheme(backgroundColor: darkBackground, foregroundColor: darkText, elevation: 0, centerTitle: false, scrolledUnderElevation: 0, surfaceTintColor: Colors.transparent, titleTextStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 20, fontWeight: FontWeight.w600, color: darkText)),
      cardTheme: CardThemeData(color: darkSurface, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius), side: const BorderSide(color: Color(0xFF3C4A54)))),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.disabled) ? const Color(0xFF2A3945) : const Color(0xFF4F7896)),
          foregroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.disabled) ? darkVariant : Colors.white),
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 24)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          elevation: const WidgetStatePropertyAll(0),
          textStyle: WidgetStatePropertyAll(GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.w700)),
          overlayColor: const WidgetStatePropertyAll(Color(0x14FFFFFF)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.disabled) ? darkVariant : navy),
          side: WidgetStateProperty.resolveWith((states) => BorderSide(color: states.contains(WidgetState.disabled) ? const Color(0xFF82909A) : navy, width: states.contains(WidgetState.focused) ? 2 : 1)),
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          textStyle: WidgetStatePropertyAll(GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.disabled) ? darkVariant : navy),
          textStyle: WidgetStatePropertyAll(GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.w700)),
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(44)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3C4A54))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3C4A54))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: blue, width: 2)),
        labelStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.w600, color: darkText),
        hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 14, color: darkVariant),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF3C4A54)),
    );

    return base.copyWith(textTheme: _arabicTextTheme(base.textTheme, darkText));
  }
}
