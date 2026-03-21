import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/enums.dart';
import '../../../core/models/bell_request.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/bell_providers.dart';
import '../../../core/providers/providers.dart';
import '../../../core/services/bell_repository.dart';
import '../../../core/services/venue_repository.dart';
import '../../../shared/widgets/shared_widgets.dart';

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
  late bool _isActive = widget.venue.status == VenueStatus.active;
  bool _isTogglingActivation = false;

  @override
  void didUpdateWidget(covariant _DashboardBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.venue.id != widget.venue.id ||
        oldWidget.venue.status != widget.venue.status) {
      _isActive = widget.venue.status == VenueStatus.active;
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
          const SizedBox(height: AppTheme.space5),

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
              final todayRevenue = todayOrders.fold<double>(
                0,
                (sum, o) => sum + o.total,
              );
              final activeOrders = orders
                  .where((o) => o.status.isActive)
                  .length;
              final totalGuests = orders.length;

              // Simple trend: today vs yesterday
              final pctRevenue = totalRevenue > 0
                  ? (todayRevenue / totalRevenue * 100)
                  : 0.0;

              return Column(
                children: [
                  _StatCard(
                    icon: LucideIcons.trendingUp,
                    iconBg: cs.primary.withValues(alpha: 0.15),
                    label: 'Total Revenue',
                    value:
                        '$_currencySymbol${totalRevenue.toStringAsFixed(totalRevenue > 999 ? 0 : 2)}',
                    trend: '+${pctRevenue.toStringAsFixed(1)}%',
                    isUp: true,
                  ).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: AppTheme.space3),
                  _StatCard(
                    icon: LucideIcons.shoppingBag,
                    iconBg: AppColors.warning.withValues(alpha: 0.15),
                    label: 'Active Orders',
                    value: '$activeOrders',
                    trend: '+${todayOrders.length}',
                    isUp: true,
                  ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
                  const SizedBox(height: AppTheme.space3),
                  _StatCard(
                    icon: LucideIcons.users,
                    iconBg: cs.tertiary.withValues(alpha: 0.15),
                    label: 'Total Guests',
                    value: '$totalGuests',
                    trend: totalGuests > 0
                        ? '${todayOrders.length} today'
                        : '0 today',
                    isUp: todayOrders.isNotEmpty,
                  ).animate(delay: 200.ms).fadeIn(duration: 400.ms),
                ],
              );
            },
          ),
          const SizedBox(height: AppTheme.space8),

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
              final recent = orders.take(3).toList();
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
                    child:
                        _OrderPreview(
                              order: order,
                              currencySymbol: _currencySymbol,
                            )
                            .animate(delay: (400 + 80 * idx).ms)
                            .fadeIn(duration: 300.ms),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: AppTheme.space8),

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
          const SizedBox(height: AppTheme.space8),

          // ═══ ACTIVE WAVES ═══
          _ActiveWavesSummary(venueId: widget.venue.id),
          const SizedBox(height: AppTheme.space8),

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

// ═══════════════════════════════════════════════════
// PRIVATE WIDGETS
// ═══════════════════════════════════════════════════

/// Stat card with green circle icon, value, and trend badge.
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String label;
  final String value;
  final String trend;
  final bool isUp;

  const _StatCard({
    required this.icon,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.trend,
    required this.isUp,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final trendColor = isUp ? AppColors.secondary : cs.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: AppTheme.clayShadow,
      ),
      child: Row(
        children: [
          // Green circular icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: cs.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: tt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          // Trend badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: trendColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUp ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight,
                  size: 12,
                  color: trendColor,
                ),
                const SizedBox(width: 3),
                Text(
                  trend,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: trendColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton loader matching stat card shape.
class _StatCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space3),
      child: SkeletonLoader(width: double.infinity, height: 80),
    );
  }
}

/// Aggregated per-item stats computed from real order data.
class _TopItemStat {
  final String name;
  final int totalOrders;
  final double totalRevenue;

  const _TopItemStat({
    required this.name,
    required this.totalOrders,
    required this.totalRevenue,
  });
}

/// Dashboard Active Waves summary — shows count + latest 2 pending cards.
class _ActiveWavesSummary extends ConsumerWidget {
  final String venueId;
  const _ActiveWavesSummary({required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final wavesAsync = ref.watch(pendingWavesProvider(venueId));

    return wavesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (waves) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Active Waves',
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (waves.isNotEmpty) ...[
                      const SizedBox(width: AppTheme.space3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${waves.length}',
                          style: TextStyle(
                            color: cs.onPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                PressableScale(
                  onTap: () => context.pushNamed(AppRouteNames.venueWaves),
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
            if (waves.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.space6,
                  horizontal: AppTheme.space4,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                  boxShadow: AppTheme.clayShadow,
                ),
                child: Center(
                  child: Text(
                    'No active waves',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              )
            else
              ...waves
                  .take(2)
                  .map(
                    (wave) => Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.space3),
                      child: _DashboardWaveCard(wave: wave),
                    ),
                  ),
          ],
        );
      },
    );
  }
}

class _DashboardWaveCard extends ConsumerStatefulWidget {
  final BellRequest wave;
  const _DashboardWaveCard({required this.wave});

  @override
  ConsumerState<_DashboardWaveCard> createState() => _DashboardWaveCardState();
}

class _DashboardWaveCardState extends ConsumerState<_DashboardWaveCard> {
  bool _isResolving = false;

  Future<void> _handleResolve() async {
    setState(() => _isResolving = true);
    try {
      await BellRepository.instance.resolveWave(widget.wave.id);
    } catch (e) {
      if (mounted) {
        setState(() => _isResolving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to resolve wave')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final duration = DateTime.now().difference(widget.wave.createdAt);
    final isUrgent = duration.inMinutes >= 5;

    return ClayCard(
      accentGradient: isUrgent,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isUrgent
                  ? cs.error.withValues(alpha: 0.1)
                  : cs.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                widget.wave.tableNumber,
                style: tt.titleMedium?.copyWith(
                  color: isUrgent ? cs.error : cs.onPrimaryContainer,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Table ${widget.wave.tableNumber}',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  'Waiting for ${duration.inMinutes}m',
                  style: tt.bodySmall?.copyWith(
                    color: isUrgent ? cs.error : cs.onSurfaceVariant,
                    fontWeight: isUrgent ? FontWeight.w700 : null,
                  ),
                ),
              ],
            ),
          ),
          if (_isResolving)
            const Padding(
              padding: EdgeInsets.all(AppTheme.space4),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PremiumButton(
              label: 'RESOLVE',
              isSmall: true,
              onPressed: _handleResolve,
            ),
        ],
      ),
    );
  }
}

/// Recent order card — #ID badge + Table + items•price + status pill.
class _OrderPreview extends StatelessWidget {
  final Order order;
  final String currencySymbol;

  const _OrderPreview({required this.order, required this.currencySymbol});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Color statusColor() {
      return switch (order.status) {
        OrderStatus.placed => cs.tertiary,
        OrderStatus.received => AppColors.warning,
        OrderStatus.served => cs.primary,
        OrderStatus.cancelled => cs.error,
      };
    }

    String statusLabel() {
      return switch (order.status) {
        OrderStatus.placed => 'NEW',
        OrderStatus.received => 'PREPARING',
        OrderStatus.served => 'SERVED',
        OrderStatus.cancelled => 'CANCELLED',
      };
    }

    return PressableScale(
      onTap: () => context.pushNamed(
        AppRouteNames.venueOrderDetail,
        pathParameters: {AppRouteParams.id: order.id},
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: AppTheme.clayShadow,
        ),
        child: Row(
          children: [
            // Order ID badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '#${order.id.substring(0, 4).toUpperCase()}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Table ${order.tableNumber ?? '—'}',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${order.itemCount} ITEMS • $currencySymbol${order.total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor().withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                statusLabel(),
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: statusColor(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick action button matching the screenshot layout.
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final Color textColor;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: AppTheme.clayShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const Spacer(),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
