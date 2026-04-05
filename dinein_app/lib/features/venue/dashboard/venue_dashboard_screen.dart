import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/bell_request.dart';
import 'package:db_pkg/models/models.dart';
import '../../../core/providers/bell_providers.dart';
import '../../../core/providers/providers.dart';
import 'package:dinein_app/core/services/bell_repository.dart';
import 'package:dinein_app/core/services/venue_repository.dart';
import 'package:ui/widgets/shared_widgets.dart';

part 'widgets/dashboard_widgets.dart';

/// Venue dashboard — matches the provided Figma screenshots.
///
/// Data sources (all from Supabase):
/// - Venue info → [currentVenueProvider]
/// - Orders → [venueOrdersProvider] (Supabase Realtime StreamProvider)
/// - Menu items → [menuItemsProvider]
/// - Revenue/guests → computed from orders
/// - Activation toggle → [VenueRepository.updateVenue]
class VenueDashboardScreen extends ConsumerWidget {
  const VenueDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueAsync = ref.watch(currentVenueProvider);

    return venueAsync.when(
      loading: () => const Scaffold(
        body: Center(
          child: SkeletonLoader(width: double.infinity, height: 200),
        ),
      ),
      error: (err, _) => Scaffold(
        body: ErrorState(
          message: 'Could not load dashboard.',
          onRetry: () => ref.invalidate(currentVenueProvider),
        ),
      ),
      data: (venue) {
        if (venue == null) {
          return const Scaffold(
            body: EmptyState(
              icon: LucideIcons.store,
              title: 'No venue access',
              subtitle: 'Claim and verify a venue to unlock the portal.',
            ),
          );
        }
        return _DashboardBody(venue: venue);
      },
    );
  }
}

class _DashboardBody extends ConsumerStatefulWidget {
  final Venue venue;

  const _DashboardBody({required this.venue});

  @override
  ConsumerState<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends ConsumerState<_DashboardBody> {
  late bool _isActive = widget.venue.canAcceptGuestOrders;
  bool _isTogglingActivation = false;

  @override
  void didUpdateWidget(covariant _DashboardBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.venue.id != widget.venue.id ||
        oldWidget.venue.status != widget.venue.status ||
        oldWidget.venue.orderingEnabled != widget.venue.orderingEnabled) {
      _isActive = widget.venue.canAcceptGuestOrders;
    }
  }

  String _formattedToday() {
    return DateFormat('MMMM d, yyyy').format(DateTime.now()).toUpperCase();
  }

  String get _currencySymbol => widget.venue.country.currencySymbol;

  Future<void> _toggleActivation() async {
    if (_isTogglingActivation) return;
    setState(() {
      _isTogglingActivation = true;
      _isActive = !_isActive;
    });
    try {
      await VenueRepository.instance.updateVenue(widget.venue.id, {
        'status': _isActive ? 'active' : 'inactive',
      });
      ref.invalidate(currentVenueProvider);
    } catch (_) {
      // Revert on failure
      if (mounted) setState(() => _isActive = !_isActive);
    } finally {
      if (mounted) setState(() => _isTogglingActivation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final ordersAsync = ref.watch(venueOrdersProvider(widget.venue.id));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ═══ HEADER ═══
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard',
                    style: tt.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.calendar,
                        size: 12,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formattedToday(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  // LIVE / OFF badge
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: (_isActive ? AppColors.secondary : cs.error)
                          .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (_isActive ? AppColors.secondary : cs.error)
                            .withValues(alpha: 0.20),
                      ),
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _isActive ? AppColors.secondary : cs.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isActive ? 'LIVE' : 'OFF',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: _isActive ? AppColors.secondary : cs.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Chart icon
                  PressableScale(
                    onTap: () => context.goNamed(AppRouteNames.venueOrders),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Icon(
                        LucideIcons.barChart3,
                        size: 18,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space6),

          // ═══ VENUE ACTIVATION TOGGLE ═══
          PressableScale(
            onTap: _toggleActivation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                boxShadow: AppTheme.elevatedShadow,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Venue Activation',
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isActive ? 'ACCEPTING ORDERS' : 'ORDERING DISABLED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  // Toggle switch
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 50,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _isActive
                          ? AppColors.secondary
                          : cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      alignment: _isActive
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black12, blurRadius: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: AppTheme.space4),

          // ═══ STAT CARDS (from orders) ═══
          ordersAsync.when(
            loading: () => Column(
              children: [
                _StatCardSkeleton(),
                const SizedBox(height: AppTheme.space3),
                _StatCardSkeleton(),
                const SizedBox(height: AppTheme.space3),
                _StatCardSkeleton(),
              ],
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (orders) {
              final todayOrders = orders.where((o) {
                final today = DateTime.now();
                return o.createdAt.day == today.day &&
                    o.createdAt.month == today.month &&
                    o.createdAt.year == today.year;
              }).toList();
              final totalRevenue = orders.fold<double>(
                0,
                (sum, o) => sum + o.total,
              );
              final activeOrders = orders
                  .where((o) => o.status.isActive)
                  .length;
              final totalGuests = orders.length;
              return Row(
                children: [
                  Expanded(
                    child: _CompactKpi(
                      label: 'REVENUE',
                      value:
                          '$_currencySymbol${totalRevenue.toStringAsFixed(totalRevenue > 999 ? 0 : 2)}',
                      sub: '${todayOrders.length} today',
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: AppTheme.space3),
                  Expanded(
                    child: _CompactKpi(
                      label: 'ACTIVE',
                      value: '$activeOrders',
                      sub: '${orders.length} total',
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: AppTheme.space3),
                  Expanded(
                    child: _CompactKpi(
                      label: 'GUESTS',
                      value: '$totalGuests',
                      sub: '${todayOrders.length} today',
                      color: cs.tertiary,
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms);
            },
          ),
          const SizedBox(height: AppTheme.space5),

          // ═══ RECENT ORDERS ═══
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Orders',
                style: tt.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              PressableScale(
                onTap: () => context.goNamed(AppRouteNames.venueOrders),
                child: Text(
                  'VIEW ALL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space4),
          ordersAsync.when(
            loading: () => Column(
              children: List.generate(
                3,
                (_) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.space3),
                  child: SkeletonLoader(width: double.infinity, height: 72),
                ),
              ),
            ),
            error: (_, _) => const EmptyState(
              icon: LucideIcons.inbox,
              title: 'Could not load orders',
              subtitle: 'Pull down to refresh.',
            ),
            data: (orders) {
              final recent = orders.take(6).toList();
              if (recent.isEmpty) {
                return const EmptyState(
                  icon: LucideIcons.inbox,
                  title: 'No orders yet',
                  subtitle:
                      'Orders will appear here when customers place them.',
                );
              }
              return Column(
                children: recent.asMap().entries.map((entry) {
                  final order = entry.value;
                  final idx = entry.key;
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: idx < recent.length - 1 ? AppTheme.space3 : 0,
                    ),
                    child: RepaintBoundary(
                      child:
                        _OrderPreview(
                              order: order,
                              currencySymbol: _currencySymbol,
                            )
                            .animate(delay: (400 + 80 * idx).ms)
                            .fadeIn(duration: 300.ms),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: AppTheme.space5),

          // ═══ QUICK ACTIONS ═══
          Text(
            'Quick Actions',
            style: tt.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: AppTheme.space4),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: LucideIcons.shoppingBag,
                  label: 'MANAGE MENU',
                  color: cs.surfaceContainerLow,
                  iconColor: cs.primary,
                  textColor: cs.onSurface,
                  onTap: () => context.goNamed(AppRouteNames.venueMenu),
                ),
              ),
              const SizedBox(width: AppTheme.space3),
              Expanded(
                child: _QuickAction(
                  icon: LucideIcons.plusCircle,
                  label: 'ADD MENU',
                  color: AppColors.secondary.withValues(alpha: 0.20),
                  iconColor: cs.onSurface,
                  textColor: cs.onSurface,
                  onTap: () => context.pushNamed(AppRouteNames.venueNewItem),
                ),
              ),
            ],
          ).animate(delay: 400.ms).fadeIn(),
          const SizedBox(height: AppTheme.space5),

          // ═══ ACTIVE WAVES ═══
          _ActiveWavesSummary(venueId: widget.venue.id),
          const SizedBox(height: AppTheme.space5),

          // ═══ TOP ITEMS (aggregated from real orders) ═══
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Top Items',
                style: tt.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              PressableScale(
                onTap: () => context.pushNamed(AppRouteNames.venueItemReport),
                child: Text(
                  'FULL REPORT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space4),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              boxShadow: AppTheme.clayShadow,
            ),
            child: ordersAsync.when(
              loading: () =>
                  const SkeletonLoader(width: double.infinity, height: 80),
              error: (_, _) => const Text('Could not load order data'),
              data: (orders) {
                // Aggregate per-item stats from real orders
                final itemMap = <String, _TopItemStat>{};
                for (final order in orders) {
                  for (final item in order.items) {
                    final key = item.name;
                    final existing = itemMap[key];
                    if (existing != null) {
                      itemMap[key] = _TopItemStat(
                        name: item.name,
                        totalOrders: existing.totalOrders + item.quantity,
                        totalRevenue: existing.totalRevenue + item.subtotal,
                      );
                    } else {
                      itemMap[key] = _TopItemStat(
                        name: item.name,
                        totalOrders: item.quantity,
                        totalRevenue: item.subtotal,
                      );
                    }
                  }
                }

                // Sort by revenue descending, take top 5
                final topItems = itemMap.values.toList()
                  ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
                final top = topItems.take(5).toList();

                if (top.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.space4,
                    ),
                    child: Center(
                      child: Text(
                        'No order data yet',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }

                // Compute max revenue for relative percentage display
                final maxRevenue = top.first.totalRevenue;

                return Column(
                  children: top.asMap().entries.map((entry) {
                    final item = entry.value;
                    final idx = entry.key;
                    final revenuePct = maxRevenue > 0
                        ? (item.totalRevenue / maxRevenue * 100).round()
                        : 0;
                    return Column(
                      children: [
                        if (idx > 0)
                          Divider(
                            height: 28,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: tt.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.totalOrders} ORDERS',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$_currencySymbol${item.totalRevenue.toStringAsFixed(item.totalRevenue > 999 ? 0 : 2)}',
                                  style: tt.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$revenuePct%',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
          ),

          const SizedBox(height: AppTheme.space24),
        ],
      ),
    );
  }
}

