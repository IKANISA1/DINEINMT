import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:core_pkg/config/country_runtime.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';
import '../../../core/providers/providers.dart';
import 'package:ui/widgets/shared_widgets.dart';


/// Admin overview dashboard — system-wide live KPIs.
/// Uses [allVenuesProvider] and [adminDashboardKpisProvider].
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final venuesAsync = ref.watch(allVenuesProvider);
    final kpisAsync = ref.watch(adminDashboardKpisProvider);
    final kpiCards = <Widget>[
      _AdminKpi(
        label: 'TOTAL VENUES',
        value: venuesAsync.when(
          loading: () => '—',
          error: (_, _) => '—',
          data: (v) => '${v.length}',
        ),
        delta: venuesAsync.when(
          loading: () => 'Loading...',
          error: (_, _) => 'Error',
          data: (v) {
            final active = v.where((v) => v.isOpen).length;
            return '$active active';
          },
        ),
        icon: LucideIcons.store,
        color: cs.primary,
      ),
      _AdminKpi(
        label: 'ORDERS TODAY',
        value: kpisAsync.when(
          loading: () => '—',
          error: (_, _) => '—',
          data: (kpis) => '${kpis['orders_today'] ?? 0}',
        ),
        delta: kpisAsync.when(
          loading: () => 'Loading...',
          error: (_, _) => 'Error',
          data: (kpis) {
            final num todayRevenue = kpis['revenue_today'] ?? 0;
            final country = CountryRuntime.config.country;
            return '${country.formatPrice(todayRevenue.toDouble())} total';
          },
        ),
        icon: LucideIcons.shoppingBag,
        color: cs.tertiary,
      ),

      _AdminKpi(
        label: 'TOTAL ORDERS',
        value: kpisAsync.when(
          loading: () => '—',
          error: (_, _) => '—',
          data: (kpis) => '${kpis['total_orders'] ?? 0}',
        ),
        delta: kpisAsync.when(
          loading: () => 'Loading...',
          error: (_, _) => 'Error',
          data: (kpis) {
            final num total = kpis['total_revenue'] ?? 0;
            final country = CountryRuntime.config.country;
            return '${country.formatPrice(total.toDouble())} lifetime';
          },
        ),
        icon: LucideIcons.activity,
        color: cs.secondary,
      ),
    ];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ADMIN',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Overview', style: tt.displaySmall),
                  ],
                ),
              ),
            ),
          ),

          // ─── System KPIs ───
          if (venuesAsync.hasError || kpisAsync.hasError)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space6,
                  vertical: AppTheme.space6,
                ),
                child: ErrorState(
                  message: 'Could not load dashboard data.',
                  onRetry: () {
                    ref.invalidate(allVenuesProvider);
                    ref.invalidate(adminDashboardKpisProvider);
                  },
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.space6),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = constraints.maxWidth;
                    final cardWidth =
                        availableWidth <= AppTheme.space4
                            ? availableWidth
                            : (availableWidth - AppTheme.space4) / 2;
                    return Wrap(
                      spacing: AppTheme.space3,
                      runSpacing: AppTheme.space3,
                      children:
                          kpiCards.asMap().entries.map((entry) {
                            final index = entry.key;
                            final card = entry.value;
                            return SizedBox(
                              width: cardWidth,
                              child: card,
                            );
                          }).toList(),
                    );
                  },
                ),
              ),
            ),

          // ─── System Health ───
          if (!venuesAsync.hasError && !kpisAsync.hasError)
            SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.space6),
              child: Column(
                children: [
                  // Order Exceptions
                  _SystemHealthCard(
                    title: 'Order Exceptions',
                    icon: LucideIcons.alertCircle,
                    iconColor: cs.error,
                    child: kpisAsync.when(
                      loading: () => const SkeletonLoader(
                        width: double.infinity,
                        height: 60,
                      ),
                      error: (_, _) => const Text('Could not load orders'),
                      data: (kpis) {
                        final cancelled = kpis['cancelled_orders'] ?? 0;
                        if (cancelled == 0) {
                          return Text(
                            'No exceptions — all orders running smoothly.',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppTheme.space2),
                              child: Text(
                                '$cancelled cancelled ${cancelled == 1 ? 'order' : 'orders'} need review.',
                                style: tt.bodyMedium?.copyWith(
                                  color: cs.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppTheme.space4),

                  // Active Venues Health
                  venuesAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (venues) {
                      final total = venues.length;
                      final active = venues.where((v) => v.isOpen).length;
                      final pct = total > 0
                          ? (active / total * 100).round()
                          : 0;
                      final offline = total - active;
                      return _SystemHealthCard(
                        title: 'Active Venues',
                        icon: LucideIcons.checkCircle2,
                        iconColor: cs.secondary,
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$pct% Online',
                                  style: tt.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  '$active/$total OPERATIONAL',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.space3),
                            // Progress bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                height: 8,
                                child: Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.05,
                                        ),
                                      ),
                                    ),
                                    FractionallySizedBox(
                                          widthFactor: pct / 100.0,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: cs.secondary,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: cs.secondary
                                                      .withValues(alpha: 0.40),
                                                  blurRadius: 20,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: AppTheme.space3),
                            Text(
                              '$offline venues are currently offline.',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.40,
                                ),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppTheme.space4),

                  // Image Generation Health
                  ref
                      .watch(imageHealthProvider)
                      .when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (stats) {
                          final pct = stats.readyPercent.round();
                          return _SystemHealthCard(
                            title: 'Image Generation',
                            icon: LucideIcons.image,
                            iconColor: cs.primary,
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '$pct% Ready',
                                      style: tt.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    Text(
                                      '${stats.ready}/${stats.total} IMAGES',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 2,
                                        color: cs.onSurfaceVariant.withValues(
                                          alpha: 0.20,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppTheme.space3),
                                // Progress bar
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    height: 8,
                                    child: Stack(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.05,
                                            ),
                                          ),
                                        ),
                                        FractionallySizedBox(
                                              widthFactor: pct / 100.0,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: cs.primary,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: cs.primary
                                                          .withValues(
                                                            alpha: 0.40,
                                                          ),
                                                      blurRadius: 20,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppTheme.space4),
                                // Status chips row
                                Row(
                                  children: [
                                    _ImageStatChip(
                                      label: 'Pending',
                                      count: stats.pending,
                                      color: AppColors.warning,
                                    ),
                                    const SizedBox(width: AppTheme.space2),
                                    _ImageStatChip(
                                      label: 'Generating',
                                      count: stats.generating,
                                      color: cs.tertiary,
                                    ),
                                    const SizedBox(width: AppTheme.space2),
                                    _ImageStatChip(
                                      label: 'Failed',
                                      count: stats.failed,
                                      color: cs.error,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ).animate(delay: 800.ms).fadeIn(duration: 400.ms);
                        },
                      ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppTheme.space8)),
        ],
      ),
    );
  }
}

class _AdminKpi extends StatelessWidget {
  final String label;
  final String value;
  final String delta;
  final IconData icon;
  final Color color;

  const _AdminKpi({
    required this.label,
    required this.value,
    required this.delta,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.space6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radius3xl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: AppTheme.clayShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  letterSpacing: 3,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space4),
          Text(
            value,
            style: tt.displaySmall?.copyWith(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: AppTheme.space1),
          Text(
            delta,
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 10,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// System health card with title, icon, and custom child content.
class _SystemHealthCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _SystemHealthCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.space6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: AppTheme.clayShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: tt.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space6),
          child,
        ],
      ),
    );
  }
}



/// Compact status chip showing a count with a colored accent.
class _ImageStatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _ImageStatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space3,
          vertical: AppTheme.space2,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: cs.onSurfaceVariant.withValues(alpha: 0.50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
