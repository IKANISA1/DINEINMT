import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../shared/widgets/shared_widgets.dart';

/// Menu screen with sticky category tabs and add-to-cart interactions.
/// Loads items from Supabase via [menuItemsProvider].
/// Cart state managed by [cartProvider].
/// Tap budget: Add item = 1 tap (tap the + on card OR tap card → bottom sheet → add).
class MenuScreen extends ConsumerStatefulWidget {
  final String venueId;

  const MenuScreen({super.key, required this.venueId});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  final Map<String, GlobalKey> _categoryKeys = {};
  bool _isAutoScrolling = false;

  List<String> _categories = [];

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  List<MenuItem> _itemsForCategory(String category, List<MenuItem> allItems) =>
      allItems.where((i) => i.category == category).toList();

  void _rebuildTabs(List<String> categories) {
    if (categories.length != _categories.length ||
        !categories.every((c) => _categories.contains(c))) {
      _tabController?.dispose();
      _categories = categories;
      _tabController = TabController(length: categories.length, vsync: this);
      _categoryKeys.clear();
      for (final c in categories) {
        _categoryKeys[c] = GlobalKey();
      }
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (_isAutoScrolling || _categoryKeys.isEmpty || _tabController == null) {
      return false;
    }

    int activeIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < _categories.length; i++) {
      final key = _categoryKeys[_categories[i]];
      if (key?.currentContext != null) {
        final box = key!.currentContext!.findRenderObject() as RenderBox;
        final position = box.localToGlobal(
          Offset.zero,
          ancestor: context.findRenderObject(),
        );
        // Calculate distance to a point slightly below the AppBar (approx 120px)
        final distance = (position.dy - 120).abs();
        if (distance < minDistance) {
          minDistance = distance;
          activeIndex = i;
        }
      }
    }

    if (_tabController!.index != activeIndex &&
        !_tabController!.indexIsChanging) {
      _tabController!.animateTo(activeIndex);
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final menuAsync = ref.watch(menuItemsProvider(widget.venueId));
    final cart = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

    return menuAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          title: Text('Menu', style: tt.headlineMedium),
          actions: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton(
                icon: Icon(LucideIcons.hand, color: cs.primary),
                onPressed: () => WaveBottomSheet.show(context, widget.venueId),
              ),
            ),
          ],
        ),
        body: const Center(
          child: SkeletonLoader(width: double.infinity, height: 200),
        ),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(
          title: Text('Menu', style: tt.headlineMedium),
          actions: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton(
                icon: Icon(LucideIcons.hand, color: cs.primary),
                onPressed: () => WaveBottomSheet.show(context, widget.venueId),
              ),
            ),
          ],
        ),
        body: ErrorState(
          message: 'Could not load menu items.',
          onRetry: () => ref.invalidate(menuItemsProvider(widget.venueId)),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Menu', style: tt.headlineMedium),
              actions: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: IconButton(
                    icon: Icon(LucideIcons.hand, color: cs.primary),
                    onPressed: () => WaveBottomSheet.show(context, widget.venueId),
                  ),
                ),
              ],
            ),
            body: const EmptyState(
              icon: LucideIcons.chefHat,
              title: 'Menu not published yet',
              subtitle:
                  'This venue has not added menu items yet. Check back later or ask the team in person.',
            ),
          );
        }

        // Derive categories from items (preserving order)
        final categories = items.map((i) => i.category).toSet().toList();

        _rebuildTabs(categories);

        return _buildMenu(
          context,
          cs,
          tt,
          items,
          categories,
          cart,
          cartNotifier,
        );
      },
    );
  }

  Widget _buildMenu(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
    List<MenuItem> items,
    List<String> categories,
    CartState cart,
    CartNotifier cartNotifier,
  ) {
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
                  cart.venueName ?? 'Menu',
                  style: tt.titleLarge, // text-lg font-black
                ),
                Text(
                  'DIGITAL MENU',
                  style: TextStyle(
                    fontSize: 8,
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
                  onPressed: () => WaveBottomSheet.show(context, widget.venueId),
                ),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              onTap: (index) async {
                final key = _categoryKeys[categories[index]];
                if (key?.currentContext != null) {
                  _isAutoScrolling = true;
                  await Scrollable.ensureVisible(
                    key!.currentContext!,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                  _isAutoScrolling = false;
                }
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
              tabs: categories.map((c) => Tab(text: c.toUpperCase())).toList(),
            ),
          ),
        ],
        body: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: categories.map((category) {
                final catItems = _itemsForCategory(category, items);
                // We use RepaintBoundary or just wrap it directly.
                return Column(
                  key: _categoryKeys[category],
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.space6,
                        AppTheme.space8,
                        AppTheme.space6,
                        AppTheme.space4,
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    ...catItems.map((item) {
                      final qty = cartNotifier.quantityOf(item.id);
                      return Padding(
                        padding: const EdgeInsets.only(
                          left: AppTheme.space5,
                          right: AppTheme.space5,
                          bottom: AppTheme.space4,
                        ),
                        child: _MenuItemCard(
                          item: item,
                          quantity: qty,
                          currencySymbol: cart.currencySymbol,
                          onAdd: () => cartNotifier.addItem(item),
                          onRemove: () => cartNotifier.removeItem(item.id),
                          onTap: () => context.pushNamed(
                            AppRouteNames.itemDetail,
                            pathParameters: {AppRouteParams.id: item.id},
                            extra: item,
                          ),
                        ),
                      );
                    }),
                  ],
                );
              }).toList(),
            ),
          ),
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
                      onPressed: () => context.pushNamed(AppRouteNames.cart),
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
                .animate()
                .fadeIn(duration: 300.ms)
                .slideY(begin: 1, end: 0, duration: 300.ms)
          : null,
    );
  }
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
                            fontSize: 8,
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
                  // Tags
                  if (item.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Wrap(
                        spacing: 6,
                        children: item.tags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: tag == 'Signature'
                                  ? cs.primary.withValues(alpha: 0.12)
                                  : cs.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusFull,
                              ),
                            ),
                            child: Text(
                              tag.toUpperCase(),
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                color: tag == 'Signature'
                                    ? cs.primary
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
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
                    maxLines: 2,
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
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _QuantityStepper({
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (quantity == 0) {
      return GestureDetector(
        onTap: onAdd,
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
          GestureDetector(
            onTap: onRemove,
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
          GestureDetector(
            onTap: onAdd,
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
