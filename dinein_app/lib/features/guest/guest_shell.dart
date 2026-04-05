import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import 'package:core_pkg/config/country_config.dart';
import 'package:core_pkg/config/country_config_provider.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_layout.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';
import 'package:dinein_app/shared/widgets/shell_scroll_chrome.dart';
import 'package:dinein_app/shared/widgets/notification_bell_button.dart';

class GuestShell extends ConsumerStatefulWidget {
  final Widget child;

  const GuestShell({super.key, required this.child});

  @override
  ConsumerState<GuestShell> createState() => _GuestShellState();
}

class _GuestShellState extends ConsumerState<GuestShell> {
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
    if (location.startsWith(AppRoutePaths.venuesBrowse)) return 1;
    if (location.startsWith('/venue/') ||
        location.startsWith('/cart') ||
        location.startsWith('/item/')) {
      return 1;
    }
    if (location.startsWith(AppRoutePaths.orderHistory) ||
        location.startsWith(AppRoutePaths.orderBase) ||
        location.startsWith(AppRoutePaths.orderSuccess)) {
      return 2;
    }
    if (location.startsWith(AppRoutePaths.guestSettings)) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppLayout.guestRailBreakpoint) {
          return _WideGuestShell(
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
                maxWidth: AppLayout.guestContentMaxWidth(constraints.maxWidth),
              ),
              child: Column(
                children: [
                  CollapsibleShellBar(
                    visible: _topBarVisible,
                    child: const _TopAppBar(),
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
            child: _BottomNav(currentIndex: index),
          ),
        );
      },
    );
  }
}

class _WideGuestShell extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  final double screenWidth;
  final bool topBarVisible;
  final ValueChanged<bool> onTopBarVisibilityChanged;

  const _WideGuestShell({
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
            width: AppLayout.guestRailWidth(screenWidth),
            child: AdaptiveGlassSurface(
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.92),
                border: Border(right: BorderSide(color: AppColors.white5)),
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
                            borderRadius: AppTheme.radiusFull,
                            shadowBlur: 18,
                            shadowOpacity: 0.28,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: NavigationRail(
                        selectedIndex: currentIndex,
                        onDestinationSelected: (index) =>
                            context.goNamed(_guestNavItems[index].routeName),
                        backgroundColor: Colors.transparent,
                        labelType: NavigationRailLabelType.all,
                        destinations: [
                          for (final item in _guestNavItems)
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
          VerticalDivider(width: 1, color: AppColors.white5),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: AppLayout.guestContentMaxWidth(screenWidth),
                ),
                child: Column(
                  children: [
                    CollapsibleShellBar(
                      visible: topBarVisible,
                      child: const _TopAppBar(),
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

class _TopAppBar extends ConsumerWidget {
  const _TopAppBar();

  Future<void> _shareApp(CountryConfig config) async {
    await SharePlus.instance.share(
      ShareParams(
        title: config.appTitle,
        text:
            'Discover venues on ${config.appTitle}.\nhttps://${config.siteHost}',
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(countryConfigProvider);
    final cs = Theme.of(context).colorScheme;

    return AdaptiveGlassSurface(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        border: Border(bottom: BorderSide(color: AppColors.white5)),
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
              PressableScale(
                onTap: () => context.goNamed(AppRouteNames.discover),
                semanticLabel: 'Open guest portal',
                child: const BrandMark(
                  size: 40,
                  borderRadius: AppTheme.radiusFull,
                  shadowBlur: 18,
                  shadowOpacity: 0.28,
                ),
              ),
              const Spacer(),
              _AppBarIcon(
                icon: LucideIcons.share2,
                onTap: () => _shareApp(config),
              ),
              const SizedBox(width: 8),
              const NotificationBellButton(),
              const SizedBox(width: 4),
              _AppBarIcon(
                icon: LucideIcons.search,
                onTap: () => context.goNamed(AppRouteNames.venuesBrowse),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppBarIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _AppBarIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Tooltip(
      message: _semanticLabel,
      child: PressableScale(
        onTap: () => onTap(),
        semanticLabel: _semanticLabel,
        minTouchTargetSize: const Size(44, 44),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 22, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }

  String get _semanticLabel {
    switch (icon) {
      case LucideIcons.share2:
        return 'Share the DineIn app';
      case LucideIcons.search:
        return 'Search venues';
      default:
        return 'Open action';
    }
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;

  const _BottomNav({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppTheme.radiusXxl);

    return ClipRRect(
      borderRadius: radius,
      child: AdaptiveGlassSurface(
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.92),
          borderRadius: radius,
          border: Border.all(color: AppColors.white5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space6,
              vertical: AppTheme.space2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_guestNavItems.length, (index) {
                final item = _guestNavItems[index];
                final isActive = currentIndex == index;

                return Expanded(
                  child: PressableScale(
                    onTap: () => context.goNamed(item.routeName),
                    semanticLabel: 'Open ${item.label}',
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isActive ? cs.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: cs.primary.withValues(alpha: 0.28),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            item.icon,
                            size: 20,
                            color: isActive
                                ? cs.onPrimary
                                : cs.onSurfaceVariant,
                          ),
                        ),
                        // Label visible only on selected tab
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 200),
                          crossFadeState: isActive
                              ? CrossFadeState.showFirst
                              : CrossFadeState.showSecond,
                          firstChild: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              item.label.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.6,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                          secondChild: const SizedBox(height: 4),
                        ),
                      ],
                    ),
                  ),
                );
              }),
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

const _guestNavItems = [
  _NavData(
    icon: LucideIcons.home,
    label: 'Discover',
    routeName: AppRouteNames.discover,
  ),
  _NavData(
    icon: LucideIcons.store,
    label: 'Venues',
    routeName: AppRouteNames.venuesBrowse,
  ),
  _NavData(
    icon: LucideIcons.history,
    label: 'Orders',
    routeName: AppRouteNames.orderHistory,
  ),
  _NavData(
    icon: LucideIcons.user,
    label: 'Profile',
    routeName: AppRouteNames.guestSettings,
  ),
];
