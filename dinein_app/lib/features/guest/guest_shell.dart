import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import 'package:dinein_app/shared/widgets/pwa_install_banner.dart';

import 'package:core_pkg/config/country_config.dart';
import 'package:core_pkg/config/country_config_provider.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/core/services/discovery_location_service.dart';
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
    if (location.startsWith(AppRoutePaths.guestSettings)) return 1;
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
          body: PwaInstallBanner(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: AppLayout.guestContentMaxWidth(
                    constraints.maxWidth,
                  ),
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
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space3,
              0,
              AppTheme.space3,
              AppTheme.space2,
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
      body: PwaInstallBanner(
        child: Row(
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
      ),
    );
  }
}

class _TopAppBar extends ConsumerStatefulWidget {
  const _TopAppBar();

  @override
  ConsumerState<_TopAppBar> createState() => _TopAppBarState();
}

class _TopAppBarState extends ConsumerState<_TopAppBar> {
  bool _requestingLocation = false;

  Future<void> _shareApp(CountryConfig config) async {
    await SharePlus.instance.share(
      ShareParams(
        title: config.appTitle,
        text:
            'Discover venues on ${config.appTitle}.\nhttps://${config.siteHost}',
      ),
    );
  }

  Future<void> _requestLocation() async {
    if (_requestingLocation) return;
    setState(() => _requestingLocation = true);
    try {
      final result = await ref
          .read(discoveryLocationServiceProvider)
          .getCurrentLocation(requestIfNeeded: true);
      ref.invalidate(discoveryLocationProvider);
      if (result == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location unavailable. Enable it in browser settings to rank venues near you.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _requestingLocation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(countryConfigProvider);
    final cs = Theme.of(context).colorScheme;
    final hasLocation =
        ref.watch(discoveryLocationProvider).asData?.value != null;

    return AdaptiveGlassSurface(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        border: Border(bottom: BorderSide(color: AppColors.white5)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space4,
            vertical: AppTheme.space2,
          ),
          child: Row(
            children: [
              PressableScale(
                onTap: () => context.goNamed(AppRouteNames.discover),
                semanticLabel: 'Open guest portal',
                child: const BrandMark(
                  size: 34,
                  borderRadius: AppTheme.radiusFull,
                  shadowBlur: 14,
                  shadowOpacity: 0.24,
                ),
              ),
              const Spacer(),
              // Location icon
              _requestingLocation
                  ? Padding(
                      padding: const EdgeInsets.all(5),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.primary,
                        ),
                      ),
                    )
                  : _AppBarIcon(
                      icon: hasLocation
                          ? LucideIcons.navigation
                          : LucideIcons.mapPin,
                      onTap: _requestLocation,
                      isActive: hasLocation,
                    ),
              const SizedBox(width: 4),
              // Search icon
              _AppBarIcon(
                icon: LucideIcons.search,
                onTap: () => context.goNamed(
                  AppRouteNames.venuesBrowse,
                  queryParameters: const {AppRouteParams.search: '1'},
                ),
              ),
              const SizedBox(width: 4),
              // Notifications
              const NotificationBellButton(),
              const SizedBox(width: 4),
              // Share
              _AppBarIcon(
                icon: LucideIcons.share2,
                onTap: () => _shareApp(config),
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
  final bool isActive;

  const _AppBarIcon({
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

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
          child: Icon(
            icon,
            size: 22,
            color: isActive ? cs.primary : cs.onSurfaceVariant,
          ),
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
      case LucideIcons.mapPin:
      case LucideIcons.navigation:
        return 'Use my location';
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
              horizontal: AppTheme.space4,
              vertical: 2,
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
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isActive ? cs.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSm,
                            ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: cs.primary.withValues(alpha: 0.28),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            item.icon,
                            size: 18,
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
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              item.label.toUpperCase(),
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                          secondChild: const SizedBox(height: 2),
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
    label: 'Home',
    routeName: AppRouteNames.discover,
  ),
  _NavData(
    icon: LucideIcons.settings,
    label: 'Settings',
    routeName: AppRouteNames.guestSettings,
  ),
];
