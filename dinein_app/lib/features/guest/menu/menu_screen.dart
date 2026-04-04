import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/core/providers/cart_provider.dart';
import 'package:dinein_app/core/services/app_telemetry.dart';
import 'package:ui/theme/motion_preferences.dart';
import 'package:ui/widgets/shared_widgets.dart';
import 'package:dinein_app/features/guest/widgets/wave_bottom_sheet.dart';
import 'menu_item_badges.dart';

/// Menu screen with sticky category tabs and add-to-cart interactions.
/// Loads items from Supabase via [menuItemsProvider].
/// Cart state managed by [cartProvider].
/// Tap budget: Add item = 1 tap (tap the + on card OR tap card → bottom sheet → add).
class MenuScreen extends ConsumerStatefulWidget {
  final String? venueId;
  final String? venueSlug;

  const MenuScreen({super.key, this.venueId, this.venueSlug})
    : assert(venueId != null || venueSlug != null);

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  bool _isAutoScrolling = false;

  List<String> _categories = [];
  List<_MenuListEntry> _entries = const [];
  Map<String, int> _categoryHeaderIndexes = const {};
  String _query = '';
  String? _trackedMenuVenueId;
  GuestMenuBundle? _lastBundle;

  @override
  void initState() {
    super.initState();
    _itemPositionsListener.itemPositions.addListener(_syncActiveTabWithScroll);
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(
      _syncActiveTabWithScroll,
    );
    _searchController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  void _rebuildTabs(List<String> categories) {
    if (categories.isEmpty) {
      _tabController?.dispose();
      _tabController = null;
      _categories = const [];
      return;
    }

    if (categories.length != _categories.length ||
        !categories.every((c) => _categories.contains(c))) {
      _tabController?.dispose();
      _categories = categories;
      _tabController = TabController(length: categories.length, vsync: this);
    }
  }

  void _rebuildEntries(List<String> categories, List<MenuItem> items) {
    final nextEntries = <_MenuListEntry>[];
    final nextHeaderIndexes = <String, int>{};

    for (final category in categories) {
      final categoryItems = items
          .where((item) => item.category == category && item.isAvailable)
          .toList(growable: false);
      if (categoryItems.isEmpty) continue;

      nextHeaderIndexes[category] = nextEntries.length;
      nextEntries.add(_MenuListEntry.header(category: category));
      for (final item in categoryItems) {
        nextEntries.add(_MenuListEntry.item(category: category, item: item));
      }
    }

    nextEntries.add(const _MenuListEntry.spacer());
    _entries = nextEntries;
    _categoryHeaderIndexes = nextHeaderIndexes;
  }

  List<MenuItem> _filterItems(List<MenuItem> items) {
    final availableItems = items.where((item) => item.isAvailable);
    if (_query.isEmpty) {
      return availableItems.toList(growable: false);
    }

    final needle = _query.toLowerCase();
    return availableItems
        .where((item) {
          final haystack =
              '${item.name} ${item.description} ${item.category} ${item.tags.join(' ')}'
                  .toLowerCase();
          return haystack.contains(needle);
        })
        .toList(growable: false);
  }

  void _syncMenuToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_itemScrollController.isAttached || _entries.isEmpty) {
        return;
      }

      _isAutoScrolling = true;
      _itemScrollController.jumpTo(index: 0, alignment: 0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _isAutoScrolling = false;
      });
    });
  }

  void _onSearchChanged(String value) {
    final normalized = value.trim();
    if (_query == normalized) return;
    setState(() => _query = normalized);
    if (normalized.isNotEmpty) {
      _trackGuestEvent(
        'menu_search',
        details: {'query': normalized, 'query_length': normalized.length},
      );
    }
    _syncMenuToTop();
  }

  void _clearSearch() {
    if (_query.isEmpty && _searchController.text.isEmpty) return;
    _searchController.clear();
    setState(() => _query = '');
    _syncMenuToTop();
  }

  void _trackGuestEvent(
    String eventName, {
    String? venueId,
    String? menuItemId,
    Map<String, Object?> details = const {},
  }) {
    unawaited(
      AppTelemetryService.trackGuestEvent(
        eventName,
        route: '/menu',
        venueId: venueId,
        menuItemId: menuItemId,
        details: details,
      ),
    );
  }

  void _trackMenuViewed(Venue venue, int itemCount) {
    if (_trackedMenuVenueId == venue.id) return;
    _trackedMenuVenueId = venue.id;
    _trackGuestEvent(
      'menu_viewed',
      venueId: venue.id,
      details: {
        'slug': venue.slug,
        'item_count': itemCount,
        'can_order': venue.canAcceptGuestOrders,
      },
    );
  }

  void _syncActiveTabWithScroll() {
    if (_isAutoScrolling || _entries.isEmpty || _tabController == null) {
      return;
    }

    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    final visible = positions.where(
      (position) => position.itemTrailingEdge > 0,
    );
    if (visible.isEmpty) return;

    final topmost = visible.reduce((current, next) {
      return next.itemLeadingEdge < current.itemLeadingEdge ? next : current;
    });

    final activeCategory = _entries[topmost.index].category;
    final activeIndex = _categories.indexOf(activeCategory);
    if (activeIndex == -1) return;

    if (_tabController!.index != activeIndex &&
        !_tabController!.indexIsChanging) {
      _tabController!.animateTo(activeIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bundleRequest = GuestMenuRequest(
      venueId: widget.venueId,
      venueSlug: widget.venueSlug,
    );
    final bundleAsync = ref.watch(guestMenuBundleProvider(bundleRequest));
    final currentBundle = bundleAsync.asData?.value;
    _lastBundle = currentBundle ?? _lastBundle;
    final bundle = currentBundle ?? _lastBundle;
    final cart = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    if (bundle == null) {
      return _buildScaffoldFrame(
        context,
        title: 'Menu',
        venueId: widget.venueId,
        body: bundleAsync.hasError
            ? ErrorState(
                message: 'Could not load the menu.',
                onRetry: () =>
                    ref.invalidate(guestMenuBundleProvider(bundleRequest)),
              )
            : const Center(
                child: SkeletonLoader(width: double.infinity, height: 200),
              ),
      );
    }

    final venue = bundle.venue;
    if (venue == null) {
      return _buildScaffoldFrame(
        context,
        title: 'Menu',
        venueId: widget.venueId,
        body: const EmptyState(
          icon: LucideIcons.store,
          title: 'Venue not found',
          subtitle: 'This venue is unavailable right now.',
        ),
      );
    }

    if (cart.venueId != venue.id ||
        cart.venueName != venue.name ||
        cart.venueCountry != venue.country ||
        cart.venueRevolutUrl != venue.revolutUrl) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(cartProvider.notifier)
            .setVenue(
              venueId: venue.id,
              venueSlug: venue.slug,
              venueName: venue.name,
              venueRevolutUrl: venue.revolutUrl,
              venueCountry: venue.country,
              tableNumber: cart.tableNumber,
            );
      });
    }

    final items = bundle.items;
    if (items.isEmpty && !bundleAsync.isLoading) {
      return _buildScaffoldFrame(
        context,
        title: venue.name,
        venueId: venue.id,
        body: const EmptyState(
          icon: LucideIcons.chefHat,
          title: 'Menu not published yet',
          subtitle:
              'This venue has not added menu items yet. Check back later or ask the team in person.',
        ),
      );
    }

    _trackMenuViewed(venue, items.length);
    final filteredItems = _filterItems(items);
    final categories = filteredItems
        .map((item) => item.category)
        .toSet()
        .toList();

    _rebuildTabs(categories);
    _rebuildEntries(categories, filteredItems);

    return _buildMenu(
      context,
      cs,
      tt,
      venue,
      categories,
      cart,
      cartNotifier,
      isRefreshing: bundleAsync.isLoading,
    );
  }

  Scaffold _buildScaffoldFrame(
    BuildContext context, {
    required String title,
    required Widget body,
    required String? venueId,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: tt.headlineMedium),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: IconButton(
              icon: Icon(LucideIcons.hand, color: cs.primary),
              onPressed: venueId == null
                  ? null
                  : () => WaveBottomSheet.show(context, venueId),
            ),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildMenu(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
    Venue? venue,
    List<String> categories,
    CartState cart,
    CartNotifier cartNotifier, {
    required bool isRefreshing,
  }) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            floating: true,
            snap: true,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venue?.name ?? cart.venueName ?? 'Menu',
                  style: tt.titleLarge, // text-lg font-black
                ),
                Text(
                  'DIGITAL MENU',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.2,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  icon: Icon(LucideIcons.hand, color: cs.primary),
                  onPressed: venue?.id == null
                      ? null
                      : () => WaveBottomSheet.show(context, venue!.id),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(categories.isEmpty ? 76 : 132),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.space4,
                      0,
                      AppTheme.space4,
                      AppTheme.space3,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.search,
                            size: 18,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.68),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              textInputAction: TextInputAction.search,
                              style: tt.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                filled: false,
                                hintText: 'Search menu items...',
                                hintStyle: tt.bodyLarge?.copyWith(
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.40,
                                  ),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          if (_query.isNotEmpty)
                            PressableScale(
                              onTap: _clearSearch,
                              semanticLabel: 'Clear search',
                              minTouchTargetSize: const Size(44, 44),
                              child: Icon(
                                LucideIcons.x,
                                size: 18,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (categories.isNotEmpty && _tabController != null)
                    TabBar(
                      controller: _tabController,
                      onTap: (index) {
                        final targetIndex =
                            _categoryHeaderIndexes[categories[index]];
                        if (targetIndex == null ||
                            !_itemScrollController.isAttached) {
                          return;
                        }

                        _isAutoScrolling = true;
                        _itemScrollController.jumpTo(
                          index: targetIndex,
                          alignment: 0,
                        );
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          _isAutoScrolling = false;
                        });
                      },
                      isScrollable: true,
                      labelColor: cs.primary,
                      unselectedLabelColor: cs.onSurfaceVariant,
                      labelStyle: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                      unselectedLabelStyle: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      indicatorSize: TabBarIndicatorSize.label,
                      indicatorColor: cs.primary,
                      indicatorWeight: 3,
                      dividerColor: Colors.transparent,
                      tabAlignment: TabAlignment.start,
                      tabs: categories
                          .map((c) => Tab(text: c.toUpperCase()))
                          .toList(),
                    ),
                ],
              ),
            ),
          ),
          if (isRefreshing)
            const SliverToBoxAdapter(
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
        body: categories.isEmpty
            ? CustomScrollView(
                slivers: [
                  ...(isRefreshing
                      ? const [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(AppTheme.space6),
                              child: SkeletonLoader(
                                width: double.infinity,
                                height: 140,
                                borderRadius: 24,
                              ),
                            ),
                          ),
                        ]
                      : const []),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.space6),
                      child: EmptyState(
                        icon: LucideIcons.search,
                        title: 'No Menu Items Found',
                        subtitle: _query.isEmpty
                            ? 'This venue has no searchable items right now.'
                            : 'Try a different item name, category, or keyword.',
                      ),
                    ),
                  ),
                ],
              )
            : ScrollablePositionedList.builder(
                itemCount: _entries.length,
                itemScrollController: _itemScrollController,
                itemPositionsListener: _itemPositionsListener,
                padding: const EdgeInsets.only(bottom: 120),
                itemBuilder: (context, index) {
                  final entry = _entries[index];

                  return switch (entry.type) {
                    _MenuListEntryType.header => Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.space6,
                        AppTheme.space8,
                        AppTheme.space6,
                        AppTheme.space4,
                      ),
                      child: Text(
                        entry.category.toUpperCase(),
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    _MenuListEntryType.item => Padding(
                      padding: const EdgeInsets.only(
                        left: AppTheme.space5,
                        right: AppTheme.space5,
                        bottom: AppTheme.space4,
                      ),
                      child: _MenuItemCard(
                        item: entry.item!,
                        quantity: cartNotifier.quantityOf(entry.item!.id),
                        currencySymbol: cart.currencySymbol,
                        onAdd: () {
                          _trackGuestEvent(
                            'menu_item_added',
                            venueId: venue?.id ?? entry.item!.venueId,
                            menuItemId: entry.item!.id,
                            details: {'source': 'menu_card', 'quantity': 1},
                          );
                          cartNotifier.addItem(entry.item!);
                        },
                        onRemove: () => cartNotifier.removeItem(entry.item!.id),
                        onTap: () {
                          _trackGuestEvent(
                            'menu_item_opened',
                            venueId: venue?.id ?? entry.item!.venueId,
                            menuItemId: entry.item!.id,
                            details: {'source': 'menu_list'},
                          );
                          context.pushNamed(
                            AppRouteNames.itemDetail,
                            pathParameters: {AppRouteParams.id: entry.item!.id},
                            extra: entry.item,
                          );
                        },
                      ),
                    ),
                    _MenuListEntryType.spacer => const SizedBox.shrink(),
                  };
                },
              ),
      ),

      // ─── Sticky Cart Pill ───
      bottomNavigationBar: cart.itemCount > 0
          ? Container(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.space6,
                    AppTheme.space3,
                    AppTheme.space6,
                    AppTheme.space8,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    border: Border(
                      top: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  child: SafeArea(
                    child: ElevatedButton(
                      onPressed: () {
                        _trackGuestEvent(
                          'cart_opened',
                          venueId: venue?.id ?? cart.venueId,
                          details: {
                            'item_count': cart.itemCount,
                            'cart_total': cart.total,
                          },
                        );
                        context.pushNamed(AppRouteNames.cart);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusFull,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.20),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusFull,
                                  ),
                                ),
                                child: Text(
                                  '${cart.itemCount}',
                                  style: TextStyle(
                                    color: cs.onPrimary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'VIEW CART  •  ${cart.currencySymbol}${cart.total.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: cs.onPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            LucideIcons.chevronRight,
                            size: 18,
                            color: cs.onPrimary,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .animate(target: reduceMotionOf(context) ? 0 : 1)
                .fadeIn(duration: 300.ms)
                .slideY(begin: 1, end: 0, duration: 300.ms)
          : null,
    );
  }
}

enum _MenuListEntryType { header, item, spacer }

class _MenuListEntry {
  final _MenuListEntryType type;
  final String category;
  final MenuItem? item;

  const _MenuListEntry._({
    required this.type,
    required this.category,
    this.item,
  });

  const _MenuListEntry.header({required String category})
    : this._(type: _MenuListEntryType.header, category: category);

  const _MenuListEntry.item({required String category, required MenuItem item})
    : this._(type: _MenuListEntryType.item, category: category, item: item);

  const _MenuListEntry.spacer()
    : this._(type: _MenuListEntryType.spacer, category: '');
}

/// Menu item card with inline +/- stepper.
class _MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final int quantity;
  final String currencySymbol;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback? onTap;

  const _MenuItemCard({
    required this.item,
    required this.quantity,
    required this.currencySymbol,
    required this.onAdd,
    required this.onRemove,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PressableScale(
      onTap: onTap,
      semanticLabel: 'View ${item.name}',
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space5),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item image with sold-out overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: DineInImage(
                      imageUrl: item.imageUrl,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      fallbackIcon: LucideIcons.chefHat,
                      semanticLabel: '${item.name} photo',
                    ),
                  ),
                ),
                if (!item.isAvailable)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.70),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          'SOLD OUT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3.2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppTheme.space4),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.guestDisplayTags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: MenuItemBadges(item: item),
                    ),

                  Text(
                    item.name,
                    style: tt.titleLarge?.copyWith(
                      letterSpacing: -0.5,
                    ), // text-lg font-black
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Price + Stepper
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$currencySymbol${item.price.toStringAsFixed(2)}',
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.primary,
                        ),
                      ),
                      _QuantityStepper(
                        quantity: quantity,
                        enabled: item.isAvailable,
                        onAdd: onAdd,
                        onRemove: onRemove,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline +/- quantity stepper.
class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final bool enabled;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _QuantityStepper({
    required this.quantity,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!enabled) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Icon(
          LucideIcons.plus,
          size: 18,
          color: cs.onSurfaceVariant.withValues(alpha: 0.45),
        ),
      );
    }

    if (quantity == 0) {
      return PressableScale(
        onTap: onAdd,
        semanticLabel: 'Add to cart',
        minTouchTargetSize: const Size(44, 44),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Icon(LucideIcons.plus, size: 18, color: cs.onPrimary),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PressableScale(
            onTap: onRemove,
            semanticLabel: 'Remove one',
            minTouchTargetSize: const Size(44, 44),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(LucideIcons.minus, size: 16, color: cs.onSurface),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '$quantity',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: cs.onSurface,
              ),
            ),
          ),
          PressableScale(
            onTap: onAdd,
            semanticLabel: 'Add one more',
            minTouchTargetSize: const Size(44, 44),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(LucideIcons.plus, size: 16, color: cs.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
