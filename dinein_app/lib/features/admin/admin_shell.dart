import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_layout.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';
import 'package:dinein_app/shared/widgets/shell_scroll_chrome.dart';

/// Admin portal shell — matches React AdminLayout.tsx exactly.
///
/// Top bar: ShieldCheck logo (primary) + "DineIn HQ" + "Admin Console" label + bell + avatar
/// Bottom nav: 4 tabs with primary-bg pill + indicator dot
/// Both bars use BackdropFilter glass blur.
class AdminShell extends StatefulWidget {
  final Widget child;

  const AdminShell({super.key, required this.child});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  bool _topBarVisible = true;
  String? _lastLocation;

  void _setTopBarVisible(bool visible) {
    if (!mounted || _topBarVisible == visible) return;
    setState(() => _topBarVisible = visible);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).uri.toString();
    if (_lastLocation != location) {
      _lastLocation = location;
      _topBarVisible = true;
    }
  }

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(AppRoutePaths.adminVenues)) return 1;
    if (location.startsWith(AppRoutePaths.adminOrders)) return 2;
    if (location.startsWith(AppRoutePaths.adminSettings)) return 3;
    return 0; // /admin/overview
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppLayout.opsRailBreakpoint) {
          return _WideAdminShell(
            currentIndex: index,
            screenWidth: constraints.maxWidth,
            topBarVisible: _topBarVisible,
            onTopBarVisibilityChanged: _setTopBarVisible,
            child: widget.child,
          );
        }

        return Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: AppLayout.opsContentMaxWidth(constraints.maxWidth),
              ),
              child: Column(
                children: [
                  CollapsibleShellBar(
                    visible: _topBarVisible,
                    child: const _AdminTopBar(),
                  ),
                  Expanded(
                    child: ShellScrollNotificationHost(
                      onTopBarVisibilityChanged: _setTopBarVisible,
                      child: widget.child,
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space4,
              0,
              AppTheme.space4,
              AppTheme.space4,
            ),
            child: _AdminBottomNav(currentIndex: index),
          ),
        );
      },
    );
  }
}

class _WideAdminShell extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  final double screenWidth;
  final bool topBarVisible;
  final ValueChanged<bool> onTopBarVisibilityChanged;

  const _WideAdminShell({
    required this.child,
    required this.currentIndex,
    required this.screenWidth,
    required this.topBarVisible,
    required this.onTopBarVisibilityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: AppLayout.opsRailWidth(screenWidth),
            child: AdaptiveGlassSurface(
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.92),
                border: Border(
                  right: BorderSide(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
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
                              Text(
                                'HQ',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                'Admin console',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: cs.primary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: NavigationRail(
                        selectedIndex: currentIndex,
                        onDestinationSelected: (index) =>
                            context.goNamed(_adminNavItems[index].routeName),
                        backgroundColor: Colors.transparent,
                        labelType: NavigationRailLabelType.all,
                        destinations: [
                          for (final item in _adminNavItems)
                            NavigationRailDestination(
                              icon: Icon(item.icon),
                              selectedIcon: Icon(item.icon),
                              label: Text(item.label),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          VerticalDivider(
            width: 1,
            color: Colors.white.withValues(alpha: 0.05),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: AppLayout.opsContentMaxWidth(screenWidth),
                ),
                child: Column(
                  children: [
                    CollapsibleShellBar(
                      visible: topBarVisible,
                      child: const _AdminTopBar(),
                    ),
                    Expanded(
                      child: ShellScrollNotificationHost(
                        onTopBarVisibilityChanged: onTopBarVisibilityChanged,
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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

    return AdaptiveGlassSurface(
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
                semanticLabel: 'Open admin overview',
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
                        Text(
                          'HQ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          'Admin console',
                          style: TextStyle(
                            fontSize: 10,
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
                ),
                child: Center(
                  child: Text(
                    'A',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom nav matching React AdminLayout:
/// 4 tabs: Overview, Venues, Orders, Settings
/// Active tab: w-14 h-9 primary-bg pill + indicator dot below
/// Glass backdrop blur.
class _AdminBottomNav extends StatelessWidget {
  final int currentIndex;

  const _AdminBottomNav({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppSurfaceCard(
      radius: AppTheme.radiusXxl,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space3,
        vertical: AppTheme.space3,
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_adminNavItems.length, (i) {
            final item = _adminNavItems[i];
            final isActive = currentIndex == i;

            return PressableScale(
              onTap: () => context.goNamed(item.routeName),
              semanticLabel: 'Open ${item.label}',
              child: SizedBox(
                width: 68,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: 44,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isActive
                            ? cs.primaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Icon(
                        item.icon,
                        size: 20,
                        color: isActive ? cs.primary : cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: isActive ? cs.primary : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
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

const _adminNavItems = [
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
