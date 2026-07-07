/// Design tokens for the Sanjeevani UI.
///
/// Design principles:
///   - Large tap targets (min 56px) for outdoor, low-light, sweaty-hand use.
///   - High contrast ratios (WCAG AA minimum) — workers may use phones
///     in bright sunlight.
///   - Three risk colours with both hue and icon distinction — not just
///     colour alone, for colour-blind accessibility.
///   - Text stays readable at 120% system font scale.
library;

import 'package:flutter/material.dart';

class SanjeevaniTheme {
  SanjeevaniTheme._();

  // ── Brand colours ─────────────────────────────────────────────────────────
  static const Color primary     = Color(0xFF085041); // deep forest green
  static const Color primaryMid  = Color(0xFF1D9E75); // mid green
  static const Color accent      = Color(0xFF5DCAA5); // teal

  // ── Risk level colours ────────────────────────────────────────────────────
  static const Color riskLow     = Color(0xFF27500A); // dark green
  static const Color riskLowBg   = Color(0xFFEAF3DE);
  static const Color riskMedium  = Color(0xFF633806); // amber-brown
  static const Color riskMedBg   = Color(0xFFFAEEDA);
  static const Color riskHigh    = Color(0xFF791F1F); // dark red
  static const Color riskHighBg  = Color(0xFFFCEBEB);

  // ── Neutral ───────────────────────────────────────────────────────────────
  static const Color surface     = Color(0xFFF7F5EF);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color border      = Color(0xFFD3D1C7);
  static const Color textPrimary = Color(0xFF2C2C2A);
  static const Color textSecond  = Color(0xFF5F5E5A);
  static const Color textMuted   = Color(0xFF888780);

  // ── Minimum tap target ────────────────────────────────────────────────────
  static const double minTapTarget = 56.0;

  static ThemeData get theme => ThemeData(
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: primary,
          onPrimary: Colors.white,
          secondary: accent,
          onSecondary: Colors.white,
          surface: surface,
          onSurface: textPrimary,
          error: riskHigh,
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: surface,
        fontFamily: 'System',
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 26, fontWeight: FontWeight.w600, color: textPrimary,
          ),
          headlineMedium: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary,
          ),
          titleMedium: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w500, color: textPrimary,
          ),
          bodyLarge: TextStyle(fontSize: 15, color: textPrimary),
          bodyMedium: TextStyle(fontSize: 13, color: textSecond),
          labelSmall: TextStyle(
            fontSize: 11, letterSpacing: 0.6,
            fontWeight: FontWeight.w500, color: textMuted,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(minTapTarget),
            backgroundColor: primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(minTapTarget),
            foregroundColor: primary,
            side: const BorderSide(color: border, width: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w500,
            ),
          ),
        ),
        cardTheme: CardTheme(
          color: surfaceCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: border, width: 0.5),
          ),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border, width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: surface,
          elevation: 0,
          foregroundColor: textPrimary,
          titleTextStyle: TextStyle(
            fontSize: 17, fontWeight: FontWeight.w600, color: textPrimary,
          ),
        ),
      );
}
