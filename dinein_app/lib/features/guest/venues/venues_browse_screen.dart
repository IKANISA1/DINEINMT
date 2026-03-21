import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../shared/widgets/shared_widgets.dart';

/// Browse venues with search and category filters.
/// Matches React Venues.tsx — tall image cards, category chips, grayscale effect.
class VenuesBrowseScreen extends ConsumerStatefulWidget {
  const VenuesBrowseScreen({super.key});

  @override
  ConsumerState<VenuesBrowseScreen> createState() => _VenuesBrowseScreenState();
}

class _VenuesBrowseScreenState extends ConsumerState<VenuesBrowseScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  List<String> _selectedCategories = ['All'];

  // Categories are derived dynamically from venue data (see _buildCategoryChips)

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleCategory(String cat) {
    setState(() {
      if (cat == 'All') {
        _selectedCategories = ['All'];
      } else {
        final newSelection = _selectedCategories
            .where((c) => c != 'All')
            .toList();
        if (newSelection.contains(cat)) {
          newSelection.remove(cat);
          _selectedCategories = newSelection.isEmpty ? ['All'] : newSelection;
        } else {
          _selectedCategories = [...newSelection, cat];
        }
      }
    });
  }

  List<Venue> _filterVenues(List<Venue> venues) {
    return venues.where((v) {
      final matchesSearch =
          _query.isEmpty ||
          v.name.toLowerCase().contains(_query.toLowerCase()) ||
          v.category.toLowerCase().contains(_query.toLowerCase());
      final matchesCategory =
          _selectedCategories.contains('All') ||
          _selectedCategories.contains(v.category);
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final venuesAsync = ref.watch(venuesProvider);

    return Scaffold(
      body: venuesAsync.when(
        loading: () => const Center(
          child: SkeletonLoader(width: double.infinity, height: 200),
        ),
        error: (err, _) => ErrorState(
          message: 'Failed to load venues.',
          onRetry: () => ref.invalidate(venuesProvider),
        ),
        data: (venues) => _buildContent(context, cs, tt, venues),
      ),
    );
  }

  /// Derive category list from actual venue data.
  List<String> _categoriesFrom(List<Venue> venues) {
    final cats = venues.map((v) => v.category).toSet().toList()..sort();
    return ['All', ...cats];
  }

  Widget _buildContent(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
    List<Venue> venues,
  ) {
    final filtered = _filterVenues(venues);
    final categories = _categoriesFrom(venues);

    return CustomScrollView(
      slivers: [
        // ─── Header & Search ───
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.space6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: tt.displayMedium?.copyWith(
                        height: 0.9,
                        letterSpacing: -2,
                      ),
                      children: [
                        const TextSpan(text: 'EXPLORE\n'),
                        TextSpan(
                          text: 'VENUES',
                          style: TextStyle(color: cs.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.space4),
                  Text(
                    'Discover the finest establishments curated for your taste.',
                    style: tt.bodyLarge?.copyWith(
                      color: AppColors.white40,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space8),

                  // Search bar
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainer,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusLg,
                            ),
                            border: Border.all(color: AppColors.white5),
                          ),
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: Icon(
                                  LucideIcons.search,
                                  size: 20,
                                  color: AppColors.white10,
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (v) =>
                                      setState(() => _query = v.trim()),
                                  decoration: InputDecoration(
                                    hintText: 'Search...',
                                    border: InputBorder.none,
                                    filled: false,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    hintStyle: tt.bodyMedium?.copyWith(
                                      color: AppColors.white5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.space4),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainer,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLg,
                          ),
                          border: Border.all(color: AppColors.white5),
                        ),
                        child: Icon(
                          LucideIcons.slidersHorizontal,
                          size: 24,
                          color: AppColors.white40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // ─── Category Chips ───
        SliverToBoxAdapter(
          child: SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.space6),
              itemCount: categories.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppTheme.space3),
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = _selectedCategories.contains(cat);
                return PressableScale(
                  onTap: () => _toggleCategory(cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? cs.primary : cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(
                        color: isSelected ? cs.primary : AppColors.white5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: cs.primary.withValues(alpha: 0.20),
                                blurRadius: 12,
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      cat.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: isSelected ? cs.onPrimary : AppColors.white40,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.space10)),

        // ─── Venue Cards ───
        if (filtered.isEmpty)
          SliverFillRemaining(hasScrollBody: false, child: _buildEmpty(cs, tt))
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space6),
            sliver: SliverList.separated(
              itemCount: filtered.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppTheme.space8),
              itemBuilder: (context, index) {
                final venue = filtered[index];
                return _VenueCard(venue: venue)
                    .animate(delay: (50 * index).ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.1, end: 0);
              },
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.space24)),
      ],
    );
  }

  Widget _buildEmpty(ColorScheme cs, TextTheme tt) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.white5,
              borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
            ),
            child: Icon(LucideIcons.search, size: 48, color: AppColors.white10),
          ),
          const SizedBox(height: AppTheme.space6),
          Text('No Venues Found', style: tt.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Try adjusting your filters.',
            style: tt.bodyMedium?.copyWith(color: AppColors.white20),
          ),
          const SizedBox(height: AppTheme.space8),
          ElevatedButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _query = '';
                _selectedCategories = ['All'];
              });
            },
            child: const Text('RESET FILTERS'),
          ),
        ],
      ),
    );
  }
}

/// Large venue card with image, overlay, rating, and category label.
class _VenueCard extends StatelessWidget {
  final Venue venue;

  const _VenueCard({required this.venue});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PressableScale(
      onTap: () => context.pushNamed(
        AppRouteNames.venueDetail,
        pathParameters: {AppRouteParams.slug: venue.slug},
      ),
      child: Column(
        children: [
          // Image card
          AspectRatio(
            aspectRatio: 4 / 5,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radius3xl),
                border: Border.all(color: AppColors.white5),
                boxShadow: AppTheme.ambientShadow,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image
                  if (venue.imageUrl != null)
                    CachedNetworkImage(
                      imageUrl: venue.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: cs.surfaceContainerHigh),
                      errorWidget: (context, url, error) => Container(
                        color: cs.surfaceContainerHigh,
                        child: Icon(
                          LucideIcons.utensils,
                          size: 48,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.30),
                        ),
                      ),
                    )
                  else
                    Container(
                      color: cs.surfaceContainerHigh,
                      child: Icon(
                        LucideIcons.utensils,
                        size: 48,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.30),
                      ),
                    ),

                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.20),
                          Colors.black.withValues(alpha: 0.90),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),

                  // Rating badge
                  Positioned(
                    top: 24,
                    right: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.40),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusFull,
                        ),
                        border: Border.all(color: AppColors.white10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.star, size: 12, color: cs.primary),
                          const SizedBox(width: 6),
                          Text(
                            '${venue.rating}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Category + Name
                  Positioned(
                    bottom: 32,
                    left: 32,
                    right: 32,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          venue.category.toUpperCase(),
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          venue.name,
                          style: tt.headlineMedium?.copyWith(
                            color: Colors.white,
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom row
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space4,
              vertical: AppTheme.space4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.clock, size: 14, color: AppColors.white40),
                    const SizedBox(width: 6),
                    Text(
                      venue.isOpen ? 'Open' : 'Closed',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: AppColors.white40,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.white5,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Icon(
                    LucideIcons.chevronRight,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
