import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Near-black background matching the new DINEIN app icon.
const _brandBg = Color(0xFF141414);

/// Shared DineIn brand mark used for app chrome and launcher icon previews.
///
/// Renders the DINEIN wordmark (gold "DINE" + white "IN") on a near-black
/// background. For very small sizes (< 36 px) falls back to a single "D".
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
    // For tiny sizes show just "D"; otherwise full wordmark
    final bool compact = size < 36;
    final resolvedFontSize = fontSize ?? (compact ? size * 0.52 : size * 0.24);

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
      child: Center(
        child: compact
            ? Text(
                'D',
                style: TextStyle(
                  color: AppColors.brandGold,
                  fontSize: resolvedFontSize,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              )
            : RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: resolvedFontSize,
                    height: 1,
                    letterSpacing: -0.3,
                  ),
                  children: const [
                    TextSpan(
                      text: 'DINE',
                      style: TextStyle(color: AppColors.brandGold),
                    ),
                    TextSpan(
                      text: 'IN',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
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
          TextSpan(text: 'DINE', style: TextStyle(color: goldColor)),
          TextSpan(text: 'IN', style: TextStyle(color: whiteColor)),
          if (suffix != null)
            TextSpan(
              text: suffix,
              style: suffixStyle ??
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
