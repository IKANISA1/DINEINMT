import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/enums.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';

class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(userOrdersProvider);

    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: _OrderHistoryHeader()),
        ordersAsync.when(
          loading: () => const SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppTheme.space6,
              0,
              AppTheme.space6,
              AppTheme.space24,
            ),
            sliver: _OrderHistorySkeletonList(),
          ),
          error: (error, stackTrace) => SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space6,
                0,
                AppTheme.space6,
                AppTheme.space16,
              ),
              child: ErrorState(
                message: 'Could not load order history.',
                onRetry: () => ref.invalidate(userOrdersProvider),
              ),
            ),
          ),
          data: (orders) {
            if (orders.isEmpty) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppTheme.space6,
                    0,
                    AppTheme.space6,
                    AppTheme.space16,
                  ),
                  child: _EmptyOrderHistoryState(),
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space6,
                0,
                AppTheme.space6,
                AppTheme.space24,
              ),
              sliver: SliverList.separated(
                itemCount: orders.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppTheme.space5),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return _OrderHistoryCard(
                        order: order,
                        onTap: () => context.pushNamed(
                          AppRouteNames.orderStatus,
                          pathParameters: {AppRouteParams.id: order.id},
                        ),
                      )
                      .animate(delay: (50 * index).ms)
                      .fadeIn(duration: 350.ms)
                      .slideY(begin: 0.08, end: 0);
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _OrderHistoryHeader extends StatelessWidget {
  const _OrderHistoryHeader();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space6,
        AppTheme.space6,
        AppTheme.space6,
        AppTheme.space8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              style: tt.displayMedium?.copyWith(
                height: 0.86,
                letterSpacing: -2.2,
              ),
              children: [
                const TextSpan(text: 'ORDER\n'),
                TextSpan(
                  text: 'HISTORY',
                  style: TextStyle(color: cs.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space4),
          SizedBox(
            width: 280,
            child: Text(
              'Every table moment, receipt, and order progress in one place.',
              style: tt.bodyLarge?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderHistorySkeletonList extends StatelessWidget {
  const _OrderHistorySkeletonList();

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: AppTheme.space5),
          child: SkeletonLoader(width: double.infinity, height: 168),
        );
      }, childCount: 3),
    );
  }
}

class _EmptyOrderHistoryState extends StatelessWidget {
  const _EmptyOrderHistoryState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.space8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.radius3xl),
          border: Border.all(color: AppColors.white5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
              ),
              child: Icon(
                LucideIcons.receipt,
                size: 44,
                color: cs.onSurfaceVariant.withValues(alpha: 0.25),
              ),
            ),
            const SizedBox(height: AppTheme.space6),
            Text('No orders yet', style: tt.headlineMedium),
            const SizedBox(height: AppTheme.space3),
            Text(
              'Your table orders and receipts will appear here after your first visit.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            PressableScale(
              onTap: () => context.goNamed(AppRouteNames.discover),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space8,
                  vertical: AppTheme.space5,
                ),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.24),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'DISCOVER VENUES',
                      style: TextStyle(
                        color: cs.onPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.4,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: cs.onPrimary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderHistoryCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;

  const _OrderHistoryCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final itemNames = order.items.take(2).map((item) => item.name).join(', ');
    final moreCount = order.items.length - 2;

    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space5),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
          border: Border.all(color: AppColors.white5),
          boxShadow: AppTheme.ambientShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              child: SizedBox(
                width: 104,
                height: 136,
                child: DineInImage(
                  imageUrl: order.venueImageUrl,
                  fit: BoxFit.cover,
                  fallbackIcon: LucideIcons.store,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.space5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '#${order.displayNumber}',
                          style: TextStyle(
                            color: cs.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.6,
                          ),
                        ),
                      ),
                      _OrderStatusPill(order: order),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    order.venueName,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: tt.headlineSmall?.copyWith(
                      letterSpacing: -0.8,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    moreCount > 0
                        ? '$itemNames +$moreCount more'
                        : itemNames.isEmpty
                        ? '${order.itemCount} items'
                        : itemNames,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.60),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.clock3,
                              size: 14,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.48),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _formatDate(order.createdAt),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.48,
                                  ),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${order.currencySymbol}${order.total.toStringAsFixed(2)}',
                        style: tt.titleMedium?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.space3),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderStatusPill extends StatelessWidget {
  final Order order;

  const _OrderStatusPill({required this.order});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (order.status) {
      OrderStatus.placed => Theme.of(context).colorScheme.tertiary,
      OrderStatus.received => Theme.of(context).colorScheme.primary,
      OrderStatus.served => AppColors.secondary,
      OrderStatus.cancelled => Theme.of(context).colorScheme.error,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        order.status.label.toUpperCase(),
        style: TextStyle(
          color: statusColor,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.4,
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
