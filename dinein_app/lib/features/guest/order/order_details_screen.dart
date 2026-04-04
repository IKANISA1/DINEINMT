import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
        loading: () => const Center(
          child: SkeletonLoader(width: double.infinity, height: 200),
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
              padding: const EdgeInsets.all(AppTheme.space10),
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
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${item.quantity}x',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: cs.primary,
                                fontSize: 14,
                              ),
                            ),
                          ),
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
                              Text(
                                '${order.currencySymbol}${item.price.toStringAsFixed(2)} each',
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.60,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${order.currencySymbol}${item.subtotal.toStringAsFixed(2)}',
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  )
                  .animate(delay: (100 * index).ms)
                  .fadeIn(duration: 400.ms)
                  .slideX(begin: -0.1, end: 0);
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
              AppTheme.space24,
            ),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.space10),
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
                        '${order.currencySymbol}${order.subtotal.toStringAsFixed(2)}',
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
                        '${order.currencySymbol}${order.serviceFee.toStringAsFixed(2)}',
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
                        '${order.currencySymbol}${finalTotal.toStringAsFixed(2)}',
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
