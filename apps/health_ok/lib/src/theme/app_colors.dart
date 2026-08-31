import 'package:flutter/material.dart';

/// App color palette. Light + Dark variants.
///
/// IMPORTANT: The "active" palette members (bgGradient, surface, textPrimary,
/// textSecondary, textMuted, surfaceMuted, border) are theme-aware and resolve
/// based on the current brightness. Call [AppColors.setBrightness] whenever the
/// theme mode changes so every screen adapts automatically.
class AppColors {
  // Brand
  static const primary = Color(0xFF6366F1); // indigo
  static const primaryDark = Color(0xFF4F46E5);
  static const secondary = Color(0xFF8B5CF6); // purple
  static const accent = Color(0xFF06B6D4); // cyan

  // Health metrics
  static const stepsColor = Color(0xFFF97316); // orange
  static const distanceColor = Color(0xFF10B981); // emerald
  static const energyColor = Color(0xFFEF4444); // red

  // Light theme surfaces
  static const lightSurface = Colors.white;
  static const lightSurfaceMuted = Color(0xFFF8FAFC);
  static const lightTextPrimary = Color(0xFF0F172A);
  static const lightTextSecondary = Color(0xFF475569);
  static const lightTextMuted = Color(0xFF94A3B8);
  static const lightBorder = Color(0xFFE2E8F0);
  static const lightBgStart = Color(0xFFE0F2FE);
  static const lightBgMid = Color(0xFFEDE9FE);
  static const lightBgEnd = Color(0xFFFCE7F3);

  // Dark theme surfaces (near-black slate, subtle indigo tint — not heavy purple)
  static const darkSurface = Color(0xFF1E293B);
  static const darkSurfaceMuted = Color(0xFF2B3648);
  static const darkTextPrimary = Color(0xFFF1F5F9);
  static const darkTextSecondary = Color(0xFFCBD5E1);
  static const darkTextMuted = Color(0xFF94A3B8);
  static const darkBorder = Color(0xFF334155);
  static const darkBgStart = Color(0xFF0B1220);
  static const darkBgMid = Color(0xFF111A2E);
  static const darkBgEnd = Color(0xFF0E1626);

  // ─── Active (theme-aware) palette ───────────────────────────
  static Brightness _brightness = Brightness.light;
  static Brightness get brightness => _brightness;

  static void setBrightness(Brightness b) => _brightness = b;

  static LinearGradient get bgGradient => _brightness == Brightness.dark
      ? darkBgGradient
      : lightBgGradient;

  static Color get surface =>
      _brightness == Brightness.dark ? darkSurface : lightSurface;

  static Color get surfaceMuted =>
      _brightness == Brightness.dark ? darkSurfaceMuted : lightSurfaceMuted;

  static Color get textPrimary =>
      _brightness == Brightness.dark ? darkTextPrimary : lightTextPrimary;

  static Color get textSecondary =>
      _brightness == Brightness.dark ? darkTextSecondary : lightTextSecondary;

  static Color get textMuted =>
      _brightness == Brightness.dark ? darkTextMuted : lightTextMuted;

  static Color get border =>
      _brightness == Brightness.dark ? darkBorder : lightBorder;

  // Accent / status
  static const success = Color(0xFF10B981);

  // ─── Gradients ───────────────────────────────────────────────
  static const LinearGradient lightBgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lightBgStart, lightBgMid, lightBgEnd],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
  );

  static const LinearGradient darkBgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [darkBgStart, darkBgMid, darkBgEnd],
  );
}

/// Light theme.
ThemeData buildLightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBgStart,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.lightSurface,
      onPrimary: Colors.white,
      onSurface: AppColors.lightTextPrimary,
    ),
  );
}

/// Dark theme.
ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBgStart,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF818CF8), // lighter indigo for dark mode
      secondary: Color(0xFFA78BFA), // lighter purple
      surface: AppColors.darkSurface,
      onPrimary: Colors.white,
      onSurface: AppColors.darkTextPrimary,
    ),
  );
}

/// Dynamic colors that respect the current theme (context-aware).
class AppColorsExt {
  static Color textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkTextPrimary
          : AppColors.lightTextPrimary;
  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkTextSecondary
          : AppColors.lightTextSecondary;
  static Color textMuted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkTextMuted
          : AppColors.lightTextMuted;
  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface
          : AppColors.lightSurface;
  static Color surfaceMuted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurfaceMuted
          : AppColors.lightSurfaceMuted;
  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkBorder
          : AppColors.lightBorder;
  static LinearGradient bgGradient(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkBgGradient
          : AppColors.lightBgGradient;
}
