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

const _discoverHeroImageUrl =
    'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=80';

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
  bool _requestingLocation = false;
  bool _trackedDiscoverView = false;
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

  void _openVenue(Venue venue, {required String source}) {
    _trackGuestEvent(
      'venue_opened',
      venueId: venue.id,
      details: {
        'source': source,
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

  Future<void> _requestLocation() async {
    if (_requestingLocation) return;
    _trackGuestEvent(
      'discover_location_requested',
      details: {'has_query': _query.isNotEmpty},
    );
    setState(() => _requestingLocation = true);
    try {
      final result = await ref
          .read(discoveryLocationServiceProvider)
          .getCurrentLocation(requestIfNeeded: true);
      ref.invalidate(discoveryLocationProvider);
      _trackGuestEvent(
        'discover_location_result',
        details: {'granted': result != null, 'has_query': _query.isNotEmpty},
      );
      if (result == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location is still unavailable. Enable it in the browser to rank venues near you.',
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
      onQueryChanged: _onSearchChanged,
      onUseMyLocation: _requestLocation,
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
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onUseMyLocation;
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
    required this.onQueryChanged,
    required this.onUseMyLocation,
    required this.onOpenFeaturedVenue,
    required this.onOpenResultVenue,
    required this.onOpenBrowse,
    required this.onClearQuery,
  });

  @override
  Widget build(BuildContext context) {
    final venues = feed?.items ?? const <Venue>[];
    final featuredVenues = venues.take(6).toList(growable: false);
    final results = venues;
    final shouldAnimateResults = query.isEmpty && !reduceMotionOf(context);

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
            child: _DiscoverHero(
              controller: controller,
              query: query,
              discoveryLocation: discoveryLocation,
              requestingLocation: requestingLocation,
              onChanged: onQueryChanged,
              onUseMyLocation: onUseMyLocation,
              onClear: onClearQuery,
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
                AppTheme.space10,
                AppTheme.space6,
                0,
              ),
              child: ErrorState(
                message: 'Check your connection and try again.',
                onRetry: onRetry,
              ),
            ),
          ),
        if (isLoading && venues.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppTheme.space6,
                AppTheme.space10,
                AppTheme.space6,
                0,
              ),
              child: _DiscoverLoadingState(),
            ),
          ),
        if (query.isEmpty && featuredVenues.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: AppTheme.space12),
              child: _SectionHeader(
                title: 'Featured',
                actionLabel: 'View All',
                onTap: () => context.pushNamed(AppRouteNames.venuesBrowse),
              ),
            ),
          ),
        if (query.isEmpty && featuredVenues.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 382,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.space6,
                  AppTheme.space4,
                  AppTheme.space6,
                  0,
                ),
                itemBuilder: (context, index) => _FeaturedVenueCard(
                  venue: featuredVenues[index],
                  distanceLabel: _distanceLabelForVenue(
                    featuredVenues[index],
                    discoveryLocation,
                  ),
                  onTap: () => onOpenFeaturedVenue(featuredVenues[index]),
                ),
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppTheme.space6),
                itemCount: featuredVenues.length,
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(
              top: query.isEmpty ? AppTheme.space10 : AppTheme.space12,
            ),
            child: _SectionHeader(
              title: query.isEmpty ? 'All Venues' : 'Results',
            ),
          ),
        ),
        if (!isLoading && results.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.space6),
              child: const EmptyState(
                icon: LucideIcons.search,
                title: 'No Venues Found',
                subtitle: 'Try adjusting your search.',
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
              itemCount: results.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppTheme.space4),
              itemBuilder: (context, index) {
                final venue = results[index];
                final card = _NearbyVenueCard(
                  venue: venue,
                  distanceLabel: _distanceLabelForVenue(
                    venue,
                    discoveryLocation,
                  ),
                  onTap: () => onOpenResultVenue(venue),
                );
                if (!shouldAnimateResults) return card;

                return card
                    .animate(delay: (50 * index).ms)
                    .fadeIn(duration: 350.ms)
                    .slideY(begin: 0.08, end: 0);
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
                  label:
                      'LOAD MORE${feed == null ? '' : ' (${results.length}/${feed!.totalCount})'}',
                  onPressed: onLoadMore,
                  isOutlined: true,
                  isSmall: true,
                ),
              ),
            ),
          ),
        if (query.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space6,
                AppTheme.space12,
                AppTheme.space6,
                AppTheme.space24,
              ),
              child: _DiscoverCta(onTap: onOpenBrowse),
            ),
          ),
      ],
    );
  }
}

class _DiscoverLoadingState extends StatelessWidget {
  const _DiscoverLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        SkeletonLoader(width: double.infinity, height: 220, borderRadius: 24),
        SizedBox(height: AppTheme.space6),
        SkeletonLoader(width: double.infinity, height: 128, borderRadius: 24),
        SizedBox(height: AppTheme.space4),
        SkeletonLoader(width: double.infinity, height: 128, borderRadius: 24),
      ],
    );
  }
}

class _DiscoverHero extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final DiscoveryCoordinates? discoveryLocation;
  final bool requestingLocation;
  final ValueChanged<String> onChanged;
  final VoidCallback onUseMyLocation;
  final VoidCallback onClear;

  const _DiscoverHero({
    required this.controller,
    required this.query,
    required this.discoveryLocation,
    required this.requestingLocation,
    required this.onChanged,
    required this.onUseMyLocation,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 340),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius3xl),
        border: Border.all(color: AppColors.white5),
        boxShadow: AppTheme.elevatedShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: DineInImage(
              imageUrl: _discoverHeroImageUrl,
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.18),
                    Colors.black.withValues(alpha: 0.54),
                    Theme.of(context).colorScheme.surfaceContainerHigh,
                  ],
                  stops: const [0.0, 0.38, 1.0],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.space8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text.rich(
                  TextSpan(
                    style: tt.displayMedium?.copyWith(
                      height: 0.84,
                      letterSpacing: -2.2,
                    ),
                    children: [
                      const TextSpan(text: 'FIND YOUR\n'),
                      TextSpan(
                        text: 'FLAVOR',
                        style: TextStyle(color: cs.primary),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                        border: Border.all(color: AppColors.white10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.search,
                            size: 20,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.68),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: controller,
                              onChanged: onChanged,
                              textInputAction: TextInputAction.search,
                              style: tt.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                filled: false,
                                hintText: 'Search venues...',
                                hintStyle: tt.bodyLarge?.copyWith(
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.30,
                                  ),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          if (query.isNotEmpty)
                            PressableScale(
                              onTap: onClear,
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
                    const SizedBox(height: AppTheme.space4),
                    PressableScale(
                      onTap: requestingLocation ? null : onUseMyLocation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: discoveryLocation != null
                              ? cs.primary.withValues(alpha: 0.14)
                              : Colors.black.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusFull,
                          ),
                          border: Border.all(
                            color: discoveryLocation != null
                                ? cs.primary.withValues(alpha: 0.28)
                                : AppColors.white10,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (requestingLocation)
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: cs.primary,
                                ),
                              )
                            else
                              Icon(
                                discoveryLocation != null
                                    ? LucideIcons.navigation
                                    : LucideIcons.mapPin,
                                size: 16,
                                color: discoveryLocation != null
                                    ? cs.primary
                                    : Colors.white,
                              ),
                            const SizedBox(width: 10),
                            Text(
                              discoveryLocation != null
                                  ? 'NEAR YOU ACTIVE'
                                  : 'USE MY LOCATION',
                              style: TextStyle(
                                color: discoveryLocation != null
                                    ? cs.primary
                                    : Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.4,
                              ),
                            ),
                          ],
                        ),
                      ),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onTap;

  const _SectionHeader({required this.title, this.actionLabel, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space6),
      child: Row(
        children: [
          Expanded(child: Text(title, style: tt.headlineLarge)),
          if (actionLabel != null && onTap != null)
            PressableScale(
              onTap: onTap,
              minTouchTargetSize: const Size(96, 44),
              child: Row(
                children: [
                  Text(
                    actionLabel!.toUpperCase(),
                    style: TextStyle(
                      color: cs.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.6,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(LucideIcons.chevronRight, size: 18, color: cs.primary),
                ],
              ),
            ),
        ],
      ),
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

    return PressableScale(
      onTap: onTap,
      child: SizedBox(
        width: 288,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
            border: Border.all(color: AppColors.white10),
            boxShadow: AppTheme.ambientShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DineInImage(imageUrl: venue.imageUrl, fit: BoxFit.cover),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.14),
                        Colors.black.withValues(alpha: 0.94),
                      ],
                      stops: const [0.0, 0.38, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 28,
                right: 28,
                bottom: 28,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venue.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: tt.headlineMedium?.copyWith(
                        color: Colors.white,
                        letterSpacing: -1.1,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(LucideIcons.star, size: 15, color: cs.primary),
                        const SizedBox(width: 6),
                        Text(
                          _ratingLabel(venue),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (distanceLabel != null) ...[
                          const SizedBox(width: 10),
                          Text(
                            distanceLabel!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.74),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
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

    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
          border: Border.all(color: AppColors.white5),
          boxShadow: AppTheme.ambientShadow,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              child: SizedBox(
                width: 96,
                height: 96,
                child: DineInImage(
                  imageUrl: venue.imageUrl,
                  fit: BoxFit.cover,
                  fallbackIcon: LucideIcons.store,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.space6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venue.name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: tt.headlineSmall?.copyWith(letterSpacing: -0.8),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(LucideIcons.star, size: 15, color: cs.primary),
                      const SizedBox(width: 6),
                      Text(
                        _ratingLabel(venue),
                        style: TextStyle(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.72),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetaPill(
                        label: venue.isOpenNow ? 'OPEN NOW' : 'CLOSED',
                        isPrimary: venue.isOpenNow,
                      ),
                      if (venue.canAcceptGuestOrders)
                        const _MetaPill(label: 'ORDERING'),
                      if (venue.priceLevelLabel != null)
                        _MetaPill(label: venue.priceLevelLabel!),
                      if (distanceLabel != null)
                        _MetaPill(label: distanceLabel!),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String label;
  final bool isPrimary;

  const _MetaPill({required this.label, this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isPrimary
            ? cs.primary.withValues(alpha: 0.14)
            : AppColors.white5,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(
          color: isPrimary
              ? cs.primary.withValues(alpha: 0.24)
              : AppColors.white5,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: isPrimary ? cs.primary : cs.onSurfaceVariant,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
        ),
      ),
    );
  }
}

class _DiscoverCta extends StatelessWidget {
  final VoidCallback onTap;

  const _DiscoverCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space6,
        vertical: AppTheme.space12,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radius3xl),
        border: Border.all(color: AppColors.white5),
      ),
      child: Column(
        children: [
          Text.rich(
            TextSpan(
              style: tt.headlineLarge?.copyWith(height: 1.05),
              children: [
                const TextSpan(text: 'STILL LOOKING FOR THE\n'),
                TextSpan(
                  text: 'PERFECT SPOT?',
                  style: TextStyle(color: cs.primary),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.space6),
          PressableScale(
            onTap: onTap,
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
                    color: cs.primary.withValues(alpha: 0.30),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'BROWSE ALL',
                    style: TextStyle(
                      color: cs.onPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.6,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(LucideIcons.chevronRight, size: 20, color: cs.onPrimary),
                ],
              ),
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
