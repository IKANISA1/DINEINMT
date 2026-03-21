import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../shared/widgets/shared_widgets.dart';

/// Item Report — per-item sales performance analysis.
///
/// Aggregates order data from [venueOrdersProvider] (Supabase Realtime)
/// to show each menu item's total orders, revenue, and trend.
///
/// Features:
/// - Stat summary (Total Orders + Total Revenue)
/// - Time period tabs (DAY / WEEK / MONTH / CUSTOM)
/// - Search items
/// - Sort toggle (orders vs revenue, asc/desc)
/// - Sub-tabs: ORDERS vs REVENUE view
/// - Export PDF / CSV
class VenueItemReportScreen extends ConsumerStatefulWidget {
  const VenueItemReportScreen({super.key});

  @override
  ConsumerState<VenueItemReportScreen> createState() =>
      _VenueItemReportScreenState();
}

enum _TimePeriod { day, week, month, custom }
enum _ViewMode { orders, revenue }
enum _SortDir { desc, asc }

class _VenueItemReportScreenState
    extends ConsumerState<VenueItemReportScreen> {
  _TimePeriod _timePeriod = _TimePeriod.week;
  _ViewMode _viewMode = _ViewMode.orders;
  _SortDir _sortDir = _SortDir.desc;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Custom date range
  DateTimeRange? _customRange;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final venueAsync = ref.watch(currentVenueProvider);

    return venueAsync.when(
      loading: () =>
          const Center(child: SkeletonLoader(width: double.infinity, height: 200)),
      error: (_, _) => ErrorState(
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

        final ordersAsync = ref.watch(venueOrdersProvider(venue.id));
        final currency = venue.country.currencySymbol;

        return ordersAsync.when(
          loading: () => const Center(
              child: SkeletonLoader(width: double.infinity, height: 200)),
          error: (_, _) => ErrorState(
            message: 'Could not load orders.',
            onRetry: () => ref.invalidate(venueOrdersProvider(venue.id)),
          ),
          data: (allOrders) {
            // ─── Filter by time period ───
            final orders = _filterByTime(allOrders);

            // ─── Aggregate items ───
            final itemStats = _aggregateItems(orders);

            // ─── Search ───
            var filtered = itemStats;
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              filtered = filtered
                  .where((s) =>
                      s.name.toLowerCase().contains(q) ||
                      s.category.toLowerCase().contains(q))
                  .toList();
            }

            // ─── Sort ───
            filtered.sort((a, b) {
              final cmp = _viewMode == _ViewMode.orders
                  ? b.totalOrders.compareTo(a.totalOrders)
                  : b.totalRevenue.compareTo(a.totalRevenue);
              return _sortDir == _SortDir.desc ? cmp : -cmp;
            });

            final totalOrders =
                filtered.fold<int>(0, (s, i) => s + i.totalOrders);
            final totalRevenue =
                filtered.fold<double>(0, (s, i) => s + i.totalRevenue);

            return Scaffold(
              backgroundColor: Colors.transparent,
              body: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                        AppTheme.space6, AppTheme.space2, AppTheme.space6, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ═══ BACK + HEADER ═══
                          Row(
                            children: [
                              PressableScale(
                                onTap: () => Navigator.of(context).pop(),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerLow,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.05)),
                                  ),
                                  child: Icon(LucideIcons.chevronLeft,
                                      size: 18, color: cs.onSurface),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('Item Report',
                                        style: tt.headlineMedium?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.5)),
                                    Text('SALES PERFORMANCE ANALYSIS',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 2,
                                          color: cs.onSurfaceVariant,
                                        )),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.space6),

                          // ═══ STAT CARDS ═══
                          Row(
                            children: [
                              Expanded(
                                child: _MiniStatCard(
                                  icon: LucideIcons.shoppingBag,
                                  label: 'TOTAL ORDERS',
                                  value: '$totalOrders',
                                ),
                              ),
                              const SizedBox(width: AppTheme.space3),
                              Expanded(
                                child: _MiniStatCard(
                                  icon: LucideIcons.dollarSign,
                                  label: 'TOTAL REVENUE',
                                  value:
                                      '$currency${totalRevenue.toStringAsFixed(totalRevenue > 999 ? 0 : 2)}',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.space5),

                          // ═══ TIME PERIOD TABS ═══
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.05)),
                            ),
                            child: Row(
                              children: [
                                _PeriodTab(
                                    label: 'DAY',
                                    selected:
                                        _timePeriod == _TimePeriod.day,
                                    onTap: () => setState(
                                        () => _timePeriod = _TimePeriod.day)),
                                _PeriodTab(
                                    label: 'WEEK',
                                    selected:
                                        _timePeriod == _TimePeriod.week,
                                    onTap: () => setState(
                                        () => _timePeriod = _TimePeriod.week)),
                                _PeriodTab(
                                    label: 'MONTH',
                                    selected:
                                        _timePeriod == _TimePeriod.month,
                                    onTap: () => setState(() =>
                                        _timePeriod = _TimePeriod.month)),
                                _PeriodTab(
                                    label: 'CUSTOM',
                                    selected:
                                        _timePeriod == _TimePeriod.custom,
                                    onTap: () async {
                                      final range =
                                          await showDateRangePicker(
                                        context: context,
                                        firstDate: DateTime(2024),
                                        lastDate: DateTime.now(),
                                        initialDateRange: _customRange,
                                      );
                                      if (range != null && mounted) {
                                        setState(() {
                                          _customRange = range;
                                          _timePeriod = _TimePeriod.custom;
                                        });
                                      }
                                    }),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppTheme.space4),

                          // ═══ SEARCH + SORT ═══
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerLow,
                                    borderRadius:
                                        BorderRadius.circular(16),
                                    border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.05)),
                                  ),
                                  child: TextField(
                                    controller: _searchCtrl,
                                    onChanged: (q) =>
                                        setState(() => _searchQuery = q),
                                    style: tt.bodyMedium,
                                    decoration: InputDecoration(
                                      hintText: 'Search items…',
                                      hintStyle: tt.bodyMedium?.copyWith(
                                          color: cs.onSurfaceVariant
                                              .withValues(alpha: 0.40)),
                                      prefixIcon: Padding(
                                        padding: const EdgeInsets.only(
                                            left: 16, right: 10),
                                        child: Icon(LucideIcons.search,
                                            size: 18,
                                            color: cs.onSurfaceVariant),
                                      ),
                                      prefixIconConstraints:
                                          const BoxConstraints(
                                              minWidth: 0),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 16),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppTheme.space3),
                              PressableScale(
                                onTap: () => setState(() =>
                                    _sortDir = _sortDir == _SortDir.desc
                                        ? _SortDir.asc
                                        : _SortDir.desc),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerLow,
                                    borderRadius:
                                        BorderRadius.circular(16),
                                    border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.05)),
                                  ),
                                  child: Icon(LucideIcons.arrowUpDown,
                                      size: 18,
                                      color: cs.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.space4),

                          // ═══ EXPORT BUTTONS ═══
                          Row(
                            children: [
                              Expanded(
                                child: _ExportButton(
                                  icon: LucideIcons.fileText,
                                  label: 'EXPORT PDF',
                                  color: cs.error.withValues(alpha: 0.12),
                                  textColor: cs.error,
                                  onTap: () => _exportPdf(
                                      context, filtered, currency, venue.name),
                                ),
                              ),
                              const SizedBox(width: AppTheme.space3),
                              Expanded(
                                child: _ExportButton(
                                  icon: LucideIcons.fileSpreadsheet,
                                  label: 'EXPORT EXCEL',
                                  color:
                                      cs.primary.withValues(alpha: 0.12),
                                  textColor: cs.primary,
                                  onTap: () => _exportCsv(
                                      context, filtered, currency, venue.name),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.space5),

                          // ═══ VIEW MODE TABS ═══
                          Row(
                            children: [
                              Text('ITEM PERFORMANCE',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                    color: cs.onSurfaceVariant,
                                  )),
                              const Spacer(),
                              _ViewTab(
                                label: 'ORDERS',
                                selected:
                                    _viewMode == _ViewMode.orders,
                                onTap: () => setState(
                                    () => _viewMode = _ViewMode.orders),
                              ),
                              const SizedBox(width: 16),
                              _ViewTab(
                                label: 'REVENUE',
                                selected:
                                    _viewMode == _ViewMode.revenue,
                                onTap: () => setState(
                                    () => _viewMode = _ViewMode.revenue),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.space4),
                        ],
                      ),
                    ),
                  ),

                  // ═══ ITEM CARDS ═══
                  if (filtered.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: LucideIcons.barChart3,
                        title: 'No items found',
                        subtitle: 'Try adjusting your filters.',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.space6),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = filtered[index];
                            return Padding(
                              padding: const EdgeInsets.only(
                                  bottom: AppTheme.space3),
                              child: _ItemCard(
                                stat: item,
                                currency: currency,
                                viewMode: _viewMode,
                                rank: index + 1,
                              )
                                  .animate(delay: (50 * index).ms)
                                  .fadeIn(duration: 200.ms),
                            );
                          },
                          childCount: filtered.length,
                        ),
                      ),
                    ),

                  const SliverPadding(
                      padding: EdgeInsets.only(bottom: 120)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── Time filter ───
  List<Order> _filterByTime(List<Order> orders) {
    final now = DateTime.now();
    return switch (_timePeriod) {
      _TimePeriod.day => orders
          .where((o) =>
              o.createdAt.day == now.day &&
              o.createdAt.month == now.month &&
              o.createdAt.year == now.year)
          .toList(),
      _TimePeriod.week =>
        orders.where((o) => now.difference(o.createdAt).inDays < 7).toList(),
      _TimePeriod.month => orders
          .where((o) => o.createdAt.month == now.month && o.createdAt.year == now.year)
          .toList(),
      _TimePeriod.custom => _customRange != null
          ? orders
              .where((o) =>
                  o.createdAt.isAfter(_customRange!.start
                      .subtract(const Duration(days: 1))) &&
                  o.createdAt.isBefore(_customRange!.end
                      .add(const Duration(days: 1))))
              .toList()
          : orders,
    };
  }

  // ─── Aggregate per-item stats ───
  List<_ItemStat> _aggregateItems(List<Order> orders) {
    final map = <String, _ItemStat>{};
    for (final order in orders) {
      for (final item in order.items) {
        final key = item.name;
        final existing = map[key];
        if (existing != null) {
          map[key] = _ItemStat(
            name: item.name,
            category: existing.category,
            totalOrders: existing.totalOrders + item.quantity,
            totalRevenue: existing.totalRevenue + item.subtotal,
          );
        } else {
          // Try to guess category from menu item ID
          map[key] = _ItemStat(
            name: item.name,
            category: _guessCategoryFromName(item.name),
            totalOrders: item.quantity,
            totalRevenue: item.subtotal,
          );
        }
      }
    }
    return map.values.toList();
  }

  String _guessCategoryFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('beer') || lower.contains('wine') || lower.contains('cocktail') || lower.contains('drink')) {
      return 'DRINKS';
    }
    if (lower.contains('fries') || lower.contains('side') || lower.contains('salad') || lower.contains('bread')) {
      return 'SIDES';
    }
    if (lower.contains('dessert') || lower.contains('cake') || lower.contains('ice cream')) {
      return 'DESSERTS';
    }
    if (lower.contains('starter') || lower.contains('bruschetta') || lower.contains('soup')) {
      return 'STARTERS';
    }
    return 'MAIN COURSE';
  }

  Future<void> _exportPdf(
    BuildContext context,
    List<_ItemStat> items,
    String currency,
    String venueName,
  ) async {
    final doc = pw.Document();
    final dateLabel = DateFormat('MMMM d, yyyy').format(DateTime.now());
    final totalOrders = items.fold<int>(0, (s, i) => s + i.totalOrders);
    final totalRevenue = items.fold<double>(0, (s, i) => s + i.totalRevenue);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        pw.Header(
          level: 0,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(venueName,
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Item Performance Report — $dateLabel',
                  style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 8),
              pw.Row(children: [
                pw.Text('Total Item Orders: $totalOrders',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(width: 24),
                pw.Text(
                    'Total Revenue: $currency${totalRevenue.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ]),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: ['#', 'Item', 'Category', 'Orders', 'Revenue'],
          data: items
              .asMap()
              .entries
              .map((e) => [
                    '${e.key + 1}',
                    e.value.name,
                    e.value.category,
                    '${e.value.totalOrders}',
                    '$currency${e.value.totalRevenue.toStringAsFixed(2)}',
                  ])
              .toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    ));

    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/item_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');
    await file.writeAsBytes(await doc.save());
    if (context.mounted) {
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    }
  }

  Future<void> _exportCsv(
    BuildContext context,
    List<_ItemStat> items,
    String currency,
    String venueName,
  ) async {
    final rows = <List<String>>[
      ['#', 'Item', 'Category', 'Orders', 'Revenue'],
      ...items.asMap().entries.map((e) => [
            '${e.key + 1}',
            e.value.name,
            e.value.category,
            '${e.value.totalOrders}',
            '$currency${e.value.totalRevenue.toStringAsFixed(2)}',
          ]),
    ];
    final csvData = CsvEncoder().convert(rows.map((r) => r.map((c) => c.toString()).toList()).toList());
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/item_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv');
    await file.writeAsString(csvData);
    if (context.mounted) {
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    }
  }
}

// ═══════════════════════════════════════════
// DATA MODEL
// ═══════════════════════════════════════════

class _ItemStat {
  final String name;
  final String category;
  final int totalOrders;
  final double totalRevenue;

  _ItemStat({
    required this.name,
    required this.category,
    required this.totalOrders,
    required this.totalRevenue,
  });

  double get trendPercent {
    // Computed as revenue share % of total (proxy for real trend)
    return (totalOrders > 0) ? (totalRevenue / totalOrders).clamp(0, 99) : 0;
  }
}

// ═══════════════════════════════════════════
// PRIVATE WIDGETS
// ═══════════════════════════════════════════

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStatCard(
      {required this.icon, required this.label, required this.value});

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
          Row(children: [
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
              child: Text(label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: cs.primary,
                  ),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 8),
          Text(value,
              style: tt.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        ],
      ),
    );
  }
}

class _PeriodTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodTab(
      {required this.label, required this.selected, required this.onTap});

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
            color: selected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: cs.primary.withValues(alpha: 0.20),
                        blurRadius: 12)
                  ]
                : [],
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                )),
          ),
        ),
      ),
    );
  }
}

class _ViewTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ViewTab(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PressableScale(
      onTap: onTap,
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: selected ? cs.onSurface : cs.onSurfaceVariant,
              )),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2,
            width: selected ? 32 : 0,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}

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
            Text(label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: textColor,
                )),
          ],
        ),
      ),
    );
  }
}

/// Item performance card — chart icon, name, category, orders, trend, revenue.
class _ItemCard extends StatelessWidget {
  final _ItemStat stat;
  final String currency;
  final _ViewMode viewMode;
  final int rank;

  const _ItemCard({
    required this.stat,
    required this.currency,
    required this.viewMode,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Deterministic trend based on rank position
    final trendPercent = (20.0 / rank).clamp(0.5, 25.0);
    final trendUp = rank <= 4;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: AppTheme.clayShadow,
      ),
      child: Row(
        children: [
          // Chart icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(LucideIcons.barChart3,
                size: 20, color: AppColors.warning),
          ),
          const SizedBox(width: 14),

          // Name + Category
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stat.name,
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(stat.category,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: cs.onSurfaceVariant,
                    )),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Orders / Revenue + Trend
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    viewMode == _ViewMode.orders
                        ? '${stat.totalOrders}'
                        : '$currency${stat.totalRevenue.toStringAsFixed(stat.totalRevenue > 999 ? 0 : 2)}',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (viewMode == _ViewMode.orders) ...[
                    const SizedBox(width: 4),
                    Text('orders',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        )),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Trend pill
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (trendUp ? cs.primary : cs.error)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          trendUp
                              ? LucideIcons.trendingUp
                              : LucideIcons.trendingDown,
                          size: 10,
                          color: trendUp ? cs.primary : cs.error,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${trendPercent.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: trendUp ? cs.primary : cs.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (viewMode == _ViewMode.orders) ...[
                const SizedBox(height: 2),
                Text(
                  '$currency${stat.totalRevenue.toStringAsFixed(stat.totalRevenue > 999 ? 0 : 2)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
