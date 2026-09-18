import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Editorial Clean" design system — a direct port of the web frontend's
/// `src/index.css` @theme block. The hex values here are the same ones the
/// Tailwind tokens (--color-carbon-*, --color-risk-*) resolve to, so the
/// mobile app and the website are visually the same product.
class AppColors {
  AppColors._();

  // Paper & ink
  static const white = Color(0xFFFFFDF8); // raised surface
  static const gray10 = Color(0xFFF6F2E8); // page background ("paper")
  static const gray20 = Color(0xFFE6DFC9); // hairline borders
  static const gray30 = Color(0xFFD6CBAC); // stronger hairline / disabled
  static const gray60 = Color(0xFF8C8368); // muted ink (captions, icons)
  static const gray70 = Color(0xFF5C5440); // secondary ink (body copy)
  static const gray90 = Color(0xFF2A2418); // near-black ink
  static const gray100 = Color(0xFF1C1810); // primary ink (headings)

  // Interactive accent — deep editorial ink-blue
  static const blue60 = Color(0xFF2B4A6F);
  static const blue70 = Color(0xFF1D3450);
  static const blue20 = Color(0xFFDFE6EC);

  // Risk tier palette
  static const riskCritical = Color(0xFF9C2B1F);
  static const riskHigh = Color(0xFFA85F17);
  static const riskMedium = Color(0xFF8F6C0C);
  static const riskLow = Color(0xFF2C6B46);

  static const riskCriticalBg = Color(0xFFF6E7E3);
  static const riskHighBg = Color(0xFFF5EAD9);
  static const riskMediumBg = Color(0xFFF2ECD6);
  static const riskLowBg = Color(0xFFE3ECDF);

  static const skeletonBase = Color(0xFFECE5D2);
  static const skeletonShine = Color(0xFFF6F2E8);
}

/// Typography helpers. The web uses IBM Plex Sans / Serif / Mono; the same
/// three families are pulled from Google Fonts here. If the device is offline
/// and the fonts can't be fetched, `google_fonts` falls back to the platform
/// default and the layout still holds.
class AppText {
  AppText._();

  static TextStyle sans({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.gray100,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    TextDecoration? decoration,
  }) =>
      GoogleFonts.ibmPlexSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        fontStyle: fontStyle,
        decoration: decoration,
      );

  static TextStyle serif({
    double size = 16,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.gray100,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
  }) =>
      GoogleFonts.ibmPlexSerif(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        fontStyle: fontStyle,
      );

  static TextStyle mono({
    double size = 13,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.gray100,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.ibmPlexMono(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// The `.kicker` utility: small, wide-tracked, uppercase section label.
  static TextStyle kicker({Color color = AppColors.gray60, double size = 11}) =>
      sans(
        size: size,
        weight: FontWeight.w600,
        color: color,
        letterSpacing: size * 0.14,
      );
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.gray10,
    colorScheme: const ColorScheme.light(
      primary: AppColors.blue60,
      onPrimary: AppColors.white,
      secondary: AppColors.blue70,
      onSecondary: AppColors.white,
      surface: AppColors.white,
      onSurface: AppColors.gray100,
      error: AppColors.riskCritical,
      onError: AppColors.white,
      outline: AppColors.gray20,
    ),
  );

  return base.copyWith(
    textTheme: GoogleFonts.ibmPlexSansTextTheme(base.textTheme).apply(
      bodyColor: AppColors.gray100,
      displayColor: AppColors.gray100,
    ),
    // Editorial surfaces are square — no rounded corners anywhere.
    cardTheme: const CardThemeData(
      color: AppColors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.gray20),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.gray20,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.gray100,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.white,
      selectedItemColor: AppColors.gray100,
      unselectedItemColor: AppColors.gray60,
      selectedLabelStyle: AppText.sans(size: 12, weight: FontWeight.w600),
      unselectedLabelStyle: AppText.sans(size: 12),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    splashFactory: InkRipple.splashFactory,
  );
}
