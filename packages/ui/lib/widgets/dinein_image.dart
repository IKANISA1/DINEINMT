import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:ui/theme/motion_preferences.dart';

/// Premium network image widget with shimmer loading and graceful fallback.
///
/// Matches the React reference's image-heavy design:
/// - Shimmer placeholder while loading
/// - Gradient + icon fallback on error or null URL
/// - Optional gradient overlay (from-black/90 via-black/20 to-transparent)
/// - Optional border radius
class DineInImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final bool showGradientOverlay;
  final IconData fallbackIcon;
  final Alignment gradientBegin;
  final Alignment gradientEnd;
  final bool isEager;

  /// Accessibility label for screen readers (alt text).
  final String? semanticLabel;

  const DineInImage({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.showGradientOverlay = false,
    this.fallbackIcon = LucideIcons.utensils,
    this.gradientBegin = Alignment.bottomCenter,
    this.gradientEnd = Alignment.topCenter,
    this.isEager = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    Widget child;
    final devicePixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final memCacheWidth = width != null
        ? (width! * devicePixelRatio).round()
        : null;
    final memCacheHeight = height != null
        ? (height! * devicePixelRatio).round()
        : null;

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      final inlineBytes = _tryDecodeInlineImage(imageUrl!);
      if (inlineBytes != null) {
        child = Image.memory(
          inlineBytes,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) =>
              _Fallback(width: width, height: height, icon: fallbackIcon),
        );
      } else {
        child = CachedNetworkImage(
          imageUrl: imageUrl!,
          width: width,
          height: height,
          fit: fit,
          memCacheWidth: memCacheWidth,
          memCacheHeight: memCacheHeight,
          maxWidthDiskCache: memCacheWidth ?? 800,
          maxHeightDiskCache: memCacheHeight ?? 800,
          fadeInDuration: isEager ? Duration.zero : const Duration(milliseconds: 200),
          fadeOutDuration: isEager ? Duration.zero : const Duration(milliseconds: 100),
          placeholder: (context, url) => _Shimmer(
            width: width,
            height: height,
            borderRadius: borderRadius,
          ),
          errorWidget: (context, url, error) =>
              _Fallback(width: width, height: height, icon: fallbackIcon),
        );
      }
    } else {
      child = _Fallback(width: width, height: height, icon: fallbackIcon);
    }

    if (borderRadius > 0 || showGradientOverlay) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            child,
            if (showGradientOverlay)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: gradientBegin,
                      end: gradientEnd,
                      colors: [
                        Colors.black.withValues(alpha: 0.85),
                        Colors.black.withValues(alpha: 0.20),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (semanticLabel != null) {
      child = Semantics(
        image: true,
        label: semanticLabel,
        excludeSemantics: true,
        child: child,
      );
    }

    return child;
  }

  Uint8List? _tryDecodeInlineImage(String url) {
    try {
      final uri = Uri.parse(url);
      final inlineData = uri.data;
      if (inlineData != null) {
        return inlineData.contentAsBytes();
      }
    } catch (_) {
      // Fall back to raw-base64 parsing below.
    }

    final match = RegExp(r'^data:[^;]+;base64,(.+)$').firstMatch(url);
    if (match == null) return null;

    try {
      return base64Decode(match.group(1)!);
    } catch (_) {
      return null;
    }
  }
}

/// Shimmer loading placeholder for images.
class _Shimmer extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const _Shimmer({this.width, this.height, this.borderRadius = 0});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reduceMotion = reduceMotionOf(context);

    if (reduceMotion) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          color: cs.surfaceContainerHigh,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(-1.0 + 2.0 * _controller.value + 1, 0),
              colors: [
                cs.surfaceContainerHigh,
                cs.surfaceContainerHighest,
                cs.surfaceContainerHigh,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Fallback placeholder when image URL is null or fails to load.
class _Fallback extends StatelessWidget {
  final double? width;
  final double? height;
  final IconData icon;

  const _Fallback({this.width, this.height, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.15),
            cs.tertiary.withValues(alpha: 0.10),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 48,
          color: cs.onSurfaceVariant.withValues(alpha: 0.30),
        ),
      ),
    );
  }
}
