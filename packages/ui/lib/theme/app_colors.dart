import 'package:flutter/material.dart';

/// DineIn color tokens — exact match of React index.css dark palette.
///
/// Creative North Star: "The Executive Architect"
/// Primary: Gold/Amber (#e1c28e) — warm, sophisticated.
/// Secondary: Mint/Forest Green (#a1d494) — fresh, alive.
/// Tertiary: Lavender Blue (#b9c6e9) — cool accent.
/// Surfaces: Near-black tonal hierarchy (#0c0e10 → #333537).
abstract final class AppColors {
  // ─── Primary Palette ───
  static const primary = Color(0xFFE1C28E);
  static const onPrimary = Color(0xFF402D06);
  static const primaryContainer = Color(0xFFA88D5D);
  static const onPrimaryContainer = Color(0xFF382701);

  /// The exact dark warm gold from the DINEIN logo wordmark.
  /// Use for brand text "DINE" whenever rendering the logo.
  static const brandGold = Color(0xFF8B7A3D);

  // ─── Secondary Palette ───
  static const secondary = Color(0xFFA1D494);
  static const onSecondary = Color(0xFF0A3909);
  static const secondaryContainer = Color(0xFF23501E);
  static const onSecondaryContainer = Color(0xFF90C283);

  // ─── Tertiary Palette ───
  static const tertiary = Color(0xFFB9C6E9);
  static const onTertiary = Color(0xFF23304B);
  static const tertiaryContainer = Color(0xFF8491B1);
  static const onTertiaryContainer = Color(0xFF1C2944);

  // ─── Error ───
  static const error = Color(0xFFFFB4AB);
  static const onError = Color(0xFF690005);
  static const errorContainer = Color(0xFF93000A);
  static const onErrorContainer = Color(0xFFFFDAD6);

  // ─── Background ───
  static const background = Color(0xFF121416);
  static const onBackground = Color(0xFFE2E2E5);

  // ─── Surface System (Dark) ───
  static const surface = Color(0xFF121416);
  static const onSurface = Color(0xFFE2E2E5);
  static const surfaceVariant = Color(0xFF333537);
  static const onSurfaceVariant = Color(0xFFD0C5B6);

  // ─── Surface Container Hierarchy ───
  static const surfaceContainerLowest = Color(0xFF0C0E10);
  static const surfaceContainerLow = Color(0xFF1A1C1E);
  static const surfaceContainer = Color(0xFF1E2022);
  static const surfaceContainerHigh = Color(0xFF282A2C);
  static const surfaceContainerHighest = Color(0xFF333537);

  // ─── Outline ───
  static const outline = Color(0xFF998F82);
  static const outlineVariant = Color(0xFF4D463B);

  // ─── Inverse ───
  static const inverseSurface = Color(0xFFE2E2E5);
  static const inverseOnSurface = Color(0xFF2F3133);
  static const inversePrimary = Color(0xFF7B6532);

  // ─── Semantic ───
  static const success = Color(0xFFA1D494); // same as secondary
  static const warning = Color(0xFFFEE191);
  static const info = Color(0xFFB9C6E9); // same as tertiary

  // ─── Utility ───
  /// Shadow color: onSurface at 4% opacity
  static Color get shadow => onSurface.withValues(alpha: 0.04);

  /// Ghost border: outlineVariant at 15% opacity
  static Color get ghostBorder => outlineVariant.withValues(alpha: 0.15);

  /// Glass overlay: surface at 60% opacity (matching React premium-blur)
  static Color get glassOverlay => surface.withValues(alpha: 0.60);

  /// White at various opacities — matching React white/5, white/10 patterns
  static Color get white5 => Colors.white.withValues(alpha: 0.05);
  static Color get white10 => Colors.white.withValues(alpha: 0.10);
  static Color get white20 => Colors.white.withValues(alpha: 0.20);
  static Color get white40 => Colors.white.withValues(alpha: 0.40);
}
