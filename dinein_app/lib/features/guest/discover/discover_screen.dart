import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/guest_venue_feed.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/core/services/app_telemetry.dart';
import 'package:dinein_app/core/services/discovery_location_service.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  static const _searchDebounce = Duration(milliseconds: 180);
  static const _pageSize = 12;

  final _searchController = TextEditingController();
  Timer? _queryDebounce;
  String _query = '';
  int _resultLimit = _pageSize;
  bool _trackedDiscoverView = false;
  bool _requestingLocation = false;
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
        'discover_search',
        details: {
          'query': normalized,
          'query_length': normalized.length,
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
        route: AppRoutePaths.discover,
        venueId: venueId,
        details: details,
      ),
    );
  }

  Future<void> _requestLocation() async {
    if (_requestingLocation) return;
    _trackGuestEvent('discover_location_requested', details: {'query': _query});
    setState(() => _requestingLocation = true);
    try {
      final result = await ref
          .read(discoveryLocationServiceProvider)
          .getCurrentLocation(requestIfNeeded: true);
      ref.invalidate(discoveryLocationProvider);
      if (result == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location unavailable. Enable it in browser settings to rank venues near you.',
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

  void _openVenue(Venue venue, {required String source}) {
    _trackGuestEvent(
      'venue_opened',
      venueId: venue.id,
      details: {
        'source': source,
        'slug': venue.slug,
        'can_order': venue.canAcceptGuestOrders,
      },
    );
    context.pushNamed(
      AppRouteNames.venueDetail,
      pathParameters: {AppRouteParams.slug: venue.slug},
    );
  }

  @override
  Widget build(BuildContext context) {
    final discoveryLocation = ref
        .watch(discoveryLocationProvider)
        .asData
        ?.value;
    final venuesQuery = GuestVenueQuery(
      limit: _resultLimit,
      query: _query.isEmpty ? null : _query,
      latitude: discoveryLocation?.latitude,
      longitude: discoveryLocation?.longitude,
    );
    final feedAsync = ref.watch(guestVenueFeedProvider(venuesQuery));
    final currentFeed = feedAsync.asData?.value;
    _lastFeed = currentFeed ?? _lastFeed;
    final feed = currentFeed ?? _lastFeed;

    if (!_trackedDiscoverView &&
        currentFeed != null &&
        currentFeed.items.isNotEmpty) {
      _trackedDiscoverView = true;
      _trackGuestEvent(
        'discover_viewed',
        details: {
          'venue_count': currentFeed.totalCount,
          'has_location': discoveryLocation != null,
        },
      );
    }

    return _DiscoverBody(
      query: _query,
      controller: _searchController,
      feed: feed,
      isLoading: feedAsync.isLoading,
      loadError: feedAsync.asError?.error,
      discoveryLocation: discoveryLocation,
      requestingLocation: _requestingLocation,
      onRetry: () => ref.invalidate(guestVenueFeedProvider(venuesQuery)),
      onLoadMore: feed?.hasMore == true
          ? () {
              _trackGuestEvent(
                'discover_load_more',
                details: {'current_limit': _resultLimit, 'query': _query},
              );
              setState(() => _resultLimit += _pageSize);
            }
          : null,
      onRequestLocation: _requestLocation,
      onQueryChanged: _onSearchChanged,
      onOpenFeaturedVenue: (venue) =>
          _openVenue(venue, source: 'discover_featured'),
      onOpenResultVenue: (venue) =>
          _openVenue(venue, source: 'discover_results'),
      onOpenBrowse: () {
        _trackGuestEvent('discover_view_all_tapped');
        context.pushNamed(AppRouteNames.venuesBrowse);
      },
      onClearQuery: () {
        _queryDebounce?.cancel();
        _searchController.clear();
        if (_query.isNotEmpty) {
          setState(() {
            _query = '';
            _resultLimit = _pageSize;
          });
        }
      },
    );
  }
}

class _DiscoverBody extends StatelessWidget {
  final String query;
  final TextEditingController controller;
  final GuestVenueFeed? feed;
  final bool isLoading;
  final Object? loadError;
  final DiscoveryCoordinates? discoveryLocation;
  final bool requestingLocation;
  final VoidCallback onRetry;
  final VoidCallback? onLoadMore;
  final VoidCallback onRequestLocation;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<Venue> onOpenFeaturedVenue;
  final ValueChanged<Venue> onOpenResultVenue;
  final VoidCallback onOpenBrowse;
  final VoidCallback onClearQuery;

  const _DiscoverBody({
    required this.query,
    required this.controller,
    required this.feed,
    required this.isLoading,
    required this.loadError,
    required this.discoveryLocation,
    required this.requestingLocation,
    required this.onRetry,
    required this.onLoadMore,
    required this.onRequestLocation,
    required this.onQueryChanged,
    required this.onOpenFeaturedVenue,
    required this.onOpenResultVenue,
    required this.onOpenBrowse,
    required this.onClearQuery,
  });

  @override
  Widget build(BuildContext context) {
    final venues = feed?.items ?? const <Venue>[];
    final featuredVenues = venues.take(6).toList(growable: false);
    final visibleCount = venues.length;
    final discoveredCount = feed?.totalCount ?? visibleCount;

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
            child: _DiscoverHero(
              controller: controller,
              query: query,
              visibleCount: visibleCount,
              featuredCount: featuredVenues.length,
              hasLocation: discoveryLocation != null,
              requestingLocation: requestingLocation,
              onChanged: onQueryChanged,
              onClear: onClearQuery,
              onRequestLocation: onRequestLocation,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.space4)),
        if (query.isEmpty)
          const SliverToBoxAdapter(child: _SmartReorderSection()),
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
                icon: Icons.wifi_off_rounded,
                title: 'Could not load venues',
                subtitle: 'Check your connection and try again.',
                actionLabel: 'Retry',
                onAction: onRetry,
                isError: true,
              ),
            ),
          ),
        if (isLoading && venues.isEmpty)
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppTheme.space6,
              AppTheme.space6,
              AppTheme.space6,
              0,
            ),
            sliver: SliverToBoxAdapter(child: _DiscoverLoadingState()),
          ),
        if (featuredVenues.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space6,
              AppTheme.space8,
              AppTheme.space6,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: GuestSectionHeader(
                title: query.isEmpty ? 'Featured' : 'Matches',
                subtitle: query.isEmpty
                    ? 'A quick starting set'
                    : '$visibleCount visible',
                actionLabel: query.isEmpty ? 'Browse' : null,
                onAction: query.isEmpty ? onOpenBrowse : null,
              ),
            ),
          ),
        if (featuredVenues.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 248,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.space6,
                  AppTheme.space4,
                  AppTheme.space6,
                  0,
                ),
                itemCount: featuredVenues.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppTheme.space4),
                itemBuilder: (context, index) {
                  final venue = featuredVenues[index];
                  return _FeaturedVenueCard(
                    venue: venue,
                    distanceLabel: _distanceLabelForVenue(
                      venue,
                      discoveryLocation,
                    ),
                    onTap: () => onOpenFeaturedVenue(venue),
                  );
                },
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.space6,
            AppTheme.space8,
            AppTheme.space6,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: GuestSectionHeader(
              title: query.isEmpty ? 'All venues' : 'Results',
              subtitle: '$visibleCount of $discoveredCount visible',
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
                title: 'No venues',
                subtitle: 'Try a different name or area.',
                actionLabel: query.isNotEmpty ? 'Clear search' : null,
                onAction: query.isNotEmpty ? onClearQuery : null,
              ),
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
                return _NearbyVenueCard(
                  venue: venue,
                  distanceLabel: _distanceLabelForVenue(
                    venue,
                    discoveryLocation,
                  ),
                  onTap: () => onOpenResultVenue(venue),
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
                  label: 'Load more',
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

class _DiscoverHero extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final int visibleCount;
  final int featuredCount;
  final bool hasLocation;
  final bool requestingLocation;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onRequestLocation;

  const _DiscoverHero({
    required this.controller,
    required this.query,
    required this.visibleCount,
    required this.featuredCount,
    required this.hasLocation,
    required this.requestingLocation,
    required this.onChanged,
    required this.onClear,
    required this.onRequestLocation,
  });

  @override
  Widget build(BuildContext context) {
    return GuestHeroCard(
      eyebrow: 'Discover',
      title: 'Find a place quickly.',
      subtitle: 'Search once, scan faster, and keep the screen quiet.',
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GuestSearchField(
            controller: controller,
            onChanged: onChanged,
            hintText: 'Search venues or cuisine',
            trailing: query.isEmpty
                ? null
                : PressableScale(
                    onTap: onClear,
                    semanticLabel: 'Clear search',
                    minTouchTargetSize: const Size(32, 32),
                    child: const Icon(Icons.close_rounded, size: 18),
                  ),
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
                  icon: Icons.local_fire_department_rounded,
                  value: '$featuredCount',
                  label: 'Top picks',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space4),
          LayoutBuilder(
            builder: (context, constraints) {
              final tiles = [
                Expanded(
                  child: GuestQuickActionTile(
                    icon: LucideIcons.mapPin,
                    label: hasLocation ? 'Nearby' : 'Use location',
                    value: requestingLocation
                        ? 'Locating...'
                        : hasLocation
                        ? 'Sort nearer venues first'
                        : 'Rank nearby venues first',
                    onTap: onRequestLocation,
                    emphasized: hasLocation,
                  ),
                ),
                const SizedBox(width: AppTheme.space3),
                Expanded(
                  child: GuestQuickActionTile(
                    icon: LucideIcons.receipt,
                    label: 'Orders',
                    value: 'Recent activity',
                    onTap: () => context.pushNamed(AppRouteNames.orderHistory),
                  ),
                ),
                const SizedBox(width: AppTheme.space3),
                Expanded(
                  child: GuestQuickActionTile(
                    icon: LucideIcons.settings,
                    label: 'Settings',
                    value: 'Preferences',
                    onTap: () => context.pushNamed(AppRouteNames.guestSettings),
                  ),
                ),
              ];

              if (constraints.maxWidth < 760) {
                return Column(
                  children: [
                    Row(children: tiles.take(2).toList()),
                    const SizedBox(height: AppTheme.space3),
                    Row(children: [tiles[4]]),
                  ],
                );
              }

              return Row(children: tiles);
            },
          ),
        ],
      ),
    );
  }
}

class _DiscoverLoadingState extends StatelessWidget {
  const _DiscoverLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        SkeletonLoader(width: double.infinity, height: 260, borderRadius: 28),
        SizedBox(height: AppTheme.space6),
        SkeletonLoader(width: double.infinity, height: 116, borderRadius: 24),
        SizedBox(height: AppTheme.space4),
        SkeletonLoader(width: double.infinity, height: 116, borderRadius: 24),
      ],
    );
  }
}

class _FeaturedVenueCard extends StatelessWidget {
  final Venue venue;
  final String? distanceLabel;
  final VoidCallback onTap;

  const _FeaturedVenueCard({
    required this.venue,
    required this.onTap,
    this.distanceLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final locality = venue.addressLocality;

    return SizedBox(
      width: 252,
      child: GuestSurfaceCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        borderRadius: 28,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: SizedBox(
                height: 148,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DineInImage(
                      imageUrl: venue.imageUrl,
                      fit: BoxFit.cover,
                      semanticLabel: '${venue.name} photo',
                      fallbackIcon: LucideIcons.store,
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
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
                    style: tt.titleLarge?.copyWith(height: 1.1),
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
                  const SizedBox(height: AppTheme.space3),
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
                    const SizedBox(height: AppTheme.space3),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyVenueCard extends StatelessWidget {
  final Venue venue;
  final String? distanceLabel;
  final VoidCallback onTap;

  const _NearbyVenueCard({
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
      borderRadius: 26,
      padding: const EdgeInsets.all(AppTheme.space4),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: 88,
              height: 88,
              child: DineInImage(
                imageUrl: venue.imageUrl,
                fit: BoxFit.cover,
                semanticLabel: '${venue.name} photo',
                fallbackIcon: LucideIcons.store,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venue.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleMedium?.copyWith(height: 1.15),
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
                const SizedBox(height: AppTheme.space3),
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
              ],
            ),
          ),
          const SizedBox(width: AppTheme.space3),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GuestMetaPill(
                label: _ratingLabel(venue),
                icon: Icons.star_rounded,
                emphasized: true,
              ),
              const SizedBox(height: AppTheme.space4),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: cs.onSurfaceVariant,
              ),
            ],
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

class _SmartReorderSection extends ConsumerWidget {
  const _SmartReorderSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(userOrdersProvider);
    final orders = ordersAsync.asData?.value ?? [];
    final pastOrders = orders
        .where((order) => order.status == OrderStatus.served)
        .toList();

    if (pastOrders.isEmpty && !ordersAsync.isLoading) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GuestSectionHeader(
            title: 'Order again',
            subtitle: 'Recent meals',
          ),
          const SizedBox(height: AppTheme.space4),
          if (ordersAsync.isLoading)
            const SkeletonLoader(
              width: double.infinity,
              height: 92,
              borderRadius: 24,
            )
          else
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: pastOrders.length.clamp(0, 5),
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppTheme.space4),
                itemBuilder: (context, index) {
                  final order = pastOrders[index];
                  final itemSummary = order.items
                      .take(2)
                      .map((item) => item.name)
                      .join(', ');

                  return SizedBox(
                    width: 236,
                    child: GuestSurfaceCard(
                      onTap: () {
                        AppTelemetryService.trackGuestEvent(
                          'smart_reorder_tapped',
                          venueId: order.venueId,
                          orderId: order.id,
                        );
                        context.pushNamed(
                          AppRouteNames.orderDetails,
                          pathParameters: {AppRouteParams.id: order.id},
                        );
                      },
                      padding: const EdgeInsets.all(AppTheme.space4),
                      borderRadius: 24,
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: DineInImage(
                                imageUrl: order.venueImageUrl,
                                fit: BoxFit.cover,
                                fallbackIcon: LucideIcons.store,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.space4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  order.venueName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  itemSummary,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                GuestMetaPill(
                                  label: '#${order.displayNumber}',
                                  emphasized: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
