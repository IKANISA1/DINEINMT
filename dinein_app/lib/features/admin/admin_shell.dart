import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';

/// Admin portal shell — matches React AdminLayout.tsx exactly.
///
/// Top bar: ShieldCheck logo (primary) + "DineIn HQ" + "Admin Console" label + bell + avatar
/// Bottom nav: 5 tabs with primary-bg pill + indicator dot
/// Both bars use BackdropFilter glass blur.
class AdminShell extends StatelessWidget {
  final Widget child;

  const AdminShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(AppRoutePaths.adminVenues)) return 1;
    if (location.startsWith(AppRoutePaths.adminMenus)) return 2;
    if (location.startsWith(AppRoutePaths.adminOrders)) return 3;
    if (location.startsWith(AppRoutePaths.adminSettings)) return 4;
    return 0; // /admin/overview
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);

    return Scaffold(
      body: Column(
        children: [
          // ─── Branded Top Bar ───
          const _AdminTopBar(),

          // ─── Content ───
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: _AdminBottomNav(currentIndex: index),
    );
  }
}

/// Top bar matching React AdminLayout:
/// Left: DineIn mark + "DineIn HQ" + "Admin Console" micro-label
/// Right: Bell (with glow dot) + admin avatar
/// Glass backdrop blur.
class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.60),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space6,
                vertical: AppTheme.space4,
              ),
              child: Row(
                children: [
                  // ─── Brand Mark + Brand ───
                  PressableScale(
                    onTap: () => context.goNamed(AppRouteNames.adminOverview),
                    child: Row(
                      children: [
                        const BrandMark(
                          size: 40,
                          borderRadius: 12,
                          fontSize: 24,
                          shadowBlur: 18,
                          shadowOpacity: 0.20,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const DineInLogoText(
                              fontSize: 18,
                              suffix: ' HQ',
                            ),
                            Text(
                              'ADMIN CONSOLE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // ─── Avatar ───
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                      boxShadow: AppTheme.clayShadow,
                    ),
                    child: Center(
                      child: Text(
                        'A',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


/// Bottom nav matching React AdminLayout:
/// 5 tabs: Overview, Venues, Menus, Orders, Settings
/// Active tab: w-14 h-9 primary-bg pill + indicator dot below
/// Glass backdrop blur.
class _AdminBottomNav extends StatelessWidget {
  final int currentIndex;

  const _AdminBottomNav({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final items = [
      _NavData(
        icon: LucideIcons.layoutDashboard,
        label: 'Overview',
        routeName: AppRouteNames.adminOverview,
      ),
      _NavData(
        icon: LucideIcons.store,
        label: 'Venues',
        routeName: AppRouteNames.adminVenues,
      ),
      _NavData(
        icon: LucideIcons.menu,
        label: 'Menus',
        routeName: AppRouteNames.adminMenus,
      ),
      _NavData(
        icon: LucideIcons.shoppingBag,
        label: 'Orders',
        routeName: AppRouteNames.adminOrders,
      ),
      _NavData(
        icon: LucideIcons.settings,
        label: 'Settings',
        routeName: AppRouteNames.adminSettings,
      ),
    ];

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.60),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space4,
                vertical: AppTheme.space4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(items.length, (i) {
                  final item = items[i];
                  final isActive = currentIndex == i;

                  return PressableScale(
                    onTap: () => context.goNamed(item.routeName),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon pill — active gets primary bg + shadow
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          width: 56,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isActive ? cs.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: isActive ? AppTheme.clayShadow : [],
                          ),
                          child: Center(
                            child: AnimatedScale(
                              scale: isActive ? 1.1 : 1.0,
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                item.icon,
                                size: 20,
                                color: isActive
                                    ? cs.onPrimary
                                    : cs.onSurface.withValues(alpha: 0.40),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Label: 9px font-black uppercase
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: isActive
                                ? cs.primary
                                : cs.onSurface.withValues(alpha: 0.20),
                          ),
                          child: Text(item.label.toUpperCase()),
                        ),
                        const SizedBox(height: 4),
                        // ─── Indicator dot ───
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          width: isActive ? 6 : 0,
                          height: isActive ? 6 : 0,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: cs.primary.withValues(alpha: 0.80),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : [],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavData {
  final IconData icon;
  final String label;
  final String routeName;
  const _NavData({
    required this.icon,
    required this.label,
    required this.routeName,
  });
}
