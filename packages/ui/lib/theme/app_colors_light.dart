import 'package:flutter/material.dart';

/// DineIn LIGHT color tokens — daylight-optimized palette.
///
/// Maintains gold primary, mint secondary, lavender tertiary.
/// Surfaces are warm off-white (not pure white) to reduce glare.
abstract final class AppColorsLight {
  // ─── Primary Palette ───
  static const primary = Color(0xFF8B7A3D);        // deeper gold for readability
  static const onPrimary = Color(0xFFFFFBF0);
  static const primaryContainer = Color(0xFFF5E6C0);
  static const onPrimaryContainer = Color(0xFF402D06);

  // ─── Secondary Palette ───
  static const secondary = Color(0xFF3A7B2E);       // deeper mint
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFD5F0CE);
  static const onSecondaryContainer = Color(0xFF0A3909);

  // ─── Tertiary Palette ───
  static const tertiary = Color(0xFF4B5E89);         // deeper lavender
  static const onTertiary = Color(0xFFFFFFFF);
  static const tertiaryContainer = Color(0xFFD9E1F5);
  static const onTertiaryContainer = Color(0xFF23304B);

  // ─── Error ───
  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF690005);

  // ─── Surface System (Light) ───
  static const surface = Color(0xFFF8F5F0);           // warm off-white
  static const onSurface = Color(0xFF1C1B1F);
  static const onSurfaceVariant = Color(0xFF5C5850);

  // ─── Surface Container Hierarchy ───
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF3F0EB);
  static const surfaceContainer = Color(0xFFEDE9E4);
  static const surfaceContainerHigh = Color(0xFFE7E3DE);
  static const surfaceContainerHighest = Color(0xFFE1DDD8);

  // ─── Outline ───
  static const outline = Color(0xFF857C72);
  static const outlineVariant = Color(0xFFD0C7BC);

  // ─── Inverse ───
  static const inverseSurface = Color(0xFF323030);
  static const inverseOnSurface = Color(0xFFF4F0EB);
  static const inversePrimary = Color(0xFFE1C28E);

  // ─── Semantic ───
  static const success = Color(0xFF3A7B2E);          // same as secondary
  static const warning = Color(0xFFA9820B);
  static const info = Color(0xFF4B5E89);             // same as tertiary

  // ─── Utility ───
  /// Shadow color for light mode
  static Color get shadow => onSurface.withValues(alpha: 0.06);

  /// Ghost border: outlineVariant at 20% opacity
  static Color get ghostBorder => outlineVariant.withValues(alpha: 0.30);

  /// Overlay for modals and sheets in light mode
  static Color get glassOverlay => surface.withValues(alpha: 0.80);

  /// White replacements for light mode — used as subtle tints
  static Color get white5 => const Color(0xFF000000).withValues(alpha: 0.04);
  static Color get white10 => const Color(0xFF000000).withValues(alpha: 0.07);
  static Color get white20 => const Color(0xFF000000).withValues(alpha: 0.10);
  static Color get white40 => const Color(0xFF000000).withValues(alpha: 0.15);
}
