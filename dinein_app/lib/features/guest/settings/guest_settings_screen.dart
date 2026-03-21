import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../shared/widgets/shared_widgets.dart';

/// Profile screen — 4th bottom nav tab.
///
/// Layout:
/// - Profile avatar + greeting
/// - Quick action chips (Orders, Favorites)
/// - Appearance section with dark/light mode toggle
/// - Account section (Add Venue CTA, Notifications, Language, About, Privacy)
class GuestSettingsScreen extends ConsumerWidget {
  const GuestSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Profile Header ───
            _ProfileHeader(cs: cs, tt: tt)
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.05),
            const SizedBox(height: AppTheme.space8),

            // ─── Quick Actions ───
            Text(
              'QUICK ACTIONS',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppTheme.space4),
            _SettingsTile(
              icon: LucideIcons.clock,
              title: 'Order History',
              subtitle: 'VIEW YOUR PAST ORDERS',
              onTap: () => context.goNamed(AppRouteNames.orderHistory),
            )
                .animate()
                .fadeIn(delay: 100.ms, duration: 400.ms)
                .slideY(begin: 0.05),
            const SizedBox(height: AppTheme.space8),

            // ─── Appearance ───
            Text(
              'APPEARANCE',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppTheme.space4),
            _DarkModeTile(
              isDark: isDark,
              onToggle: () => ref.read(themeModeProvider.notifier).toggle(),
            )
                .animate()
                .fadeIn(delay: 200.ms, duration: 400.ms)
                .slideY(begin: 0.05),
            const SizedBox(height: AppTheme.space8),

            // ─── Account ───
            Text(
              'ACCOUNT',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppTheme.space4),
            _SettingsTile(
              icon: LucideIcons.store,
              title: 'Add Your Venue',
              onTap: () => context.goNamed(AppRouteNames.venueClaim),
            ),
            const SizedBox(height: AppTheme.space3),
            _SettingsTile(
              icon: LucideIcons.messageSquare,
              title: 'Get in Touch',
              onTap: () => _showContactSheet(context),
            ),
            const SizedBox(height: AppTheme.space3),
            _SettingsTile(
              icon: LucideIcons.info,
              title: 'About DINEIN',
              onTap: () => _showAboutDialog(context),
            ),
            const SizedBox(height: AppTheme.space3),
            _SettingsTile(
              icon: LucideIcons.shield,
              title: 'Privacy Policy',
              onTap: () async {
                final uri = Uri.parse('https://dineinmt.ikanisa.com/privacy.html');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
            const SizedBox(height: AppTheme.space3),
            _SettingsTile(
              icon: LucideIcons.fileText,
              title: 'Terms & Conditions',
              onTap: () async {
                final uri = Uri.parse('https://dineinmt.ikanisa.com/terms.html');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
            const SizedBox(height: AppTheme.space8),

            // ─── Role Switch Footer ───
            const RoleSwitchFooter(currentRole: ActiveRole.guest),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  Dialogs & Bottom Sheets
  // ──────────────────────────────────────────────

  void _showAboutDialog(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

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
            // DineInLogoText removed as BrandMark image contains the text
            Text('Version 1.0.0', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: AppTheme.space6),
            Text(
              'DINEIN is a dine-in only ordering platform connecting guests with Malta\'s finest restaurants. '
              'Scan a QR code, browse the menu, and place your order — all from your table.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.6,
              ),
            ),
            const SizedBox(height: AppTheme.space6),
            Row(
              children: [
                _InfoChip(icon: LucideIcons.mapPin, label: 'Malta', cs: cs, tt: tt),
                const SizedBox(width: AppTheme.space3),
                _InfoChip(icon: LucideIcons.utensils, label: 'Dine-In Only', cs: cs, tt: tt),
                const SizedBox(width: AppTheme.space3),
                _InfoChip(icon: LucideIcons.qrCode, label: 'QR Entry', cs: cs, tt: tt),
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


  void _showContactSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
            Text(
              'Get in Touch',
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'We\'d love to hear from you',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppTheme.space6),
            _ContactOption(
              icon: LucideIcons.mail,
              label: 'Email Us',
              subtitle: 'hello@dinein.mt',
              onTap: () async {
                final uri = Uri.parse('mailto:hello@dinein.mt');
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
            ),
            const SizedBox(height: AppTheme.space3),
            _ContactOption(
              icon: LucideIcons.instagram,
              label: 'Instagram',
              subtitle: '@dinein.malta',
              onTap: () async {
                final uri = Uri.parse('https://instagram.com/dinein.malta');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
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
}

// ──────────────────────────────────────────────
//  Helper Widgets
// ──────────────────────────────────────────────

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




/// Profile header with avatar, name, and subtitle.
class _ProfileHeader extends StatelessWidget {
  final ColorScheme cs;
  final TextTheme tt;

  const _ProfileHeader({required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
        border: Border.all(color: AppColors.white5),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primary,
                  cs.primary.withValues(alpha: 0.70),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                LucideIcons.user,
                size: 36,
                color: cs.onPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space4),
          Text(
            'Guest',
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Welcome to DINEIN MALTA',
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Contact option row for the Get in Touch sheet.
class _ContactOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space5),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(color: AppColors.white5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(icon, size: 20, color: cs.primary),
            ),
            const SizedBox(width: AppTheme.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    subtitle,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.externalLink, size: 16, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}



/// Dark mode toggle tile with animated switch.
class _DarkModeTile extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggle;

  const _DarkModeTile({required this.isDark, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PressableScale(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space5),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(color: AppColors.white5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  isDark ? LucideIcons.sun : LucideIcons.moon,
                  key: ValueKey(isDark),
                  size: 20,
                  color: isDark
                      ? const Color(0xFFFFC107)
                      : cs.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dark Mode',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    isDark ? 'Currently dark' : 'Currently light',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: isDark,
              onChanged: (_) => onToggle(),
              activeTrackColor: cs.primary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings tile — icon + title + optional subtitle + chevron.
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
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space5),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(color: AppColors.white5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(icon, size: 20, color: cs.onSurfaceVariant),
            ),
            const SizedBox(width: AppTheme.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
