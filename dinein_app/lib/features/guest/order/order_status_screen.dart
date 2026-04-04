import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:dinein_app/core/router/app_routes.dart';
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
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final orderAsync = ref.watch(orderByIdProvider(widget.orderId));

    return orderAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text('Order', style: tt.headlineMedium)),
        body: const Center(
          child: SkeletonLoader(width: double.infinity, height: 200),
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
            padding: const EdgeInsets.all(AppTheme.space6),
            children: [
              // ─── Status Header ───
              Container(
                padding: const EdgeInsets.all(AppTheme.space8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                ),
                child: Column(
                  children: [
                    Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: _statusColor(
                              cs,
                              currentStatus,
                            ).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _statusIcon(currentStatus),
                            size: 36,
                            color: _statusColor(cs, currentStatus),
                          ),
                        )
                        .animate()
                        .scale(
                          begin: const Offset(0, 0),
                          end: const Offset(1, 1),
                          duration: 500.ms,
                          curve: Curves.elasticOut,
                        )
                        .fadeIn(),
                    const SizedBox(height: AppTheme.space5),
                    Text(
                      currentStatus.label,
                      style: tt.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space2),
                    Text(
                      _statusMessage(currentStatus),
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: AppTheme.space8),

              // ─── Step Indicator ───
              Text(
                'ORDER PROGRESS',
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: AppTheme.space5),
              _StepIndicator(
                currentStatus: currentStatus,
              ).animate(delay: 300.ms).fadeIn(duration: 500.ms),

              const SizedBox(height: AppTheme.space8),

              // ─── Order Details ───
              Text(
                'ORDER DETAILS',
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: AppTheme.space4),
              ClayCard(
                child: Column(
                  children: [
                    _OrderDetailRow(
                      label: 'Venue',
                      value: displayOrder.venueName,
                    ),
                    const SizedBox(height: 8),
                    _OrderDetailRow(
                      label: 'Items',
                      value: '${displayOrder.itemCount} items',
                    ),
                    const SizedBox(height: 8),
                    _OrderDetailRow(
                      label: 'Payment',
                      value: displayOrder.paymentMethod.label,
                    ),
                    if (displayOrder.tableNumber != null) ...[
                      const SizedBox(height: 8),
                      _OrderDetailRow(
                        label: 'Table',
                        value: displayOrder.tableNumber!,
                      ),
                    ],
                    if (displayOrder.specialRequests != null &&
                        displayOrder.specialRequests!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _OrderDetailRow(
                        label: 'Requests',
                        value: displayOrder.specialRequests!,
                        multiline: true,
                      ),
                    ],
                    Divider(
                      color: cs.outlineVariant.withValues(alpha: 0.10),
                      height: 24,
                    ),
                    _OrderDetailRow(
                      label: 'Total',
                      value:
                          '${displayOrder.currencySymbol}${displayOrder.total.toStringAsFixed(2)}',
                      isBold: true,
                    ),
                  ],
                ),
              ).animate(delay: 500.ms).fadeIn(),
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

  IconData _statusIcon(OrderStatus status) {
    return switch (status) {
      OrderStatus.placed => LucideIcons.clock,
      OrderStatus.received => LucideIcons.chefHat,
      OrderStatus.served => LucideIcons.check,
      OrderStatus.cancelled => LucideIcons.x,
    };
  }

  String _statusMessage(OrderStatus status) {
    return switch (status) {
      OrderStatus.placed =>
        'Your order has been placed.\nWaiting for the venue to confirm.',
      OrderStatus.received =>
        'The venue has received your order\nand is preparing it now.',
      OrderStatus.served => 'Your order has been served.\nEnjoy your meal!',
      OrderStatus.cancelled => 'This order was cancelled.',
    };
  }
}

/// Vertical timeline matching React OrderStatus.tsx.
class _StepIndicator extends StatelessWidget {
  final OrderStatus currentStatus;

  const _StepIndicator({required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final steps = [
      (LucideIcons.checkCircle2, 'Order Confirmed', OrderStatus.placed),
      (LucideIcons.chefHat, 'Preparing', OrderStatus.received),
      (LucideIcons.utensilsCrossed, 'Served', OrderStatus.served),
    ];

    return Column(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final (icon, label, status) = entry.value;
        final isCompleted = currentStatus.stepIndex > status.stepIndex;
        final isActive = currentStatus == status;
        final isPending = !isCompleted && !isActive;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.secondary
                        : isActive
                        ? cs.primary
                        : cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      if (isActive)
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.10),
                          blurRadius: 24,
                          spreadRadius: 8,
                        ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: isPending
                        ? cs.onSurfaceVariant.withValues(alpha: 0.50)
                        : isCompleted
                        ? AppColors.onSecondary
                        : cs.onPrimary,
                  ),
                ),
                if (index < steps.length - 1)
                  Container(
                    width: 4,
                    height: 64,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppColors.secondary
                          : cs.surfaceContainerHigh.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 32),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: isPending
                            ? cs.onSurfaceVariant.withValues(alpha: 0.40)
                            : cs.onSurface,
                      ),
                    ),
                    if (isActive)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: RepaintBoundary(
                          child:
                            Text(
                                  'IN PROGRESS',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 4.8,
                                    color: cs.primary,
                                  ),
                                )
                                .animate(onPlay: (c) => c.repeat(reverse: true))
                                .fadeIn(duration: 1000.ms)
                                .then()
                                .fade(begin: 1, end: 0.4, duration: 1000.ms),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      }).toList(),
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
