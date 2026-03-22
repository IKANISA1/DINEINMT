import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/services/order_repository.dart';
import '../../../shared/widgets/shared_widgets.dart';

/// Venue-side single order detail matching React venue/OrderDetail.tsx.
///
/// Layout:
/// - Header: back button + "Order Details" + #id + status badge (with icon)
/// - Guest Info: avatar (UtensilsCrossed) + Table + guest name + count + Message/Phone buttons
/// - Order Items: quantity badge + name + per-unit price + total + note alert (if any)
/// - Summary: subtotal + service charge (5%) + divider + total (primary color)
/// - Fixed bottom action bar: Cancel Order + Mark as Ready (secondary bg)
class VenueOrderDetailScreen extends ConsumerWidget {
  final String orderId;

  const VenueOrderDetailScreen({super.key, required this.orderId});

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
          message: 'Could not load order.',
          onRetry: () => ref.invalidate(orderByIdProvider(orderId)),
        ),
        data: (order) {
          if (order == null) {
            return Center(child: Text('Order not found', style: tt.bodyLarge));
          }
          return _buildContent(context, ref, cs, tt, order);
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ColorScheme cs,
    TextTheme tt,
    Order order,
  ) {
    return Stack(
      children: [
        // ─── Scrollable Content ───
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.space5,
            0,
            AppTheme.space5,
            140,
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppTheme.space5),

                // ─── Header ───
                Row(
                  children: [
                    PressableScale(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLg,
                          ),
                          border: Border.all(color: AppColors.white5),
                        ),
                        child: const Icon(LucideIcons.chevronLeft, size: 24),
                      ),
                    ),
                    const SizedBox(width: AppTheme.space4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order Details',
                            style: tt.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'ORDER #${order.displayNumber}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: cs.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status badge with icon
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: order.status == OrderStatus.received
                            ? AppColors.secondary.withValues(alpha: 0.10)
                            : cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            order.status == OrderStatus.received
                                ? LucideIcons.chefHat
                                : LucideIcons.checkCircle2,
                            size: 14,
                            color: order.status == OrderStatus.received
                                ? AppColors.secondary
                                : cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            order.status.label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: order.status == OrderStatus.received
                                  ? AppColors.secondary
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.space6),

                // ─── Guest Info Section ───
                Container(
                  padding: const EdgeInsets.all(AppTheme.space5),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                    border: Border.all(color: AppColors.white5),
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLg,
                          ),
                        ),
                        child: Icon(
                          LucideIcons.utensilsCrossed,
                          size: 28,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: AppTheme.space4),
                      // Table + Guest info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Table ${order.tableNumber ?? '—'}',
                              style: tt.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Guest • ${order.itemCount} Items',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Message + Phone buttons
                      Row(
                        children: [
                          PressableScale(
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMd,
                                ),
                              ),
                              child: Icon(
                                LucideIcons.messageSquare,
                                size: 20,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          PressableScale(
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMd,
                                ),
                              ),
                              child: Icon(
                                LucideIcons.phone,
                                size: 20,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.space6),

                // ─── Order Items ───
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space2,
                  ),
                  child: Text(
                    'Order Items',
                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: AppTheme.space3),
                ...order.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.space3),
                    child: _buildItemCard(cs, tt, item, order.currencySymbol),
                  ),
                ),
                const SizedBox(height: AppTheme.space5),

                // ─── Summary Section ───
                Container(
                  padding: const EdgeInsets.all(AppTheme.space5),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                    border: Border.all(color: AppColors.white10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Subtotal',
                            style: tt.bodyLarge?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '${order.currencySymbol}${order.subtotal.toStringAsFixed(2)}',
                            style: tt.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.space3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Service Fee (5%)',
                            style: tt.bodyLarge?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '${order.currencySymbol}${order.serviceFee.toStringAsFixed(2)}',
                            style: tt.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.space4),
                      Divider(color: AppColors.white10),
                      const SizedBox(height: AppTheme.space4),
                      // Total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: tt.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '${order.currencySymbol}${order.total.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: cs.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ─── Fixed Bottom Action Bar ───
        if (order.status.isActive)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space5,
                AppTheme.space5,
                AppTheme.space5,
                AppTheme.space5,
              ),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.80),
                border: Border(top: BorderSide(color: AppColors.white5)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    // Cancel Order
                    Expanded(
                      child: PressableScale(
                        onTap: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Cancel Order?'),
                              content: const Text(
                                'This action cannot be undone. The guest will be notified.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('Keep Order'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Theme.of(
                                      ctx,
                                    ).colorScheme.error,
                                  ),
                                  child: const Text('Cancel Order'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true || !context.mounted) return;
                          try {
                            await OrderRepository.instance.updateOrderStatus(
                              order.id,
                              OrderStatus.cancelled,
                            );
                            ref.invalidate(orderByIdProvider(orderId));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Order cancelled'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to cancel: $e')),
                              );
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusLg,
                            ),
                            border: Border.all(color: AppColors.white10),
                          ),
                          child: Center(
                            child: Text(
                              'Cancel Order',
                              style: tt.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.space3),
                    // Mark as Ready
                    Expanded(
                      child: PressableScale(
                        onTap: () async {
                          final nextStatus = switch (order.status) {
                            OrderStatus.placed => OrderStatus.received,
                            OrderStatus.received => OrderStatus.served,
                            _ => null,
                          };
                          if (nextStatus == null) return;
                          try {
                            await OrderRepository.instance.updateOrderStatus(
                              order.id,
                              nextStatus,
                            );
                            ref.invalidate(orderByIdProvider(orderId));
                          } catch (_) {}
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusLg,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.secondary.withValues(
                                  alpha: 0.20,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                order.status == OrderStatus.placed
                                    ? 'Mark as Ready'
                                    : 'Mark as Served',
                                style: tt.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                LucideIcons.checkCircle2,
                                size: 18,
                                color: cs.onSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Item card with quantity badge, name, per-unit price, total, and optional note alert.
  Widget _buildItemCard(
    ColorScheme cs,
    TextTheme tt,
    OrderItem item,
    String currencySymbol,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.white5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Quantity badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Center(
                  child: Text(
                    '${item.quantity}x',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: cs.primary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.space3),
              // Name + per-unit price
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '$currencySymbol${item.price.toStringAsFixed(2)} each',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              // Total
              Text(
                '$currencySymbol${item.subtotal.toStringAsFixed(2)}',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          // Note alert (if any)
          if (item.note != null && item.note!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space3),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.error.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: cs.error.withValues(alpha: 0.10)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.alertCircle, size: 14, color: cs.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '"${item.note}"',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: cs.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
