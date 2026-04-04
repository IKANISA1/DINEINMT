import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';
import '../../../core/providers/providers.dart';
import 'package:dinein_app/core/services/order_repository.dart';
import 'package:core_pkg/utils/time_ago.dart';
import 'package:ui/widgets/shared_widgets.dart';

part 'widgets/venue_order_widgets.dart';

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

    final bytes = Uint8List.fromList(await doc.save());
    final fileName =
        'orders_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

    if (context.mounted) {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes, name: fileName, mimeType: 'application/pdf'),
          ],
        ),
      );
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
    final bytes = Uint8List.fromList(utf8.encode(csvData));
    final fileName =
        'orders_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';

    if (context.mounted) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, name: fileName, mimeType: 'text/csv')],
        ),
      );
    }
  }
}
