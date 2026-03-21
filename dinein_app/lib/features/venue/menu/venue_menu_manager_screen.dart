import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/enums.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/services/menu_repository.dart';
import '../../../shared/widgets/shared_widgets.dart';

/// Venue menu manager — CRUD menu items with search + tag filter.
///
/// Data: [menuItemsProvider] (edge function → Supabase).
/// Mutations: [MenuRepository] (toggle availability, delete, etc.).
class VenueMenuManagerScreen extends ConsumerStatefulWidget {
  const VenueMenuManagerScreen({super.key});

  @override
  ConsumerState<VenueMenuManagerScreen> createState() =>
      _VenueMenuManagerScreenState();
}

class _VenueMenuManagerScreenState
    extends ConsumerState<VenueMenuManagerScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _selectedTag;
  bool _showTagFilter = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final venueAsync = ref.watch(currentVenueProvider);

    return venueAsync.when(
      loading: () => const Center(
        child: SkeletonLoader(width: double.infinity, height: 200),
      ),
      error: (_, _) => ErrorState(
        message: 'Could not load venue.',
        onRetry: () => ref.invalidate(currentVenueProvider),
      ),
      data: (venue) {
        if (venue == null) {
          return const EmptyState(
            icon: LucideIcons.store,
            title: 'No venue access',
            subtitle: 'Claim and verify a venue to manage its menu.',
          );
        }
        return _MenuBody(
          venueId: venue.id,
          currencySymbol: venue.country.currencySymbol,
          searchQuery: _searchQuery,
          searchCtrl: _searchCtrl,
          selectedTag: _selectedTag,
          showTagFilter: _showTagFilter,
          onSearch: (q) => setState(() => _searchQuery = q),
          onSelectTag: (t) =>
              setState(() => _selectedTag = _selectedTag == t ? null : t),
          onToggleTagFilter: () =>
              setState(() => _showTagFilter = !_showTagFilter),
          onAddItem: () => context
              .pushNamed(AppRouteNames.venueNewItem)
              .then((_) => ref.invalidate(menuItemsProvider(venue.id))),
        );
      },
    );
  }
}

class _MenuBody extends ConsumerWidget {
  final String venueId;
  final String currencySymbol;
  final String searchQuery;
  final TextEditingController searchCtrl;
  final String? selectedTag;
  final bool showTagFilter;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onSelectTag;
  final VoidCallback onToggleTagFilter;
  final VoidCallback onAddItem;

  const _MenuBody({
    required this.venueId,
    required this.currencySymbol,
    required this.searchQuery,
    required this.searchCtrl,
    required this.selectedTag,
    required this.showTagFilter,
    required this.onSearch,
    required this.onSelectTag,
    required this.onToggleTagFilter,
    required this.onAddItem,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final menuAsync = ref.watch(menuItemsProvider(venueId));

    return menuAsync.when(
      loading: () => const Center(
        child: SkeletonLoader(width: double.infinity, height: 300),
      ),
      error: (_, _) => ErrorState(
        message: 'Could not load menu items.',
        onRetry: () => ref.invalidate(menuItemsProvider(venueId)),
      ),
      data: (items) {
        // Collect all unique tags/categories
        final allTags = <String>{};
        for (final item in items) {
          allTags.add(item.category);
          allTags.addAll(item.tags);
        }
        final tagList = allTags.toList()..sort();

        // Apply filters
        var filtered = List<MenuItem>.from(items);
        if (selectedTag != null) {
          filtered = filtered
              .where((i) =>
                  i.category.toLowerCase() ==
                      selectedTag!.toLowerCase() ||
                  i.tags.any((t) =>
                      t.toLowerCase() == selectedTag!.toLowerCase()))
              .toList();
        }
        if (searchQuery.isNotEmpty) {
          final q = searchQuery.toLowerCase();
          filtered = filtered
              .where((i) =>
                  i.name.toLowerCase().contains(q) ||
                  i.category.toLowerCase().contains(q) ||
                  i.tags.any((t) => t.toLowerCase().contains(q)))
              .toList();
        }

        return CustomScrollView(
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
                          'Menu',
                          style: tt.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        PressableScale(
                          onTap: onAddItem,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      cs.primary.withValues(alpha: 0.25),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              LucideIcons.plus,
                              size: 22,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.space5),

                    // ═══ SEARCH BAR ═══
                    Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: TextField(
                        controller: searchCtrl,
                        onChanged: onSearch,
                        style: tt.bodyMedium,
                        decoration: InputDecoration(
                          hintText: 'Search items...',
                          hintStyle: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant
                                .withValues(alpha: 0.40),
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
                          prefixIconConstraints:
                              const BoxConstraints(minWidth: 0),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.space4),

                    // ═══ FILTER BY TAGS ═══
                    PressableScale(
                      onTap: onToggleTagFilter,
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.tag,
                            size: 14,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'FILTER BY TAGS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          AnimatedRotation(
                            turns: showTagFilter ? 0.5 : 0,
                            duration:
                                const Duration(milliseconds: 200),
                            child: Icon(
                              LucideIcons.chevronDown,
                              size: 16,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ═══ TAG CHIPS ═══
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      child: showTagFilter
                          ? Padding(
                              padding: const EdgeInsets.only(
                                top: AppTheme.space3,
                              ),
                              child: SizedBox(
                                height: 40,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: tagList.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (_, i) {
                                    final tag = tagList[i];
                                    final active = tag.toLowerCase() ==
                                        selectedTag?.toLowerCase();
                                    return PressableScale(
                                      onTap: () =>
                                          onSelectTag(tag),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        padding:
                                            const EdgeInsets
                                                .symmetric(
                                          horizontal: 20,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: active
                                              ? cs.primary
                                              : cs.surfaceContainerLow,
                                          borderRadius:
                                              BorderRadius.circular(
                                                20,
                                              ),
                                          border: Border.all(
                                            color: active
                                                ? cs.primary
                                                : Colors.white
                                                    .withValues(
                                                      alpha: 0.05,
                                                    ),
                                          ),
                                        ),
                                        child: Text(
                                          tag.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight:
                                                FontWeight.w800,
                                            letterSpacing: 1.5,
                                            color: active
                                                ? cs.onPrimary
                                                : cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: AppTheme.space5),
                  ],
                ),
              ),
            ),

            // ═══ EMPTY STATE ═══
            if (filtered.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: LucideIcons.utensils,
                  title: 'No menu items',
                  subtitle:
                      'Add your first item or adjust your filters.',
                ),
              )
            else
              // ═══ MENU ITEM CARDS ═══
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space6,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = filtered[index];
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppTheme.space3,
                        ),
                        child: _MenuItemCard(
                          item: item,
                          currencySymbol: currencySymbol,
                          onEdit: () {
                            context
                                .pushNamed(
                                  AppRouteNames.venueEditItem,
                                  pathParameters: {
                                    AppRouteParams.id: item.id,
                                  },
                                )
                                .then((_) => ref.invalidate(
                                    menuItemsProvider(venueId)));
                          },
                          onToggleVisibility: () async {
                            await MenuRepository.instance
                                .toggleAvailability(
                              item.id,
                              !item.isAvailable,
                            );
                            ref.invalidate(
                              menuItemsProvider(venueId),
                            );
                          },
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
              padding: EdgeInsets.only(bottom: 100),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════
// PRIVATE WIDGETS
// ═══════════════════════════════════════════

/// Menu item card matching screenshot — thumbnail, name, price, tags, stock, edit/visibility.
class _MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final String currencySymbol;
  final VoidCallback onEdit;
  final VoidCallback onToggleVisibility;

  const _MenuItemCard({
    required this.item,
    required this.currencySymbol,
    required this.onEdit,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: AppTheme.clayShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Thumbnail ───
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: DineInImage(
                      imageUrl: item.imageUrl,
                      width: 72,
                      height: 72,
                      fallbackIcon: LucideIcons.chefHat,
                    ),
                  ),
                ),
                if (item.effectiveImageStatus ==
                    MenuItemImageStatus.generating)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: _PulsingDot(color: cs.tertiary),
                  ),
                if (item.effectiveImageStatus ==
                    MenuItemImageStatus.failed)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: cs.error,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cs.surfaceContainerLow,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        LucideIcons.alertCircle,
                        size: 10,
                        color: cs.onError,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // ─── Info ───
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                Text(
                  item.name,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: item.isAvailable
                        ? cs.onSurface
                        : cs.onSurfaceVariant.withValues(alpha: 0.50),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),

                // Price
                Text(
                  '$currencySymbol${item.price.toStringAsFixed(2)}',
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: item.isAvailable
                        ? AppColors.secondary
                        : cs.onSurfaceVariant.withValues(alpha: 0.30),
                  ),
                ),
                const SizedBox(height: 8),

                // Tags
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (item.category.isNotEmpty)
                      _TagChip(label: item.category),
                    ...item.tags.take(2).map(
                          (t) => _TagChip(label: t),
                        ),
                  ],
                ),
                const SizedBox(height: 8),

                // Stock status
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: item.isAvailable
                            ? cs.primary
                            : cs.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.isAvailable
                          ? 'IN STOCK'
                          : 'OUT OF STOCK',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: item.isAvailable
                            ? cs.primary
                            : cs.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ─── Actions ───
          Column(
            children: [
              // Edit button
              PressableScale(
                onTap: onEdit,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    LucideIcons.pencil,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Visibility toggle
              PressableScale(
                onTap: onToggleVisibility,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: item.isAvailable
                        ? cs.surfaceContainerHigh
                        : cs.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item.isAvailable
                        ? LucideIcons.eye
                        : LucideIcons.eyeOff,
                    size: 16,
                    color: item.isAvailable
                        ? cs.onSurfaceVariant
                        : cs.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small tag chip for category/tags.
class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Pulsing dot overlay for items with 'generating' image status.
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final scale = 0.6 + 0.4 * _ctrl.value;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.4),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
