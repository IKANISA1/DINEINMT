import 'package:flutter/material.dart';

/// Core UI colors for the minimalist DineIn system.
///
/// The palette is intentionally restrained:
/// - warm neutral surfaces for lighter, calmer screens
/// - bronze as the primary brand/action accent
/// - muted green and slate for supporting status/tone
abstract final class AppColors {
  static const primary = Color(0xFF75663A);
  static const onPrimary = Color(0xFFFFFCF6);
  static const primaryContainer = Color(0xFFF0E6CF);
  static const onPrimaryContainer = Color(0xFF4B3E1E);

  static const brandGold = Color(0xFF8B7A3D);

  static const secondary = Color(0xFF496654);
  static const onSecondary = Color(0xFFF7F5F0);
  static const secondaryContainer = Color(0xFFDCE7DF);
  static const onSecondaryContainer = Color(0xFF25352B);

  static const tertiary = Color(0xFF62707B);
  static const onTertiary = Color(0xFFF7F7F7);
  static const tertiaryContainer = Color(0xFFDCE3E8);
  static const onTertiaryContainer = Color(0xFF2B3540);

  static const error = Color(0xFFB44940);
  static const onError = Color(0xFFFFFBFA);
  static const errorContainer = Color(0xFFF5DDD9);
  static const onErrorContainer = Color(0xFF6C231D);

  static const background = Color(0xFFF7F4EE);
  static const onBackground = Color(0xFF181611);

  static const surface = Color(0xFFF7F4EE);
  static const onSurface = Color(0xFF181611);
  static const surfaceVariant = Color(0xFFF0EBE4);
  static const onSurfaceVariant = Color(0xFF6B645B);

  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFFCFAF7);
  static const surfaceContainer = Color(0xFFF5F0E8);
  static const surfaceContainerHigh = Color(0xFFECE5DB);
  static const surfaceContainerHighest = Color(0xFFE2D8CC);

  static const outline = Color(0xFFB7AB9B);
  static const outlineVariant = Color(0xFFD9D0C4);

  static const inverseSurface = Color(0xFF25221E);
  static const inverseOnSurface = Color(0xFFF8F5EF);
  static const inversePrimary = Color(0xFFE2D4AF);

  static const success = Color(0xFF3F6C57);
  static const warning = Color(0xFFC18C30);
  static const info = Color(0xFF5C748E);

  static Color get shadow => const Color(0xFF181611).withValues(alpha: 0.08);
  static Color get ghostBorder => outlineVariant.withValues(alpha: 0.72);
  static Color get glassOverlay => surface.withValues(alpha: 0.88);

  // Legacy utility names kept for compatibility with existing screens.
  static Color get white5 => const Color(0xFF181611).withValues(alpha: 0.04);
  static Color get white10 => const Color(0xFF181611).withValues(alpha: 0.08);
  static Color get white20 => const Color(0xFF181611).withValues(alpha: 0.12);
  static Color get white40 => const Color(0xFF181611).withValues(alpha: 0.18);
}
