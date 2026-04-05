import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';
import '../../../core/providers/providers.dart';
import 'package:dinein_app/core/services/auth_repository.dart';
import 'package:ui/widgets/shared_widgets.dart';

/// Venue settings landing page aligned to the provided reference screenshots.
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
    final currentUser = ref.watch(currentUserProvider);

    return venueAsync.when(
      loading: () => const Center(
        child: SkeletonLoader(width: double.infinity, height: 200),
      ),
      error: (_, _) => ErrorState(
        message: 'Could not load venue.',
        onRetry: () => ref.invalidate(currentVenueProvider),
      ),
      data: (venue) {
        if (venue == null) {
          return const EmptyState(
            icon: LucideIcons.store,
            title: 'No Venue Access',
            subtitle: 'No venue linked to this account.',
          );
        }

        final rawDisplayName =
            currentUser?.userMetadata?['display_name'] ??
            currentUser?.userMetadata?['full_name'];
        final managerName =
            rawDisplayName is String && rawDisplayName.trim().isNotEmpty
            ? rawDisplayName.trim()
            : (currentUser?.email?.split('@').first ?? venue.name);
        final rawAvatarUrl = currentUser?.userMetadata?['avatar_url'];
        final managerImageUrl =
            rawAvatarUrl is String && rawAvatarUrl.isNotEmpty
            ? rawAvatarUrl
            : venue.imageUrl;

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.space6,
            AppTheme.space6,
            AppTheme.space6,
            120,
          ),
          children: [
            // ═══ HEADER ═══
            Text(
              'Settings',
              style: tt.headlineLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'VENUE MANAGEMENT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.space6),

            // ═══ OWNER PROFILE CARD ═══
            PressableScale(
                  onTap: () => context.pushNamed(AppRouteNames.venueProfile),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: AppTheme.clayShadow,
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            width: 68,
                            height: 68,
                            child: DineInImage(
                              imageUrl: managerImageUrl,
                              fit: BoxFit.cover,
                              fallbackIcon: LucideIcons.user,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            managerName,
                            style: tt.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: AppColors.onPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          LucideIcons.chevronRight,
                          size: 18,
                          color: AppColors.onPrimary.withValues(alpha: 0.65),
                        ),
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
              onTap: () => context.pushNamed(AppRouteNames.venueProfile),
            ),
            _SettingTile(
              icon: LucideIcons.clock,
              iconColor: cs.primary,
              title: 'Opening Hours',
              subtitle: 'MANAGE WEEKLY SCHEDULE',
              onTap: () => context.pushNamed(AppRouteNames.venueHours),
            ),
            _SettingTile(
              icon: LucideIcons.qrCode,
              iconColor: cs.primary,
              title: 'Venue QR Codes',
              subtitle: 'GUEST, APP, AND TABLE QR TOOLS',
              onTap: () => context.pushNamed(AppRouteNames.venueTableQr),
            ),
            _SettingTile(
              icon: LucideIcons.wifi,
              iconColor: cs.primary,
              title: 'WiFi Sharing',
              subtitle: 'GUEST AUTO-CONNECT',
              onTap: () => context.pushNamed(AppRouteNames.venueWifi),
            ),
            const SizedBox(height: AppTheme.space6),

            // ═══ PREFERENCES & SAFETY ═══
            _SectionHeader(label: 'PREFERENCES & SAFETY'),
            const SizedBox(height: AppTheme.space3),
            _SettingTile(
              icon: LucideIcons.bell,
              iconColor: AppColors.secondary,
              title: 'Notifications',
              subtitle: 'PUSH, EMAIL, AND WHATSAPP',
              onTap: () => context.pushNamed(AppRouteNames.venueNotifications),
            ),
            _SettingTile(
              icon: LucideIcons.languages,
              iconColor: AppColors.secondary,
              title: 'Language & Region',
              subtitle: 'ENGLISH, EUR, CET',
              onTap: () => context.pushNamed(AppRouteNames.venueLanguageRegion),
            ),
            _SettingTile(
              icon: LucideIcons.fileCheck,
              iconColor: AppColors.secondary,
              title: 'Legal & Policies',
              subtitle: 'TERMS, PRIVACY, AND REFUNDS',
              onTap: () => context.pushNamed(AppRouteNames.venueLegal),
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
                  border: Border.all(color: cs.error.withValues(alpha: 0.20)),
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
                    Text(
                      'SIGN OUT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: cs.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),

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
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 3,
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.50),
        ),
      ),
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
                    Text(
                      title,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.50),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: cs.onSurfaceVariant.withValues(alpha: 0.40),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
