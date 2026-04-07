import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:ui/widgets/shared_widgets.dart';

/// Order details/receipt screen — shows venue, items, totals.
/// Matches React OrderDetails.tsx.
class OrderDetailsScreen extends ConsumerWidget {
  final String orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final orderAsync = ref.watch(orderByIdProvider(orderId));

    return Scaffold(
      body: orderAsync.when(
        loading: () => SafeArea(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: const [
              SkeletonLoader(width: 160, height: 24, borderRadius: 8),
              SizedBox(height: 8),
              SkeletonLoader(width: 80, height: 12, borderRadius: 4),
              SizedBox(height: 24),
              SkeletonLoader(width: double.infinity, height: 140, borderRadius: 24),
              SizedBox(height: 20),
              SkeletonLoader(width: 60, height: 14, borderRadius: 6),
              SizedBox(height: 16),
              SkeletonLoader(width: double.infinity, height: 88, borderRadius: 20),
              SizedBox(height: 12),
              SkeletonLoader(width: double.infinity, height: 88, borderRadius: 20),
              SizedBox(height: 24),
              SkeletonLoader(width: double.infinity, height: 100, borderRadius: 24),
            ],
          ),
        ),
        error: (err, _) => ErrorState(
          message: 'Could not load order details.',
          onRetry: () => ref.invalidate(orderByIdProvider(orderId)),
        ),
        data: (order) {
          if (order == null) return _buildNotFound(context, cs, tt);
          return _buildContent(context, cs, tt, order);
        },
      ),
    );
  }

  Widget _buildNotFound(BuildContext context, ColorScheme cs, TextTheme tt) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                border: Border.all(color: AppColors.white5),
              ),
              child: Icon(
                LucideIcons.shoppingBag,
                size: 48,
                color: cs.onSurfaceVariant.withValues(alpha: 0.30),
              ),
            ),
            const SizedBox(height: AppTheme.space6),
            Text('Order Not Found', style: tt.headlineMedium),
            const SizedBox(height: AppTheme.space6),
            ElevatedButton(
              onPressed: () => context.goNamed(AppRouteNames.orderHistory),
              child: const Text('BACK TO HISTORY'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
    Order order,
  ) {
    final finalTotal = order.total;

    return CustomScrollView(
      slivers: [
        // ─── Header ───
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space8,
              AppTheme.space8,
              AppTheme.space8,
              0,
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  PressableScale(
                    onTap: () => context.pop(),
                    semanticLabel: 'Go back',
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(color: AppColors.white5),
                      ),
                      child: const Icon(LucideIcons.chevronLeft, size: 28),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Details',
                        style: tt.headlineMedium?.copyWith(height: 1),
                      ),
                      Text(
                        '#${order.displayNumber}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // ─── Order Info Card ───
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space8),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.space6),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppTheme.radius3xl),
                border: Border.all(color: AppColors.white5),
                boxShadow: AppTheme.ambientShadow,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'VENUE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                              color: cs.onSurfaceVariant.withValues(
                                alpha: 0.60,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(order.venueName, style: tt.titleLarge),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: cs.secondary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                          border: Border.all(
                            color: cs.secondary.withValues(alpha: 0.20),
                          ),
                        ),
                        child: Text(
                          order.status.label.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: cs.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space6),
                  Container(height: 1, color: AppColors.white5),
                  const SizedBox(height: AppTheme.space6),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DATE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.60,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  LucideIcons.clock,
                                  size: 16,
                                  color: cs.onSurface.withValues(alpha: 0.40),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatDate(order.createdAt),
                                  style: tt.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PAYMENT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.60,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  LucideIcons.receipt,
                                  size: 16,
                                  color: cs.onSurface.withValues(alpha: 0.40),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  order.paymentMethod.label,
                                  style: tt.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // ─── Items Header ───
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Items', style: tt.titleLarge),
                Text(
                  '${order.itemCount} Items',
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.60),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ─── Items List ───
        SliverPadding(
          padding: const EdgeInsets.all(AppTheme.space8),
          sliver: SliverList.separated(
            itemCount: order.items.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppTheme.space4),
            itemBuilder: (context, index) {
              final item = order.items[index];
              return Container(
                    padding: const EdgeInsets.all(AppTheme.space6),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                      border: Border.all(color: AppColors.white5),
                      boxShadow: AppTheme.ambientShadow,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusLg,
                              ),
                              child: SizedBox(
                                width: 72,
                                height: 72,
                                child: DineInImage(
                                  imageUrl: item.imageUrl,
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  fallbackIcon: LucideIcons.chefHat,
                                  semanticLabel: '${item.name} photo',
                                ),
                              ),
                            ),
                            Positioned(
                              right: 6,
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.72),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusFull,
                                  ),
                                ),
                                child: Text(
                                  '${item.quantity}x',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: AppTheme.space5),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: tt.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              if (item.description.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  item.description.trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.72,
                                    ),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                order.formatPrice(item.price),
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.60,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppTheme.space4),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              order.formatPrice(item.subtotal),
                              style: tt.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.quantity} item${item.quantity == 1 ? '' : 's'}',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.60,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
            },
          ),
        ),

        // ─── Total Card ───
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space8,
              0,
              AppTheme.space8,
              AppTheme.space8,
            ),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.space4),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppTheme.radius3xl),
                border: Border.all(color: AppColors.white10),
                boxShadow: AppTheme.elevatedShadow,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Subtotal',
                        style: tt.titleMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        order.formatPrice(order.subtotal),
                        style: tt.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Service Fee (5%)',
                        style: tt.titleMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        order.formatPrice(order.serviceFee),
                        style: tt.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Total', style: tt.titleLarge),
                      Text(
                        order.formatPrice(finalTotal),
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: cs.primary,
                          letterSpacing: -2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
