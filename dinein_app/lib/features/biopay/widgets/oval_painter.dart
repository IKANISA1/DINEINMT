import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Custom painter for the face scanner oval overlay.
///
/// Draws a semi-transparent dark overlay with an oval cutout in the center.
/// The oval border color indicates the scanning state:
/// - `searching`: amber/gold (AppColors.warning)
/// - `locked`: green (AppColors.secondary)
/// - `error`: red (AppColors.error)
class OvalPainter extends CustomPainter {
  final ScannerState state;
  final double progress; // 0..1 for animation

  OvalPainter({required this.state, this.progress = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    // Oval dimensions: 65% width, 80% height, centered
    final ovalWidth = size.width * 0.65;
    final ovalHeight = size.height * 0.55;
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: ovalWidth,
      height: ovalHeight,
    );

    // Dark overlay with oval cutout
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(ovalRect)
      ..fillType = PathFillType.evenOdd;

    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.72)
      ..style = PaintingStyle.fill;

    canvas.drawPath(overlayPath, overlayPaint);

    // Oval border
    final borderColor = switch (state) {
      ScannerState.searching => AppColors.warning,
      ScannerState.locked => AppColors.secondary,
      ScannerState.captured => AppColors.secondary,
      ScannerState.error => AppColors.error,
      ScannerState.noMatch => AppColors.error,
    };

    final borderPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.9 * progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawOval(ovalRect, borderPaint);

    // Glow effect for locked state
    if (state == ScannerState.locked || state == ScannerState.captured) {
      final glowPaint = Paint()
        ..color = AppColors.secondary.withValues(alpha: 0.15 * progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawOval(ovalRect, glowPaint);
    }
  }

  @override
  bool shouldRepaint(OvalPainter oldDelegate) =>
      oldDelegate.state != state || oldDelegate.progress != progress;
}

/// Scanner overlay states.
enum ScannerState { searching, locked, captured, error, noMatch }
