import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/providers/permission_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../biopay_providers.dart';
import '../biopay_strings.dart';
import '../services/enrollment_capture_session.dart';
import '../services/face_alignment_service.dart';
import '../services/face_detection_service.dart';
import '../services/stable_frame_gate.dart';
import 'oval_painter.dart';

typedef EnrollmentCaptureReady =
    void Function(EnrollmentCaptureAggregate aggregate);

/// World-class face enrollment capture widget.
///
/// Features:
/// - Edge-to-edge responsive camera preview
/// - Segmented progress ring (Apple Face ID-style)
/// - Animated sample capture dots
/// - Quality feedback overlay with animated transitions
/// - Pulsing ring animation during face lock
class FaceEnrollmentCapture extends ConsumerStatefulWidget {
  const FaceEnrollmentCapture({
    super.key,
    required this.onCaptureReady,
    this.fullBleed = false,
  });

  final EnrollmentCaptureReady onCaptureReady;

  /// When true, camera preview expands edge-to-edge (no border radius).
  final bool fullBleed;

  @override
  ConsumerState<FaceEnrollmentCapture> createState() =>
      _FaceEnrollmentCaptureState();
}

class _FaceEnrollmentCaptureState extends ConsumerState<FaceEnrollmentCapture>
    with SingleTickerProviderStateMixin {
  static const Duration _captureDelay = Duration(milliseconds: 500);

  final EnrollmentCaptureSession _session = EnrollmentCaptureSession();
  final StableFrameGate _gate = StableFrameGate(requiredFrames: 2);

  CameraController? _cameraController;
  ScannerState _scannerState = ScannerState.searching;
  String _statusText = 'Preparing camera...';
  String? _blockingError;
  String? _qualityFeedback;
  bool _isInitializing = true;
  bool _isProcessingCapture = false;
  bool _isCaptureScheduled = false;
  bool _hasSubmittedResult = false;
  bool _showCaptureFlash = false;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeCapture();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    final controller = _cameraController;
    _cameraController = null;
    controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeCapture() async {
    if (_isInitializing) {
      setState(() {
        _blockingError = null;
        _statusText = 'Preparing camera...';
      });
    } else {
      setState(() {
        _isInitializing = true;
        _blockingError = null;
        _statusText = 'Preparing camera...';
        _scannerState = ScannerState.searching;
      });
    }

    final action = await PermissionAccessDialog.show(
      context,
      config: PermissionAccessDialogConfig.biopayCamera(),
    );
    if (!mounted) return;
    if (action != PermissionAccessDialogAction.grantAccess) {
      setState(() {
        _isInitializing = false;
        _blockingError = 'Camera access is required to capture your face.';
      });
      return;
    }

    final permissionService = ref.read(appPermissionServiceProvider);
    final hasAccess = await permissionService.ensureBiopayCameraAccess();
    if (!mounted) return;
    if (!hasAccess) {
      setState(() {
        _isInitializing = false;
        _blockingError = 'Camera access is required to capture your face.';
      });
      return;
    }

    try {
      debugPrint('[BioPay Enrollment] Initializing face detection...');
      ref.read(faceDetectionProvider).initialize();
      debugPrint('[BioPay Enrollment] Initializing embedding service...');
      await ref.read(embeddingServiceProvider).initialize();
      debugPrint('[BioPay Enrollment] Services initialized.');

      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        throw StateError('No camera is available on this device.');
      }

      final selectedCamera =
          cameras
              .where(
                (camera) => camera.lensDirection == CameraLensDirection.front,
              )
              .firstOrNull ??
          cameras.first;

      final previousController = _cameraController;
      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      await previousController?.dispose();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      _cameraController = controller;
      _session.reset();
      _gate.reset();

      setState(() {
        _isInitializing = false;
        _blockingError = null;
        _scannerState = ScannerState.searching;
        _statusText = 'Center your face in the frame';
      });

      _scheduleNextCapture();
    } catch (error, stackTrace) {
      debugPrint('[BioPay Enrollment] Init error: $error');
      debugPrint('[BioPay Enrollment] Stack: $stackTrace');
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _blockingError = error.toString();
        _scannerState = ScannerState.error;
      });
    }
  }

  void _scheduleNextCapture() {
    if (_isCaptureScheduled ||
        _hasSubmittedResult ||
        _blockingError != null ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }

    _isCaptureScheduled = true;
    Future<void>.delayed(_captureDelay, () async {
      _isCaptureScheduled = false;
      if (!mounted ||
          _hasSubmittedResult ||
          _blockingError != null ||
          _cameraController == null ||
          !_cameraController!.value.isInitialized) {
        return;
      }

      await _captureSingleSample();
      if (!mounted || _hasSubmittedResult || _blockingError != null) {
        return;
      }
      _scheduleNextCapture();
    });
  }

  Future<void> _captureSingleSample() async {
    if (_isProcessingCapture || _hasSubmittedResult) return;

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    setState(() {
      _isProcessingCapture = true;
      _scannerState = ScannerState.searching;
      _qualityFeedback = null;
    });

    XFile? capture;
    try {
      capture = await controller.takePicture();
      final processed = await _processCapture(capture.path);
      if (!mounted || processed == null) {
        return;
      }

      // Stability gate: require 2 consecutive good frames before accepting
      final isStable = _gate.onFrame(
        isQualityAcceptable: true,
        trackingId: processed.trackingId,
      );
      if (!isStable) {
        if (!mounted) return;
        setState(() {
          _scannerState = ScannerState.searching;
          _statusText = 'Hold still...';
        });
        return;
      }

      _session.addSample(
        processed.embedding,
        qualityScore: processed.qualityScore,
      );
      await HapticFeedback.lightImpact();
      if (!mounted) return;

      // Brief green flash effect
      setState(() => _showCaptureFlash = true);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      setState(() => _showCaptureFlash = false);

      if (_session.isComplete) {
        _hasSubmittedResult = true;
        final aggregate = _session.buildAggregate();
        setState(() {
          _scannerState = ScannerState.captured;
          _statusText = 'Face captured successfully!';
        });
        await HapticFeedback.mediumImpact();
        widget.onCaptureReady(aggregate);
        return;
      }

      setState(() {
        _scannerState = ScannerState.locked;
        _statusText =
            'Sample ${_session.sampleCount} of ${_session.requiredSamples} captured';
      });
    } catch (error, stackTrace) {
      debugPrint('[BioPay Enrollment] Capture error: $error');
      debugPrint('[BioPay Enrollment] Stack: $stackTrace');
      if (!mounted) return;
      setState(() {
        _blockingError = 'Face capture failed. Please try again.';
        _scannerState = ScannerState.error;
      });
    } finally {
      _isProcessingCapture = false;
      if (capture != null) {
        try {
          await File(capture.path).delete();
        } catch (_) {
          // Ignore temp-file cleanup failures.
        }
      }
    }
  }

  Future<_ProcessedCapture?> _processCapture(String imagePath) async {
    debugPrint('[BioPay Enrollment] Processing capture: $imagePath');
    final faceDetection = ref.read(faceDetectionProvider);
    final faces = await faceDetection.detectFacesFromFilePath(imagePath);
    debugPrint('[BioPay Enrollment] Faces detected: ${faces.length}');

    if (faces.isEmpty) {
      _gate.reset();
      if (!mounted) return null;
      setState(() {
        _scannerState = ScannerState.searching;
        _statusText = 'Center your face in the frame';
        _qualityFeedback = 'No face detected';
      });
      return null;
    }

    if (faces.length > 1) {
      _gate.reset();
      if (!mounted) return null;
      setState(() {
        _scannerState = ScannerState.error;
        _statusText = BiopayStrings.qualityMultipleFaces;
        _qualityFeedback = BiopayStrings.qualityMultipleFaces;
      });
      return null;
    }

    final decodedImage = await _decodeImage(imagePath);
    final face = faces.first;
    final brightness = faceDetection.estimateBrightness(
      decodedImage.rgbaPixels,
      imageWidth: decodedImage.width,
      imageHeight: decodedImage.height,
      region: face.boundingBox,
    );

    final quality = faceDetection.checkQuality(
      face,
      ui.Size(decodedImage.width.toDouble(), decodedImage.height.toDouble()),
      meanBrightness: brightness,
    );
    if (!quality.isAcceptable) {
      _gate.reset();
      if (!mounted) return null;
      final feedbackMsg = _messageForQualityIssue(quality.issues.first);
      setState(() {
        _scannerState = ScannerState.error;
        _statusText = feedbackMsg;
        _qualityFeedback = feedbackMsg;
      });
      return null;
    }

    // Quality passed — clear any feedback
    if (mounted) {
      setState(() => _qualityFeedback = null);
    }

    final landmarks = FaceAlignmentService.extractLandmarks(face);
    if (landmarks == null) {
      _gate.reset();
      if (!mounted) return null;
      setState(() {
        _scannerState = ScannerState.error;
        _statusText = 'Keep your eyes and nose visible inside the frame.';
        _qualityFeedback = 'Keep your eyes and nose visible';
      });
      return null;
    }

    final transform = await FaceAlignmentService.computeAffineTransform(
      landmarks,
    );
    final alignedFace = await FaceAlignmentService.applyTransform(
      pixelData: decodedImage.rgbaPixels,
      transform: transform,
      srcWidth: decodedImage.width,
      srcHeight: decodedImage.height,
    );
    final embedding = ref
        .read(embeddingServiceProvider)
        .getEmbedding(alignedFace);

    return _ProcessedCapture(
      embedding: embedding,
      qualityScore: _computeQualityScore(quality),
      trackingId: face.trackingId,
    );
  }

  Future<_DecodedImage> _decodeImage(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.FrameInfo? frame;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      codec = await descriptor.instantiateCodec();
      frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) {
        throw StateError('Unable to decode captured image.');
      }
      // Deep-copy pixel data BEFORE disposing native resources.
      final width = frame.image.width;
      final height = frame.image.height;
      final pixels = Uint8List.fromList(byteData.buffer.asUint8List());
      return _DecodedImage(width: width, height: height, rgbaPixels: pixels);
    } finally {
      frame?.image.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  String _messageForQualityIssue(FaceQualityIssue issue) {
    return switch (issue) {
      FaceQualityIssue.faceTooSmall => BiopayStrings.qualityFaceTooSmall,
      FaceQualityIssue.yawTooHigh => BiopayStrings.qualityYawTooHigh,
      FaceQualityIssue.eyesClosed => BiopayStrings.qualityEyesClosed,
      FaceQualityIssue.multipleFaces => BiopayStrings.qualityMultipleFaces,
      FaceQualityIssue.lowLighting => BiopayStrings.qualityLowLight,
    };
  }

  IconData _iconForQualityIssue(String message) {
    if (message == BiopayStrings.qualityFaceTooSmall) {
      return LucideIcons.maximize;
    }
    if (message == BiopayStrings.qualityYawTooHigh) {
      return LucideIcons.moveHorizontal;
    }
    if (message == BiopayStrings.qualityEyesClosed) {
      return LucideIcons.eye;
    }
    if (message == BiopayStrings.qualityMultipleFaces) {
      return LucideIcons.users;
    }
    if (message == BiopayStrings.qualityLowLight) {
      return LucideIcons.sun;
    }
    return LucideIcons.alertCircle;
  }

  double _computeQualityScore(FaceQualityResult quality) {
    final sizeScore =
        ((quality.faceWidthRatio - FaceDetectionService.minFaceWidthRatio) /
                0.35)
            .clamp(0.0, 1.0);
    final yawScore =
        (1 - (quality.yawAngle.abs() / FaceDetectionService.maxYawAngle)).clamp(
          0.0,
          1.0,
        );
    final brightnessScore = quality.meanBrightness == null
        ? 1.0
        : ((quality.meanBrightness! - FaceDetectionService.minBrightness) / 0.5)
              .clamp(0.0, 1.0);

    return (sizeScore * 0.45) + (yawScore * 0.35) + (brightnessScore * 0.20);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;
    final previewReady =
        controller != null &&
        controller.value.isInitialized &&
        !_isInitializing;
    final previewAspectRatio = previewReady
        ? (1 / controller.value.aspectRatio)
        : (3 / 4);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 360;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─── Camera preview with overlay ───
        ClipRRect(
          borderRadius: widget.fullBleed
              ? BorderRadius.zero
              : BorderRadius.circular(AppTheme.radiusXl),
          child: Container(
            color: Colors.black,
            child: AspectRatio(
              aspectRatio: previewAspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Camera feed
                  if (previewReady) CameraPreview(controller),
                  if (!previewReady)
                    Center(
                      child: _isInitializing
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  color: cs.primary,
                                  strokeWidth: 2.5,
                                ),
                                const SizedBox(height: AppTheme.space4),
                                Text(
                                  'Initializing camera...',
                                  style: tt.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            )
                          : Icon(
                              LucideIcons.cameraOff,
                              size: 48,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                    ),

                  // Animated segmented progress oval
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: OvalPainter(
                          state: _scannerState,
                          progress: _pulseController.value,
                          samplesCaptured: _session.sampleCount,
                          totalSamples: _session.requiredSamples,
                        ),
                        child: const SizedBox.expand(),
                      );
                    },
                  ),

                  // Green flash on capture
                  if (_showCaptureFlash)
                    Container(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                    ),

                  // ─── Status chip (top) ───
                  Positioned(
                    top: AppTheme.space3,
                    left: AppTheme.space3,
                    right: AppTheme.space3,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _StatusChip(
                          key: ValueKey('status_${_scannerState.name}_${_session.sampleCount}'),
                          state: _scannerState,
                          text: _statusText,
                          isCompact: isCompact,
                        ),
                      ),
                    ),
                  ),

                  // ─── Quality feedback overlay (bottom of camera) ───
                  if (_qualityFeedback != null)
                    Positioned(
                      bottom: AppTheme.space4,
                      left: AppTheme.space4,
                      right: AppTheme.space4,
                      child: _QualityFeedbackBanner(
                        message: _qualityFeedback!,
                        icon: _iconForQualityIssue(_qualityFeedback!),
                      ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.3),
                    ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: AppTheme.space5),

        // ─── Sample capture dots ───
        Padding(
          padding: widget.fullBleed
              ? const EdgeInsets.symmetric(horizontal: AppTheme.space6)
              : EdgeInsets.zero,
          child: _SampleDots(
            captured: _session.sampleCount,
            total: _session.requiredSamples,
            isProcessing: _isProcessingCapture,
          ),
        ),

        const SizedBox(height: AppTheme.space3),

        // ─── Privacy badge ───
        Padding(
          padding: widget.fullBleed
              ? const EdgeInsets.symmetric(horizontal: AppTheme.space6)
              : EdgeInsets.zero,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.lock,
                size: 12,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 6),
              Text(
                'No photos saved — processed in memory only',
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),

        // ─── Error retry ───
        if (_blockingError != null) ...[
          const SizedBox(height: AppTheme.space4),
          Padding(
            padding: widget.fullBleed
                ? const EdgeInsets.symmetric(horizontal: AppTheme.space6)
                : EdgeInsets.zero,
            child: Column(
              children: [
                Text(
                  _blockingError!,
                  style: tt.bodyMedium?.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.space4),
                PremiumButton(
                  label: 'TRY AGAIN',
                  icon: LucideIcons.refreshCw,
                  onPressed: _initializeCapture,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Status Chip ───────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final ScannerState state;
  final String text;
  final bool isCompact;

  const _StatusChip({
    super.key,
    required this.state,
    required this.text,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final (Color bgColor, Color fgColor, IconData icon) = switch (state) {
      ScannerState.searching => (
        Colors.white.withValues(alpha: 0.12),
        Colors.white.withValues(alpha: 0.85),
        LucideIcons.scanFace,
      ),
      ScannerState.locked => (
        AppColors.secondary.withValues(alpha: 0.20),
        AppColors.secondary,
        LucideIcons.lock,
      ),
      ScannerState.captured => (
        AppColors.secondary.withValues(alpha: 0.25),
        AppColors.secondary,
        LucideIcons.checkCircle2,
      ),
      ScannerState.error => (
        AppColors.error.withValues(alpha: 0.20),
        AppColors.error,
        LucideIcons.alertCircle,
      ),
      ScannerState.noMatch => (
        AppColors.error.withValues(alpha: 0.20),
        AppColors.error,
        LucideIcons.xCircle,
      ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? AppTheme.space3 : AppTheme.space4,
        vertical: AppTheme.space2,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(
          color: fgColor.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fgColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: fgColor,
                fontSize: isCompact ? 11 : 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quality Feedback Banner ────────────────────────────────

class _QualityFeedbackBanner extends StatelessWidget {
  final String message;
  final IconData icon;

  const _QualityFeedbackBanner({
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space4,
        vertical: AppTheme.space3,
      ),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sample Capture Dots ──────────────────────────────────

class _SampleDots extends StatelessWidget {
  final int captured;
  final int total;
  final bool isProcessing;

  const _SampleDots({
    required this.captured,
    required this.total,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(total, (index) {
            final isCaptured = index < captured;
            final isCurrent = index == captured;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: isCaptured ? 28 : (isCurrent ? 24 : 20),
                height: isCaptured ? 28 : (isCurrent ? 24 : 20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCaptured
                      ? AppColors.secondary.withValues(alpha: 0.20)
                      : isCurrent
                          ? AppColors.warning.withValues(alpha: 0.12)
                          : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: Border.all(
                    color: isCaptured
                        ? AppColors.secondary
                        : isCurrent
                            ? AppColors.warning.withValues(alpha: 0.6)
                            : cs.onSurfaceVariant.withValues(alpha: 0.15),
                    width: isCaptured ? 2 : 1.5,
                  ),
                ),
                child: isCaptured
                    ? Icon(
                        LucideIcons.check,
                        size: 14,
                        color: AppColors.secondary,
                      )
                    : isCurrent && isProcessing
                        ? SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppColors.warning,
                            ),
                          )
                        : null,
              ),
            );
          }),
        ),
        const SizedBox(height: AppTheme.space2),
        Text(
          captured == total
              ? 'All samples captured!'
              : '$captured of $total samples',
          style: tt.bodySmall?.copyWith(
            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ─── Private data classes ──────────────────────────────────

class _DecodedImage {
  const _DecodedImage({
    required this.width,
    required this.height,
    required this.rgbaPixels,
  });

  final int width;
  final int height;
  final Uint8List rgbaPixels;
}

class _ProcessedCapture {
  const _ProcessedCapture({
    required this.embedding,
    required this.qualityScore,
    this.trackingId,
  });

  final List<double> embedding;
  final double qualityScore;
  final int? trackingId;
}
