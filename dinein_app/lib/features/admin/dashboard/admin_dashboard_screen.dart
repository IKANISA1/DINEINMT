import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';
import 'package:core_pkg/config/country_runtime.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';
import '../../../core/providers/providers.dart';
import 'package:ui/widgets/shared_widgets.dart';

bool _hasVenueAccessReady(Venue venue) => venue.isAccessReady;

/// Admin overview dashboard — system-wide live KPIs.
/// Uses [allVenuesProvider] and [allOrdersProvider].
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final venuesAsync = ref.watch(allVenuesProvider);
    final ordersAsync = ref.watch(allOrdersProvider);
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
        value: ordersAsync.when(
          loading: () => '—',
          error: (_, _) => '—',
          data: (orders) {
            final today = DateTime.now();
            final todayOrders = orders.where(
              (o) =>
                  o.createdAt.day == today.day &&
                  o.createdAt.month == today.month &&
                  o.createdAt.year == today.year,
            );
            return '${todayOrders.length}';
          },
        ),
        delta: ordersAsync.when(
          loading: () => 'Loading...',
          error: (_, _) => 'Error',
          data: (orders) {
            final today = DateTime.now();
            final todayRevenue = orders
                .where(
                  (o) =>
                      o.createdAt.day == today.day &&
                      o.createdAt.month == today.month &&
                      o.createdAt.year == today.year,
                )
                .fold<double>(0, (sum, o) => sum + o.total);
            final cs = CountryRuntime.config.country.currencySymbol;
            return '$cs${todayRevenue.toStringAsFixed(0)} total';
          },
        ),
        icon: LucideIcons.shoppingBag,
        color: cs.tertiary,
      ),
      _AdminKpi(
        label: 'ACCESS READY',
        value: venuesAsync.when(
          loading: () => '—',
          error: (_, _) => '—',
          data: (venues) => '${venues.where(_hasVenueAccessReady).length}',
        ),
        delta: venuesAsync.when(
          loading: () => 'Loading...',
          error: (_, _) => 'Error',
          data: (venues) {
            final ready = venues.where(_hasVenueAccessReady).length;
            final remaining = venues.length - ready;
            return remaining == 0
                ? 'All venue access configured'
                : '$remaining still need setup';
          },
        ),
        icon: LucideIcons.messageCircle,
        color: AppColors.warning,
      ),
      _AdminKpi(
        label: 'TOTAL ORDERS',
        value: ordersAsync.when(
          loading: () => '—',
          error: (_, _) => '—',
          data: (o) => '${o.length}',
        ),
        delta: ordersAsync.when(
          loading: () => 'Loading...',
          error: (_, _) => 'Error',
          data: (o) {
            final total = o.fold<double>(0, (sum, o) => sum + o.total);
            final cs = CountryRuntime.config.country.currencySymbol;
            return '$cs${total.toStringAsFixed(0)} lifetime';
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
                    spacing: AppTheme.space4,
                    runSpacing: AppTheme.space4,
                    children:
                        kpiCards.asMap().entries.map((entry) {
                          final index = entry.key;
                          final card = entry.value;
                          return SizedBox(
                            width: cardWidth,
                            child: card
                                .animate(delay: (80 + 80 * index).ms)
                                .fadeIn(duration: 500.ms),
                          );
                        }).toList(),
                  );
                },
              ),
            ),
          ),

          // ─── Venue Access Setup ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.space6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Venue Access Setup', style: tt.headlineSmall),
                  const SizedBox(height: AppTheme.space4),
                  venuesAsync.when(
                    loading: () => const SkeletonLoader(
                      width: double.infinity,
                      height: 100,
                    ),
                    error: (_, _) => const Text('Could not load venues'),
                    data: (venues) {
                      final pendingAccess = venues
                          .where((venue) => !_hasVenueAccessReady(venue))
                          .take(3)
                          .toList();
                      if (pendingAccess.isEmpty) {
                        return const EmptyState(
                          icon: LucideIcons.shieldCheck,
                          title: 'All venue access is configured',
                          subtitle:
                              'Every active venue has a WhatsApp login number.',
                        );
                      }

                      return Column(
                        children: pendingAccess.asMap().entries.map((entry) {
                          final venue = entry.value;
                          final requiresPhone = !venue.hasAssignedAccessPhone;
                          final accessLabel = requiresPhone
                              ? 'Add WhatsApp number'
                              : !venue.isOpen
                              ? 'Activate venue'
                              : !venue.isAccessVerified
                              ? 'Finish validation'
                              : 'Review access';
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppTheme.space3,
                            ),
                            child:
                                ClayCard(
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: AppColors.warning
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppTheme.radiusMd,
                                                  ),
                                            ),
                                            child: Icon(
                                              LucideIcons.messageCircle,
                                              size: 20,
                                              color: AppColors.warning,
                                            ),
                                          ),
                                          const SizedBox(
                                            width: AppTheme.space3,
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  venue.name,
                                                  style: tt.titleSmall,
                                                ),
                                                Text(
                                                  requiresPhone
                                                      ? 'WhatsApp number missing'
                                                      : 'Venue is not active yet',
                                                  style: tt.bodySmall?.copyWith(
                                                    color: cs.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          StatusBadge(
                                            label: accessLabel,
                                            color: AppColors.warning.withValues(
                                              alpha: 0.12,
                                            ),
                                            textColor: AppColors.warning,
                                          ),
                                        ],
                                      ),
                                    )
                                    .animate(delay: (300 + 100 * entry.key).ms)
                                    .fadeIn(duration: 300.ms),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // ─── System Health ───
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
                    child: ordersAsync.when(
                      loading: () => const SkeletonLoader(
                        width: double.infinity,
                        height: 60,
                      ),
                      error: (_, _) => const Text('Could not load orders'),
                      data: (orders) {
                        final cancelled = orders
                            .where((o) => o.status == OrderStatus.cancelled)
                            .take(3)
                            .toList();
                        if (cancelled.isEmpty) {
                          return Text(
                            'No exceptions — all orders running smoothly.',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          );
                        }
                        return Column(
                          children: cancelled.asMap().entries.map((entry) {
                            final o = entry.value;
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: entry.key < cancelled.length - 1
                                    ? AppTheme.space3
                                    : 0,
                              ),
                              child: _ExceptionRow(
                                label: '${o.venueName} — #${o.displayNumber}',
                                severity: 'Cancelled',
                                severityColor: cs.error,
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ).animate(delay: 600.ms).fadeIn(duration: 400.ms),
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
                                        )
                                        .animate(delay: 500.ms)
                                        .slideX(
                                          begin: -1,
                                          end: 0,
                                          duration: 1500.ms,
                                          curve: Curves.easeOutCubic,
                                        ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: AppTheme.space3),
                            Text(
                              '$offline venues are currently in scheduled maintenance mode.',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.40,
                                ),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ).animate(delay: 700.ms).fadeIn(duration: 400.ms);
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
                                            )
                                            .animate(delay: 500.ms)
                                            .slideX(
                                              begin: -1,
                                              end: 0,
                                              duration: 1500.ms,
                                              curve: Curves.easeOutCubic,
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

          const SliverToBoxAdapter(child: SizedBox(height: AppTheme.space24)),
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
      padding: const EdgeInsets.all(AppTheme.space5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
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
                  letterSpacing: 1.5,
                  fontSize: 8,
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
            ],
          ),
          Text(value, style: tt.displaySmall?.copyWith(fontSize: 28)),
          Text(
            delta,
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 10,
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

/// Exception row for the Order Exceptions card.
class _ExceptionRow extends StatelessWidget {
  final String label;
  final String severity;
  final Color severityColor;

  const _ExceptionRow({
    required this.label,
    required this.severity,
    required this.severityColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.space4),
      decoration: BoxDecoration(
        color: severityColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: severityColor.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: severityColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              severity.toUpperCase(),
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: cs.onPrimary,
              ),
            ),
          ),
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
