import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class FaceEnrollmentCapture extends ConsumerStatefulWidget {
  const FaceEnrollmentCapture({super.key, required this.onCaptureReady});

  final EnrollmentCaptureReady onCaptureReady;

  @override
  ConsumerState<FaceEnrollmentCapture> createState() =>
      _FaceEnrollmentCaptureState();
}

class _FaceEnrollmentCaptureState extends ConsumerState<FaceEnrollmentCapture> {
  static const Duration _captureDelay = Duration(milliseconds: 500);

  final EnrollmentCaptureSession _session = EnrollmentCaptureSession();
  final StableFrameGate _gate = StableFrameGate(requiredFrames: 2);

  CameraController? _cameraController;
  ScannerState _scannerState = ScannerState.searching;
  String _statusText = 'Preparing camera...';
  String? _blockingError;
  bool _isInitializing = true;
  bool _isProcessingCapture = false;
  bool _isCaptureScheduled = false;
  bool _hasSubmittedResult = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeCapture();
    });
  }

  @override
  void dispose() {
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
        _statusText = 'Hold still. We need 5 face samples.';
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
      _statusText =
          'Capturing sample ${_session.sampleCount + 1} of ${_session.requiredSamples}...';
    });

    XFile? capture;
    try {
      capture = await controller.takePicture();
      final processed = await _processCapture(capture.path);
      if (!mounted || processed == null) {
        // Quality failed or no face — gate was already reset inside _processCapture
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

      if (_session.isComplete) {
        _hasSubmittedResult = true;
        final aggregate = _session.buildAggregate();
        setState(() {
          _scannerState = ScannerState.captured;
          _statusText = 'Face capture complete. Finalizing enrollment...';
        });
        widget.onCaptureReady(aggregate);
        return;
      }

      setState(() {
        _scannerState = ScannerState.locked;
        _statusText =
            'Captured ${_session.sampleCount} of ${_session.requiredSamples} samples';
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
        _statusText = 'No face found. Center your face in the frame.';
      });
      return null;
    }

    if (faces.length > 1) {
      _gate.reset();
      if (!mounted) return null;
      setState(() {
        _scannerState = ScannerState.error;
        _statusText = BiopayStrings.qualityMultipleFaces;
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
      setState(() {
        _scannerState = ScannerState.error;
        _statusText = _messageForQualityIssue(quality.issues.first);
      });
      return null;
    }

    final landmarks = FaceAlignmentService.extractLandmarks(face);
    if (landmarks == null) {
      _gate.reset();
      if (!mounted) return null;
      setState(() {
        _scannerState = ScannerState.error;
        _statusText = 'Keep your eyes and nose visible inside the frame.';
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: Container(
            color: Colors.black,
            child: AspectRatio(
              aspectRatio: previewAspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (previewReady) CameraPreview(controller),
                  if (!previewReady)
                    Center(
                      child: _isInitializing
                          ? CircularProgressIndicator(color: cs.primary)
                          : Icon(
                              LucideIcons.cameraOff,
                              size: 48,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                    ),
                  CustomPaint(
                    painter: OvalPainter(
                      state: _scannerState,
                      progress: _isProcessingCapture ? 1.0 : 0.88,
                    ),
                    child: const SizedBox.expand(),
                  ),
                  Positioned(
                    top: AppTheme.space4,
                    right: AppTheme.space4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space3,
                        vertical: AppTheme.space2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.48),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusFull,
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Text(
                        '${_session.sampleCount}/${_session.requiredSamples}',
                        style: tt.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.space4),
        LinearProgressIndicator(
          value: _session.progress,
          minHeight: 6,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          color: AppColors.secondary,
          backgroundColor: cs.surfaceContainerHighest,
        ),
        const SizedBox(height: AppTheme.space3),
        Text(
          _blockingError ?? _statusText,
          style: tt.bodyMedium?.copyWith(
            color: _blockingError == null
                ? cs.onSurfaceVariant
                : AppColors.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.space2),
        Text(
          'No photos are saved. Samples are processed in memory only.',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        if (_blockingError != null) ...[
          const SizedBox(height: AppTheme.space5),
          PremiumButton(label: 'TRY AGAIN', onPressed: _initializeCapture),
        ],
      ],
    );
  }
}

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
