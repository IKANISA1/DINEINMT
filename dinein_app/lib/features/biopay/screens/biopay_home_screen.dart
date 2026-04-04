import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:dinein_app/core/router/app_routes.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';
import '../biopay_providers.dart';

/// BioPay home screen — pre-warms camera-related services on mount.
///
/// By initialising face detection, TFLite, and match cache here,
/// the scanner opens ~200-500ms faster (no cold-start delay).
class BiopayHomeScreen extends ConsumerStatefulWidget {
  const BiopayHomeScreen({super.key});

  @override
  ConsumerState<BiopayHomeScreen> createState() => _BiopayHomeScreenState();
}

class _BiopayHomeScreenState extends ConsumerState<BiopayHomeScreen> {
  @override
  void initState() {
    super.initState();
    _preWarmServices();
  }

  /// Pre-warm ML services and cache so the scanner opens instantly.
  Future<void> _preWarmServices() async {
    // Load persistent match cache from SharedPreferences
    await ref.read(matchCacheProvider).loadFromDisk();

    // Pre-initialise face detector (idempotent — returns if already init'd)
    ref.read(faceDetectionProvider).initialize();

    // Pre-load TFLite model
    await ref.read(embeddingServiceProvider).initialize();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('BioPay')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.space6,
          AppTheme.space6,
          AppTheme.space6,
          AppTheme.space16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.space8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppTheme.radius3xl),
                border: Border.all(color: AppColors.white5),
                boxShadow: AppTheme.ambientShadow,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.surfaceContainerLow,
                    cs.surfaceContainerLowest,
                    cs.primary.withValues(alpha: 0.08),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.scanFace,
                      color: cs.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space6),
                  Text(
                    'Register your face. Scan a face. Pay instantly.',
                    style: tt.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space3),
                  Text(
                    'BioPay lets Rwanda guests register a face-linked MoMo payment identity and launch payment from a face scan.',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            _BioPayActionCard(
              icon: LucideIcons.user,
              eyebrow: 'PAYEE',
              title: 'Register My Face',
              subtitle:
                  'Create your BioPay profile and link it to your Rwanda USSD payment string.',
              cta: 'START REGISTRATION',
              onTap: () => context.pushNamed(AppRouteNames.biopayRegister),
            ),
            const SizedBox(height: AppTheme.space4),
            _BioPayActionCard(
              icon: LucideIcons.camera,
              eyebrow: 'PAYER',
              title: 'Scan To Pay',
              subtitle:
                  'Point your phone at the payee, confirm the matched name, and launch payment.',
              cta: 'OPEN SCANNER',
              onTap: () => context.pushNamed(AppRouteNames.biopayScanner),
            ),
            const SizedBox(height: AppTheme.space4),
            _BioPayActionCard(
              icon: LucideIcons.settings,
              eyebrow: 'PROFILE',
              title: 'Manage BioPay',
              subtitle:
                  'Update your display name, payment string, or prepare to re-enroll your face.',
              cta: 'MANAGE PROFILE',
              onTap: () => context.pushNamed(AppRouteNames.biopayManage),
            ),
          ],
        ),
      ),
    );
  }
}

class _BioPayActionCard extends StatelessWidget {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String subtitle;
  final String cta;
  final VoidCallback onTap;

  const _BioPayActionCard({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ClayCard(
      onTap: onTap,
      borderRadius: AppTheme.radiusXxl,
      padding: const EdgeInsets.all(AppTheme.space6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: Icon(icon, color: cs.primary, size: 24),
          ),
          const SizedBox(width: AppTheme.space5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.78),
                    letterSpacing: 2.6,
                  ),
                ),
                const SizedBox(height: AppTheme.space2),
                Text(title, style: tt.titleLarge),
                const SizedBox(height: AppTheme.space2),
                Text(
                  subtitle,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppTheme.space4),
                Row(
                  children: [
                    PremiumButton(label: cta, onPressed: onTap, isSmall: true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
