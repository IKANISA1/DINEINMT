import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// DineIn typography system — exact match of React Tailwind classes.
///
/// Font pairing: **Public Sans** (headlines, w900/800) + **Inter** (body, w500).
///
/// Tailwind → px mapping (source of truth):
/// text-6xl = 60px | text-5xl = 48px | text-4xl = 36px
/// text-3xl = 30px | text-2xl = 24px | text-xl  = 20px
/// text-lg  = 18px | text-base = 16px | text-sm = 14px
/// text-xs  = 12px | text-[10px] = 10px | text-[8px] = 8px
///
/// Weight mapping:
/// font-black = w900 | font-extrabold = w800 | font-bold = w700
/// font-semibold = w600 | font-medium = w500
///
/// Rules from design system:
/// - Never use "Light" or "Thin" weights.
/// - Headlines: Public Sans Black/ExtraBold with tight letter-spacing.
/// - Body/Labels: Inter Medium.
/// - Hierarchy via Scale + Color, not weight reduction.
abstract final class AppTypography {
  static const List<String> _fontFallbacks = [
    'Noto Sans',
    'Noto Color Emoji',
    'Segoe UI Emoji',
    'Apple Color Emoji',
    'sans-serif',
  ];

  // ─── Headline Font ───
  static TextStyle _headline({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w900,
    double letterSpacing = -0.05,
    double height = 1.1,
    Color? color,
  }) {
    return GoogleFonts.publicSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: fontSize * letterSpacing,
      height: height,
      color: color,
      textStyle: const TextStyle(fontFamilyFallback: _fontFallbacks),
    );
  }

  // ─── Body Font ───
  static TextStyle _body({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w500,
    double letterSpacing = 0,
    double height = 1.5,
    Color? color,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
      textStyle: const TextStyle(fontFamilyFallback: _fontFallbacks),
    );
  }

  /// Creates the full TextTheme for Material 3.
  ///
  /// Sizes match React Tailwind classes EXACTLY:
  /// displayLarge  = text-6xl (60px)
  /// displayMedium = text-5xl (48px)
  /// displaySmall  = text-4xl (36px)
  /// headlineLarge = text-3xl (30px)
  /// headlineMedium = text-2xl (24px)
  /// headlineSmall = text-xl  (20px)
  /// titleLarge   = text-lg  (18px)
  /// titleMedium  = text-base (16px)
  /// titleSmall   = text-sm  (14px)
  /// bodyLarge    = text-base (16px)
  /// bodyMedium   = text-sm  (14px)
  /// bodySmall    = text-xs  (12px)
  /// labelLarge   = text-sm  (14px)
  /// labelMedium  = text-xs  (12px)
  /// labelSmall   = text-[10px] (10px)
  static TextTheme textTheme({Color? onSurface, Color? onSurfaceVariant}) {
    final primary = onSurface ?? const Color(0xFFE2E2E5);
    final secondary = onSurfaceVariant ?? const Color(0xFFD0C5B6);

    return TextTheme(
      // Display: Public Sans, oversized — maps to text-6xl, text-5xl, text-4xl
      displayLarge: _headline(fontSize: 60, color: primary), // text-6xl
      displayMedium: _headline(fontSize: 48, color: primary), // text-5xl
      displaySmall: _headline(fontSize: 36, color: primary), // text-4xl
      // Headlines: Public Sans Black — maps to text-3xl, text-2xl, text-xl
      headlineLarge: _headline(fontSize: 30, color: primary), // text-3xl
      headlineMedium: _headline(fontSize: 24, color: primary), // text-2xl
      headlineSmall: _headline(fontSize: 20, color: primary), // text-xl
      // Titles: Public Sans Bold — maps to text-lg, text-base, text-sm
      titleLarge: _headline(
        fontSize: 18, // text-lg
        fontWeight: FontWeight.w800,
        color: primary,
      ),
      titleMedium: _headline(
        fontSize: 16, // text-base
        fontWeight: FontWeight.w800,
        letterSpacing: -0.01,
        color: primary,
      ),
      titleSmall: _headline(
        fontSize: 14, // text-sm
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: primary,
      ),

      // Body: Inter Medium (never Light)
      bodyLarge: _body(fontSize: 16, color: primary), // text-base
      bodyMedium: _body(fontSize: 14, color: primary), // text-sm
      bodySmall: _body(fontSize: 12, color: secondary), // text-xs
      // Labels: Inter Bold for buttons/badges/metadata
      labelLarge: _body(
        fontSize: 14, // text-sm
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      labelMedium: _body(
        fontSize: 12, // text-xs
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: primary,
      ),
      labelSmall: _body(
        fontSize: 10, // text-[10px]
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        color: secondary,
      ),
    );
  }
}
