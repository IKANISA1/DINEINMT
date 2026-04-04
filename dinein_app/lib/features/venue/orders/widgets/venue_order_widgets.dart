part of '../venue_orders_screen.dart';

// ═══════════════════════════════════════════════════
// PRIVATE WIDGETS
// ═══════════════════════════════════════════════════

/// Mini stat card for the header.
class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: AppTheme.clayShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: cs.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: cs.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: tt.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Status filter tab chip.
class _TabChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.20),
                      blurRadius: 12,
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Collapsible filter panel.
class _FilterPanel extends StatelessWidget {
  final _TimePeriod timePeriod;
  final _SortBy sortBy;
  final String itemFilter;
  final Set<String> itemNames;
  final ValueChanged<_TimePeriod> onTimePeriod;
  final ValueChanged<_SortBy> onSortBy;
  final ValueChanged<String> onItemFilter;
  final VoidCallback onExportPdf;
  final VoidCallback onExportCsv;

  const _FilterPanel({
    required this.timePeriod,
    required this.sortBy,
    required this.itemFilter,
    required this.itemNames,
    required this.onTimePeriod,
    required this.onSortBy,
    required this.onItemFilter,
    required this.onExportPdf,
    required this.onExportCsv,
  });

  String _timePeriodLabel(_TimePeriod p) => switch (p) {
    _TimePeriod.allTime => 'All Time',
    _TimePeriod.today => 'Today',
    _TimePeriod.thisWeek => 'This Week',
    _TimePeriod.thisMonth => 'This Month',
  };

  String _sortByLabel(_SortBy s) => switch (s) {
    _SortBy.newestFirst => 'Newest First',
    _SortBy.oldestFirst => 'Oldest First',
    _SortBy.highestValue => 'Highest Value',
    _SortBy.lowestValue => 'Lowest Value',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(top: AppTheme.space4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: AppTheme.clayShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time Period + Sort By (side by side)
          Row(
            children: [
              Expanded(
                child: _FilterDropdown<_TimePeriod>(
                  icon: LucideIcons.calendar,
                  label: 'TIME PERIOD',
                  value: timePeriod,
                  items: _TimePeriod.values,
                  labelBuilder: _timePeriodLabel,
                  onChanged: onTimePeriod,
                ),
              ),
              const SizedBox(width: AppTheme.space4),
              Expanded(
                child: _FilterDropdown<_SortBy>(
                  icon: LucideIcons.arrowUpDown,
                  label: 'SORT BY',
                  value: sortBy,
                  items: _SortBy.values,
                  labelBuilder: _sortByLabel,
                  onChanged: onSortBy,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space4),

          // Filter by Item
          Row(
            children: [
              Icon(LucideIcons.tag, size: 12, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'FILTER BY ITEM',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: itemNames.contains(itemFilter)
                    ? itemFilter
                    : 'All Items',
                isExpanded: true,
                dropdownColor: cs.surfaceContainerHigh,
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                items: [
                  const DropdownMenuItem(
                    value: 'All Items',
                    child: Text('All Items'),
                  ),
                  ...itemNames.map(
                    (name) => DropdownMenuItem(
                      value: name,
                      child: Text(name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) onItemFilter(v);
                },
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space5),

          // Export buttons
          Row(
            children: [
              Expanded(
                child: _ExportButton(
                  icon: LucideIcons.fileText,
                  label: 'EXPORT PDF',
                  color: cs.error.withValues(alpha: 0.12),
                  textColor: cs.error,
                  onTap: onExportPdf,
                ),
              ),
              const SizedBox(width: AppTheme.space3),
              Expanded(
                child: _ExportButton(
                  icon: LucideIcons.fileSpreadsheet,
                  label: 'EXPORT EXCEL',
                  color: cs.primary.withValues(alpha: 0.12),
                  textColor: cs.primary,
                  onTap: onExportCsv,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}

/// Dropdown-style filter widget.
class _FilterDropdown<T> extends StatelessWidget {
  final IconData icon;
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onChanged;

  const _FilterDropdown({
    required this.icon,
    required this.label,
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: cs.surfaceContainerHigh,
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              items: items
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(
                        labelBuilder(item),
                        style: tt.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Export action button.
class _ExportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _ExportButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: textColor.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rich order card matching screenshots — guest name, item chips, time, total.
class _OrderCard extends StatelessWidget {
  final Order order;
  final String currencySymbol;
  final VoidCallback onAdvance;

  const _OrderCard({
    required this.order,
    required this.currencySymbol,
    required this.onAdvance,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Color statusColor() {
      return switch (order.status) {
        OrderStatus.placed => cs.tertiary,
        OrderStatus.received => AppColors.warning,
        OrderStatus.served => cs.primary,
        OrderStatus.cancelled => cs.error,
      };
    }

    String statusLabel() {
      return switch (order.status) {
        OrderStatus.placed => 'NEW',
        OrderStatus.received => 'PREPARING',
        OrderStatus.served => 'SERVED',
        OrderStatus.cancelled => 'CANCELLED',
      };
    }

    IconData statusIcon() {
      return switch (order.status) {
        OrderStatus.placed => LucideIcons.inbox,
        OrderStatus.received => LucideIcons.shoppingBag,
        OrderStatus.served => LucideIcons.checkCircle,
        OrderStatus.cancelled => LucideIcons.xCircle,
      };
    }

    return PressableScale(
      onTap: () => context.pushNamed(
        AppRouteNames.venueOrderDetail,
        pathParameters: {AppRouteParams.id: order.id},
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: AppTheme.clayShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header: Order ID + Status ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ORDER #${order.displayNumber}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: cs.primary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor().withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon(), size: 12, color: statusColor()),
                      const SizedBox(width: 5),
                      Text(
                        statusLabel(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: statusColor(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ─── Guest Name ───
            Text(
              order.userName ?? 'Table ${order.tableNumber ?? '—'}',
              style: tt.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // ─── Item Chips ───
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: order.items.take(3).map((item) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${item.quantity}x ${item.name}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                );
              }).toList(),
            ),
            if (order.items.length > 3) ...[
              const SizedBox(height: 4),
              Text(
                '+${order.items.length - 3} more',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ],

            // ─── Special Requests Note ───
            if (order.specialRequests != null &&
                order.specialRequests!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      LucideIcons.messageSquare,
                      size: 12,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.specialRequests!.trim(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          color: cs.onSurface.withValues(alpha: 0.80),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // ─── Footer: Time + Total + Arrow / Action ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          LucideIcons.clock,
                          size: 12,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          timeAgo(order.createdAt).toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$currencySymbol${order.total.toStringAsFixed(2)}',
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                order.status.isActive
                    ? PressableScale(
                        onTap: onAdvance,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            order.status == OrderStatus.placed
                                ? 'ACCEPT'
                                : 'SERVED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: cs.onPrimary,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          LucideIcons.chevronRight,
                          size: 20,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
