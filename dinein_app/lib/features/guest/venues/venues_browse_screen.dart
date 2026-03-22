import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';

const _venueCategories = [
  'All',
  'Bars',
  'Restaurants',
  'Immersive Sound',
  'Seafood',
  'Italian',
];

const _grayscaleMatrix = <double>[
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

class VenuesBrowseScreen extends ConsumerStatefulWidget {
  const VenuesBrowseScreen({super.key});

  @override
  ConsumerState<VenuesBrowseScreen> createState() => _VenuesBrowseScreenState();
}

class _VenuesBrowseScreenState extends ConsumerState<VenuesBrowseScreen> {
  static const _searchDebounce = Duration(milliseconds: 180);

  final _searchController = TextEditingController();
  Timer? _queryDebounce;
  List<String> _selectedCategories = const ['All'];
  String _query = '';

  @override
  void dispose() {
    _queryDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    final normalized = value.trim();
    _queryDebounce?.cancel();

    if (normalized.isEmpty) {
      if (_query.isNotEmpty) {
        setState(() => _query = '');
      }
      return;
    }

    _queryDebounce = Timer(_searchDebounce, () {
      if (!mounted || _query == normalized) return;
      setState(() => _query = normalized);
    });
  }

  void _toggleCategory(String category) {
    setState(() {
      if (category == 'All') {
        _selectedCategories = const ['All'];
        return;
      }

      final next = _selectedCategories.where((item) => item != 'All').toList();
      if (next.contains(category)) {
        next.remove(category);
      } else {
        next.add(category);
      }
      _selectedCategories = next.isEmpty ? const ['All'] : next;
    });
  }

  bool _matchesCategory(Venue venue, String category) {
    if (category == 'All') return true;

    final haystack = '${venue.category} ${venue.description} ${venue.name}'
        .toLowerCase();

    switch (category) {
      case 'Bars':
        return haystack.contains('bar') ||
            haystack.contains('lounge') ||
            haystack.contains('cocktail') ||
            haystack.contains('pub') ||
            haystack.contains('rooftop');
      case 'Restaurants':
        return haystack.contains('restaurant') ||
            haystack.contains('grill') ||
            haystack.contains('bistro') ||
            haystack.contains('dining') ||
            haystack.contains('gastro');
      case 'Immersive Sound':
        return haystack.contains('immersive') ||
            haystack.contains('sound') ||
            haystack.contains('music');
      case 'Seafood':
        return haystack.contains('seafood') || haystack.contains('fish');
      case 'Italian':
        return haystack.contains('italian') ||
            haystack.contains('pizza') ||
            haystack.contains('pasta') ||
            haystack.contains('trattoria');
    }

    return false;
  }

  List<Venue> _filterVenues(List<Venue> venues) {
    final selected = _selectedCategories;
    return venues
        .where((venue) {
          final matchesSearch =
              _query.isEmpty ||
              venue.name.toLowerCase().contains(_query.toLowerCase()) ||
              venue.category.toLowerCase().contains(_query.toLowerCase()) ||
              venue.description.toLowerCase().contains(_query.toLowerCase());

          final matchesCategory =
              selected.contains('All') ||
              selected.any((category) => _matchesCategory(venue, category));

          return matchesSearch && matchesCategory;
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final venuesAsync = ref.watch(venuesProvider);

    return venuesAsync.when(
      loading: () => const Center(
        child: SkeletonLoader(width: double.infinity, height: 320),
      ),
      error: (error, stackTrace) => ErrorState(
        message: 'Failed to load venues.',
        onRetry: () => ref.invalidate(venuesProvider),
      ),
      data: (venues) => _VenuesBody(
        venues: _filterVenues(venues),
        query: _query,
        searchController: _searchController,
        selectedCategories: _selectedCategories,
        onSearchChanged: _onSearchChanged,
        onCategorySelected: _toggleCategory,
        onResetFilters: () {
          _queryDebounce?.cancel();
          _searchController.clear();
          setState(() {
            _query = '';
            _selectedCategories = const ['All'];
          });
        },
      ),
    );
  }
}

class _VenuesBody extends StatelessWidget {
  final List<Venue> venues;
  final String query;
  final TextEditingController searchController;
  final List<String> selectedCategories;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onResetFilters;

  const _VenuesBody({
    required this.venues,
    required this.query,
    required this.searchController,
    required this.selectedCategories,
    required this.onSearchChanged,
    required this.onCategorySelected,
    required this.onResetFilters,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final shouldAnimateVenues =
        query.isEmpty &&
        selectedCategories.length == 1 &&
        selectedCategories.first == 'All';

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space6,
              AppTheme.space6,
              AppTheme.space6,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: tt.displayMedium?.copyWith(
                      height: 0.86,
                      letterSpacing: -2.2,
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
                SizedBox(
                  width: 280,
                  child: Text(
                    'Discover the finest establishments curated for your taste.',
                    style: tt.bodyLarge?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.space8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainer,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusXl,
                          ),
                          border: Border.all(color: AppColors.white5),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.search,
                              size: 20,
                              color: AppColors.white10,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: searchController,
                                onChanged: onSearchChanged,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  filled: false,
                                  hintText: 'Search...',
                                  hintStyle: tt.bodyLarge?.copyWith(
                                    color: AppColors.white10,
                                    fontWeight: FontWeight.w800,
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
                        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
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
        SliverToBoxAdapter(
          child: SizedBox(
            height: 64,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space6,
                AppTheme.space8,
                AppTheme.space6,
                0,
              ),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final category = _venueCategories[index];
                final isSelected = selectedCategories.contains(category);
                return PressableScale(
                  onTap: () => onCategorySelected(category),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? cs.primary : cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                      border: Border.all(
                        color: isSelected ? cs.primary : AppColors.white5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: cs.primary.withValues(alpha: 0.22),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      category.toUpperCase(),
                      style: TextStyle(
                        color: isSelected ? cs.onPrimary : AppColors.white40,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.2,
                      ),
                    ),
                  ),
                );
              },
              separatorBuilder: (_, _) =>
                  const SizedBox(width: AppTheme.space3),
              itemCount: _venueCategories.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.space8)),
        if (venues.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyVenuesState(onResetFilters: onResetFilters),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space6),
            sliver: SliverList.separated(
              itemCount: venues.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppTheme.space8),
              itemBuilder: (context, index) {
                final venue = venues[index];
                final card = _VenueCard(venue: venue);
                if (!shouldAnimateVenues) return card;

                return card
                    .animate(delay: (50 * index).ms)
                    .fadeIn(duration: 350.ms)
                    .slideY(begin: 0.08, end: 0);
              },
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.space24)),
      ],
    );
  }
}

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
          AspectRatio(
            aspectRatio: 4 / 5,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                border: Border.all(color: AppColors.white5),
                boxShadow: AppTheme.ambientShadow,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColorFiltered(
                    colorFilter: const ColorFilter.matrix(_grayscaleMatrix),
                    child: DineInImage(
                      imageUrl: venue.imageUrl,
                      fit: BoxFit.cover,
                      fallbackIcon: LucideIcons.store,
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.08),
                            Colors.black.withValues(alpha: 0.24),
                            Colors.black.withValues(alpha: 0.92),
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 24,
                    right: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.42),
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
                            venue.rating.toStringAsFixed(
                              venue.rating.truncateToDouble() == venue.rating
                                  ? 0
                                  : 1,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 32,
                    right: 32,
                    bottom: 32,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          venue.category.toUpperCase(),
                          style: TextStyle(
                            color: cs.primary,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          venue.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tt.headlineMedium?.copyWith(
                            color: Colors.white,
                            letterSpacing: -1.2,
                            height: 0.96,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space4,
              vertical: AppTheme.space4,
            ),
            child: Row(
              children: [
                Icon(LucideIcons.clock3, size: 14, color: AppColors.white40),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    venue.isOpen ? 'OPEN' : 'CLOSED',
                    style: TextStyle(
                      color: AppColors.white40,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.2,
                    ),
                  ),
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

class _EmptyVenuesState extends StatelessWidget {
  final VoidCallback onResetFilters;

  const _EmptyVenuesState({required this.onResetFilters});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.white5,
                borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
              ),
              child: Icon(
                LucideIcons.search,
                size: 44,
                color: cs.onSurfaceVariant.withValues(alpha: 0.22),
              ),
            ),
            const SizedBox(height: AppTheme.space6),
            Text('No Venues Found', style: tt.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            PressableScale(
              onTap: onResetFilters,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space8,
                  vertical: AppTheme.space5,
                ),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  'RESET FILTERS',
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
