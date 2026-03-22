import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/enums.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/services/order_repository.dart';
import '../../../core/utils/time_ago.dart';
import '../../../shared/widgets/shared_widgets.dart';

/// Venue order management — fullstack with sorting, filtering, search, export.
///
/// Data sources (all from Supabase):
/// - Orders → [venueOrdersProvider] (Supabase Realtime StreamProvider)
/// - Status updates → [OrderRepository.updateOrderStatus]
///
/// Features:
/// - Summary stat cards (total orders + revenue)
/// - Status filter tabs (ALL, PREPARING, SERVED)
/// - Search by Order ID, Guest Name, or Item
/// - Filter panel: Time Period, Sort By, Filter by Item
/// - Export as PDF or CSV (Excel)
class VenueOrdersScreen extends ConsumerStatefulWidget {
  const VenueOrdersScreen({super.key});

  @override
  ConsumerState<VenueOrdersScreen> createState() => _VenueOrdersScreenState();
}

enum _StatusFilter { all, preparing, served, cancelled }

enum _TimePeriod { allTime, today, thisWeek, thisMonth }

enum _SortBy { newestFirst, oldestFirst, highestValue, lowestValue }

class _VenueOrdersScreenState extends ConsumerState<VenueOrdersScreen> {
  _StatusFilter _statusFilter = _StatusFilter.all;
  _TimePeriod _timePeriod = _TimePeriod.allTime;
  _SortBy _sortBy = _SortBy.newestFirst;
  String _itemFilter = 'All Items';
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showFilterPanel = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final venueAsync = ref.watch(currentVenueProvider);

    return venueAsync.when(
      loading: () => const Center(
        child: SkeletonLoader(width: double.infinity, height: 200),
      ),
      error: (err, _) => ErrorState(
        message: 'Could not load venue data.',
        onRetry: () => ref.invalidate(currentVenueProvider),
      ),
      data: (venue) {
        if (venue == null) {
          return const EmptyState(
            icon: LucideIcons.store,
            title: 'No venue access',
            subtitle: 'Claim and verify a venue first.',
          );
        }
        return _OrdersBody(
          venueId: venue.id,
          venueName: venue.name,
          currencySymbol: venue.country.currencySymbol,
          statusFilter: _statusFilter,
          timePeriod: _timePeriod,
          sortBy: _sortBy,
          itemFilter: _itemFilter,
          searchQuery: _searchQuery,
          searchController: _searchController,
          showFilterPanel: _showFilterPanel,
          onStatusFilter: (f) => setState(() => _statusFilter = f),
          onTimePeriod: (p) => setState(() => _timePeriod = p),
          onSortBy: (s) => setState(() => _sortBy = s),
          onItemFilter: (i) => setState(() => _itemFilter = i),
          onSearch: (q) => setState(() => _searchQuery = q),
          onToggleFilter: () =>
              setState(() => _showFilterPanel = !_showFilterPanel),
        );
      },
    );
  }
}

class _OrdersBody extends ConsumerWidget {
  final String venueId;
  final String venueName;
  final String currencySymbol;
  final _StatusFilter statusFilter;
  final _TimePeriod timePeriod;
  final _SortBy sortBy;
  final String itemFilter;
  final String searchQuery;
  final TextEditingController searchController;
  final bool showFilterPanel;
  final ValueChanged<_StatusFilter> onStatusFilter;
  final ValueChanged<_TimePeriod> onTimePeriod;
  final ValueChanged<_SortBy> onSortBy;
  final ValueChanged<String> onItemFilter;
  final ValueChanged<String> onSearch;
  final VoidCallback onToggleFilter;

  const _OrdersBody({
    required this.venueId,
    required this.venueName,
    required this.currencySymbol,
    required this.statusFilter,
    required this.timePeriod,
    required this.sortBy,
    required this.itemFilter,
    required this.searchQuery,
    required this.searchController,
    required this.showFilterPanel,
    required this.onStatusFilter,
    required this.onTimePeriod,
    required this.onSortBy,
    required this.onItemFilter,
    required this.onSearch,
    required this.onToggleFilter,
  });

  List<Order> _applyFilters(List<Order> orders) {
    var filtered = List<Order>.from(orders);

    // Status filter
    filtered = switch (statusFilter) {
      _StatusFilter.all => filtered,
      _StatusFilter.preparing =>
        filtered
            .where(
              (o) =>
                  o.status == OrderStatus.placed ||
                  o.status == OrderStatus.received,
            )
            .toList(),
      _StatusFilter.served =>
        filtered.where((o) => o.status == OrderStatus.served).toList(),
      _StatusFilter.cancelled =>
        filtered.where((o) => o.status == OrderStatus.cancelled).toList(),
    };

    // Time period filter
    final now = DateTime.now();
    filtered = switch (timePeriod) {
      _TimePeriod.allTime => filtered,
      _TimePeriod.today =>
        filtered
            .where(
              (o) =>
                  o.createdAt.day == now.day &&
                  o.createdAt.month == now.month &&
                  o.createdAt.year == now.year,
            )
            .toList(),
      _TimePeriod.thisWeek =>
        filtered.where((o) => now.difference(o.createdAt).inDays < 7).toList(),
      _TimePeriod.thisMonth =>
        filtered
            .where(
              (o) =>
                  o.createdAt.month == now.month &&
                  o.createdAt.year == now.year,
            )
            .toList(),
    };

    // Item filter
    if (itemFilter != 'All Items') {
      filtered = filtered
          .where((o) => o.items.any((item) => item.name == itemFilter))
          .toList();
    }

    // Search
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      filtered = filtered.where((o) {
        return o.displayNumber.toLowerCase().contains(q) ||
            o.id.toLowerCase().contains(q) ||
            (o.userName ?? '').toLowerCase().contains(q) ||
            (o.tableNumber ?? '').toLowerCase().contains(q) ||
            o.items.any((item) => item.name.toLowerCase().contains(q));
      }).toList();
    }

    // Sort
    switch (sortBy) {
      case _SortBy.newestFirst:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _SortBy.oldestFirst:
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case _SortBy.highestValue:
        filtered.sort((a, b) => b.total.compareTo(a.total));
      case _SortBy.lowestValue:
        filtered.sort((a, b) => a.total.compareTo(b.total));
    }

    return filtered;
  }

  Set<String> _allItemNames(List<Order> orders) {
    final names = <String>{};
    for (final o in orders) {
      for (final item in o.items) {
        names.add(item.name);
      }
    }
    return names;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ordersAsync = ref.watch(venueOrdersProvider(venueId));

    return ordersAsync.when(
      loading: () => const Center(
        child: SkeletonLoader(width: double.infinity, height: 200),
      ),
      error: (err, _) => ErrorState(
        message: 'Could not load orders.',
        onRetry: () => ref.invalidate(venueOrdersProvider(venueId)),
      ),
      data: (allOrders) {
        final filtered = _applyFilters(allOrders);
        final totalRevenue = filtered.fold<double>(
          0,
          (sum, o) => sum + o.total,
        );
        final itemNames = _allItemNames(allOrders);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scrollable header + filters + list
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.space6,
                      AppTheme.space6,
                      AppTheme.space6,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ═══ HEADER ═══
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Orders',
                                style: tt.headlineLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              PressableScale(
                                onTap: onToggleFilter,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: showFilterPanel
                                        ? cs.primary.withValues(alpha: 0.15)
                                        : cs.surfaceContainerLow,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: showFilterPanel
                                          ? cs.primary.withValues(alpha: 0.3)
                                          : Colors.white.withValues(
                                              alpha: 0.05,
                                            ),
                                    ),
                                  ),
                                  child: Icon(
                                    LucideIcons.slidersHorizontal,
                                    size: 18,
                                    color: showFilterPanel
                                        ? cs.primary
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.space5),

                          // ═══ STAT CARDS ═══
                          Row(
                            children: [
                              Expanded(
                                child: _MiniStatCard(
                                  icon: LucideIcons.shoppingBag,
                                  label: 'TOTAL ORDERS',
                                  value: '${filtered.length}',
                                ),
                              ),
                              const SizedBox(width: AppTheme.space3),
                              Expanded(
                                child: _MiniStatCard(
                                  icon: LucideIcons.dollarSign,
                                  label: 'REVENUE',
                                  value:
                                      '$currencySymbol${totalRevenue.toStringAsFixed(totalRevenue > 999 ? 0 : 2)}',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.space5),

                          // ═══ STATUS TABS ═══
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Row(
                              children: [
                                _TabChip(
                                  label: 'ALL',
                                  isSelected: statusFilter == _StatusFilter.all,
                                  onTap: () =>
                                      onStatusFilter(_StatusFilter.all),
                                ),
                                _TabChip(
                                  label: 'PREPARING',
                                  isSelected:
                                      statusFilter == _StatusFilter.preparing,
                                  onTap: () =>
                                      onStatusFilter(_StatusFilter.preparing),
                                ),
                                _TabChip(
                                  label: 'SERVED',
                                  isSelected:
                                      statusFilter == _StatusFilter.served,
                                  onTap: () =>
                                      onStatusFilter(_StatusFilter.served),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppTheme.space4),

                          // ═══ SEARCH BAR ═══
                          Container(
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            child: TextField(
                              controller: searchController,
                              onChanged: onSearch,
                              style: tt.bodyMedium,
                              decoration: InputDecoration(
                                hintText:
                                    'Search Order Number, Guest or Item...',
                                hintStyle: tt.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.40,
                                  ),
                                ),
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 16,
                                    right: 10,
                                  ),
                                  child: Icon(
                                    LucideIcons.search,
                                    size: 18,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                prefixIconConstraints: const BoxConstraints(
                                  minWidth: 0,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),

                          // ═══ FILTER PANEL (collapsible) ═══
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            child: showFilterPanel
                                ? _FilterPanel(
                                    timePeriod: timePeriod,
                                    sortBy: sortBy,
                                    itemFilter: itemFilter,
                                    itemNames: itemNames,
                                    onTimePeriod: onTimePeriod,
                                    onSortBy: onSortBy,
                                    onItemFilter: onItemFilter,
                                    onExportPdf: () =>
                                        _exportPdf(context, filtered),
                                    onExportCsv: () =>
                                        _exportCsv(context, filtered),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          const SizedBox(height: AppTheme.space5),

                          // ═══ RESULTS COUNT ═══
                          Text(
                            '${filtered.length} ORDERS FOUND',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppTheme.space4),
                        ],
                      ),
                    ),
                  ),

                  // ═══ ORDER CARDS ═══
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: LucideIcons.clipboardList,
                        title: 'No orders found',
                        subtitle: 'Try adjusting your filters or search.',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space6,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final order = filtered[index];
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppTheme.space4,
                            ),
                            child:
                                _OrderCard(
                                      order: order,
                                      currencySymbol: currencySymbol,
                                      onAdvance: () =>
                                          _advanceStatus(ref, order),
                                    )
                                    .animate(delay: (60 * index).ms)
                                    .fadeIn(duration: 250.ms),
                          );
                        }, childCount: filtered.length),
                      ),
                    ),

                  // Bottom padding
                  const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _advanceStatus(WidgetRef ref, Order order) async {
    final nextStatus = switch (order.status) {
      OrderStatus.placed => OrderStatus.received,
      OrderStatus.received => OrderStatus.served,
      _ => null,
    };
    if (nextStatus == null) return;
    try {
      await OrderRepository.instance.updateOrderStatus(order.id, nextStatus);
      ref.invalidate(venueOrdersProvider(venueId));
    } catch (_) {}
  }

  Future<void> _exportPdf(BuildContext context, List<Order> orders) async {
    final doc = pw.Document();
    final dateLabel = DateFormat('MMMM d, yyyy').format(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  venueName,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Orders Report — $dateLabel',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  children: [
                    pw.Text(
                      'Total Orders: ${orders.length}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(width: 24),
                    pw.Text(
                      'Revenue: $currencySymbol${orders.fold<double>(0, (s, o) => s + o.total).toStringAsFixed(2)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: [
              'Order Number',
              'Guest',
              'Table',
              'Items',
              'Total',
              'Status',
              'Date',
            ],
            data: orders
                .map(
                  (o) => [
                    '#${o.displayNumber}',
                    o.userName ?? '—',
                    o.tableNumber ?? '—',
                    '${o.itemCount}',
                    '$currencySymbol${o.total.toStringAsFixed(2)}',
                    o.status.label,
                    DateFormat('dd/MM/yy HH:mm').format(o.createdAt),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/orders_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
    await file.writeAsBytes(await doc.save());

    if (context.mounted) {
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    }
  }

  Future<void> _exportCsv(BuildContext context, List<Order> orders) async {
    final rows = <List<String>>[
      [
        'Order Number',
        'Guest',
        'Table',
        'Items',
        'Item Details',
        'Total',
        'Status',
        'Payment Method',
        'Date',
      ],
      ...orders.map(
        (o) => [
          '#${o.displayNumber}',
          o.userName ?? '—',
          o.tableNumber ?? '—',
          '${o.itemCount}',
          o.items.map((i) => '${i.quantity}x ${i.name}').join('; '),
          '$currencySymbol${o.total.toStringAsFixed(2)}',
          o.status.label,
          o.paymentMethod.label,
          DateFormat('dd/MM/yy HH:mm').format(o.createdAt),
        ],
      ),
    ];

    final csvData = CsvEncoder().convert(
      rows.map((r) => r.map((c) => c.toString()).toList()).toList(),
    );
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/orders_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
    );
    await file.writeAsString(csvData);

    if (context.mounted) {
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    }
  }
}

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
