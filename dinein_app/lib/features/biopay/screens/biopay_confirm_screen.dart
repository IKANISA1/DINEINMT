import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';
import '../biopay_providers.dart';
import '../biopay_strings.dart';
import '../models/biopay_models.dart';
import '../services/ussd_launcher_service.dart';

/// BioPay match confirmation screen.
///
/// Shows the matched profile (display name, BioPay ID, confidence score)
/// and offers two actions:
/// - "PAY WITH MOMO" → launches USSD via native dialer
/// - "NOT ME — REPORT" → navigates to report flow
class BiopayConfirmScreen extends ConsumerWidget {
  final dynamic matchResult;

  const BiopayConfirmScreen({super.key, this.matchResult});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Extract match data
    final match = matchResult is MatchResult
        ? matchResult as MatchResult
        : MatchResult.noMatch();

    if (!match.isMatch) {
      return Scaffold(
        appBar: AppBar(title: const Text('No Match')),
        body: EmptyState(
          icon: LucideIcons.searchX,
          title: 'No Match Found',
          subtitle:
              'The face scan did not match any registered BioPay profile.',
          actionLabel: 'TRY AGAIN',
          onAction: () => context.pop(),
        ),
      );
    }

    final confidence = ((match.score ?? 0) * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Payment'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Match card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.space8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppTheme.radius3xl),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.3),
                ),
                boxShadow: AppTheme.ambientShadow,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.surfaceContainerLow,
                    cs.surfaceContainerLowest,
                    AppColors.secondary.withValues(alpha: 0.06),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Success icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.checkCircle2,
                      size: 36,
                      color: AppColors.secondary,
                    ),
                  ).animate().scale(
                    begin: const Offset(0.5, 0.5),
                    duration: 400.ms,
                    curve: Curves.elasticOut,
                  ),
                  const SizedBox(height: AppTheme.space5),

                  // Display name
                  Text(
                    match.displayName ?? '—',
                    style: tt.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.space2),

                  // BioPay ID
                  Text(
                    match.biopayId ?? '',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space4),

                  // Confidence badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space4,
                      vertical: AppTheme.space2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.shield,
                          size: 14,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: AppTheme.space1),
                        Text(
                          '$confidence% match confidence',
                          style: tt.labelSmall?.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.03),

            const SizedBox(height: AppTheme.space4),

            // Verification prompt
            Text(
              BiopayStrings.confirmSubtitle,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppTheme.space8),

            // PAY button
            SizedBox(
              width: double.infinity,
              child: PremiumButton(
                label: BiopayStrings.confirmPayCta,
                onPressed: () => _launchPayment(context, match.ussdString),
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 300.ms),

            const SizedBox(height: AppTheme.space4),

            // NOT ME button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _reportMismatch(context, ref, match.biopayId),
                icon: const Icon(LucideIcons.alertTriangle, size: 18),
                label: const Text(BiopayStrings.confirmNotMe),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.space4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 300.ms, duration: 300.ms),
          ],
        ),
      ),
    );
  }

  void _launchPayment(BuildContext context, String? ussd) async {
    if (ussd == null || ussd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No payment string available')),
      );
      return;
    }

    final launched = await UssdLauncherService.launch(ussd);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open dialer')));
    }
  }

  void _reportMismatch(BuildContext context, WidgetRef ref, String? biopayId) {
    if (biopayId == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report Mismatch'),
        content: const Text(
          'Are you sure this is not the correct person? '
          'This will flag the profile for review.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final installId = await ref.read(installIdProvider.future);
                await ref
                    .read(biopayRepositoryProvider)
                    .reportProfile(
                      biopayId: biopayId,
                      reason: 'Reported mismatch',
                      notes: 'Submitted from the BioPay confirm screen.',
                      clientInstallId: installId,
                    );
                if (!context.mounted) return;
                context.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report submitted. Thank you.')),
                );
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not submit report: $error')),
                );
              }
            },
            child: const Text('REPORT'),
          ),
        ],
      ),
    );
  }
}
