import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/config/country_config_provider.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_theme.dart';
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
        return AppRoutePaths.guestSettings;
      case ActiveRole.venue:
        return AppRoutePaths.venueSettings;
      case ActiveRole.admin:
        return AppRoutePaths.adminSettings;
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
                AppRouteNames.venueLogin,
                queryParameters: {AppRouteParams.returnTo: _returnToPath},
              ),
            ),
            _RoleIconData(
              icon: LucideIcons.shieldCheck,
              tooltip: 'Admin Console',
              isActive: false,
              onTap: () => context.goNamed(
                AppRouteNames.adminLogin,
                queryParameters: {AppRouteParams.returnTo: _returnToPath},
              ),
            ),
          ]
        : currentRole == ActiveRole.venue
        ? [
            _RoleIconData(
              icon: LucideIcons.users,
              tooltip: 'Guest',
              isActive: false,
              onTap: () => context.goNamed(AppRouteNames.discover),
            ),
            _RoleIconData(
              icon: LucideIcons.shieldCheck,
              tooltip: 'Admin Console',
              isActive: false,
              onTap: () => context.goNamed(
                AppRouteNames.adminLogin,
                queryParameters: {AppRouteParams.returnTo: _returnToPath},
              ),
            ),
          ]
        : [
            _RoleIconData(
              icon: LucideIcons.users,
              tooltip: 'Guest',
              isActive: false,
              onTap: () => context.goNamed(AppRouteNames.discover),
            ),
            _RoleIconData(
              icon: LucideIcons.store,
              tooltip: 'Venue Portal',
              isActive: false,
              onTap: () => context.goNamed(
                AppRouteNames.venueLogin,
                queryParameters: {AppRouteParams.returnTo: _returnToPath},
              ),
            ),
          ];

    return Center(
      child: Column(
        children: [
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
