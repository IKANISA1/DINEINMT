import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/enums.dart';
import '../../../core/providers/providers.dart';
import '../../../core/models/models.dart';
import '../../../core/utils/time_ago.dart';
import '../../../shared/widgets/shared_widgets.dart';

/// Admin order oversight — system-wide order monitoring.
/// Matches React admin/Orders.tsx:
/// - Header: ShoppingBag icon + "GLOBAL OPERATIONS" + "Orders" 6xl + Filter button
/// - Clay search bar (rounded-[2.5rem])
/// - Stats grid: 3-column (Active / Completed / Issues)
/// - "Global Feed" label → rich order cards with payment icons + issue alerts
class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

enum _AdminOrderFilter { all, active, completed, issues }

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _AdminOrderFilter _statusFilter = _AdminOrderFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesFilter(Order order) {
    return switch (_statusFilter) {
      _AdminOrderFilter.all => true,
      _AdminOrderFilter.active =>
        order.status == OrderStatus.placed ||
            order.status == OrderStatus.received,
      _AdminOrderFilter.completed => order.status == OrderStatus.served,
      _AdminOrderFilter.issues => order.status == OrderStatus.cancelled,
    };
  }

  String _filterLabel(_AdminOrderFilter filter) {
    return switch (filter) {
      _AdminOrderFilter.all => 'All Orders',
      _AdminOrderFilter.active => 'Active',
      _AdminOrderFilter.completed => 'Completed',
      _AdminOrderFilter.issues => 'Issues',
    };
  }

  Future<void> _openFilterSheet(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(AppTheme.space4),
        padding: const EdgeInsets.all(AppTheme.space6),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
          border: Border.all(color: AppColors.white5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter Orders',
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppTheme.space2),
            Text(
              'Choose which orders appear in the global feed.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppTheme.space5),
            ..._AdminOrderFilter.values.map((filter) {
              final selected = filter == _statusFilter;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.space3),
                child: PressableScale(
                  onTap: () {
                    setState(() => _statusFilter = filter);
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.space5),
                    decoration: BoxDecoration(
                      color: selected
                          ? cs.primary.withValues(alpha: 0.08)
                          : cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                      border: Border.all(
                        color: selected
                            ? cs.primary.withValues(alpha: 0.20)
                            : Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _filterLabel(filter),
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (selected)
                          Icon(LucideIcons.check, size: 18, color: cs.primary),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ordersAsync = ref.watch(allOrdersProvider);

    return ordersAsync.when(
      loading: () => const Center(
        child: SkeletonLoader(width: double.infinity, height: 300),
      ),
      error: (_, _) => ErrorState(
        message: 'Could not load orders.',
        onRetry: () => ref.invalidate(allOrdersProvider),
      ),
      data: (orders) => _buildContent(context, cs, tt, orders),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
    List<Order> orders,
  ) {
    // Filter by search
    final filtered = _query.isEmpty
        ? orders
        : orders.where((o) {
            final q = _query.toLowerCase();
            return o.displayNumber.toLowerCase().contains(q) ||
                o.id.toLowerCase().contains(q) ||
                o.venueName.toLowerCase().contains(q);
          }).toList();
    final visibleOrders = filtered.where(_matchesFilter).toList();

    // Stats
    final activeCount = orders
        .where(
          (o) =>
              o.status == OrderStatus.placed ||
              o.status == OrderStatus.received,
        )
        .length;
    final completedCount = orders
        .where((o) => o.status == OrderStatus.served)
        .length;
    final issueCount = orders
        .where((o) => o.status == OrderStatus.cancelled)
        .length;

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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          LucideIcons.shoppingBag,
                          size: 20,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'GLOBAL OPERATIONS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            color: cs.primary.withValues(alpha: 0.70),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.space2),
                    Text(
                      'Orders',
                      style: tt.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.5,
                      ),
                    ),
                  ],
                ),
                PressableScale(
                  onTap: () => _openFilterSheet(context),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                      boxShadow: AppTheme.clayShadow,
                    ),
                    child: Icon(
                      LucideIcons.filter,
                      size: 24,
                      color: _statusFilter == _AdminOrderFilter.all
                          ? cs.onSurfaceVariant.withValues(alpha: 0.60)
                          : cs.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ─── Search Bar ───
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space8,
              AppTheme.space10,
              AppTheme.space8,
              0,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                boxShadow: AppTheme.clayShadow,
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Icon(
                      LucideIcons.search,
                      size: 24,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.20),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v.trim()),
                      decoration: InputDecoration(
                        hintText: 'Search orders by ID or venue...',
                        border: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        hintStyle: tt.titleLarge?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.10),
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ─── Stats Grid (3-column) ───
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space8,
              AppTheme.space10,
              AppTheme.space8,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Active',
                    value: '$activeCount',
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(width: AppTheme.space5),
                Expanded(
                  child: _StatCard(
                    label: 'Completed',
                    value: '$completedCount',
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(width: AppTheme.space5),
                Expanded(
                  child: _StatCard(
                    label: 'Issues',
                    value: '$issueCount',
                    color: cs.error,
                    isError: true,
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_statusFilter != _AdminOrderFilter.all)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space8,
                AppTheme.space4,
                AppTheme.space8,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusBadge(
                  label: _filterLabel(_statusFilter),
                  color: cs.primary.withValues(alpha: 0.12),
                  textColor: cs.primary,
                ),
              ),
            ),
          ),

        // ─── "Global Feed" label ───
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space8 + 16,
              AppTheme.space12,
              AppTheme.space8,
              AppTheme.space4,
            ),
            child: Text(
              'Global Feed',
              style: tt.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),

        // ─── Order Cards ───
        if (visibleOrders.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: LucideIcons.shoppingBag,
              title: 'No orders',
              subtitle: _query.isNotEmpty
                  ? 'Try a different search term.'
                  : 'Orders will appear here once placed.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space8,
              0,
              AppTheme.space8,
              AppTheme.space24,
            ),
            sliver: SliverList.separated(
              itemCount: visibleOrders.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppTheme.space5),
              itemBuilder: (context, index) {
                final order = visibleOrders[index];
                return _OrderFeedCard(order: order)
                    .animate(delay: (100 * index).ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.05, end: 0);
              },
            ),
          ),
      ],
    );
  }
}

/// 3-column stat card matching React's stats grid.
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isError;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.space6),
      decoration: BoxDecoration(
        color: isError
            ? cs.error.withValues(alpha: 0.05)
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: isError
              ? cs.error.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.05),
        ),
        boxShadow: AppTheme.clayShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              color: isError
                  ? cs.error
                  : cs.onSurfaceVariant.withValues(alpha: 0.50),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rich order card matching React's Global Feed cards.
class _OrderFeedCard extends StatelessWidget {
  final Order order;

  const _OrderFeedCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasIssue = order.status == OrderStatus.cancelled;

    Color statusColor() {
      return switch (order.status) {
        OrderStatus.placed => cs.primary,
        OrderStatus.received => AppColors.secondary,
        OrderStatus.served => cs.onSurface.withValues(alpha: 0.40),
        OrderStatus.cancelled => cs.error,
      };
    }

    IconData paymentIcon() {
      return switch (order.paymentMethod) {
        PaymentMethod.revolutLink => LucideIcons.creditCard,
        PaymentMethod.cash => LucideIcons.banknote,
        PaymentMethod.momoUssd => LucideIcons.smartphone,
      };
    }

    return PressableScale(
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.radius3xl),
          border: Border.all(
            color: hasIssue
                ? cs.error.withValues(alpha: 0.20)
                : Colors.white.withValues(alpha: 0.05),
          ),
          boxShadow: AppTheme.clayShadow,
        ),
        child: Column(
          children: [
            // ─── Top Row: ID + Venue + Status ───
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order ID badge
                Container(
                  width: 92,
                  height: 64,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  ),
                  child: Center(
                    child: Text(
                      '#${order.displayNumber}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.30),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.space5),
                // Venue + table + items
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.venueName,
                        style: tt.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'TABLE ${order.tableNumber ?? '—'}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                              color: cs.onSurfaceVariant.withValues(
                                alpha: 0.50,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: cs.outlineVariant.withValues(
                                  alpha: 0.20,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Text(
                            '${order.itemCount} ITEMS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                              color: cs.onSurfaceVariant.withValues(
                                alpha: 0.50,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor().withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    order.status.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      color: statusColor(),
                    ),
                  ),
                ),
              ],
            ),

            // ─── Divider ───
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.space6),
              child: Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),

            // ─── Bottom Row: Payment + Time + Total + Chevron ───
            Row(
              children: [
                // Payment method
                Row(
                  children: [
                    Icon(
                      paymentIcon(),
                      size: 14,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.50),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      order.paymentMethod.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.50),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppTheme.space6),
                // Time
                Row(
                  children: [
                    Icon(
                      LucideIcons.clock,
                      size: 14,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.50),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeAgo(order.createdAt).toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.50),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Total price
                Text(
                  '${order.currencySymbol}${order.total.toStringAsFixed(2)}',
                  style: tt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: AppTheme.space5),
                // Chevron
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.chevronRight,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            // ─── Issue Alert (if applicable) ───
            if (hasIssue) ...[
              const SizedBox(height: AppTheme.space5),
              Container(
                padding: const EdgeInsets.all(AppTheme.space5),
                decoration: BoxDecoration(
                  color: cs.error.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                  border: Border.all(color: cs.error.withValues(alpha: 0.10)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cs.error.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        LucideIcons.alertCircle,
                        size: 18,
                        color: cs.error,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'ACTION REQUIRED: ORDER CANCELLED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: cs.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
