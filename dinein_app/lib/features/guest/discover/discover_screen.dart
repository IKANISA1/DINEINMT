import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/models.dart';
import '../../../core/constants/enums.dart';
import '../../../core/providers/providers.dart';
import '../../../shared/widgets/shared_widgets.dart';


/// Discover screen — database-based venue discovery + promos.
/// Per DineIn rules: NO maps, NO geolocation, NO "near me".
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Filter venues by name or category (case-insensitive).
  List<Venue> _filterVenues(List<Venue> venues) {
    if (_query.isEmpty) return venues;
    final q = _query.toLowerCase();
    return venues.where((v) {
      final haystack = '${v.name} ${v.category} ${v.description} ${v.address}'
          .toLowerCase();
      return haystack.contains(q);
    }).toList();
  }
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final venuesAsync = ref.watch(venuesProvider);

    return venuesAsync.when(
      loading: () => const Center(
        child: SkeletonLoader(width: double.infinity, height: 200),
      ),
      error: (err, _) => ErrorState(
        message: 'Check your connection and try again.',
        onRetry: () => ref.invalidate(venuesProvider),
      ),
      data: (venues) => _buildContent(context, cs, tt, venues),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
    List<Venue> venues,
  ) {
    if (venues.isEmpty) {
      return const EmptyState(
        icon: LucideIcons.store,
        title: 'No venues yet',
        subtitle: 'Check back soon for newly onboarded venues.',
      );
    }

    final filtered = _filterVenues(venues);
    final allActiveVenues = venues
        .where((v) => v.status == VenueStatus.active)
        .toList();

    return CustomScrollView(
      slivers: [
        // ─── Hero Search Section ───
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space6,
              AppTheme.space6,
              AppTheme.space6,
              0,
            ),
            child: _buildHeroSearch(context, cs, tt, venues),
          ),
        ),

        // ─── Featured Venues (horizontal scroll) — shown only when not searching ───
        if (_query.isEmpty && allActiveVenues.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: AppTheme.space12),
              child: _buildFeaturedSection(context, cs, tt, allActiveVenues),
            ),
          ),

        // ─── Venue List ───
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppTheme.space6,
              right: AppTheme.space6,
              top: AppTheme.space12,
            ),
            child: Text(
              _query.isEmpty ? 'Active Venues' : 'Results',
              style: tt.headlineLarge,
            ),
          ),
        ),

        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: LucideIcons.searchX,
              title: 'No matches',
              subtitle: 'Try a different search term.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(AppTheme.space6),
            sliver: SliverList.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppTheme.space4),
              itemBuilder: (context, index) {
                final venue = filtered[index];
                return _VenueListTile(venue: venue)
                    .animate(delay: (100 * index).ms)
                    .fadeIn(duration: 400.ms)
                    .slideX(begin: 0.05, end: 0);
              },
            ),
          ),

        // ─── Bottom CTA (hidden when searching) ───
        if (_query.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space6,
                0,
                AppTheme.space6,
                AppTheme.space24,
              ),
              child: _buildBottomCta(context, cs, tt),
            ),
          ),
      ],
    );
  }

  Widget _buildHeroSearch(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
    List<Venue> venues,
  ) {
    return Stack(
      children: [
        // Ambient glow blob (matching React)
        Positioned(
          top: -40,
          right: -40,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  cs.primary.withValues(alpha: 0.10),
                  cs.primary.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppTheme.space8),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppTheme.radius3xl),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            boxShadow: AppTheme.elevatedShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: tt.displayMedium?.copyWith(height: 0.9),
                  children: [
                    const TextSpan(text: 'FIND YOUR\n'),
                    TextSpan(
                      text: 'FLAVOR',
                      style: TextStyle(color: cs.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.space8),

              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                  boxShadow: AppTheme.ambientShadow,
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Icon(
                        LucideIcons.search,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) =>
                            setState(() => _query = value.trim()),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search venues...',
                          border: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          hintStyle: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.30),
                            fontWeight: FontWeight.w700,
                          ),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    LucideIcons.x,
                                    size: 18,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => FocusScope.of(context).unfocus(),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'GO',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedSection(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
    List<Venue> activeVenues,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.space6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Featured', style: tt.headlineLarge),
              TextButton.icon(
                onPressed: () => context.pushNamed(AppRouteNames.venuesBrowse),
                icon: Text(
                  'VIEW ALL',
                  style: tt.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                label: Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.space4),

        SizedBox(
          height: 360,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space6),
            itemCount: activeVenues.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppTheme.space6),
            itemBuilder: (context, index) {
              return _FeaturedVenueCard(venue: activeVenues[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomCta(BuildContext context, ColorScheme cs, TextTheme tt) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
      ),
      child: Column(
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: tt.headlineLarge,
              children: [
                const TextSpan(text: 'STILL LOOKING FOR THE\n'),
                TextSpan(
                  text: 'PERFECT SPOT?',
                  style: TextStyle(color: cs.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space6),
          ElevatedButton.icon(
            onPressed: () => context.pushNamed(AppRouteNames.venuesBrowse),
            icon: const Text('BROWSE ALL'),
            label: const Icon(LucideIcons.chevronRight, size: 18),
          ),
        ],
      ),
    );
  }
}

// ─── Featured Venue Card (large, image-based) ───
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
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
          boxShadow: AppTheme.clayShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
          child: Stack(
            children: [
              // Full-bleed venue image with gradient overlay
              Positioned.fill(
                child: DineInImage(
                  imageUrl: venue.imageUrl,
                  fit: BoxFit.cover,
                  showGradientOverlay: true,
                ),
              ),
              // Content overlay at bottom
              Positioned(
                bottom: 24,
                left: 24,
                right: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      venue.name,
                      style: tt.headlineMedium?.copyWith(
                        color: Colors.white,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(LucideIcons.star, size: 16, color: cs.primary),
                        const SizedBox(width: 6),
                        Text(
                          '${venue.rating}',
                          style: tt.labelMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
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

// ─── Venue List Tile (compact row) ───
class _VenueListTile extends StatelessWidget {
  final Venue venue;

  const _VenueListTile({required this.venue});

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
        padding: const EdgeInsets.all(AppTheme.space5),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            // Venue thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              child: SizedBox(
                width: 80,
                height: 80,
                child: DineInImage(
                  imageUrl: venue.imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.space5),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venue.name,
                    style: tt.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.clock,
                        size: 14,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        venue.isOpen ? 'Open Now' : 'Closed',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Chevron
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
