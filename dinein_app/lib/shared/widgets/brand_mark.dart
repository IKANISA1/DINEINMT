import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Near-black background matching the new DINEIN app icon.
const _brandBg = Color(0xFF141414);

/// Shared DineIn square brand mark used across app chrome and splash surfaces.
class BrandMark extends StatelessWidget {
  final double size;
  final double? borderRadius;
  final double? fontSize;
  final double shadowBlur;
  final double shadowOpacity;
  final Color backgroundColor;

  const BrandMark({
    super.key,
    required this.size,
    this.borderRadius,
    this.fontSize,
    this.shadowBlur = 0,
    this.shadowOpacity = 0.18,
    this.backgroundColor = _brandBg,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedRadius = borderRadius ?? size * 0.22;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(resolvedRadius),
        boxShadow: shadowBlur <= 0
            ? null
            : [
                BoxShadow(
                  color: backgroundColor.withValues(alpha: shadowOpacity),
                  blurRadius: shadowBlur,
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/branding/dinein-brand-icon-1024.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

/// Rich text widget for the DINEIN brand name.
///
/// Matches the brand logo: **"DINE"** in [AppColors.brandGold] and
/// **"IN"** in white (or [onSurface] on light backgrounds).
class DineInLogoText extends StatelessWidget {
  final double fontSize;

  /// Color for "DINE". Defaults to [AppColors.brandGold].
  final Color? dineColor;

  /// Color for "IN". Defaults to [ColorScheme.onSurface] (white in dark mode).
  final Color? inColor;

  final double letterSpacing;
  final String? suffix;
  final TextStyle? suffixStyle;

  const DineInLogoText({
    super.key,
    this.fontSize = 20,
    this.dineColor,
    this.inColor,
    this.letterSpacing = -0.5,
    this.suffix,
    this.suffixStyle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final goldColor = dineColor ?? AppColors.brandGold;
    final whiteColor = inColor ?? cs.onSurface;

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          letterSpacing: letterSpacing,
          height: 1,
        ),
        children: [
          TextSpan(
            text: 'DINE',
            style: TextStyle(color: goldColor),
          ),
          TextSpan(
            text: 'IN',
            style: TextStyle(color: whiteColor),
          ),
          if (suffix != null)
            TextSpan(
              text: suffix,
              style:
                  suffixStyle ??
                  TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: fontSize,
                    letterSpacing: letterSpacing,
                    color: whiteColor,
                  ),
            ),
        ],
      ),
    );
  }
}
