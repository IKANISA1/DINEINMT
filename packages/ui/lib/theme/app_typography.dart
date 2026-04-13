import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Minimal typography with a tight, controlled scale.
///
/// The system favors a single readable family and avoids the oversized,
/// heavily-tracked labels that made the previous UI feel louder than needed.
abstract final class AppTypography {
  static const List<String> _fontFallbacks = [
    'Noto Sans',
    'Noto Color Emoji',
    'Segoe UI Emoji',
    'Apple Color Emoji',
    'sans-serif',
  ];

  static TextStyle _style({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w600,
    double letterSpacing = 0,
    double height = 1.2,
    Color? color,
  }) {
    return GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
      textStyle: const TextStyle(fontFamilyFallback: _fontFallbacks),
    );
  }

  static TextTheme textTheme({Color? onSurface, Color? onSurfaceVariant}) {
    final primary = onSurface ?? const Color(0xFF181611);
    final secondary = onSurfaceVariant ?? const Color(0xFF6B645B);

    return TextTheme(
      displayLarge: _style(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.04,
        color: primary,
      ),
      displayMedium: _style(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
        height: 1.06,
        color: primary,
      ),
      displaySmall: _style(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        height: 1.08,
        color: primary,
      ),
      headlineLarge: _style(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.1,
        color: primary,
      ),
      headlineMedium: _style(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.12,
        color: primary,
      ),
      headlineSmall: _style(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.16,
        color: primary,
      ),
      titleLarge: _style(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.2,
        color: primary,
      ),
      titleMedium: _style(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
        height: 1.22,
        color: primary,
      ),
      titleSmall: _style(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.24,
        color: primary,
      ),
      bodyLarge: _style(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.46,
        color: primary,
      ),
      bodyMedium: _style(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.42,
        color: primary,
      ),
      bodySmall: _style(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.36,
        color: secondary,
      ),
      labelLarge: _style(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.18,
        color: primary,
      ),
      labelMedium: _style(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        height: 1.18,
        color: primary,
      ),
      labelSmall: _style(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        height: 1.16,
        color: secondary,
      ),
    );
  }
}
