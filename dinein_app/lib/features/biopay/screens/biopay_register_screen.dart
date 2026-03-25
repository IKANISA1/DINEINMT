import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../biopay_providers.dart';
import '../biopay_strings.dart';
import '../models/biopay_models.dart';
import '../services/enrollment_capture_session.dart';
import '../widgets/face_enrollment_capture.dart';

/// BioPay enrollment screen — multi-step flow.
///
/// Steps: 1) Consent → 2) USSD string → 3) Display name → 4) Face capture → 5) Submit
class BiopayRegisterScreen extends ConsumerStatefulWidget {
  const BiopayRegisterScreen({super.key});

  @override
  ConsumerState<BiopayRegisterScreen> createState() =>
      _BiopayRegisterScreenState();
}

class _BiopayRegisterScreenState extends ConsumerState<BiopayRegisterScreen> {
  int _step = 0;
  bool _consentAccepted = false;
  final _ussdController = TextEditingController();
  final _nameController = TextEditingController();
  List<double>? _capturedEmbedding;
  double? _captureQualityScore;
  bool _isSubmitting = false;
  EnrollmentResult? _result;

  static const _totalSteps = 5;

  @override
  void dispose() {
    _ussdController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _step < _totalSteps - 1
              ? 'Register — Step ${_step + 1}'
              : 'Registration Complete',
        ),
        leading: _step > 0 && _result == null
            ? IconButton(
                icon: const Icon(LucideIcons.arrowLeft),
                onPressed: () => setState(() => _step--),
              )
            : null,
      ),
      body: AnimatedSwitcher(duration: 250.ms, child: _buildStep(cs, tt)),
    );
  }

  Widget _buildStep(ColorScheme cs, TextTheme tt) {
    return switch (_step) {
      0 => _buildConsent(cs, tt),
      1 => _buildUssd(cs, tt),
      2 => _buildName(cs, tt),
      3 => _buildFaceCapture(cs, tt),
      4 => _buildResult(cs, tt),
      _ => const SizedBox.shrink(),
    };
  }

  // ─── Step 0: Consent ──────────────────────────────────────

  Widget _buildConsent(ColorScheme cs, TextTheme tt) {
    return _StepContainer(
      key: const ValueKey('consent'),
      icon: LucideIcons.shieldCheck,
      iconColor: cs.primary,
      title: 'Privacy Consent',
      children: [
        Text(
          BiopayStrings.registerConsent,
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: AppTheme.space4),
        Container(
          padding: const EdgeInsets.all(AppTheme.space4),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppColors.white5),
          ),
          child: Text(
            BiopayStrings.registerConsentKw,
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.space6),
        Row(
          children: [
            Checkbox(
              value: _consentAccepted,
              onChanged: (v) => setState(() => _consentAccepted = v ?? false),
              activeColor: cs.primary,
            ),
            Expanded(
              child: GestureDetector(
                onTap: () =>
                    setState(() => _consentAccepted = !_consentAccepted),
                child: Text(
                  'I agree to the privacy terms above',
                  style: tt.bodyMedium,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space6),
        PremiumButton(
          label: 'CONTINUE',
          onPressed: _consentAccepted ? () => setState(() => _step = 1) : null,
        ),
      ],
    );
  }

  // ─── Step 1: USSD string ──────────────────────────────────

  Widget _buildUssd(ColorScheme cs, TextTheme tt) {
    return _StepContainer(
      key: const ValueKey('ussd'),
      icon: LucideIcons.phone,
      iconColor: AppColors.warning,
      title: 'Payment String',
      children: [
        Text(
          'Enter your Rwanda MoMo USSD payment string. '
          'This is the code someone would dial to pay you.',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: AppTheme.space6),
        TextField(
          controller: _ussdController,
          onChanged: (_) => setState(() {}),
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'USSD String',
            hintText: '*182*1*1*0788123456#',
            prefixIcon: const Icon(LucideIcons.hash),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.space6),
        PremiumButton(
          label: 'CONTINUE',
          onPressed: _ussdController.text.trim().isNotEmpty
              ? () => setState(() => _step = 2)
              : null,
        ),
      ],
    );
  }

  // ─── Step 2: Display name ─────────────────────────────────

  Widget _buildName(ColorScheme cs, TextTheme tt) {
    return _StepContainer(
      key: const ValueKey('name'),
      icon: LucideIcons.user,
      iconColor: AppColors.secondary,
      title: 'Display Name',
      children: [
        Text(
          'Choose a name that will be shown to the payer when they scan your face. '
          'This helps them verify they\'re paying the right person.',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: AppTheme.space6),
        TextField(
          controller: _nameController,
          onChanged: (_) => setState(() {}),
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Display Name',
            hintText: 'e.g., Jean Baptiste',
            prefixIcon: const Icon(LucideIcons.userCircle),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.space6),
        PremiumButton(
          label: 'CAPTURE FACE',
          onPressed: _nameController.text.trim().isNotEmpty
              ? () => _startFaceCapture()
              : null,
        ),
      ],
    );
  }

  // ─── Step 3: Face capture ─────────────────────────────────

  void _startFaceCapture() {
    setState(() {
      _capturedEmbedding = null;
      _captureQualityScore = null;
      _step = 3;
    });
  }

  Future<void> _handleCaptureReady(EnrollmentCaptureAggregate aggregate) async {
    if (_capturedEmbedding != null || _isSubmitting) return;

    setState(() {
      _capturedEmbedding = aggregate.embedding;
      _captureQualityScore = aggregate.qualityScore;
    });

    await _submitEnrollment();
  }

  Widget _buildFaceCapture(ColorScheme cs, TextTheme tt) {
    return _StepContainer(
      key: const ValueKey('face'),
      icon: LucideIcons.scanFace,
      iconColor: cs.primary,
      title: 'Capturing Face...',
      children: [
        Text(
          'Use the front camera and keep your face centered until all 5 samples are captured.',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: AppTheme.space6),
        if (_capturedEmbedding == null && !_isSubmitting) ...[
          FaceEnrollmentCapture(onCaptureReady: _handleCaptureReady),
          const SizedBox(height: AppTheme.space6),
        ] else if (_isSubmitting) ...[
          const SizedBox(height: AppTheme.space8),
          Center(
            child: Column(
              children: [
                CircularProgressIndicator(color: cs.primary),
                const SizedBox(height: AppTheme.space4),
                Text(
                  'Submitting registration...',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ─── Submit enrollment ────────────────────────────────────

  Future<void> _submitEnrollment() async {
    if (_capturedEmbedding == null) return;

    setState(() => _isSubmitting = true);

    try {
      final repository = ref.read(biopayRepositoryProvider);
      final installId = await ref.read(installIdProvider.future);

      final result = await repository.enrollFace(
        displayName: _nameController.text.trim(),
        ussdString: _ussdController.text.trim(),
        embedding: _capturedEmbedding!,
        qualityScore: _captureQualityScore ?? 0.0,
        clientInstallId: installId,
      );
      await ref.read(localBiopayAuthProvider.notifier).refresh();

      if (!mounted) return;
      setState(() {
        _result = result;
        _step = 4;
        _isSubmitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = EnrollmentResult.failure(e.toString());
        _step = 4;
        _isSubmitting = false;
      });
    }
  }

  // ─── Step 4: Result ───────────────────────────────────────

  Widget _buildResult(ColorScheme cs, TextTheme tt) {
    final success = _result?.success ?? false;

    return _StepContainer(
      key: const ValueKey('result'),
      icon: success ? LucideIcons.checkCircle : LucideIcons.xCircle,
      iconColor: success ? AppColors.secondary : AppColors.error,
      title: success ? 'Registration Complete!' : 'Registration Failed',
      children: [
        if (success && _result != null) ...[
          _InfoRow(label: 'BioPay ID', value: _result!.biopayId ?? '—'),
          const SizedBox(height: AppTheme.space3),
          _InfoRow(label: 'Display Name', value: _result!.displayName ?? '—'),
          if (_result!.managementCode != null) ...[
            const SizedBox(height: AppTheme.space6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.space5),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.key, size: 16, color: AppColors.warning),
                      const SizedBox(width: AppTheme.space2),
                      Text(
                        BiopayStrings.managementCodeTitle,
                        style: tt.titleSmall?.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space2),
                  SelectableText(
                    _result!.managementCode!,
                    style: tt.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: AppTheme.space2),
                  Text(
                    BiopayStrings.managementCodeBody,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ] else ...[
          Text(
            _result?.error ?? 'An unknown error occurred.',
            style: tt.bodyMedium?.copyWith(color: AppColors.error),
          ),
        ],
        const SizedBox(height: AppTheme.space8),
        PremiumButton(
          label: success ? 'DONE' : 'TRY AGAIN',
          onPressed: () {
            if (success) {
              context.goNamed(AppRouteNames.biopayHome);
            } else {
              setState(() {
                _step = 0;
                _result = null;
                _capturedEmbedding = null;
                _captureQualityScore = null;
                _consentAccepted = false;
              });
            }
          },
        ),
      ],
    );
  }
}

// ─── Reusable step layout ───────────────────────────────────

class _StepContainer extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<Widget> children;

  const _StepContainer({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: AppTheme.space5),
          Text(
            title,
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppTheme.space5),
          ...children,
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.02);
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        Text(label, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        const Spacer(),
        Text(
          value,
          style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
