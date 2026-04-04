import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:core_pkg/config/country_config.dart';
import 'package:core_pkg/config/country_config_provider.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/core/infrastructure/support_contact_service.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';

class GuestSettingsScreen extends ConsumerWidget {
  const GuestSettingsScreen({super.key});

  Future<void> _launchExternal(BuildContext context, Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open that link.')));
  }

  void _showAboutSheet(BuildContext context, CountryConfig config) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final countryName = config.country.label;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        margin: const EdgeInsets.all(AppTheme.space4),
        padding: const EdgeInsets.all(AppTheme.space6),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
          border: Border.all(color: AppColors.white5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandMark(
              size: 56,
              borderRadius: 16,
              fontSize: 32,
              shadowBlur: 20,
              shadowOpacity: 0.25,
            ),
            const SizedBox(height: AppTheme.space4),
            Text(
              'Version 1.0.0',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppTheme.space6),
            Text(
              'DINEIN is a dine-in only ordering platform connecting guests with $countryName\'s finest restaurants. '
              'Scan a QR code, browse the menu, and place your order from your table.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.6,
              ),
            ),
            const SizedBox(height: AppTheme.space6),
            Row(
              children: [
                _InfoChip(
                  icon: LucideIcons.mapPin,
                  label: countryName,
                  cs: cs,
                  tt: tt,
                ),
                const SizedBox(width: AppTheme.space3),
                _InfoChip(
                  icon: LucideIcons.utensils,
                  label: 'Dine-In',
                  cs: cs,
                  tt: tt,
                ),
                const SizedBox(width: AppTheme.space3),
                _InfoChip(
                  icon: LucideIcons.qrCode,
                  label: 'QR Entry',
                  cs: cs,
                  tt: tt,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space6),
            SizedBox(
              width: double.infinity,
              child: PremiumButton(
                label: 'CLOSE',
                onPressed: () => Navigator.of(context).pop(),
                icon: LucideIcons.x,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(countryConfigProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space6,
        AppTheme.space6,
        AppTheme.space6,
        120,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileHeaderCard(
            welcomeMessage: config.welcomeMessage,
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
          const SizedBox(height: AppTheme.space8),
          const _SectionLabel(label: 'QUICK ACTIONS'),
          const SizedBox(height: AppTheme.space4),
          _SettingsTile(
                icon: LucideIcons.history,
                title: 'Order History',
                subtitle: 'VIEW YOUR PAST ORDERS',
                onTap: () => context.goNamed(AppRouteNames.orderHistory),
              )
              .animate()
              .fadeIn(delay: 100.ms, duration: 320.ms)
              .slideY(begin: 0.05),
          if (config.hasBioPay && !kIsWeb) ...[
            const SizedBox(height: AppTheme.space3),
            _SettingsTile(
                  icon: LucideIcons.scanFace,
                  title: 'BioPay',
                  subtitle: 'FACE-SCAN PAYMENTS',
                  onTap: () => context.goNamed(AppRouteNames.biopayHome),
                )
                .animate()
                .fadeIn(delay: 130.ms, duration: 320.ms)
                .slideY(begin: 0.05),
          ],
          const SizedBox(height: AppTheme.space8),
          const _SectionLabel(label: 'ACCOUNT'),
          const SizedBox(height: AppTheme.space4),
          _SettingsTile(
                icon: LucideIcons.store,
                title: 'Venue Portal',
                onTap: () => context.pushNamed(AppRouteNames.venueLogin),
              )
              .animate()
              .fadeIn(delay: 150.ms, duration: 320.ms)
              .slideY(begin: 0.05),
          const SizedBox(height: AppTheme.space3),
          _SettingsTile(
                icon: LucideIcons.messageSquare,
                title: 'Get in Touch',
                onTap: () => SupportContactService.contactSupport(context),
              )
              .animate()
              .fadeIn(delay: 180.ms, duration: 320.ms)
              .slideY(begin: 0.05),
          const SizedBox(height: AppTheme.space3),
          _SettingsTile(
                icon: LucideIcons.info,
                title: 'About DINEIN',
                onTap: () => _showAboutSheet(context, config),
              )
              .animate()
              .fadeIn(delay: 210.ms, duration: 320.ms)
              .slideY(begin: 0.05),
          const SizedBox(height: AppTheme.space3),
          _SettingsTile(
                icon: LucideIcons.shield,
                title: 'Privacy Policy',
                onTap: () => _launchExternal(
                  context,
                  Uri.parse(config.privacyPolicyUrl),
                ),
              )
              .animate()
              .fadeIn(delay: 240.ms, duration: 320.ms)
              .slideY(begin: 0.05),
          const SizedBox(height: AppTheme.space3),
          _SettingsTile(
                icon: LucideIcons.trash2,
                title: 'Delete My Data',
                subtitle: 'REQUEST DATA REMOVAL',
                onTap: () => _launchExternal(
                  context,
                  Uri.parse(
                    'mailto:info@ikanisa.com'
                    '?subject=DineIn%20Data%20Deletion%20Request'
                    '&body=I%20would%20like%20to%20request%20deletion%20of%20all%20'
                    'my%20personal%20data%20associated%20with%20the%20DineIn%20app.',
                  ),
                ),
              )
              .animate()
              .fadeIn(delay: 270.ms, duration: 320.ms)
              .slideY(begin: 0.05),
          const SizedBox(height: AppTheme.space8),
          const _GuestProfileFooter(),
        ],
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  final String welcomeMessage;
  const _ProfileHeaderCard({required this.welcomeMessage});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space6,
        vertical: AppTheme.space8,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radius3xl),
        border: Border.all(color: AppColors.white5),
        boxShadow: AppTheme.ambientShadow,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [cs.surfaceContainerLow, cs.surfaceContainerLowest],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withValues(alpha: 0.16),
              border: Border.all(color: cs.primary.withValues(alpha: 0.28)),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.16),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(LucideIcons.user, size: 44, color: cs.primary),
          ),
          const SizedBox(height: AppTheme.space6),
          Text(
            'Guest',
            style: tt.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            welcomeMessage,
            style: TextStyle(
              color: cs.onSurfaceVariant.withValues(alpha: 0.68),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 3.2,
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.62),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PressableScale(
      onTap: onTap,
      semanticLabel: title,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space5,
          vertical: AppTheme.space5,
        ),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.radius3xl),
          border: Border.all(color: AppColors.white5),
          boxShadow: AppTheme.ambientShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              ),
              child: Icon(icon, size: 24, color: cs.onSurfaceVariant),
            ),
            const SizedBox(width: AppTheme.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 22,
              color: cs.onSurfaceVariant.withValues(alpha: 0.82),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestProfileFooter extends StatelessWidget {
  const _GuestProfileFooter();

  @override
  Widget build(BuildContext context) {
    return const RoleSwitchFooter(currentRole: ActiveRole.guest);
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme cs;
  final TextTheme tt;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: cs.primary),
            const SizedBox(height: 4),
            Text(
              label,
              style: tt.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
