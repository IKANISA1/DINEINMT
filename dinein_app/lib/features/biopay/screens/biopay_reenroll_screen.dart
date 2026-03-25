import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../biopay_providers.dart';
import '../models/biopay_models.dart';
import '../services/enrollment_capture_session.dart';
import '../widgets/face_enrollment_capture.dart';

class BiopayReEnrollScreen extends ConsumerStatefulWidget {
  const BiopayReEnrollScreen({super.key});

  @override
  ConsumerState<BiopayReEnrollScreen> createState() =>
      _BiopayReEnrollScreenState();
}

class _BiopayReEnrollScreenState extends ConsumerState<BiopayReEnrollScreen> {
  bool _isSubmitting = false;
  EnrollmentResult? _result;

  Future<void> _handleCaptureReady(EnrollmentCaptureAggregate aggregate) async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _result = null;
    });

    try {
      final installId = await ref.read(installIdProvider.future);
      final result = await ref
          .read(biopayRepositoryProvider)
          .reEnrollFace(
            embedding: aggregate.embedding,
            qualityScore: aggregate.qualityScore,
            clientInstallId: installId,
          );
      await ref.read(localBiopayAuthProvider.notifier).refresh();

      if (!mounted) return;
      setState(() {
        _result = result;
        _isSubmitting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _result = EnrollmentResult.failure(error.toString());
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final success = _result?.success ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Re-Enroll Face')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Capture a fresh face scan to replace your current BioPay biometric profile.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppTheme.space6),
            if (_result == null && !_isSubmitting)
              FaceEnrollmentCapture(onCaptureReady: _handleCaptureReady),
            if (_isSubmitting)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.space10,
                  ),
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: cs.primary),
                      const SizedBox(height: AppTheme.space4),
                      Text(
                        'Replacing your face data...',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_result != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.space6),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                  border: Border.all(color: AppColors.white5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          success
                              ? LucideIcons.checkCircle2
                              : LucideIcons.xCircle,
                          color: success
                              ? AppColors.secondary
                              : AppColors.error,
                        ),
                        const SizedBox(width: AppTheme.space3),
                        Text(
                          success
                              ? 'Face re-enrollment complete'
                              : 'Re-enrollment failed',
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.space4),
                    Text(
                      success
                          ? 'Your old face template has been replaced and your device session has been refreshed.'
                          : (_result?.error ?? 'An unknown error occurred.'),
                      style: tt.bodyMedium?.copyWith(
                        color: success ? cs.onSurfaceVariant : AppColors.error,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space6),
                    SizedBox(
                      width: double.infinity,
                      child: PremiumButton(
                        label: success ? 'BACK TO PROFILE' : 'TRY AGAIN',
                        icon: success
                            ? LucideIcons.arrowLeft
                            : LucideIcons.refreshCw,
                        onPressed: () {
                          if (success) {
                            context.goNamed(AppRouteNames.biopayManage);
                            return;
                          }
                          setState(() => _result = null);
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
