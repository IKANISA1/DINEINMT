import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/core/services/notification_inbox_service.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:core_pkg/constants/enums.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:ui/widgets/shared_widgets.dart';
import 'package:dinein_app/features/guest/widgets/wave_bottom_sheet.dart';

/// Order status tracking screen with step indicator.
/// Uses [orderByIdProvider] for initial data + [orderStreamProvider] for real-time updates.
/// Status progression: Placed → Received → Served (or Cancelled).
class OrderStatusScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderStatusScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends ConsumerState<OrderStatusScreen> {
  OrderStatus? _lastKnownStatus;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final orderAsync = ref.watch(orderByIdProvider(widget.orderId));

    // Listen for status transitions → fire toast + inbox entry
    ref.listen<AsyncValue<OrderStatus>>(
      orderStreamProvider(widget.orderId),
      (previous, next) {
        final newStatus = next.value;
        if (newStatus == null) return;
        if (_lastKnownStatus != null && newStatus != _lastKnownStatus) {
          _onStatusChanged(newStatus);
        }
        _lastKnownStatus = newStatus;
      },
    );

    return orderAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text('Order', style: tt.headlineMedium)),
        body: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: const [
            SkeletonLoader(width: double.infinity, height: 64, borderRadius: 16),
            SizedBox(height: 12),
            SkeletonLoader(width: double.infinity, height: 48, borderRadius: 12),
            SizedBox(height: 16),
            SkeletonLoader(width: double.infinity, height: 160, borderRadius: 20),
          ],
        ),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: Text('Order', style: tt.headlineMedium)),
        body: ErrorState(
          message: 'Could not load order details.',
          onRetry: () => ref.invalidate(orderByIdProvider(widget.orderId)),
        ),
      ),
      data: (order) {
        if (order == null) {
          return Scaffold(
            appBar: AppBar(title: Text('Order', style: tt.headlineMedium)),
            body: const EmptyState(
              icon: LucideIcons.receipt,
              title: 'Order not found',
              subtitle: 'This order may have been removed.',
            ),
          );
        }

        // Also listen to real-time stream for status updates
        final streamAsync = ref.watch(orderStreamProvider(widget.orderId));
        final currentStatus = streamAsync.value ?? order.status;
        _lastKnownStatus ??= currentStatus;
        final displayOrder = order;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Order #${displayOrder.displayNumber}',
              style: tt.headlineMedium,
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  icon: Icon(LucideIcons.hand, color: cs.primary),
                  onPressed: () =>
                      WaveBottomSheet.show(context, displayOrder.venueId),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space6,
              vertical: AppTheme.space4,
            ),
            children: [
              // ─── Compact Status Banner ───
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space5,
                  vertical: AppTheme.space4,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(cs, currentStatus).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(
                    color: _statusColor(cs, currentStatus).withValues(alpha: 0.20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _statusColor(cs, currentStatus).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _statusIcon(currentStatus),
                        size: 20,
                        color: _statusColor(cs, currentStatus),
                      ),
                    ),
                    const SizedBox(width: AppTheme.space4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentStatus.label,
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: _statusColor(cs, currentStatus),
                            ),
                          ),
                          Text(
                            _statusMessageShort(currentStatus),
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.space4),

              // ─── Compact Horizontal Progress ───
              _CompactProgressBar(currentStatus: currentStatus),

              const SizedBox(height: AppTheme.space6),

              // ─── Order Info Row ───
              ClayCard(
                child: Column(
                  children: [
                    _OrderDetailRow(
                      label: 'Venue',
                      value: displayOrder.venueName,
                    ),
                    const SizedBox(height: 6),
                    _OrderDetailRow(
                      label: 'Payment',
                      value: displayOrder.paymentMethod.label,
                    ),
                    if (displayOrder.tableNumber != null) ...[
                      const SizedBox(height: 6),
                      _OrderDetailRow(
                        label: 'Table',
                        value: displayOrder.tableNumber!,
                      ),
                    ],
                    if (displayOrder.specialRequests != null &&
                        displayOrder.specialRequests!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _OrderDetailRow(
                        label: 'Requests',
                        value: displayOrder.specialRequests!,
                        multiline: true,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.space6),

              // ─── Items List ───
              Text(
                'ITEMS ORDERED',
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: AppTheme.space3),
              ClayCard(
                child: Column(
                  children: [
                    for (int i = 0; i < displayOrder.items.length; i++) ...[
                      if (i > 0)
                        Divider(
                          color: cs.outlineVariant.withValues(alpha: 0.08),
                          height: 12,
                        ),
                      _ItemRow(
                        item: displayOrder.items[i],
                        formatPrice: displayOrder.formatPrice,
                      ),
                    ],
                    Divider(
                      color: cs.outlineVariant.withValues(alpha: 0.10),
                      height: 20,
                    ),
                    // Total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          displayOrder.formatPrice(displayOrder.total),
                          style: tt.titleSmall?.copyWith(
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

          // ─── Bottom CTA ───
          bottomNavigationBar: Container(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space6,
              AppTheme.space4,
              AppTheme.space6,
              AppTheme.space8,
            ),
            child: SafeArea(
              child: PremiumButton(
                label: 'BACK TO HOME',
                isOutlined: true,
                onPressed: () => context.goNamed(AppRouteNames.discover),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _statusColor(ColorScheme cs, OrderStatus status) {
    return switch (status) {
      OrderStatus.placed => cs.tertiary,
      OrderStatus.received => cs.primary,
      OrderStatus.served => AppColors.primary,
      OrderStatus.cancelled => cs.error,
    };
  }

  void _onStatusChanged(OrderStatus newStatus) {
    final (title, body, type) = switch (newStatus) {
      OrderStatus.received => (
        'Order confirmed',
        'Your order is being prepared!',
        ToastType.success,
      ),
      OrderStatus.served => (
        'Order served',
        'Your order has been served! Enjoy your meal!',
        ToastType.success,
      ),
      OrderStatus.cancelled => (
        'Order cancelled',
        'Your order has been cancelled.',
        ToastType.error,
      ),
      OrderStatus.placed => (
        'Order placed',
        'Your order has been placed.',
        ToastType.info,
      ),
    };

    DineInToast.instance.show(message: body, type: type);

    NotificationInboxService.instance.add(
      id: 'order-status-${widget.orderId}-${newStatus.dbValue}',
      title: title,
      body: body,
      type: 'order',
    );
  }

  IconData _statusIcon(OrderStatus status) {
    return switch (status) {
      OrderStatus.placed => LucideIcons.clock,
      OrderStatus.received => LucideIcons.chefHat,
      OrderStatus.served => LucideIcons.check,
      OrderStatus.cancelled => LucideIcons.x,
    };
  }

  String _statusMessageShort(OrderStatus status) {
    return switch (status) {
      OrderStatus.placed => 'Waiting for the venue to confirm.',
      OrderStatus.received => 'Being prepared now.',
      OrderStatus.served => 'Enjoy your meal!',
      OrderStatus.cancelled => 'This order was cancelled.',
    };
  }
}

/// Compact horizontal progress bar: 3 dots with connecting lines.
class _CompactProgressBar extends StatelessWidget {
  final OrderStatus currentStatus;

  const _CompactProgressBar({required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final steps = [
      ('Confirmed', OrderStatus.placed),
      ('Preparing', OrderStatus.received),
      ('Served', OrderStatus.served),
    ];

    return Row(
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: currentStatus.stepIndex >= steps[i].$2.stepIndex
                      ? AppColors.secondary
                      : cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: currentStatus.stepIndex >= steps[i].$2.stepIndex
                      ? (currentStatus == steps[i].$2
                          ? cs.primary
                          : AppColors.secondary)
                      : cs.surfaceContainerHigh,
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (currentStatus == steps[i].$2)
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.20),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: Icon(
                  currentStatus.stepIndex > steps[i].$2.stepIndex
                      ? LucideIcons.check
                      : _stepIcon(steps[i].$2),
                  size: 14,
                  color: currentStatus.stepIndex >= steps[i].$2.stepIndex
                      ? Colors.white
                      : cs.onSurfaceVariant.withValues(alpha: 0.40),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                steps[i].$1,
                style: tt.labelSmall?.copyWith(
                  fontSize: 9,
                  fontWeight: currentStatus == steps[i].$2
                      ? FontWeight.w900
                      : FontWeight.w600,
                  color: currentStatus.stepIndex >= steps[i].$2.stepIndex
                      ? cs.onSurface
                      : cs.onSurfaceVariant.withValues(alpha: 0.40),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  IconData _stepIcon(OrderStatus status) {
    return switch (status) {
      OrderStatus.placed => LucideIcons.checkCircle2,
      OrderStatus.received => LucideIcons.chefHat,
      OrderStatus.served => LucideIcons.utensilsCrossed,
      OrderStatus.cancelled => LucideIcons.x,
    };
  }
}

/// A single item row showing name, qty × price, subtotal.
class _ItemRow extends StatelessWidget {
  final dynamic item;
  final String Function(double) formatPrice;

  const _ItemRow({required this.item, required this.formatPrice});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Quantity badge
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            '${item.quantity}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: cs.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Item name
        Expanded(
          child: Text(
            item.name,
            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        // Subtotal
        Text(
          formatPrice(item.subtotal),
          style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _OrderDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool multiline;

  const _OrderDetailRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: multiline
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: isBold
                ? tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)
                : tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: isBold
                ? tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                  )
                : tt.bodyMedium,
          ),
        ),
      ],
    );
  }
}
