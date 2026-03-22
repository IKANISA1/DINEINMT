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

const _discoverHeroImageUrl =
    'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=80';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  static const _searchDebounce = Duration(milliseconds: 180);

  final _searchController = TextEditingController();
  Timer? _queryDebounce;
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

  List<Venue> _filterVenues(List<Venue> venues) {
    if (_query.isEmpty) return venues;
    final needle = _query.toLowerCase();
    return venues
        .where((venue) {
          final haystack =
              '${venue.name} ${venue.category} ${venue.description} ${venue.address}'
                  .toLowerCase();
          return haystack.contains(needle);
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
        message: 'Check your connection and try again.',
        onRetry: () => ref.invalidate(venuesProvider),
      ),
      data: (venues) => _DiscoverBody(
        query: _query,
        controller: _searchController,
        venues: venues,
        filteredVenues: _filterVenues(venues),
        onQueryChanged: _onSearchChanged,
        onClearQuery: () {
          _queryDebounce?.cancel();
          _searchController.clear();
          if (_query.isNotEmpty) {
            setState(() => _query = '');
          }
        },
      ),
    );
  }
}

class _DiscoverBody extends StatelessWidget {
  final String query;
  final TextEditingController controller;
  final List<Venue> venues;
  final List<Venue> filteredVenues;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;

  const _DiscoverBody({
    required this.query,
    required this.controller,
    required this.venues,
    required this.filteredVenues,
    required this.onQueryChanged,
    required this.onClearQuery,
  });

  @override
  Widget build(BuildContext context) {
    final featuredVenues = venues.take(6).toList(growable: false);
    final results = filteredVenues;
    final shouldAnimateResults = query.isEmpty;

    if (venues.isEmpty) {
      return const EmptyState(
        icon: LucideIcons.store,
        title: 'No venues yet',
        subtitle: 'Check back soon for newly onboarded venues.',
      );
    }

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
              onChanged: onQueryChanged,
              onClear: onClearQuery,
            ),
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
                itemBuilder: (context, index) =>
                    _FeaturedVenueCard(venue: featuredVenues[index]),
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
        if (results.isEmpty)
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
                final card = _NearbyVenueCard(venue: venue);
                if (!shouldAnimateResults) return card;

                return card
                    .animate(delay: (50 * index).ms)
                    .fadeIn(duration: 350.ms)
                    .slideY(begin: 0.08, end: 0);
              },
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
              child: _DiscoverCta(
                onTap: () => context.pushNamed(AppRouteNames.venuesBrowse),
              ),
            ),
          ),
      ],
    );
  }
}

class _DiscoverHero extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _DiscoverHero({
    required this.controller,
    required this.query,
    required this.onChanged,
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

  const _FeaturedVenueCard({required this.venue});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PressableScale(
      onTap: () => context.pushNamed(
        AppRouteNames.venueDetail,
        pathParameters: {AppRouteParams.slug: venue.slug},
      ),
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
                      maxLines: 2,
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
                          venue.rating.toStringAsFixed(
                            venue.rating.truncateToDouble() == venue.rating
                                ? 0
                                : 1,
                          ),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
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

  const _NearbyVenueCard({required this.venue});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PressableScale(
      onTap: () => context.pushNamed(
        AppRouteNames.venueDetail,
        pathParameters: {AppRouteParams.slug: venue.slug},
      ),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.headlineSmall?.copyWith(letterSpacing: -0.8),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.clock3,
                        size: 15,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        venue.isOpen ? 'OPEN NOW' : 'CLOSED',
                        style: TextStyle(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.72),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.2,
                        ),
                      ),
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
