import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:dinein_app/shared/widgets/pwa_install_banner.dart';

import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/core/services/discovery_location_service.dart';
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
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  border: Border(
                    right: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.72),
                    ),
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                        child: Row(
                          children: [
                            const BrandMark(
                              size: 36,
                              borderRadius: AppTheme.radiusFull,
                              shadowBlur: 12,
                              shadowOpacity: 0.14,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'DineIn',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
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
                          indicatorColor: cs.primaryContainer,
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
    final cs = Theme.of(context).colorScheme;
    final hasLocation =
        ref.watch(discoveryLocationProvider).asData?.value != null;

    return GlassHeader(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space4,
        AppTheme.space3,
        AppTheme.space4,
        AppTheme.space2,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            PressableScale(
              onTap: () => context.goNamed(AppRouteNames.discover),
              semanticLabel: 'Open guest portal',
              child: Row(
                children: [
                  const BrandMark(
                    size: 32,
                    borderRadius: AppTheme.radiusFull,
                    shadowBlur: 10,
                    shadowOpacity: 0.14,
                  ),
                  const SizedBox(width: 12),
                  Text('DineIn', style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
            const Spacer(),
            if (_requestingLocation)
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.primary,
                  ),
                ),
              )
            else
              _AppBarIcon(
                icon: hasLocation ? LucideIcons.navigation : LucideIcons.mapPin,
                onTap: _requestLocation,
                isActive: hasLocation,
              ),
            const SizedBox(width: 8),
            _AppBarIcon(
              icon: LucideIcons.search,
              onTap: () => context.goNamed(
                AppRouteNames.venuesBrowse,
                queryParameters: const {AppRouteParams.search: '1'},
              ),
            ),
            const SizedBox(width: 8),
            _AppBarIcon(
              icon: LucideIcons.receipt,
              onTap: () => context.goNamed(AppRouteNames.orderHistory),
            ),
            const SizedBox(width: 8),
            const NotificationBellButton(),
          ],
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
    return Tooltip(
      message: _semanticLabel,
      child: AppIconButton(
        icon: icon,
        onTap: onTap,
        selected: isActive,
        semanticLabel: _semanticLabel,
      ),
    );
  }

  String get _semanticLabel {
    switch (icon) {
      case LucideIcons.receipt:
        return 'Open order history';
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
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.72)),
        boxShadow: AppTheme.ambientShadow,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space2),
          child: Row(
            children: List.generate(_guestNavItems.length, (index) {
              final item = _guestNavItems[index];
              final isActive = currentIndex == index;

              return Expanded(
                child: PressableScale(
                  onTap: () => context.goNamed(item.routeName),
                  semanticLabel: 'Open ${item.label}',
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? cs.primaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.icon,
                          size: 18,
                          color: isActive ? cs.primary : cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            item.label,
                            overflow: TextOverflow.ellipsis,
                            style: tt.labelMedium?.copyWith(
                              color: isActive
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
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
