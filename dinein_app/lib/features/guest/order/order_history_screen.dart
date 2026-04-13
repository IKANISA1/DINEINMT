import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';

class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(userOrdersProvider);

    return ordersAsync.when(
      loading: () => const CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _OrderHistoryHeader()),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppTheme.space6,
              0,
              AppTheme.space6,
              AppTheme.space8,
            ),
            sliver: _OrderHistorySkeletonList(),
          ),
        ],
      ),
      error: (error, stackTrace) => CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _OrderHistoryHeader()),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space6,
                0,
                AppTheme.space6,
                AppTheme.space8,
              ),
              child: ErrorState(
                message: 'Could not load order history.',
                onRetry: () => ref.invalidate(userOrdersProvider),
              ),
            ),
          ),
        ],
      ),
      data: (orders) => CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _OrderHistoryHeader()),
          if (orders.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.space6,
                  0,
                  AppTheme.space6,
                  AppTheme.space8,
                ),
                child: _EmptyOrderHistoryState(
                  onBrowseVenues: () => context.goNamed(AppRouteNames.discover),
                ),
              ),
            )
          else ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppTheme.space6,
                  0,
                  AppTheme.space6,
                  AppTheme.space4,
                ),
                child: GuestSectionHeader(
                  title: 'Recent',
                  subtitle: 'Open any order for live status.',
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space6,
                0,
                AppTheme.space6,
                AppTheme.space8,
              ),
              sliver: SliverList.separated(
                itemCount: orders.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppTheme.space4),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return _OrderHistoryCard(
                    order: order,
                    onTap: () => context.pushNamed(
                      AppRouteNames.orderStatus,
                      pathParameters: {AppRouteParams.id: order.id},
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderHistoryHeader extends StatelessWidget {
  const _OrderHistoryHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space6,
        AppTheme.space6,
        AppTheme.space6,
        AppTheme.space5,
      ),
      child: GuestHeroCard(
        eyebrow: 'Your orders',
        title: 'Track every table visit',
        subtitle: 'Past and active orders in one place.',
        footer: Wrap(
          spacing: AppTheme.space3,
          runSpacing: AppTheme.space3,
          children: const [
            GuestMetaPill(
              label: 'Live status',
              icon: LucideIcons.clock3,
              emphasized: true,
            ),
            GuestMetaPill(label: 'Receipts', icon: Icons.receipt_long_rounded),
          ],
        ),
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
          padding: EdgeInsets.only(bottom: AppTheme.space4),
          child: SkeletonLoader(width: double.infinity, height: 140),
        );
      }, childCount: 4),
    );
  }
}

class _EmptyOrderHistoryState extends StatelessWidget {
  final VoidCallback onBrowseVenues;

  const _EmptyOrderHistoryState({required this.onBrowseVenues});

  @override
  Widget build(BuildContext context) {
    return GuestStatePanel(
      icon: LucideIcons.receipt,
      title: 'No orders yet',
      subtitle: 'Your past table orders will show up here.',
      actionLabel: 'Browse venues',
      onAction: onBrowseVenues,
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

    return GuestSurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppTheme.space4),
      borderRadius: 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: SizedBox(
              width: 88,
              height: 88,
              child: DineInImage(
                imageUrl: order.venueImageUrl,
                fit: BoxFit.cover,
                fallbackIcon: LucideIcons.store,
                semanticLabel: '${order.venueName} photo',
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        order.venueName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleLarge,
                      ),
                    ),
                    const SizedBox(width: AppTheme.space3),
                    _OrderStatusPill(order: order),
                  ],
                ),
                const SizedBox(height: AppTheme.space3),
                Wrap(
                  spacing: AppTheme.space2,
                  runSpacing: AppTheme.space2,
                  children: [
                    GuestMetaPill(
                      label: '#${order.displayNumber}',
                      icon: Icons.receipt_long_rounded,
                      emphasized: true,
                    ),
                    GuestMetaPill(
                      label: _formatDate(order.createdAt),
                      icon: LucideIcons.clock3,
                    ),
                    GuestMetaPill(
                      label: '${order.itemCount} items',
                      icon: LucideIcons.utensilsCrossed,
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.space3),
                Text(
                  moreCount > 0
                      ? '$itemNames +$moreCount more'
                      : itemNames.isEmpty
                      ? '${order.itemCount} items'
                      : itemNames,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.84),
                  ),
                ),
                const SizedBox(height: AppTheme.space3),
                Row(
                  children: [
                    Text(
                      order.formatPrice(order.total),
                      style: tt.titleMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: cs.onSurfaceVariant,
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
}

class _OrderStatusPill extends StatelessWidget {
  final Order order;

  const _OrderStatusPill({required this.order});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = switch (order.status) {
      OrderStatus.placed => cs.tertiary,
      OrderStatus.received => cs.primary,
      OrderStatus.served => cs.secondary,
      OrderStatus.cancelled => cs.error,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: statusColor.withValues(alpha: 0.18)),
      ),
      child: Text(
        order.status.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: statusColor,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
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
