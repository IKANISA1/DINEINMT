import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/cart_provider.dart';
import '../../shared/widgets/shared_widgets.dart';

/// Guest shell — matches React GuestLayout.tsx exactly.
///
/// Top app bar: D logo + brand name + share/search/cart actions.
/// Bottom nav:  Discover | Venues | Orders | Profile (4 items)
/// Active tab:  Primary BG + shadow + translate-y lift.
class GuestShell extends ConsumerWidget {
  final Widget child;

  const GuestShell({super.key, required this.child});

  /// Bottom nav index: 0 = Home (Discover + Venues), 1 = Settings (Profile + Orders)
  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(AppRoutePaths.guestSettings) ||
        location.startsWith(AppRoutePaths.orderHistory) ||
        location.startsWith(AppRoutePaths.orderBase)) {
      return 1;
    }
    return 0; // /discover, /venues, and everything else
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = _currentIndex(context);
    final cart = ref.watch(cartProvider);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448),
          child: Column(
            children: [
              // ─── Top App Bar (premium blur) ───
              _TopAppBar(
                cartItemCount: cart.itemCount,
                cartVenueId: cart.venueId,
              ),

              // ─── Content ───
              Expanded(child: child),
            ],
          ),
        ),
      ),

      // ─── Bottom Navigation ───
      bottomNavigationBar: _BottomNav(currentIndex: index),
    );
  }
}

/// Top app bar matching React GuestLayout:
/// Left: D logo pill + "DineIn" brand
/// Right: Wave (Call Staff), Share, Search, Cart
/// Frosted glass backdrop blur.
class _TopAppBar extends StatelessWidget {
  final int cartItemCount;
  final String? cartVenueId;

  const _TopAppBar({required this.cartItemCount, this.cartVenueId});

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
                   // ─── Logo + Brand ───
                  PressableScale(
                    onTap: () => context.goNamed(AppRouteNames.discover),
                    child: Row(
                      children: [
                        const BrandMark(
                          size: 32,
                          borderRadius: 8,
                          fontSize: 19,
                          shadowBlur: 12,
                          shadowOpacity: 0.20,
                        ),
                        const SizedBox(width: 8),
                        const DineInLogoText(
                          fontSize: 20,
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // ─── Action Icons ───
                  // Wave (Call Staff)
                  if (cartVenueId != null) ...[
                    _AppBarIcon(
                      icon: LucideIcons.hand,
                      onTap: () {
                        // Show bottom sheet to capture table number and send wave
                        WaveBottomSheet.show(context, cartVenueId!);
                      },
                    ),
                    const SizedBox(width: 4),
                  ],
                  // Share
                  _AppBarIcon(
                    icon: LucideIcons.share2,
                    onTap: () async {
                      await SharePlus.instance.share(
                        ShareParams(
                          title: 'DINEIN - Private Culinary Experiences',
                          text: 'Check out these exclusive venues on DINEIN!',
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  // Search
                  _AppBarIcon(
                    icon: LucideIcons.search,
                    onTap: () => context.goNamed(AppRouteNames.venuesBrowse),
                  ),
                  const SizedBox(width: 4),
                  // Cart
                  GestureDetector(
                    onTap: () => context.goNamed(AppRouteNames.cart),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            LucideIcons.shoppingBag,
                            size: 20,
                            color: cs.onSurfaceVariant,
                          ),
                          if (cartItemCount > 0)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: cs.surface,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
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

class _AppBarIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _AppBarIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PressableScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 20, color: cs.onSurfaceVariant),
      ),
    );
  }
}

/// Bottom navigation — 4 items matching React GuestLayout:
/// Discover (Home) | Venues (Store) | Orders (History) | Profile (User)
///
/// Active tab: primary bg, shadow, -translate-y lift.
/// Label: 9px font-black uppercase.
/// Frosted glass backdrop blur.
class _BottomNav extends StatelessWidget {
  final int currentIndex;

  const _BottomNav({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // STARTER RULES §1: Customer bottom nav = EXACTLY 2 items.
    final items = [
      _NavData(
        icon: LucideIcons.home,
        label: 'Home',
        routeName: AppRouteNames.discover,
      ),
      _NavData(
        icon: LucideIcons.user,
        label: 'Settings',
        routeName: AppRouteNames.guestSettings,
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
                horizontal: AppTheme.space6,
                vertical: 12,
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
                        // Icon container — active gets primary bg + shadow + lift
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.all(10),
                          transform: Matrix4.translationValues(
                            0,
                            isActive ? -4 : 0,
                            0,
                          ),
                          decoration: BoxDecoration(
                            color: isActive ? cs.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: cs.primary.withValues(alpha: 0.30),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Icon(
                            item.icon,
                            size: 24,
                            color: isActive
                                ? cs.onPrimary
                                : cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Label — 9px font-black uppercase
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: isActive ? 1.0 : 0.4,
                          child: AnimatedSlide(
                            duration: const Duration(milliseconds: 300),
                            offset: Offset(0, isActive ? 0 : 0.2),
                            child: Text(
                              item.label.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                color: cs.onSurface,
                              ),
                            ),
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
