import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/providers.dart';
import '../../../core/services/auth_repository.dart';
import '../../../shared/widgets/shared_widgets.dart';

/// Venue Settings — single scrollable page.
///
/// Layout (matching screenshots):
///   Header → Owner Profile Card → Venue Configuration (2 tiles) →
///   Preferences & Safety (3 tiles) → Sign Out → Footer
///
/// Navigation tiles push to full-page screens where applicable.
class VenueSettingsScreen extends ConsumerStatefulWidget {
  const VenueSettingsScreen({super.key});

  @override
  ConsumerState<VenueSettingsScreen> createState() =>
      _VenueSettingsScreenState();
}

class _VenueSettingsScreenState extends ConsumerState<VenueSettingsScreen> {
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      await AuthRepository.instance.signOut();
      if (!mounted) return;
      context.go(AppRoutePaths.splash);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not sign out. Try again.')),
        );
        setState(() => _isSigningOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final venueAsync = ref.watch(currentVenueProvider);

    return venueAsync.when(
      loading: () =>
          const Center(child: SkeletonLoader(width: double.infinity, height: 200)),
      error: (_, _) => ErrorState(
        message: 'Could not load venue.',
        onRetry: () => ref.invalidate(currentVenueProvider),
      ),
      data: (venue) {
        if (venue == null) {
          return const EmptyState(
            icon: LucideIcons.store,
            title: 'No venue access',
            subtitle: 'Claim and verify a venue first.',
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(
              AppTheme.space6, AppTheme.space6, AppTheme.space6, 120),
          children: [
            // ═══ HEADER ═══
            Text('Settings',
                style: tt.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            const SizedBox(height: 2),
            Text('VENUE MANAGEMENT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: cs.onSurfaceVariant,
                )),
            const SizedBox(height: AppTheme.space6),

            // ═══ OWNER PROFILE CARD ═══
            PressableScale(
              onTap: () =>
                  context.pushNamed(AppRouteNames.venueProfile),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.secondary.withValues(alpha: 0.28),
                      AppColors.secondary.withValues(alpha: 0.10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.24)),
                  boxShadow: AppTheme.clayShadow,
                ),
                child: Row(
                  children: [
                    // Venue image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: DineInImage(
                          imageUrl: venue.imageUrl,
                          fit: BoxFit.cover,
                          fallbackIcon: LucideIcons.store,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        venue.name,
                        style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(LucideIcons.chevronRight,
                        size: 18, color: cs.onSurfaceVariant),
                  ],
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.05, end: 0, duration: 300.ms),
            const SizedBox(height: AppTheme.space8),

            // ═══ VENUE CONFIGURATION ═══
            _SectionHeader(label: 'VENUE CONFIGURATION'),
            const SizedBox(height: AppTheme.space3),
            _SettingTile(
              icon: LucideIcons.mapPin,
              iconColor: cs.primary,
              title: 'Venue Profile',
              subtitle: 'NAME, ADDRESS, AND CONTACT INFO',
              onTap: () =>
                  context.pushNamed(AppRouteNames.venueProfile),
            ),
            _SettingTile(
              icon: LucideIcons.clock,
              iconColor: cs.primary,
              title: 'Opening Hours',
              subtitle: 'MANAGE WEEKLY SCHEDULE',
              onTap: () =>
                  context.pushNamed(AppRouteNames.venueHours),
            ),
            _SettingTile(
              icon: LucideIcons.wifi,
              iconColor: cs.primary,
              title: 'WiFi Sharing',
              subtitle: 'GUEST AUTO-CONNECT',
              onTap: () =>
                  context.pushNamed(AppRouteNames.venueWifi),
            ),
            const SizedBox(height: AppTheme.space6),

            // ═══ PREFERENCES & SAFETY ═══
            _SectionHeader(label: 'PREFERENCES & SAFETY'),
            const SizedBox(height: AppTheme.space3),
            _SettingTile(
              icon: LucideIcons.bell,
              iconColor: cs.primary,
              title: 'Notifications',
              subtitle: 'PUSH, EMAIL, AND WHATSAPP',
              onTap: () =>
                  context.pushNamed(AppRouteNames.venueNotifications),
            ),
            _SettingTile(
              icon: LucideIcons.languages,
              iconColor: cs.primary,
              title: 'Language & Region',
              subtitle: 'ENGLISH, EUR, CET',
              onTap: () =>
                  context.pushNamed(AppRouteNames.venueLanguageRegion),
            ),
            _SettingTile(
              icon: LucideIcons.fileCheck,
              iconColor: cs.primary,
              title: 'Legal & Policies',
              subtitle: 'TERMS, PRIVACY, AND REFUNDS',
              onTap: () =>
                  context.pushNamed(AppRouteNames.venueLegal),
            ),
            const SizedBox(height: AppTheme.space8),

            // ═══ SIGN OUT ═══
            PressableScale(
              onTap: _isSigningOut ? null : _signOut,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: cs.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: cs.error.withValues(alpha: 0.20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isSigningOut)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.error,
                        ),
                      )
                    else
                      Icon(LucideIcons.logOut, size: 18, color: cs.error),
                    const SizedBox(width: 10),
                    Text('SIGN OUT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: cs.error,
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.space8),

            // ═══ ROLE SWITCH FOOTER ═══
            const RoleSwitchFooter(currentRole: ActiveRole.venue),
          ],
        );
      },
    );
  }
}

// ─── Private Widgets ───

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant
                .withValues(alpha: 0.50),
          )),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space2),
      child: PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: tt.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.50),
                        )),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight,
                  size: 16, color: cs.onSurfaceVariant.withValues(alpha: 0.40)),
            ],
          ),
        ),
      ),
    );
  }
}
