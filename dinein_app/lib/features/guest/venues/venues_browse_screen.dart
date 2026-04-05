import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:db_pkg/models/guest_venue_feed.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/core/services/app_telemetry.dart';
import 'package:dinein_app/core/services/discovery_location_service.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/theme/motion_preferences.dart';
import 'package:ui/widgets/shared_widgets.dart';

const _baseVenueFilters = ['All', 'Open Now', 'Ordering'];

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
  static const _pageSize = 18;

  final _searchController = TextEditingController();
  Timer? _queryDebounce;
  List<String> _selectedCategories = const ['All'];
  String _query = '';
  int _resultLimit = _pageSize;
  bool _requestingLocation = false;
  bool _trackedBrowseView = false;
  GuestVenueFeed? _lastFeed;

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
        setState(() {
          _query = '';
          _resultLimit = _pageSize;
        });
      }
      return;
    }

    _queryDebounce = Timer(_searchDebounce, () {
      if (!mounted || _query == normalized) return;
      setState(() {
        _query = normalized;
        _resultLimit = _pageSize;
      });
      _trackGuestEvent(
        'venues_search',
        details: {
          'query': normalized,
          'query_length': normalized.length,
          'filters': _selectedCategories,
          'has_location':
              ref.read(discoveryLocationProvider).asData?.value != null,
        },
      );
    });
  }

  void _trackGuestEvent(
    String eventName, {
    String? venueId,
    Map<String, Object?> details = const {},
  }) {
    unawaited(
      AppTelemetryService.trackGuestEvent(
        eventName,
        route: AppRoutePaths.venuesBrowse,
        venueId: venueId,
        details: details,
      ),
    );
  }

  void _openVenue(Venue venue) {
    _trackGuestEvent(
      'venue_opened',
      venueId: venue.id,
      details: {
        'source': 'venues_browse',
        'slug': venue.slug,
        'can_order': venue.canAcceptGuestOrders,
        'is_open_now': venue.isOpenNow,
      },
    );
    context.pushNamed(
      AppRouteNames.venueDetail,
      pathParameters: {AppRouteParams.slug: venue.slug},
    );
  }

  void _toggleCategory(String category) {
    setState(() {
      if (category == 'All') {
        _selectedCategories = const ['All'];
      } else {
        final next = _selectedCategories
            .where((item) => item != 'All')
            .toList();
        if (next.contains(category)) {
          next.remove(category);
        } else {
          next.add(category);
        }
        _selectedCategories = next.isEmpty ? const ['All'] : next;
      }
      _resultLimit = _pageSize;
    });

    _trackGuestEvent(
      'venues_filters_changed',
      details: {'filters': _selectedCategories, 'query': _query},
    );
  }

  List<String> _buildCategoryOptions(GuestVenueFeed? feed) {
    return [
      ..._baseVenueFilters,
      ...(feed?.categories ?? const <String>[])
          .where((category) => !_baseVenueFilters.contains(category))
          .take(6),
    ];
  }

  Future<void> _requestLocation() async {
    if (_requestingLocation) return;
    _trackGuestEvent(
      'venues_location_requested',
      details: {'filters': _selectedCategories, 'query': _query},
    );
    setState(() => _requestingLocation = true);
    try {
      final result = await ref
          .read(discoveryLocationServiceProvider)
          .getCurrentLocation(requestIfNeeded: true);
      ref.invalidate(discoveryLocationProvider);
      _trackGuestEvent(
        'venues_location_result',
        details: {
          'granted': result != null,
          'filters': _selectedCategories,
          'query': _query,
        },
      );
      if (result == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location is still unavailable. Enable it in the browser to browse venues near you.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _requestingLocation = false);
      }
    }
  }

  GuestVenueQuery _buildGuestVenueQuery(DiscoveryCoordinates? location) {
    final selected = _selectedCategories;
    final categoryFilters = selected
        .where((category) => !_baseVenueFilters.contains(category))
        .toList(growable: false);
    final backendCategory = categoryFilters.length == 1
        ? categoryFilters.first
        : null;

    return GuestVenueQuery(
      limit: _resultLimit,
      query: _query.isEmpty ? null : _query,
      category: backendCategory,
      orderingOnly: selected.contains('Ordering'),
      latitude: location?.latitude,
      longitude: location?.longitude,
    );
  }

  List<Venue> _applyClientFilters(List<Venue> venues) {
    final selected = _selectedCategories;
    final categoryFilters = selected.where(
      (category) => !_baseVenueFilters.contains(category),
    );

    return venues
        .where((venue) {
          if (selected.contains('Open Now') && !venue.isOpenNow) {
            return false;
          }
          if (categoryFilters.isNotEmpty &&
              !categoryFilters.contains(venue.category)) {
            return false;
          }

          return true;
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final discoveryLocation = ref
        .watch(discoveryLocationProvider)
        .asData
        ?.value;
    final venuesQuery = _buildGuestVenueQuery(discoveryLocation);
    final feedAsync = ref.watch(guestVenueFeedProvider(venuesQuery));
    final currentFeed = feedAsync.asData?.value;
    _lastFeed = currentFeed ?? _lastFeed;
    final feed = currentFeed ?? _lastFeed;
    final venues = _applyClientFilters(feed?.items ?? const []);

    if (!_trackedBrowseView &&
        currentFeed != null &&
        currentFeed.items.isNotEmpty) {
      _trackedBrowseView = true;
      _trackGuestEvent(
        'venues_browse_viewed',
        details: {
          'venue_count': currentFeed.totalCount,
          'has_location': discoveryLocation != null,
        },
      );
    }

    return _VenuesBody(
      venues: venues,
      categoryOptions: _buildCategoryOptions(feed),
      totalCount: feed?.totalCount ?? venues.length,
      query: _query,
      isLoading: feedAsync.isLoading,
      loadError: feedAsync.asError?.error,
      onRetry: () => ref.invalidate(guestVenueFeedProvider(venuesQuery)),
      onLoadMore: feed?.hasMore == true
          ? () {
              _trackGuestEvent(
                'venues_load_more',
                details: {
                  'current_limit': _resultLimit,
                  'filters': _selectedCategories,
                  'query': _query,
                },
              );
              setState(() => _resultLimit += _pageSize);
            }
          : null,
      searchController: _searchController,
      discoveryLocation: discoveryLocation,
      requestingLocation: _requestingLocation,
      selectedCategories: _selectedCategories,
      onSearchChanged: _onSearchChanged,
      onUseMyLocation: _requestLocation,
      onCategorySelected: _toggleCategory,
      onOpenVenue: _openVenue,
      onResetFilters: () {
        _queryDebounce?.cancel();
        _searchController.clear();
        setState(() {
          _query = '';
          _selectedCategories = const ['All'];
          _resultLimit = _pageSize;
        });
        _trackGuestEvent('venues_filters_reset');
      },
    );
  }
}

class _VenuesBody extends StatelessWidget {
  final List<Venue> venues;
  final List<String> categoryOptions;
  final int totalCount;
  final String query;
  final bool isLoading;
  final Object? loadError;
  final VoidCallback onRetry;
  final VoidCallback? onLoadMore;
  final TextEditingController searchController;
  final DiscoveryCoordinates? discoveryLocation;
  final bool requestingLocation;
  final List<String> selectedCategories;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onUseMyLocation;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<Venue> onOpenVenue;
  final VoidCallback onResetFilters;

  const _VenuesBody({
    required this.venues,
    required this.categoryOptions,
    required this.totalCount,
    required this.query,
    required this.isLoading,
    required this.loadError,
    required this.onRetry,
    required this.onLoadMore,
    required this.searchController,
    required this.discoveryLocation,
    required this.requestingLocation,
    required this.selectedCategories,
    required this.onSearchChanged,
    required this.onUseMyLocation,
    required this.onCategorySelected,
    required this.onOpenVenue,
    required this.onResetFilters,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final shouldAnimateVenues =
        query.isEmpty &&
        selectedCategories.length == 1 &&
        selectedCategories.first == 'All' &&
        !reduceMotionOf(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final useGrid = screenWidth >= 1100;
    final crossAxisCount = screenWidth >= 1480 ? 3 : 2;

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
                    // Search icon — opens search sheet
                    PressableScale(
                      onTap: () => _showSearchSheet(context, cs, tt),
                      semanticLabel: 'Search venues',
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: query.isNotEmpty
                              ? cs.primary.withValues(alpha: 0.14)
                              : cs.surfaceContainer,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusXl,
                          ),
                          border: Border.all(
                            color: query.isNotEmpty
                                ? cs.primary.withValues(alpha: 0.28)
                                : AppColors.white5,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            LucideIcons.search,
                            size: 22,
                            color: query.isNotEmpty
                                ? cs.primary
                                : AppColors.white40,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.space4),
                    // Location button
                    PressableScale(
                      onTap: requestingLocation ? null : onUseMyLocation,
                      semanticLabel: 'Use my location',
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: discoveryLocation != null
                              ? cs.primary.withValues(alpha: 0.14)
                              : cs.surfaceContainer,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusXl,
                          ),
                          border: Border.all(
                            color: discoveryLocation != null
                                ? cs.primary.withValues(alpha: 0.28)
                                : AppColors.white5,
                          ),
                        ),
                        child: Center(
                          child: requestingLocation
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cs.primary,
                                  ),
                                )
                              : Icon(
                                  discoveryLocation != null
                                      ? LucideIcons.navigation
                                      : LucideIcons.mapPin,
                                  size: 22,
                                  color: discoveryLocation != null
                                      ? cs.primary
                                      : AppColors.white40,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Active query chip
                if (query.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.space3),
                  PressableScale(
                    onTap: onResetFilters,
                    semanticLabel: 'Clear search',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusFull,
                        ),
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.search, size: 12, color: cs.primary),
                          const SizedBox(width: 6),
                          Text(
                            '"$query"',
                            style: tt.labelSmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(LucideIcons.x, size: 12, color: cs.primary),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppTheme.space4),
                Text(
                  discoveryLocation != null
                      ? 'VENUES ARE RANKED USING YOUR CURRENT LOCATION'
                      : 'ALLOW LOCATION TO RANK VENUES NEAR YOU',
                  style: TextStyle(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.58),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.1,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isLoading)
          const SliverToBoxAdapter(
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (loadError != null && venues.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space6,
                AppTheme.space8,
                AppTheme.space6,
                0,
              ),
              child: ErrorState(
                message: 'Failed to load venues.',
                onRetry: onRetry,
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
                final category = categoryOptions[index];
                final isSelected = selectedCategories.contains(category);
                return PressableScale(
                  onTap: () => onCategorySelected(category),
                  semanticLabel: 'Filter by $category',
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
              itemCount: categoryOptions.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.space8)),
        if (isLoading && venues.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppTheme.space6),
              child: _VenueBrowseLoadingState(),
            ),
          )
        else
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space6,
                0,
                AppTheme.space6,
                AppTheme.space4,
              ),
              child: Text(
                '${venues.length} of $totalCount venues',
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.66),
                ),
              ),
            ),
          ),
        if (!isLoading && venues.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyVenuesState(onResetFilters: onResetFilters),
          )
        else if (useGrid)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space6),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: AppTheme.space8,
                crossAxisSpacing: AppTheme.space6,
                childAspectRatio: 0.66,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final venue = venues[index];
                final card = _VenueCard(
                  venue: venue,
                  distanceLabel: _distanceLabelForVenue(
                    venue,
                    discoveryLocation,
                  ),
                  onTap: () => onOpenVenue(venue),
                );
                if (!shouldAnimateVenues) return card;
                return RepaintBoundary(
                  child: card
                    .animate(delay: (50 * index).ms)
                    .fadeIn(duration: 350.ms)
                    .slideY(begin: 0.08, end: 0),
                );
              }, childCount: venues.length),
            ),
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
                final card = _VenueCard(
                  venue: venue,
                  distanceLabel: _distanceLabelForVenue(
                    venue,
                    discoveryLocation,
                  ),
                  onTap: () => onOpenVenue(venue),
                );
                if (!shouldAnimateVenues) return card;

                return RepaintBoundary(
                  child: card
                    .animate(delay: (50 * index).ms)
                    .fadeIn(duration: 350.ms)
                    .slideY(begin: 0.08, end: 0),
                );
              },
            ),
          ),
        if (onLoadMore != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space6,
                AppTheme.space8,
                AppTheme.space6,
                0,
              ),
              child: Center(
                child: PremiumButton(
                  label: 'LOAD MORE ($totalCount)',
                  onPressed: onLoadMore,
                  isOutlined: true,
                  isSmall: true,
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.space24)),
      ],
    );
  }

  void _showSearchSheet(BuildContext context, ColorScheme cs, TextTheme tt) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppTheme.space6, AppTheme.space6, AppTheme.space6,
            MediaQuery.of(sheetContext).viewInsets.bottom + AppTheme.space6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: AppTheme.space5),
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: cs.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  border: Border.all(color: AppColors.white5),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.search, size: 20, color: AppColors.white10),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        onChanged: onSearchChanged,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => Navigator.pop(sheetContext),
                        style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          filled: false,
                          hintText: 'Search venues...',
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
            ],
          ),
        );
      },
    );
  }
}

class _VenueBrowseLoadingState extends StatelessWidget {
  const _VenueBrowseLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        SkeletonLoader(width: double.infinity, height: 240, borderRadius: 24),
        SizedBox(height: AppTheme.space6),
        SkeletonLoader(width: double.infinity, height: 240, borderRadius: 24),
      ],
    );
  }
}

class _VenueCard extends StatelessWidget {
  final Venue venue;
  final String? distanceLabel;
  final VoidCallback onTap;

  const _VenueCard({
    required this.venue,
    required this.onTap,
    this.distanceLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PressableScale(
      onTap: onTap,
      semanticLabel: 'View ${venue.name}',
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
                            _ratingLabel(venue),
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
                            fontSize: 11,
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
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _VenueMetaPill(
                              label: venue.isOpenNow ? 'OPEN NOW' : 'CLOSED',
                              isPrimary: venue.isOpenNow,
                            ),
                            if (venue.canAcceptGuestOrders)
                              const _VenueMetaPill(label: 'ORDERING'),
                            if (venue.priceLevelLabel != null)
                              _VenueMetaPill(label: venue.priceLevelLabel!),
                            if (distanceLabel != null)
                              _VenueMetaPill(label: distanceLabel!),
                          ],
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
                    venue.primaryReviewSnippet ??
                        (venue.isOpenNow ? 'OPEN NOW' : 'CLOSED'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _VenueMetaPill extends StatelessWidget {
  final String label;
  final bool isPrimary;

  const _VenueMetaPill({required this.label, this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isPrimary
            ? cs.primary.withValues(alpha: 0.14)
            : Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(
          color: isPrimary
              ? cs.primary.withValues(alpha: 0.28)
              : AppColors.white10,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: isPrimary ? cs.primary : Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
        ),
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
              semanticLabel: 'Reset filters',
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

String _ratingLabel(Venue venue) {
  final rating = venue.rating.toStringAsFixed(
    venue.rating.truncateToDouble() == venue.rating ? 0 : 1,
  );
  if (venue.ratingCount <= 0) return rating;
  return '$rating · ${venue.ratingCount}';
}

String? _distanceLabelForVenue(Venue venue, DiscoveryCoordinates? location) {
  if (location == null) return null;
  return venue.distanceLabelFrom(location.latitude, location.longitude);
}
