import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';

/// Order details / receipt screen.
class OrderDetailsScreen extends ConsumerWidget {
  final String orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderByIdProvider(orderId));

    return Scaffold(
      body: orderAsync.when(
        loading: () => const SafeArea(child: _OrderDetailsLoadingState()),
        error: (err, _) => ErrorState(
          message: 'Could not load order details.',
          onRetry: () => ref.invalidate(orderByIdProvider(orderId)),
        ),
        data: (order) {
          if (order == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space6),
                child: GuestStatePanel(
                  icon: LucideIcons.receipt,
                  title: 'Order not found',
                  subtitle: 'This receipt is unavailable right now.',
                  actionLabel: 'Order history',
                  onAction: () => context.goNamed(AppRouteNames.orderHistory),
                ),
              ),
            );
          }
          return _OrderDetailsContent(order: order);
        },
      ),
    );
  }
}

class _OrderDetailsContent extends StatelessWidget {
  final Order order;

  const _OrderDetailsContent({required this.order});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final finalTotal = order.total;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.space6,
          AppTheme.space5,
          AppTheme.space6,
          AppTheme.space8,
        ),
        children: [
          Row(
            children: [
              AppIconButton(
                icon: LucideIcons.chevronLeft,
                onTap: () => context.pop(),
                semanticLabel: 'Go back',
              ),
              const SizedBox(width: AppTheme.space4),
              Expanded(child: Text('Receipt', style: tt.titleLarge)),
            ],
          ),
          const SizedBox(height: AppTheme.space5),
          GuestHeroCard(
            eyebrow: 'Order #${order.displayNumber}',
            title: order.venueName,
            subtitle: 'Placed ${_formatDate(order.createdAt)}',
            footer: Wrap(
              spacing: AppTheme.space3,
              runSpacing: AppTheme.space3,
              children: [
                GuestMetaPill(
                  label: order.status.label,
                  icon: _statusIcon(order.status),
                  emphasized: true,
                ),
                GuestMetaPill(
                  label: order.paymentMethod.label,
                  icon: LucideIcons.wallet,
                ),
                if ((order.tableNumber ?? '').trim().isNotEmpty)
                  GuestMetaPill(
                    label: 'Table ${order.tableNumber!.trim()}',
                    icon: LucideIcons.hash,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space5),
          GuestSurfaceCard(
            padding: const EdgeInsets.all(AppTheme.space5),
            borderRadius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GuestSectionHeader(
                  title: 'Items',
                  subtitle: 'Everything included in this order.',
                ),
                const SizedBox(height: AppTheme.space4),
                ...order.items.indexed.expand((entry) {
                  final index = entry.$1;
                  final item = entry.$2;
                  return [
                    if (index > 0)
                      Divider(
                        color: cs.outlineVariant.withValues(alpha: 0.5),
                        height: AppTheme.space6,
                      ),
                    _ReceiptItemRow(order: order, item: item),
                  ];
                }),
              ],
            ),
          ),
          if ((order.specialRequests ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppTheme.space5),
            GuestSurfaceCard(
              padding: const EdgeInsets.all(AppTheme.space5),
              borderRadius: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Table notes', style: tt.titleSmall),
                  const SizedBox(height: AppTheme.space2),
                  Text(
                    order.specialRequests!.trim(),
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.84),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppTheme.space5),
          GuestSurfaceCard(
            highlighted: true,
            padding: const EdgeInsets.all(AppTheme.space5),
            borderRadius: 24,
            child: Column(
              children: [
                _SummaryRow(
                  label: 'Subtotal',
                  value: order.formatPrice(order.subtotal),
                ),
                const SizedBox(height: AppTheme.space3),
                _SummaryRow(
                  label: 'Service fee',
                  value: order.formatPrice(order.serviceFee),
                ),
                const SizedBox(height: AppTheme.space4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total', style: tt.titleLarge),
                    Text(
                      order.formatPrice(finalTotal),
                      style: tt.headlineSmall?.copyWith(
                        color: cs.primary,
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
    );
  }

  IconData _statusIcon(OrderStatus status) {
    return switch (status) {
      OrderStatus.placed => LucideIcons.clock3,
      OrderStatus.received => LucideIcons.chefHat,
      OrderStatus.served => LucideIcons.check,
      OrderStatus.cancelled => LucideIcons.x,
    };
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

class _ReceiptItemRow extends StatelessWidget {
  final Order order;
  final OrderItem item;

  const _ReceiptItemRow({required this.order, required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: SizedBox(
            width: 64,
            height: 64,
            child: DineInImage(
              imageUrl: item.imageUrl,
              fit: BoxFit.cover,
              fallbackIcon: LucideIcons.chefHat,
              semanticLabel: '${item.name} photo',
            ),
          ),
        ),
        const SizedBox(width: AppTheme.space4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(item.name, style: tt.titleSmall)),
                  Text(
                    order.formatPrice(item.subtotal),
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space2),
              Wrap(
                spacing: AppTheme.space2,
                runSpacing: AppTheme.space2,
                children: [
                  GuestMetaPill(
                    label:
                        '${item.quantity} item${item.quantity == 1 ? '' : 's'}',
                    icon: LucideIcons.hash,
                  ),
                  GuestMetaPill(
                    label: order.formatPrice(item.price),
                    icon: LucideIcons.wallet,
                  ),
                ],
              ),
              if (item.description.trim().isNotEmpty) ...[
                const SizedBox(height: AppTheme.space2),
                Text(
                  item.description.trim(),
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.78),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if ((item.note ?? '').toString().trim().isNotEmpty) ...[
                const SizedBox(height: AppTheme.space2),
                Text(
                  'Note: ${item.note.toString().trim()}',
                  style: tt.bodySmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: tt.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant.withValues(alpha: 0.84),
          ),
        ),
        Text(value, style: tt.titleSmall),
      ],
    );
  }
}

class _OrderDetailsLoadingState extends StatelessWidget {
  const _OrderDetailsLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppTheme.space6),
      children: const [
        SkeletonLoader(width: 120, height: 40, borderRadius: 14),
        SizedBox(height: AppTheme.space5),
        SkeletonLoader(width: double.infinity, height: 180, borderRadius: 28),
        SizedBox(height: AppTheme.space5),
        SkeletonLoader(width: double.infinity, height: 220, borderRadius: 24),
        SizedBox(height: AppTheme.space5),
        SkeletonLoader(width: double.infinity, height: 120, borderRadius: 24),
      ],
    );
  }
}
