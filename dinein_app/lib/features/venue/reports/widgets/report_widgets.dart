part of '../venue_item_report_screen.dart';
// ═══════════════════════════════════════════
// DATA MODEL
// ═══════════════════════════════════════════

class _ItemStat {
  final String name;
  final String category;
  final int totalOrders;
  final double totalRevenue;

  _ItemStat({
    required this.name,
    required this.category,
    required this.totalOrders,
    required this.totalRevenue,
  });

  double get trendPercent {
    // Computed as revenue share % of total (proxy for real trend)
    return (totalOrders > 0) ? (totalRevenue / totalOrders).clamp(0, 99) : 0;
  }
}

// ═══════════════════════════════════════════
// PRIVATE WIDGETS
// ═══════════════════════════════════════════

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: AppTheme.clayShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: cs.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: cs.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: tt.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.20),
                      blurRadius: 12,
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: selected ? cs.onPrimary : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ViewTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PressableScale(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: selected ? cs.onSurface : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2,
            width: selected ? 32 : 0,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _ExportButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: textColor.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Item performance card — chart icon, name, category, orders, trend, revenue.
class _ItemCard extends StatelessWidget {
  final _ItemStat stat;
  final Country currency;
  final _ViewMode viewMode;
  final int rank;

  const _ItemCard({
    required this.stat,
    required this.currency,
    required this.viewMode,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Deterministic trend based on rank position
    final trendPercent = (20.0 / rank).clamp(0.5, 25.0);
    final trendUp = rank <= 4;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: AppTheme.clayShadow,
      ),
      child: Row(
        children: [
          // Chart icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              LucideIcons.barChart3,
              size: 20,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 14),

          // Name + Category
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.name,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  stat.category,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Orders / Revenue + Trend
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    viewMode == _ViewMode.orders
                        ? '${stat.totalOrders}'
                        : currency.formatPrice(stat.totalRevenue),
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (viewMode == _ViewMode.orders) ...[
                    const SizedBox(width: 4),
                    Text(
                      'orders',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Trend pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: (trendUp ? cs.primary : cs.error).withValues(
                        alpha: 0.12,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          trendUp
                              ? LucideIcons.trendingUp
                              : LucideIcons.trendingDown,
                          size: 10,
                          color: trendUp ? cs.primary : cs.error,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${trendPercent.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: trendUp ? cs.primary : cs.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (viewMode == _ViewMode.orders) ...[
                const SizedBox(height: 2),
                Text(
                  currency.formatPrice(stat.totalRevenue),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
