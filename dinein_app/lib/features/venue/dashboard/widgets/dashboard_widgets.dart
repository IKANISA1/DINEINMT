part of '../venue_dashboard_screen.dart';
// ═══════════════════════════════════════════════════
// PRIVATE WIDGETS
// ═══════════════════════════════════════════════════

/// Stat card with green circle icon, value, and trend badge.
// ignore: unused_element
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

/// Compact single-value KPI card for 3-column dashboard row.
class _CompactKpi extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;

  const _CompactKpi({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Color accent bar
          Container(
            width: 24,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant.withValues(alpha: 0.60),
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
              width: 72,
              height: 40,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '#${order.displayNumber}',
                  style: TextStyle(
                    fontSize: 11,
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
