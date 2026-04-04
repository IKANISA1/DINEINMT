import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:core_pkg/config/country_config_provider.dart';
import 'package:ui/theme/app_theme.dart';
import 'pressable_scale.dart';

/// Which UI the user is currently viewing.
enum ActiveRole { guest, venue, admin }

/// Role-switch footer rendered at the bottom of every settings/profile screen.
///
/// Displays the two non-current roles so the footer always functions as a
/// direct role switcher between profile contexts.
///
/// Includes the DINEIN MALTA version footer text beneath the icons.
class RoleSwitchFooter extends ConsumerWidget {
  /// Which role the containing screen represents.
  final ActiveRole currentRole;

  const RoleSwitchFooter({super.key, required this.currentRole});

  String get _returnToPath {
    switch (currentRole) {
      case ActiveRole.guest:
        return '/settings';
      case ActiveRole.venue:
        return '/v/settings';
      case ActiveRole.admin:
        return '/admin/settings';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(countryConfigProvider);
    final icons = currentRole == ActiveRole.guest
        ? [
            _RoleIconData(
              icon: LucideIcons.store,
              tooltip: 'Venue Portal',
              isActive: false,
              onTap: () => context.goNamed(
                'venueLogin',
                queryParameters: {'returnTo': _returnToPath},
              ),
            ),
            _RoleIconData(
              icon: LucideIcons.shieldCheck,
              tooltip: 'Admin Console',
              isActive: false,
              onTap: () => context.goNamed(
                'adminLogin',
                queryParameters: {'returnTo': _returnToPath},
              ),
            ),
          ]
        : currentRole == ActiveRole.venue
        ? [
            _RoleIconData(
              icon: LucideIcons.users,
              tooltip: 'Guest',
              isActive: false,
              onTap: () => context.goNamed('discover'),
            ),
            _RoleIconData(
              icon: LucideIcons.shieldCheck,
              tooltip: 'Admin Console',
              isActive: false,
              onTap: () => context.goNamed(
                'adminLogin',
                queryParameters: {'returnTo': _returnToPath},
              ),
            ),
          ]
        : [
            _RoleIconData(
              icon: LucideIcons.users,
              tooltip: 'Guest',
              isActive: false,
              onTap: () => context.goNamed('discover'),
            ),
            _RoleIconData(
              icon: LucideIcons.store,
              tooltip: 'Venue Portal',
              isActive: false,
              onTap: () => context.goNamed(
                'venueLogin',
                queryParameters: {'returnTo': _returnToPath},
              ),
            ),
          ];

    return Center(
      child: Column(
        children: [
          if (kIsWeb) ...[
            _MobileAppDownloadCard(
              appTitle: config.appTitle,
              onOpen: () => _openPlayStore(context, config.playStoreUrl),
            ),
            const SizedBox(height: AppTheme.space4),
          ],
          Row(
                mainAxisSize: MainAxisSize.min,
                children: icons.asMap().entries.map((entry) {
                  final i = entry.key;
                  final data = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(left: i > 0 ? AppTheme.space4 : 0),
                    child: _RoleIcon(data: data),
                  );
                }).toList(),
              )
              .animate()
              .fadeIn(duration: 400.ms, delay: 200.ms)
              .slideY(begin: 0.1, end: 0, duration: 300.ms),
          const SizedBox(height: AppTheme.space3),
          Text(
            '${config.appTitle} V1.0.0',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.40),
            ),
          ),
          const SizedBox(height: AppTheme.space4),
        ],
      ),
    );
  }

  Future<void> _openPlayStore(BuildContext context, String playStoreUrl) async {
    final uri = Uri.parse(playStoreUrl);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open Google Play.')),
    );
  }
}

class _RoleIconData {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  const _RoleIconData({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onTap,
  });
}

/// A single circular icon button for role switching.
///
/// Active icon gets a tinted border + subtle glow to indicate "you are here".
class _RoleIcon extends StatelessWidget {
  final _RoleIconData data;

  const _RoleIcon({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Tooltip(
      message: data.tooltip,
      child: PressableScale(
        onTap: data.onTap,
        semanticLabel: data.tooltip,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: data.isActive
                ? cs.primary.withValues(alpha: 0.12)
                : cs.surfaceContainerLow,
            shape: BoxShape.circle,
            border: Border.all(
              color: data.isActive
                  ? cs.primary.withValues(alpha: 0.40)
                  : Colors.white.withValues(alpha: 0.05),
              width: data.isActive ? 1.5 : 1,
            ),
            boxShadow: data.isActive
                ? [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.15),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: Icon(
            data.icon,
            size: 20,
            color: data.isActive ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _MobileAppDownloadCard extends StatelessWidget {
  final String appTitle;
  final VoidCallback onOpen;

  const _MobileAppDownloadCard({required this.appTitle, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.space5),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          boxShadow: AppTheme.ambientShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                  child: Icon(LucideIcons.smartphone, color: cs.primary),
                ),
                const SizedBox(width: AppTheme.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Need the native app?',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$appTitle on Google Play for BioPay, face scan, and device-only features.',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space4),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(LucideIcons.externalLink, size: 18),
                label: const Text('OPEN GOOGLE PLAY'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
