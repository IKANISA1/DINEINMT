import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_colors_light.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 18;
  static const double radiusXl = 22;
  static const double radiusLgx = 26;
  static const double radiusXxl = 30;
  static const double radius3xl = 36;
  static const double radiusFull = 999;

  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;
  static const double space10 = 40;
  static const double space12 = 48;
  static const double space16 = 64;
  static const double space24 = 96;

  static List<BoxShadow> get clayShadow => [
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get clayHoverShadow => [
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: 0.12),
      blurRadius: 28,
      offset: const Offset(0, 12),
    ),
  ];

  static List<BoxShadow> get ambientShadow => clayShadow;

  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: 0.14),
      blurRadius: 36,
      offset: const Offset(0, 18),
    ),
  ];

  static ThemeData get light => _buildTheme(
    brightness: Brightness.light,
    primary: AppColorsLight.primary,
    onPrimary: AppColorsLight.onPrimary,
    primaryContainer: AppColorsLight.primaryContainer,
    onPrimaryContainer: AppColorsLight.onPrimaryContainer,
    secondary: AppColorsLight.secondary,
    onSecondary: AppColorsLight.onSecondary,
    secondaryContainer: AppColorsLight.secondaryContainer,
    onSecondaryContainer: AppColorsLight.onSecondaryContainer,
    tertiary: AppColorsLight.tertiary,
    onTertiary: AppColorsLight.onTertiary,
    tertiaryContainer: AppColorsLight.tertiaryContainer,
    onTertiaryContainer: AppColorsLight.onTertiaryContainer,
    error: AppColorsLight.error,
    onError: AppColorsLight.onError,
    errorContainer: AppColorsLight.errorContainer,
    onErrorContainer: AppColorsLight.onErrorContainer,
    surface: AppColorsLight.surface,
    onSurface: AppColorsLight.onSurface,
    onSurfaceVariant: AppColorsLight.onSurfaceVariant,
    outline: AppColorsLight.outline,
    outlineVariant: AppColorsLight.outlineVariant,
    inverseSurface: AppColorsLight.inverseSurface,
    inverseOnSurface: AppColorsLight.inverseOnSurface,
    inversePrimary: AppColorsLight.inversePrimary,
    surfaceContainerLowest: AppColorsLight.surfaceContainerLowest,
    surfaceContainerLow: AppColorsLight.surfaceContainerLow,
    surfaceContainer: AppColorsLight.surfaceContainer,
    surfaceContainerHigh: AppColorsLight.surfaceContainerHigh,
    surfaceContainerHighest: AppColorsLight.surfaceContainerHighest,
  );

  static ThemeData get dark => light;

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color primary,
    required Color onPrimary,
    required Color primaryContainer,
    required Color onPrimaryContainer,
    required Color secondary,
    required Color onSecondary,
    required Color secondaryContainer,
    required Color onSecondaryContainer,
    required Color tertiary,
    required Color onTertiary,
    required Color tertiaryContainer,
    required Color onTertiaryContainer,
    required Color error,
    required Color onError,
    required Color errorContainer,
    required Color onErrorContainer,
    required Color surface,
    required Color onSurface,
    required Color onSurfaceVariant,
    required Color outline,
    required Color outlineVariant,
    required Color inverseSurface,
    required Color inverseOnSurface,
    required Color inversePrimary,
    required Color surfaceContainerLowest,
    required Color surfaceContainerLow,
    required Color surfaceContainer,
    required Color surfaceContainerHigh,
    required Color surfaceContainerHighest,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: secondary,
      onSecondary: onSecondary,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onSecondaryContainer,
      tertiary: tertiary,
      onTertiary: onTertiary,
      tertiaryContainer: tertiaryContainer,
      onTertiaryContainer: onTertiaryContainer,
      error: error,
      onError: onError,
      errorContainer: errorContainer,
      onErrorContainer: onErrorContainer,
      surface: surface,
      onSurface: onSurface,
      outline: outline,
      outlineVariant: outlineVariant,
      shadow: AppColors.shadow,
      scrim: Colors.black.withValues(alpha: 0.12),
      inverseSurface: inverseSurface,
      onInverseSurface: inverseOnSurface,
      inversePrimary: inversePrimary,
      surfaceContainerLowest: surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      onSurfaceVariant: onSurfaceVariant,
    );

    final textTheme = AppTypography.textTheme(
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: surface,
      canvasColor: surface,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: onSurface,
        titleTextStyle: textTheme.titleLarge,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          side: BorderSide(color: outlineVariant.withValues(alpha: 0.72)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: outlineVariant.withValues(alpha: 0.72),
        thickness: 1,
        space: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: inverseOnSurface,
        ),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(space4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXxl),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXxl)),
        ),
        showDragHandle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLowest,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: onSurfaceVariant.withValues(alpha: 0.72),
        ),
        labelStyle: textTheme.labelMedium?.copyWith(color: onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: space4,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          borderSide: BorderSide(color: outlineVariant.withValues(alpha: 0.72)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          borderSide: BorderSide(color: outlineVariant.withValues(alpha: 0.72)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          borderSide: BorderSide(color: primary.withValues(alpha: 0.88)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          foregroundColor: onSurface,
          side: BorderSide(color: outlineVariant.withValues(alpha: 0.9)),
          backgroundColor: surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceContainerLowest,
        selectedColor: primaryContainer,
        disabledColor: surfaceContainerHigh,
        labelStyle: textTheme.labelMedium?.copyWith(color: onSurfaceVariant),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: onPrimaryContainer,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusFull),
          side: BorderSide(color: outlineVariant.withValues(alpha: 0.72)),
        ),
        side: BorderSide(color: outlineVariant.withValues(alpha: 0.72)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceContainerLowest,
        indicatorColor: primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 20,
            color: selected ? primary : onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? onSurface : onSurfaceVariant,
          );
        }),
      ),
    );
  }
}
