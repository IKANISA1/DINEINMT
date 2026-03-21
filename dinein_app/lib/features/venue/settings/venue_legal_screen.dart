import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/providers.dart';
import '../../../shared/widgets/shared_widgets.dart';

/// Venue Legal & Policies — full-page screen.
///
/// Layout (matching screenshot):
///   Back + Header → 3 policy tiles (Terms of Service, Privacy Policy,
///   Cookie Policy) each with an external-link action.
class VenueLegalScreen extends ConsumerWidget {
  const VenueLegalScreen({super.key});

  static const _policies = [
    _PolicyItem(
      icon: LucideIcons.fileText,
      title: 'Terms of Service',
      updatedLabel: 'UPDATED JAN 2026',
      url: 'https://dineinmalta.com/terms',
    ),
    _PolicyItem(
      icon: LucideIcons.shield,
      title: 'Privacy Policy',
      updatedLabel: 'UPDATED DEC 2025',
      url: 'https://dineinmalta.com/privacy',
    ),
    _PolicyItem(
      icon: LucideIcons.info,
      title: 'Cookie Policy',
      updatedLabel: 'UPDATED JAN 2026',
      url: 'https://dineinmalta.com/cookies',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final venueAsync = ref.watch(currentVenueProvider);

    return Scaffold(
      body: venueAsync.when(
        loading: () => const Center(
            child: SkeletonLoader(width: double.infinity, height: 200)),
        error: (_, _) => ErrorState(
          message: 'Could not load venue.',
          onRetry: () => ref.invalidate(currentVenueProvider),
        ),
        data: (venue) {
          if (venue == null) {
            return const EmptyState(
              icon: LucideIcons.store,
              title: 'No venue',
              subtitle: 'Claim a venue first.',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
                AppTheme.space6, AppTheme.space6, AppTheme.space6, 120),
            children: [
              // ─── Header ───
              Row(
                children: [
                  PressableScale(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Icon(LucideIcons.chevronLeft,
                          size: 18, color: cs.onSurface),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Legal & Policies',
                          style: tt.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5)),
                      Text('VENUE MANAGEMENT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: cs.onSurfaceVariant,
                          )),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space6),

              // ─── Policy Tiles ───
              ...List.generate(_policies.length, (i) {
                final policy = _policies[i];
                // Cycle icon color: primary, secondary, secondary-dim
                final iconColors = [
                  cs.primary,
                  AppColors.secondary,
                  AppColors.secondary.withValues(alpha: 0.70),
                ];
                final iconColor = iconColors[i % iconColors.length];

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.space3),
                  child: PressableScale(
                    onTap: () => _openPolicy(policy.url),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05)),
                        boxShadow: AppTheme.clayShadow,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(policy.icon,
                                size: 18, color: iconColor),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(policy.title,
                                    style: tt.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(policy.updatedLabel,
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2,
                                      color: cs.onSurfaceVariant
                                          .withValues(alpha: 0.50),
                                    )),
                              ],
                            ),
                          ),
                          Icon(LucideIcons.externalLink,
                              size: 16,
                              color: cs.onSurfaceVariant
                                  .withValues(alpha: 0.40)),
                        ],
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(
                          duration: 300.ms,
                          delay: Duration(milliseconds: i * 100))
                      .slideY(
                          begin: 0.05,
                          end: 0,
                          duration: 300.ms,
                          delay: Duration(milliseconds: i * 100)),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openPolicy(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ─── Data Model ───

class _PolicyItem {
  final IconData icon;
  final String title;
  final String updatedLabel;
  final String url;

  const _PolicyItem({
    required this.icon,
    required this.title,
    required this.updatedLabel,
    required this.url,
  });
}
