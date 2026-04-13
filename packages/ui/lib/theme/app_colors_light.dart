import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Light tokens are intentionally aligned with [AppColors] so the app can roll
/// out a single, consistent minimalist language without divergent palettes.
abstract final class AppColorsLight {
  static const primary = AppColors.primary;
  static const onPrimary = AppColors.onPrimary;
  static const primaryContainer = AppColors.primaryContainer;
  static const onPrimaryContainer = AppColors.onPrimaryContainer;

  static const secondary = AppColors.secondary;
  static const onSecondary = AppColors.onSecondary;
  static const secondaryContainer = AppColors.secondaryContainer;
  static const onSecondaryContainer = AppColors.onSecondaryContainer;

  static const tertiary = AppColors.tertiary;
  static const onTertiary = AppColors.onTertiary;
  static const tertiaryContainer = AppColors.tertiaryContainer;
  static const onTertiaryContainer = AppColors.onTertiaryContainer;

  static const error = AppColors.error;
  static const onError = AppColors.onError;
  static const errorContainer = AppColors.errorContainer;
  static const onErrorContainer = AppColors.onErrorContainer;

  static const surface = AppColors.surface;
  static const onSurface = AppColors.onSurface;
  static const onSurfaceVariant = AppColors.onSurfaceVariant;

  static const surfaceContainerLowest = AppColors.surfaceContainerLowest;
  static const surfaceContainerLow = AppColors.surfaceContainerLow;
  static const surfaceContainer = AppColors.surfaceContainer;
  static const surfaceContainerHigh = AppColors.surfaceContainerHigh;
  static const surfaceContainerHighest = AppColors.surfaceContainerHighest;

  static const outline = AppColors.outline;
  static const outlineVariant = AppColors.outlineVariant;

  static const inverseSurface = AppColors.inverseSurface;
  static const inverseOnSurface = AppColors.inverseOnSurface;
  static const inversePrimary = AppColors.inversePrimary;

  static const success = AppColors.success;
  static const warning = AppColors.warning;
  static const info = AppColors.info;

  static Color get shadow => AppColors.shadow;
  static Color get ghostBorder => AppColors.ghostBorder;
  static Color get glassOverlay => AppColors.glassOverlay;
  static Color get white5 => AppColors.white5;
  static Color get white10 => AppColors.white10;
  static Color get white20 => AppColors.white20;
  static Color get white40 => AppColors.white40;
}
