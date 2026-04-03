import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_layout.dart';
import '../../core/providers/providers.dart';
import '../../core/providers/bell_providers.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'package:flutter/services.dart';
import 'shared/bell_requests_sheet.dart';

/// Venue portal shell — matches React VenueLayout.tsx exactly.
///
/// Top bar: V badge (secondary) + venue name + "VENUE MANAGER" label + bell + avatar
/// Bottom nav: 4 tabs with secondary-colored active pill + shadow + lift
/// Both bars use BackdropFilter glass blur.
class VenueShell extends ConsumerWidget {
  final Widget child;

  const VenueShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(AppRoutePaths.venueOrders)) return 1;
    if (location.startsWith(AppRoutePaths.venueMenu)) return 2;
    if (location.startsWith(AppRoutePaths.venueSettings) ||
        location.startsWith(AppRoutePaths.venueProfile) ||
        location.startsWith(AppRoutePaths.venueTableQr)) {
      return 3;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = _currentIndex(context);
    final venueAsync = ref.watch(currentVenueProvider);
    final venueId = venueAsync.value?.id;
    final venueName = venueAsync.value?.name ?? 'Venue Portal';
    final venueImageUrl = venueAsync.value?.imageUrl;

    if (venueId != null) {
      ref.listen(pendingWavesProvider(venueId), (previous, next) {
        if (next.hasValue && next.value != null && previous?.value != null) {
          if (next.value!.length > previous!.value!.length) {
            HapticFeedback.heavyImpact();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '🔔 New staff request (Table ${next.value!.last.tableNumber})',
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        }
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppLayout.opsRailBreakpoint) {
          return _WideVenueShell(
            currentIndex: index,
            venueName: venueName,
            venueId: venueId,
            avatarUrl: venueImageUrl,
            screenWidth: constraints.maxWidth,
            child: child,
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
                  _VenueTopBar(
                    venueName: venueName,
                    avatarUrl: venueImageUrl,
                    venueId: venueId,
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
          bottomNavigationBar: _VenueBottomNav(currentIndex: index),
        );
      },
    );
  }
}

class _WideVenueShell extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  final String venueName;
  final String? avatarUrl;
  final String? venueId;
  final double screenWidth;

  const _WideVenueShell({
    required this.child,
    required this.currentIndex,
    required this.venueName,
    required this.avatarUrl,
    required this.venueId,
    required this.screenWidth,
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
                            size: 36,
                            borderRadius: 12,
                            fontSize: 21,
                            shadowBlur: 12,
                            shadowOpacity: 0.20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  venueName,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.3,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Venue manager',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: AppColors.secondary),
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
                            context.goNamed(_venueNavItems[index].routeName),
                        backgroundColor: Colors.transparent,
                        labelType: NavigationRailLabelType.all,
                        leading: venueId != null
                            ? Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _VenueRailSummary(
                                  venueName: venueName,
                                  avatarUrl: avatarUrl,
                                ),
                              )
                            : null,
                        destinations: [
                          for (final item in _venueNavItems)
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
                    _VenueTopBar(
                      venueName: venueName,
                      avatarUrl: avatarUrl,
                      venueId: venueId,
                    ),
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

class _VenueRailSummary extends StatelessWidget {
  final String venueName;
  final String? avatarUrl;

  const _VenueRailSummary({required this.venueName, required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: avatarUrl != null
                ? DineInImage(
                    imageUrl: avatarUrl,
                    fit: BoxFit.cover,
                    borderRadius: 12,
                    fallbackIcon: LucideIcons.store,
                  )
                : Icon(LucideIcons.store, size: 18, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              venueName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Top bar matching React VenueLayout:
/// Left: DineIn mark + venue name + "VENUE MANAGER" micro-label
/// Right: Bell icon (with notif dot) + avatar
/// Glass backdrop blur.
class _VenueTopBar extends ConsumerWidget {
  final String venueName;
  final String? avatarUrl;
  final String? venueId;

  const _VenueTopBar({required this.venueName, this.avatarUrl, this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              // ─── Brand Mark + Venue Name ───
              PressableScale(
                onTap: () => context.goNamed(AppRouteNames.venueDashboard),
                semanticLabel: 'Open venue dashboard',
                child: Row(
                  children: [
                    const BrandMark(
                      size: 36,
                      borderRadius: 12,
                      fontSize: 21,
                      shadowBlur: 12,
                      shadowOpacity: 0.20,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          venueName,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            letterSpacing: -0.3,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          'VENUE MANAGER',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.5,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // ─── Bell Notifications ───
              if (venueId != null)
                Builder(
                  builder: (context) {
                    final wavesAsync = ref.watch(
                      pendingWavesProvider(venueId!),
                    );
                    final count = wavesAsync.value?.length ?? 0;
                    final label = count > 0
                        ? 'Open staff requests, $count pending'
                        : 'Open staff requests';
                    return Tooltip(
                      message: label,
                      child: PressableScale(
                        onTap: () => BellRequestsSheet.show(context, venueId!),
                        semanticLabel: label,
                        minTouchTargetSize: const Size(44, 44),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                LucideIcons.bell,
                                size: 24,
                                color: count > 0
                                    ? cs.onSurface
                                    : cs.onSurfaceVariant,
                              ),
                              if (count > 0)
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: cs.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: cs.surface,
                                        width: 2,
                                      ),
                                    ),
                                    child: Text(
                                      count.toString(),
                                      style: TextStyle(
                                        color: cs.onPrimary,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(width: 8),

              // ─── Avatar ───
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: avatarUrl != null
                    ? DineInImage(
                        imageUrl: avatarUrl,
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                        borderRadius: 12,
                        fallbackIcon: LucideIcons.user,
                      )
                    : Center(
                        child: Text(
                          venueName.isNotEmpty
                              ? venueName[0].toUpperCase()
                              : 'V',
                          style: TextStyle(
                            fontSize: 14,
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
    );
  }
}

/// Bottom nav matching React VenueLayout:
/// 4 tabs: Dashboard, Orders, Menu, Settings
/// Active tab: secondary bg pill + shadow + -translate-y lift
/// Label: 8px font-black uppercase tracking-[0.15em]
/// Glass backdrop blur.
class _VenueBottomNav extends StatelessWidget {
  final int currentIndex;

  const _VenueBottomNav({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AdaptiveGlassSurface(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.60),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_venueNavItems.length, (i) {
              final item = _venueNavItems[i];
              final isActive = currentIndex == i;

              return PressableScale(
                onTap: () => context.goNamed(item.routeName),
                semanticLabel: 'Open ${item.label}',
                child: SizedBox(
                  width: 56,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon pill — active gets secondary bg + shadow + lift
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.all(8),
                        transform: Matrix4.translationValues(
                          0,
                          isActive ? -2 : 0,
                          0,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.secondary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: AppColors.secondary.withValues(
                                      alpha: 0.20,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: Icon(
                          item.icon,
                          size: 20,
                          color: isActive ? Colors.white : cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Label: 8px font-black uppercase
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: isActive ? 1.0 : 0.4,
                        child: Text(
                          item.label.toUpperCase(),
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: cs.onSurface,
                          ),
                          textAlign: TextAlign.center,
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

const _venueNavItems = [
  _NavData(
    icon: LucideIcons.layoutDashboard,
    label: 'Dashboard',
    routeName: AppRouteNames.venueDashboard,
  ),
  _NavData(
    icon: LucideIcons.shoppingCart,
    label: 'Orders',
    routeName: AppRouteNames.venueOrders,
  ),
  _NavData(
    icon: LucideIcons.menu,
    label: 'Menu',
    routeName: AppRouteNames.venueMenu,
  ),
  _NavData(
    icon: LucideIcons.settings,
    label: 'Settings',
    routeName: AppRouteNames.venueSettings,
  ),
];
