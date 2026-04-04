import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/providers/permission_providers.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';
import '../biopay_providers.dart';
import '../biopay_strings.dart';
import '../models/biopay_models.dart';
import '../services/face_alignment_service.dart';
import '../services/face_detection_service.dart';
import '../services/stable_frame_gate.dart';
import '../widgets/oval_painter.dart';

/// Full-screen face scanner for BioPay payment matching.
///
/// Flow: camera preview → face detection → quality gate → stable lock (3 frames)
///       → align → embedding → cache check → API match → confirm screen.
class BiopayScannerScreen extends ConsumerStatefulWidget {
  const BiopayScannerScreen({super.key});

  @override
  ConsumerState<BiopayScannerScreen> createState() =>
      _BiopayScannerScreenState();
}

class _BiopayScannerScreenState extends ConsumerState<BiopayScannerScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _captureDelay = Duration(milliseconds: 400);

  CameraController? _cameraController;
  final StableFrameGate _gate = StableFrameGate.scan();
  ScannerState _scannerState = ScannerState.searching;
  String _statusMessage = BiopayStrings.scanSearching;
  String? _blockingError;
  bool _isInitializing = true;
  bool _isProcessing = false;
  bool _hasNavigated = false;
  bool _isSoftFlashActive = false; // Screen illumination for low-light
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeCamera();
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

  Future<void> _initializeCamera() async {
    setState(() {
      _isInitializing = true;
      _blockingError = null;
      _statusMessage = 'Preparing camera...';
      _scannerState = ScannerState.searching;
    });

    final action = await PermissionAccessDialog.show(
      context,
      config: PermissionAccessDialogConfig.biopayCamera(),
    );
    if (!mounted) return;
    if (action != PermissionAccessDialogAction.grantAccess) {
      setState(() {
        _isInitializing = false;
        _blockingError = 'Camera access is required to scan faces.';
      });
      return;
    }

    final permissionService = ref.read(appPermissionServiceProvider);
    final hasAccess = await permissionService.ensureBiopayCameraAccess();
    if (!mounted) return;
    if (!hasAccess) {
      setState(() {
        _isInitializing = false;
        _blockingError = 'Camera access is required to scan faces.';
      });
      return;
    }

    try {
      // Initialize services (idempotent — pre-warmed on home screen)
      debugPrint('[BioPay Scanner] Initializing face detection...');
      ref.read(faceDetectionProvider).initialize();
      debugPrint('[BioPay Scanner] Initializing embedding service...');
      await ref.read(embeddingServiceProvider).initialize();
      debugPrint('[BioPay Scanner] Loading match cache...');
      await ref.read(matchCacheProvider).loadFromDisk();
      debugPrint('[BioPay Scanner] Services initialized.');

      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        throw StateError('No camera available on this device.');
      }

      final frontCamera =
          cameras
              .where((c) => c.lensDirection == CameraLensDirection.front)
              .firstOrNull ??
          cameras.first;

      final previousController = _cameraController;
      final controller = CameraController(
        frontCamera,
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
      _gate.reset();

      setState(() {
        _isInitializing = false;
        _blockingError = null;
        _scannerState = ScannerState.searching;
        _statusMessage = BiopayStrings.scanSearching;
      });

      _scheduleScanFrame();
    } catch (error, stackTrace) {
      debugPrint('[BioPay Scanner] Init error: $error');
      debugPrint('[BioPay Scanner] Stack: $stackTrace');
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _blockingError = error.toString();
        _scannerState = ScannerState.error;
      });
    }
  }

  void _scheduleScanFrame() {
    if (_hasNavigated || _isProcessing || _blockingError != null) return;
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    Future<void>.delayed(_captureDelay, () async {
      if (!mounted || _hasNavigated || _blockingError != null) return;
      await _processSingleFrame();
      if (!mounted || _hasNavigated || _blockingError != null) return;
      _scheduleScanFrame();
    });
  }

  Future<void> _processSingleFrame() async {
    if (_isProcessing || _hasNavigated) return;
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    _isProcessing = true;
    XFile? capture;

    try {
      debugPrint('[BioPay Scanner] Taking picture...');
      capture = await controller.takePicture();
      debugPrint('[BioPay Scanner] Detecting faces from file...');
      final faceDetection = ref.read(faceDetectionProvider);
      final faces = await faceDetection.detectFacesFromFilePath(capture.path);
      debugPrint('[BioPay Scanner] Faces found: ${faces.length}');

      if (!mounted) return;

      if (faces.isEmpty) {
        _gate.reset();
        setState(() {
          _scannerState = ScannerState.searching;
          _statusMessage = BiopayStrings.scanSearching;
        });
        return;
      }

      if (faces.length > 1) {
        _gate.reset();
        setState(() {
          _scannerState = ScannerState.error;
          _statusMessage = BiopayStrings.qualityMultipleFaces;
        });
        return;
      }

      final face = faces.first;

      // Decode image for quality + alignment
      final decoded = await _decodeImage(capture.path);
      if (!mounted) return;

      final brightness = faceDetection.estimateBrightness(
        decoded.rgbaPixels,
        imageWidth: decoded.width,
        imageHeight: decoded.height,
        region: face.boundingBox,
      );

      final quality = faceDetection.checkQuality(
        face,
        ui.Size(decoded.width.toDouble(), decoded.height.toDouble()),
        meanBrightness: brightness,
      );

      // Feed quality into stable gate
      final isStable = _gate.onFrame(
        isQualityAcceptable: quality.isAcceptable,
        trackingId: face.trackingId,
      );

      if (!quality.isAcceptable) {
        final hasLowLight = quality.issues.contains(FaceQualityIssue.lowLighting);
        if (hasLowLight && !_isSoftFlashActive) {
          // Trigger screen illumination to act as a soft-flash
          setState(() {
            _isSoftFlashActive = true;
          });
        }

        setState(() {
          _scannerState = ScannerState.searching;
          _statusMessage = _messageForQualityIssue(quality.issues.first);
        });
        return;
      }

      if (!isStable) {
        setState(() {
          _scannerState = ScannerState.locked;
          _statusMessage = BiopayStrings.scanLocked;
        });
        return;
      }

      // 3 stable frames → extract embedding and match
      setState(() {
        _scannerState = ScannerState.locked;
        _statusMessage = 'Matching face...';
      });

      final landmarks = FaceAlignmentService.extractLandmarks(face);
      if (landmarks == null) {
        _gate.reset();
        setState(() {
          _scannerState = ScannerState.searching;
          _statusMessage = 'Keep your eyes and nose visible.';
        });
        return;
      }

      final transform = await FaceAlignmentService.computeAffineTransform(
        landmarks,
      );
      final alignedFace = await FaceAlignmentService.applyTransform(
        pixelData: decoded.rgbaPixels,
        transform: transform,
        srcWidth: decoded.width,
        srcHeight: decoded.height,
      );

      final embedding = ref
          .read(embeddingServiceProvider)
          .getEmbedding(alignedFace);

      await HapticFeedback.mediumImpact();

      // 1) Check local cache first
      final cache = ref.read(matchCacheProvider);
      final cached = cache.findMatch(embedding);

      MatchResult result;
      if (cached != null) {
        result = MatchResult(
          isMatch: true,
          displayName: cached.displayName,
          ussdString: cached.ussdString,
          biopayId: cached.biopayId,
          score: cached.similarity,
          isCached: true,
        );
      } else {
        // 2) API call via repository (handles cache + session sync)
        final installId = await ref.read(installIdProvider.future);
        final repo = ref.read(biopayRepositoryProvider);
        result = await repo.matchFace(
          embedding: embedding,
          clientInstallId: installId,
        );
      }

      if (!mounted) return;

      if (result.isMatch) {
        _hasNavigated = true;
        setState(() {
          _scannerState = ScannerState.captured;
        });
        await context.pushNamed(AppRouteNames.biopayConfirm, extra: result);
        if (!mounted) return;
        _handleRetry();
      } else {
        _gate.reset();
        setState(() {
          _scannerState = ScannerState.noMatch;
          _statusMessage = BiopayStrings.scanNoMatch;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[BioPay Scanner] Error: $e');
      debugPrint('[BioPay Scanner] Stack: $stackTrace');
      if (!mounted) return;
      _gate.reset();
      setState(() {
        _scannerState = ScannerState.error;
        _statusMessage = BiopayStrings.scanError;
      });
    } finally {
      _isProcessing = false;
      if (capture != null) {
        try {
          await File(capture.path).delete();
        } catch (_) {}
      }
    }
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

  void _handleRetry() {
    _hasNavigated = false;
    _gate.reset();
    setState(() {
      _scannerState = ScannerState.searching;
      _statusMessage = BiopayStrings.scanSearching;
      _blockingError = null;
      _isSoftFlashActive = false;
    });
    if (_cameraController?.value.isInitialized == true) {
      _scheduleScanFrame();
    } else {
      _initializeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final controller = _cameraController;
    final previewReady =
        controller != null &&
        controller.value.isInitialized &&
        !_isInitializing;

    return Scaffold(
      backgroundColor: _isSoftFlashActive ? Colors.white : Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview or placeholder
          if (previewReady)
            CameraPreview(controller)
          else
            Container(
              color: cs.surface.withValues(alpha: 0.05),
              child: Center(
                child: _isInitializing
                    ? CircularProgressIndicator(color: cs.primary)
                    : Icon(
                        LucideIcons.cameraOff,
                        size: 80,
                        color: cs.onSurface.withValues(alpha: 0.1),
                      ),
              ),
            ),

          // Scanner overlay
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) => CustomPaint(
              painter: OvalPainter(
                state: _scannerState,
                progress: _pulseController.value,
                totalSamples: 0, // scan mode — simple border, no segments
              ),
            ),
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.x, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                    const Spacer(),
                    Text(
                      'BioPay Scanner',
                      style: tt.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),

          // Bottom status & controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(AppTheme.space6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isProcessing && _scannerState == ScannerState.locked)
                      const Padding(
                        padding: EdgeInsets.only(bottom: AppTheme.space4),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    Text(
                      _blockingError ?? _statusMessage,
                      style: tt.bodyLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_scannerState == ScannerState.noMatch ||
                        _scannerState == ScannerState.error ||
                        _blockingError != null) ...[
                      const SizedBox(height: AppTheme.space4),
                      PremiumButton(
                        label: 'RETRY SCAN',
                        onPressed: _handleRetry,
                        isSmall: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
