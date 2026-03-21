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
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../shared/widgets/shared_widgets.dart';

/// Order history — matches React OrderHistory.tsx.
///
/// Each card shows: venue image, venue name, items list (truncated),
/// date, total, status badge, and chevron arrow.
class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ordersAsync = ref.watch(userOrdersProvider);
    final loadedOrders = ordersAsync.asData?.value;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (loadedOrders?.isNotEmpty == true)
              // ─── Header ───
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.space8,
                  AppTheme.space8,
                  AppTheme.space8,
                  AppTheme.space6,
                ),
                child: Text(
                  'Order\nHistory',
                  style: tt.displayMedium, // text-5xl font-black
                ),
              ),

            // ─── Orders List ───
            Expanded(
              child: ordersAsync.when(
                loading: () => const Center(
                  child: SkeletonLoader(width: double.infinity, height: 200),
                ),
                error: (err, _) => ErrorState(
                  message: 'Could not load order history.',
                  onRetry: () => ref.invalidate(userOrdersProvider),
                ),
                data: (orders) {
                  if (orders.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHigh,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              LucideIcons.receipt,
                              size: 48,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppTheme.space6),
                          Text('No orders yet', style: tt.headlineLarge),
                          const SizedBox(height: AppTheme.space4),
                          Text(
                            'Your order history will appear\nhere after your first visit.',
                            textAlign: TextAlign.center,
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space6,
                    ),
                    itemCount: orders.length,
                    separatorBuilder: (_, i) =>
                        const SizedBox(height: AppTheme.space4),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return _OrderHistoryCard(
                            order: order,
                            onTap: () => context.pushNamed(
                              AppRouteNames.orderStatus,
                              pathParameters: {AppRouteParams.id: order.id},
                            ),
                          )
                          .animate(delay: (80 * index).ms)
                          .fadeIn(duration: 300.ms)
                          .slideY(begin: 0.05);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inHours < 24 && date.day == now.day) {
    return 'Today, ${DateFormat.jm().format(date)}';
  } else if (diff.inHours < 48 &&
      date.day == now.subtract(const Duration(days: 1)).day) {
    return 'Yesterday, ${DateFormat.jm().format(date)}';
  }
  return DateFormat('MMM d, h:mm a').format(date);
}

/// Order history card — matches React OrderHistory.tsx card layout.
///
/// Left: venue image placeholder (w-24 h-24 rounded-3xl)
/// Center: venue name (text-xl font-black), items list (truncated 2),
///         date, total, status badge
/// Right: chevron arrow
class _OrderHistoryCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;

  const _OrderHistoryCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Color statusColor() {
      return switch (order.status) {
        OrderStatus.placed => cs.tertiary,
        OrderStatus.received => cs.primary,
        OrderStatus.served => AppColors.secondary,
        OrderStatus.cancelled => cs.error,
      };
    }

    // Truncate items list to max 2 names
    final itemNames = order.items.take(2).map((i) => i.name).join(', ');
    final moreCount = order.items.length - 2;

    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: AppTheme.ambientShadow,
        ),
        child: Row(
          children: [
            // ─── Venue image placeholder ───
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.primary.withValues(alpha: 0.08),
                    cs.tertiary.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  LucideIcons.store,
                  size: 36,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.30),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.space5),

            // ─── Info ───
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Venue name
                  Text(
                    order.venueName,
                    style: tt.headlineSmall?.copyWith(
                      letterSpacing: -0.5,
                    ), // text-xl font-black
                  ),
                  const SizedBox(height: 4),

                  // Items list
                  Text(
                    moreCount > 0
                        ? '$itemNames +$moreCount more'
                        : itemNames.isEmpty
                        ? '${order.itemCount} items'
                        : itemNames,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.60),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Date + Total + Status
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _formatDate(order.createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.40),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${order.currencySymbol}${order.total.toStringAsFixed(2)}',
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor().withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      order.status.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3.2,
                        color: statusColor(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ─── Chevron ───
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                LucideIcons.chevronRight,
                size: 20,
                color: cs.onSurfaceVariant.withValues(alpha: 0.40),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
