import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:db_pkg/models/guest_venue_feed.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/core/services/app_telemetry.dart';
import 'package:dinein_app/core/services/discovery_location_service.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';

const _venueFilters = ['All', 'Ordering'];
const _openSearchIntent = '1';

class VenuesBrowseScreen extends ConsumerStatefulWidget {
  const VenuesBrowseScreen({super.key});

  @override
  ConsumerState<VenuesBrowseScreen> createState() => _VenuesBrowseScreenState();
}

class _VenuesBrowseScreenState extends ConsumerState<VenuesBrowseScreen> {
  static const _searchDebounce = Duration(milliseconds: 180);
  static const _pageSize = 18;

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _queryDebounce;
  List<String> _selectedFilters = const ['All'];
  String _query = '';
  int _resultLimit = _pageSize;
  bool _requestingLocation = false;
  bool _trackedBrowseView = false;
  bool _searchIntentHandled = false;
  GuestVenueFeed? _lastFeed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final shouldOpenSearch =
        GoRouterState.of(context).uri.queryParameters[AppRouteParams.search] ==
        _openSearchIntent;

    if (shouldOpenSearch && !_searchIntentHandled) {
      _searchIntentHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        GoRouter.of(context).replaceNamed(AppRouteNames.venuesBrowse);
        _searchFocusNode.requestFocus();
      });
      return;
    }

    if (!shouldOpenSearch) {
      _searchIntentHandled = false;
    }
  }

  @override
  void dispose() {
    _queryDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
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
          'filters': _selectedFilters,
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
      },
    );
    context.pushNamed(
      AppRouteNames.venueDetail,
      pathParameters: {AppRouteParams.slug: venue.slug},
    );
  }

  void _toggleFilter(String filter) {
    setState(() {
      if (filter == 'All') {
        _selectedFilters = const ['All'];
      } else {
        final next = _selectedFilters.where((item) => item != 'All').toList();
        if (next.contains(filter)) {
          next.remove(filter);
        } else {
          next.add(filter);
        }
        _selectedFilters = next.isEmpty ? const ['All'] : next;
      }
      _resultLimit = _pageSize;
    });

    _trackGuestEvent(
      'venues_filters_changed',
      details: {'filters': _selectedFilters, 'query': _query},
    );
  }

  Future<void> _requestLocation() async {
    if (_requestingLocation) return;
    _trackGuestEvent(
      'venues_location_requested',
      details: {'filters': _selectedFilters, 'query': _query},
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
          'filters': _selectedFilters,
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
    final selected = _selectedFilters;
    return GuestVenueQuery(
      limit: _resultLimit,
      query: _query.isEmpty ? null : _query,
      orderingOnly: selected.contains('Ordering'),
      latitude: location?.latitude,
      longitude: location?.longitude,
    );
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
    final venues = feed?.items ?? const <Venue>[];

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
                  'filters': _selectedFilters,
                  'query': _query,
                },
              );
              setState(() => _resultLimit += _pageSize);
            }
          : null,
      searchController: _searchController,
      searchFocusNode: _searchFocusNode,
      discoveryLocation: discoveryLocation,
      requestingLocation: _requestingLocation,
      selectedFilters: _selectedFilters,
      onSearchChanged: _onSearchChanged,
      onUseMyLocation: _requestLocation,
      onFilterSelected: _toggleFilter,
      onOpenVenue: _openVenue,
      onResetFilters: () {
        _queryDebounce?.cancel();
        _searchController.clear();
        setState(() {
          _query = '';
          _selectedFilters = const ['All'];
          _resultLimit = _pageSize;
        });
        _trackGuestEvent('venues_filters_reset');
      },
    );
  }
}

class _VenuesBody extends StatelessWidget {
  final List<Venue> venues;
  final int totalCount;
  final String query;
  final bool isLoading;
  final Object? loadError;
  final VoidCallback onRetry;
  final VoidCallback? onLoadMore;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final DiscoveryCoordinates? discoveryLocation;
  final bool requestingLocation;
  final List<String> selectedFilters;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onUseMyLocation;
  final ValueChanged<String> onFilterSelected;
  final ValueChanged<Venue> onOpenVenue;
  final VoidCallback onResetFilters;

  const _VenuesBody({
    required this.venues,
    required this.totalCount,
    required this.query,
    required this.isLoading,
    required this.loadError,
    required this.onRetry,
    required this.onLoadMore,
    required this.searchController,
    required this.searchFocusNode,
    required this.discoveryLocation,
    required this.requestingLocation,
    required this.selectedFilters,
    required this.onSearchChanged,
    required this.onUseMyLocation,
    required this.onFilterSelected,
    required this.onOpenVenue,
    required this.onResetFilters,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final useGrid = screenWidth >= 1180;
    final crossAxisCount = screenWidth >= 1480 ? 3 : 2;

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
            child: _BrowseHero(
              query: query,
              totalCount: totalCount,
              visibleCount: venues.length,
              searchController: searchController,
              searchFocusNode: searchFocusNode,
              selectedFilters: selectedFilters,
              hasLocation: discoveryLocation != null,
              requestingLocation: requestingLocation,
              onSearchChanged: onSearchChanged,
              onUseMyLocation: onUseMyLocation,
              onFilterSelected: onFilterSelected,
              onResetFilters: onResetFilters,
            ),
          ),
        ),
        if (isLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: AppTheme.space4),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          ),
        if (loadError != null && venues.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space6,
              AppTheme.space6,
              AppTheme.space6,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: GuestStatePanel(
                icon: Icons.signal_wifi_connected_no_internet_4_rounded,
                title: 'Failed to load venues',
                subtitle: 'Try again in a moment.',
                actionLabel: 'Retry',
                onAction: onRetry,
                isError: true,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.space8)),
        if (isLoading && venues.isEmpty)
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.space6),
            sliver: SliverToBoxAdapter(child: _VenueBrowseLoadingState()),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space6),
            sliver: SliverToBoxAdapter(
              child: GuestSectionHeader(
                title: query.isEmpty ? 'All venues' : 'Search results',
                subtitle: '${venues.length} of $totalCount visible',
              ),
            ),
          ),
        if (!isLoading && venues.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.all(AppTheme.space6),
            sliver: SliverFillRemaining(
              hasScrollBody: false,
              child: GuestStatePanel(
                icon: Icons.search_off_rounded,
                title: 'No venues found',
                subtitle: 'Try a different search or clear your filters.',
                actionLabel: 'Reset',
                onAction: onResetFilters,
              ),
            ),
          )
        else if (useGrid)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space6,
              AppTheme.space4,
              AppTheme.space6,
              0,
            ),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: AppTheme.space6,
                crossAxisSpacing: AppTheme.space6,
                childAspectRatio: 0.82,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final venue = venues[index];
                return _VenueCard(
                  venue: venue,
                  distanceLabel: _distanceLabelForVenue(
                    venue,
                    discoveryLocation,
                  ),
                  onTap: () => onOpenVenue(venue),
                );
              }, childCount: venues.length),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space6,
              AppTheme.space4,
              AppTheme.space6,
              0,
            ),
            sliver: SliverList.separated(
              itemCount: venues.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppTheme.space4),
              itemBuilder: (context, index) {
                final venue = venues[index];
                return _VenueCard(
                  venue: venue,
                  distanceLabel: _distanceLabelForVenue(
                    venue,
                    discoveryLocation,
                  ),
                  onTap: () => onOpenVenue(venue),
                );
              },
            ),
          ),
        if (onLoadMore != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space6,
              AppTheme.space8,
              AppTheme.space6,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: PremiumButton(
                  label: 'LOAD MORE',
                  onPressed: onLoadMore,
                  isOutlined: true,
                  isSmall: true,
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.space8)),
      ],
    );
  }
}

class _BrowseHero extends StatelessWidget {
  final String query;
  final int totalCount;
  final int visibleCount;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final List<String> selectedFilters;
  final bool hasLocation;
  final bool requestingLocation;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onUseMyLocation;
  final ValueChanged<String> onFilterSelected;
  final VoidCallback onResetFilters;

  const _BrowseHero({
    required this.query,
    required this.totalCount,
    required this.visibleCount,
    required this.searchController,
    required this.searchFocusNode,
    required this.selectedFilters,
    required this.hasLocation,
    required this.requestingLocation,
    required this.onSearchChanged,
    required this.onUseMyLocation,
    required this.onFilterSelected,
    required this.onResetFilters,
  });

  @override
  Widget build(BuildContext context) {
    return GuestHeroCard(
      eyebrow: 'Venues',
      title: 'Browse with less noise.',
      subtitle:
          'Search faster, filter earlier, and surface what matters first.',
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GuestSearchField(
            controller: searchController,
            focusNode: searchFocusNode,
            onChanged: onSearchChanged,
            hintText: 'Search venues...',
            trailing: query.isEmpty
                ? null
                : PressableScale(
                    onTap: onResetFilters,
                    semanticLabel: 'Clear search and filters',
                    minTouchTargetSize: const Size(32, 32),
                    child: const Icon(Icons.close_rounded, size: 18),
                  ),
          ),
          const SizedBox(height: AppTheme.space4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final filter in _venueFilters)
                GuestFilterPill(
                  label: filter,
                  selected: selectedFilters.contains(filter),
                  onTap: () => onFilterSelected(filter),
                ),
              GuestFilterPill(
                label: hasLocation
                    ? (requestingLocation ? 'Refreshing' : 'Nearby on')
                    : (requestingLocation ? 'Locating' : 'Use location'),
                selected: hasLocation,
                onTap: onUseMyLocation,
                icon: LucideIcons.mapPin,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space4),
          Row(
            children: [
              Expanded(
                child: GuestMetricTile(
                  icon: Icons.storefront_rounded,
                  value: '$visibleCount',
                  label: 'Visible',
                ),
              ),
              const SizedBox(width: AppTheme.space3),
              Expanded(
                child: GuestMetricTile(
                  icon: Icons.layers_outlined,
                  value: '$totalCount',
                  label: 'Total',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VenueBrowseLoadingState extends StatelessWidget {
  const _VenueBrowseLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        SkeletonLoader(width: double.infinity, height: 260, borderRadius: 28),
        SizedBox(height: AppTheme.space6),
        SkeletonLoader(width: double.infinity, height: 260, borderRadius: 28),
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
    final locality = venue.addressLocality;

    return GuestSurfaceCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      borderRadius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: SizedBox(
              height: 188,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DineInImage(
                    imageUrl: venue.imageUrl,
                    fit: BoxFit.cover,
                    fallbackIcon: LucideIcons.store,
                    semanticLabel: '${venue.name} photo',
                  ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: GuestMetaPill(
                      label: _ratingLabel(venue),
                      icon: Icons.star_rounded,
                      emphasized: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venue.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.headlineSmall?.copyWith(height: 1.08),
                ),
                if (locality != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    locality,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                ],
                const SizedBox(height: AppTheme.space4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    GuestMetaPill(
                      label: venue.canAcceptGuestOrders
                          ? 'Ordering'
                          : venue.guestAvailabilityLabel,
                      emphasized: venue.canAcceptGuestOrders,
                    ),
                    if (venue.priceLevelLabel != null)
                      GuestMetaPill(label: venue.priceLevelLabel!),
                    if (distanceLabel != null)
                      GuestMetaPill(label: distanceLabel!),
                  ],
                ),
                if (venue.isPromoActive &&
                    venue.promoMessage?.isNotEmpty == true) ...[
                  const SizedBox(height: AppTheme.space4),
                  Text(
                    venue.promoMessage!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: AppTheme.space4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        venue.guestAvailabilityReason,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.78),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.space3),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
