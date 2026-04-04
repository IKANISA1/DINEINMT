import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:ui/theme/app_colors.dart';

/// Custom painter for the face scanner oval overlay.
///
/// Draws a semi-transparent dark overlay with an oval cutout in the center.
/// Supports a segmented progress arc (Apple Face ID-style) where each
/// captured sample fills a segment of the ring.
///
/// The oval border color indicates the scanning state:
/// - `searching`: amber/gold pulsing
/// - `locked`: bright green
/// - `captured`: solid green
/// - `error`/`noMatch`: red
class OvalPainter extends CustomPainter {
  final ScannerState state;
  final double progress; // 0..1 for pulse animation
  final int samplesCaptured;
  final int totalSamples;

  OvalPainter({
    required this.state,
    this.progress = 1.0,
    this.samplesCaptured = 0,
    this.totalSamples = 5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Oval dimensions: 65% width, 55% height, pushed slightly up
    final ovalWidth = size.width * 0.65;
    final ovalHeight = size.height * 0.55;
    final center = Offset(size.width / 2, size.height * 0.42);
    final ovalRect = Rect.fromCenter(
      center: center,
      width: ovalWidth,
      height: ovalHeight,
    );

    // ─── Dark overlay with oval cutout ───
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(ovalRect)
      ..fillType = PathFillType.evenOdd;

    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.72)
      ..style = PaintingStyle.fill;

    canvas.drawPath(overlayPath, overlayPaint);

    // ─── Corner alignment markers ───
    _drawCornerMarkers(canvas, ovalRect);

    // ─── Segmented progress ring ───
    if (totalSamples > 0) {
      _drawSegmentedRing(canvas, ovalRect);
    } else {
      _drawSimpleBorder(canvas, ovalRect);
    }

    // ─── Pulsing outer glow for locked/captured ───
    if (state == ScannerState.locked || state == ScannerState.captured) {
      _drawPulsingGlow(canvas, ovalRect);
    }
  }

  void _drawCornerMarkers(Canvas canvas, Rect ovalRect) {
    final markerLength = ovalRect.width * 0.08;
    final markerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Top center
    final top = Offset(ovalRect.center.dx, ovalRect.top);
    canvas.drawLine(
      top.translate(0, -6),
      top.translate(0, -6 - markerLength),
      markerPaint,
    );

    // Bottom center
    final bottom = Offset(ovalRect.center.dx, ovalRect.bottom);
    canvas.drawLine(
      bottom.translate(0, 6),
      bottom.translate(0, 6 + markerLength),
      markerPaint,
    );

    // Left center
    final left = Offset(ovalRect.left, ovalRect.center.dy);
    canvas.drawLine(
      left.translate(-6, 0),
      left.translate(-6 - markerLength, 0),
      markerPaint,
    );

    // Right center
    final right = Offset(ovalRect.right, ovalRect.center.dy);
    canvas.drawLine(
      right.translate(6, 0),
      right.translate(6 + markerLength, 0),
      markerPaint,
    );
  }

  void _drawSegmentedRing(Canvas canvas, Rect ovalRect) {
    final segments = totalSamples;
    final gapAngle = 0.06; // radians between segments
    final totalGap = gapAngle * segments;
    final totalArc = (2 * math.pi) - totalGap;
    final segmentArc = totalArc / segments;
    final startOffset = -math.pi / 2; // Start from top

    for (int i = 0; i < segments; i++) {
      final segmentStart = startOffset + i * (segmentArc + gapAngle);
      final isFilled = i < samplesCaptured;
      final isCurrent = i == samplesCaptured && state == ScannerState.locked;

      Color segmentColor;
      double strokeWidth;
      double alpha;

      if (isFilled) {
        segmentColor = AppColors.secondary;
        strokeWidth = 3.5;
        alpha = 0.95;
      } else if (isCurrent) {
        // Pulsing current segment
        segmentColor = AppColors.warning;
        strokeWidth = 3.5;
        alpha = 0.5 + 0.5 * progress;
      } else {
        segmentColor = Colors.white;
        strokeWidth = 2.0;
        alpha = 0.15;
      }

      final paint = Paint()
        ..color = segmentColor.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(ovalRect, segmentStart, segmentArc, false, paint);

      // Filled segment inner glow
      if (isFilled) {
        final glowPaint = Paint()
          ..color = AppColors.secondary.withValues(alpha: 0.10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

        canvas.drawArc(ovalRect, segmentStart, segmentArc, false, glowPaint);
      }
    }
  }

  void _drawSimpleBorder(Canvas canvas, Rect ovalRect) {
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
  }

  void _drawPulsingGlow(Canvas canvas, Rect ovalRect) {
    // Breathing glow intensity
    final breathe = 0.08 + 0.12 * ((math.sin(progress * math.pi * 2) + 1) / 2);

    final glowPaint = Paint()
      ..color = AppColors.secondary.withValues(alpha: breathe)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    canvas.drawOval(ovalRect, glowPaint);

    // Tight inner glow
    final innerGlow = Paint()
      ..color = AppColors.secondary.withValues(alpha: breathe * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawOval(ovalRect, innerGlow);
  }

  @override
  bool shouldRepaint(OvalPainter oldDelegate) =>
      oldDelegate.state != state ||
      oldDelegate.progress != progress ||
      oldDelegate.samplesCaptured != samplesCaptured ||
      oldDelegate.totalSamples != totalSamples;
}

/// Scanner overlay states.
enum ScannerState { searching, locked, captured, error, noMatch }
