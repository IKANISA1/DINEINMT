import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/country_config.dart';
import '../../core/config/country_config_provider.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';

class GuestShell extends ConsumerWidget {
  final Widget child;

  const GuestShell({super.key, required this.child});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final index = _currentIndex(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppLayout.guestRailBreakpoint) {
          return _WideGuestShell(
            currentIndex: index,
            screenWidth: constraints.maxWidth,
            child: child,
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
                  const _TopAppBar(),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
          bottomNavigationBar: _BottomNav(currentIndex: index),
        );
      },
    );
  }
}

class _WideGuestShell extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  final double screenWidth;

  const _WideGuestShell({
    required this.child,
    required this.currentIndex,
    required this.screenWidth,
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DINEIN',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.8,
                                      ),
                                ),
                                Text(
                                  'Guest portal',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
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
                    const _TopAppBar(),
                    Expanded(child: child),
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
    final tt = Theme.of(context).textTheme;

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
                child: Row(
                  children: [
                    const BrandMark(
                      size: 40,
                      borderRadius: AppTheme.radiusFull,
                      shadowBlur: 18,
                      shadowOpacity: 0.28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'DINEIN',
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _AppBarIcon(
                icon: LucideIcons.share2,
                onTap: () => _shareApp(config),
              ),
              const SizedBox(width: 8),
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

    return AdaptiveGlassSurface(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        border: Border(top: BorderSide(color: AppColors.white5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space6,
            vertical: AppTheme.space3,
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
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isActive ? cs.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLg,
                          ),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: cs.primary.withValues(alpha: 0.28),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ]
                              : null,
                        ),
                        child: Transform.translate(
                          offset: Offset(0, isActive ? -1 : 0),
                          child: Icon(
                            item.icon,
                            size: 24,
                            color: isActive
                                ? cs.onPrimary
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 250),
                        opacity: isActive ? 1 : 0.55,
                        child: Text(
                          item.label.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.8,
                            color: isActive
                                ? cs.onSurface
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
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
