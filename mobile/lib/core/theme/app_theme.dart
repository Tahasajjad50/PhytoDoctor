import 'package:flutter/material.dart';

/// Phyto Doctor Agri-Biotech Design System
/// Calibrated for high readability in harsh outdoor sunlight
class AppTheme {
  // --- Botanical & Agri-Biotech Palette ---
  static const Color botanicalDark = Color(0xFF1B3B1D);       // Deep canopy green
  static const Color botanicalPrimary = Color(0xFF28542A);    // Official field green
  static const Color botanicalMedium = Color(0xFF386B3B);     // Foliage green
  static const Color sageLight = Color(0xFFEFF5ED);          // Soft sage background
  static const Color sageBorder = Color(0xFFD4E2D1);         // Crisp contrast border
  static const Color warmOffWhite = Color(0xFFF9F8F5);       // Anti-glare outdoor background
  static const Color surfaceCard = Color(0xFFFFFFFF);        // Opaque card surface
  
  // High-Contrast Text (WCAG AAA compliant in direct sunlight)
  static const Color textMain = Color(0xFF152216);           // Near-black botanical ink
  static const Color textMuted = Color(0xFF4D614E);          // Deep sage-slate (contrast > 5.5:1)
  static const Color textLight = Color(0xFFFFFFFF);
  
  // Restrained Functional Status Accents
  static const Color earthAmber = Color(0xFFB46912);         // Pending / Target accent
  static const Color earthAmberLight = Color(0xFFFEF7ED);
  static const Color cropGreen = Color(0xFF236E27);          // Verified / Success
  static const Color cropGreenLight = Color(0xFFEBF7EB);
  static const Color mintBadge = Color(0xFFEBF7EB);
  static const Color alertCrimson = Color(0xFFA62520);       // Rejected / Urgent
  static const Color alertCrimsonLight = Color(0xFFFDF2F2);
  static const Color adminSlate = Color(0xFF203E48);         // Admin portal distinction
  static const Color adminSlateLight = Color(0xFFF0F5F7);

  // Outdoor Sizing Standards (Accessible touch targets for field workers)
  static const double minTouchTargetHeight = 48.0;
  static const double standardButtonHeight = 52.0;
  static const double standardBorderRadius = 8.0; // Restrained, professional (no excessive curves)

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: warmOffWhite,
      primaryColor: botanicalPrimary,
      colorScheme: ColorScheme.light(
        primary: botanicalPrimary,
        secondary: botanicalMedium,
        surface: surfaceCard,
        error: alertCrimson,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textMain,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceCard,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textMain, size: 22),
        titleTextStyle: TextStyle(
          color: textMain,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        shape: Border(
          bottom: BorderSide(color: sageBorder, width: 1.0),
        ),
      ),
      cardTheme: const CardThemeData(
        color: surfaceCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(standardBorderRadius)),
          side: BorderSide(color: sageBorder, width: 1.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(standardBorderRadius),
          borderSide: const BorderSide(color: sageBorder, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(standardBorderRadius),
          borderSide: const BorderSide(color: sageBorder, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(standardBorderRadius),
          borderSide: const BorderSide(color: botanicalPrimary, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(standardBorderRadius),
          borderSide: const BorderSide(color: alertCrimson, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(standardBorderRadius),
          borderSide: const BorderSide(color: alertCrimson, width: 2.0),
        ),
        labelStyle: const TextStyle(color: textMuted, fontSize: 14, fontWeight: FontWeight.w500),
        hintStyle: TextStyle(color: textMuted.withOpacity(0.7), fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(double.infinity, standardButtonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(standardBorderRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(double.infinity, standardButtonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(standardBorderRadius),
          ),
          side: const BorderSide(color: botanicalPrimary, width: 1.5),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: sageBorder,
        thickness: 1.0,
        space: 1.0,
      ),
    );
  }
}
