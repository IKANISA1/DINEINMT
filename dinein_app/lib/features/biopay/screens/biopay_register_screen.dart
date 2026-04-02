import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// BioPay enrollment screen — multi-step flow with premium UI.
///
/// Steps: 1) Consent → 2) USSD string → 3) Display name → 4) Face capture → 5) Result
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

  static const _stepLabels = [
    'Consent',
    'Payment',
    'Name',
    'Face',
    'Done',
  ];

  static const _stepIcons = [
    LucideIcons.shieldCheck,
    LucideIcons.phone,
    LucideIcons.user,
    LucideIcons.scanFace,
    LucideIcons.checkCircle2,
  ];

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
    final isFaceCaptureStep = _step == 3;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _step < _totalSteps - 1
              ? 'Register Your Face'
              : 'Registration Complete',
        ),
        leading: _step > 0 && _result == null
            ? IconButton(
                icon: const Icon(LucideIcons.arrowLeft),
                onPressed: () => setState(() => _step--),
              )
            : null,
      ),
      body: Column(
        children: [
          // ─── Step progress indicator ───
          if (_step < _totalSteps - 1 || _result == null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space6,
                vertical: AppTheme.space3,
              ),
              child: _StepProgressBar(
                currentStep: _step,
                totalSteps: _totalSteps,
                labels: _stepLabels,
                icons: _stepIcons,
              ),
            ),

          // ─── Step content ───
          Expanded(
            child: AnimatedSwitcher(
              duration: 250.ms,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.03, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: isFaceCaptureStep
                  ? _buildFaceCapture(cs, tt)
                  : _buildStep(cs, tt),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(ColorScheme cs, TextTheme tt) {
    return switch (_step) {
      0 => _buildConsent(cs, tt),
      1 => _buildUssd(cs, tt),
      2 => _buildName(cs, tt),
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
        GestureDetector(
          onTap: () => setState(() => _consentAccepted = !_consentAccepted),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.space4),
            decoration: BoxDecoration(
              color: _consentAccepted
                  ? AppColors.secondary.withValues(alpha: 0.08)
                  : cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: _consentAccepted
                    ? AppColors.secondary.withValues(alpha: 0.3)
                    : AppColors.white5,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _consentAccepted
                        ? AppColors.secondary
                        : Colors.transparent,
                    border: Border.all(
                      color: _consentAccepted
                          ? AppColors.secondary
                          : cs.onSurfaceVariant.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: _consentAccepted
                      ? const Icon(
                          LucideIcons.check,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: AppTheme.space3),
                Expanded(
                  child: Text(
                    'I agree to the privacy terms above',
                    style: tt.bodyMedium?.copyWith(
                      fontWeight:
                          _consentAccepted ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTheme.space6),
        PremiumButton(
          label: 'CONTINUE',
          icon: LucideIcons.arrowRight,
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
          icon: LucideIcons.arrowRight,
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
          icon: LucideIcons.scanFace,
          onPressed: _nameController.text.trim().isNotEmpty
              ? () => _startFaceCapture()
              : null,
        ),
      ],
    );
  }

  // ─── Step 3: Face capture (full-bleed) ────────────────────

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
    return Column(
      key: const ValueKey('face_capture'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_capturedEmbedding == null && !_isSubmitting)
          Expanded(
            child: FaceEnrollmentCapture(
              onCaptureReady: _handleCaptureReady,
              fullBleed: true,
            ),
          )
        else if (_isSubmitting)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      color: cs.primary,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space6),
                  Text(
                    'Finalizing registration...',
                    style: tt.titleMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space2),
                  Text(
                    'This usually takes a few seconds',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
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

    return SingleChildScrollView(
      key: const ValueKey('result'),
      padding: const EdgeInsets.all(AppTheme.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: AppTheme.space4),

          // Animated result icon
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: success
                  ? AppColors.secondary.withValues(alpha: 0.12)
                  : AppColors.error.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              success ? LucideIcons.checkCircle2 : LucideIcons.xCircle,
              size: 40,
              color: success ? AppColors.secondary : AppColors.error,
            ),
          )
              .animate()
              .scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1.0, 1.0),
                duration: 400.ms,
                curve: Curves.elasticOut,
              )
              .fadeIn(duration: 200.ms),

          const SizedBox(height: AppTheme.space6),

          Text(
            success ? 'You\'re all set!' : 'Registration Failed',
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 150.ms, duration: 300.ms),

          const SizedBox(height: AppTheme.space2),

          Text(
            success
                ? 'Your BioPay profile has been created successfully.'
                : (_result?.error ?? 'An unknown error occurred.'),
            style: tt.bodyMedium?.copyWith(
              color: success ? cs.onSurfaceVariant : AppColors.error,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 250.ms, duration: 300.ms),

          if (success && _result != null) ...[
            const SizedBox(height: AppTheme.space8),

            // Profile info card
            ClayCard(
              borderRadius: AppTheme.radiusXl,
              padding: const EdgeInsets.all(AppTheme.space5),
              child: Column(
                children: [
                  _InfoRow(
                    label: 'BioPay ID',
                    value: _result!.biopayId ?? '—',
                    icon: LucideIcons.fingerprint,
                  ),
                  Divider(
                    height: AppTheme.space6,
                    color: AppColors.white5,
                  ),
                  _InfoRow(
                    label: 'Display Name',
                    value: _result!.displayName ?? '—',
                    icon: LucideIcons.user,
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 350.ms, duration: 300.ms).slideY(begin: 0.05),

            // Management code — golden ticket style
            if (_result!.managementCode != null) ...[
              const SizedBox(height: AppTheme.space6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.space6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.warning.withValues(alpha: 0.15),
                      AppColors.warning.withValues(alpha: 0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.key,
                          size: 18,
                          color: AppColors.warning,
                        ),
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
                    const SizedBox(height: AppTheme.space4),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: _result!.managementCode!),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Management code copied!'),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.space6,
                          vertical: AppTheme.space4,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surface.withValues(alpha: 0.5),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _result!.managementCode!,
                              style: tt.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: AppTheme.space3),
                            Icon(
                              LucideIcons.copy,
                              size: 18,
                              color: cs.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.space3),
                    Text(
                      BiopayStrings.managementCodeBody,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 450.ms, duration: 300.ms).slideY(begin: 0.05),
            ],
          ],

          const SizedBox(height: AppTheme.space10),

          SizedBox(
            width: double.infinity,
            child: PremiumButton(
              label: success ? 'DONE' : 'TRY AGAIN',
              icon: success ? LucideIcons.checkCircle2 : LucideIcons.refreshCw,
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
          ).animate().fadeIn(delay: 550.ms, duration: 300.ms),
        ],
      ),
    );
  }
}

// ─── Step Progress Bar ──────────────────────────────────────

class _StepProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> labels;
  final List<IconData> icons;

  const _StepProgressBar({
    required this.currentStep,
    required this.totalSteps,
    required this.labels,
    required this.icons,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      children: List.generate(totalSteps * 2 - 1, (index) {
        if (index.isOdd) {
          // Connector line
          final stepBefore = index ~/ 2;
          final isCompleted = stepBefore < currentStep;

          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 2,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.secondary.withValues(alpha: 0.6)
                    : cs.onSurfaceVariant.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          );
        }

        // Step dot
        final stepIndex = index ~/ 2;
        final isCompleted = stepIndex < currentStep;
        final isCurrent = stepIndex == currentStep;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isCurrent ? 32 : 24,
              height: isCurrent ? 32 : 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? AppColors.secondary
                    : isCurrent
                        ? cs.primary
                        : cs.surfaceContainerHighest,
                border: isCurrent
                    ? Border.all(
                        color: cs.primary.withValues(alpha: 0.3),
                        width: 3,
                      )
                    : null,
              ),
              child: Icon(
                isCompleted ? LucideIcons.check : icons[stepIndex],
                size: isCurrent ? 14 : 12,
                color: isCompleted || isCurrent
                    ? Colors.white
                    : cs.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              labels[stepIndex],
              style: tt.labelSmall?.copyWith(
                color: isCurrent
                    ? cs.primary
                    : isCompleted
                        ? AppColors.secondary
                        : cs.onSurfaceVariant.withValues(alpha: 0.4),
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                fontSize: 9,
                letterSpacing: 0.5,
              ),
            ),
          ],
        );
      }),
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
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  iconColor.withValues(alpha: 0.20),
                  iconColor.withValues(alpha: 0.08),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: iconColor.withValues(alpha: 0.15),
              ),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: AppTheme.space5),
          Text(
            title,
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          Divider(
            height: AppTheme.space8,
            color: cs.onSurfaceVariant.withValues(alpha: 0.08),
          ),
          ...children,
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.02);
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        const SizedBox(width: AppTheme.space3),
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
