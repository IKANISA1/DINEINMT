import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/enums.dart';
import '../../../core/providers/providers.dart';
import '../../../shared/widgets/shared_widgets.dart';

/// Admin venues management — matches React admin/Venues.tsx exactly.
///
/// Features: search bar, Active/Suspended tabs, venue cards with images,
/// category/location badges, operational status, chevron navigation.
class AdminVenuesScreen extends ConsumerStatefulWidget {
  const AdminVenuesScreen({super.key});

  @override
  ConsumerState<AdminVenuesScreen> createState() => _AdminVenuesScreenState();
}

class _AdminVenuesScreenState extends ConsumerState<AdminVenuesScreen> {
  String _activeTab = 'active';
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final venuesAsync = ref.watch(allVenuesProvider);

    return Scaffold(
      body: venuesAsync.when(
        loading: () => const Center(
          child: SkeletonLoader(width: double.infinity, height: 300),
        ),
        error: (_, _) => ErrorState(
          message: 'Could not load venues.',
          onRetry: () => ref.invalidate(allVenuesProvider),
        ),
        data: (venues) {
          // Filter by search
          final filtered = _query.isEmpty
              ? venues
              : venues.where((v) {
                  final q = _query.toLowerCase();
                  return v.name.toLowerCase().contains(q) ||
                      v.id.toLowerCase().contains(q) ||
                      v.category.toLowerCase().contains(q);
                }).toList();

          // Tab filtering
          final activeVenues = filtered
              .where((v) => v.status == VenueStatus.active)
              .toList();
          final suspendedVenues = filtered
              .where((v) => v.status != VenueStatus.active)
              .toList();
          final displayVenues = _activeTab == 'active'
              ? activeVenues
              : suspendedVenues;

          return CustomScrollView(
            slivers: [
              // ─── Header ───
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Venues',
                                style: tt.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Manage and verify venue partners.',
                                style: tt.bodyLarge?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          PressableScale(
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                                boxShadow: AppTheme.clayShadow,
                              ),
                              child: Icon(
                                LucideIcons.filter,
                                size: 20,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.40,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.space6),

                      // ─── Search ───
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusXxl,
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                          boxShadow: AppTheme.clayShadow,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.search,
                              size: 20,
                              color: cs.onSurface.withValues(alpha: 0.10),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (v) =>
                                    setState(() => _query = v.trim()),
                                style: tt.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Search venues by name or ID...',
                                  border: InputBorder.none,
                                  filled: false,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  hintStyle: tt.titleSmall?.copyWith(
                                    color: cs.onSurface.withValues(alpha: 0.05),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.space6),

                      // ─── Tabs ───
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(48),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Row(
                          children: [
                            _buildTab(
                              'active',
                              'Active',
                              activeVenues.length,
                              cs,
                              tt,
                            ),
                            const SizedBox(width: 8),
                            _buildTab(
                              'suspended',
                              'Suspended',
                              suspendedVenues.length,
                              cs,
                              tt,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.space6),
                    ],
                  ),
                ),
              ),

              // ─── Venue List ───
              if (displayVenues.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: LucideIcons.store,
                    title: _activeTab == 'active'
                        ? 'No active venues'
                        : 'No suspended venues',
                    subtitle: 'Venues matching your filter will appear here.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space6,
                  ),
                  sliver: SliverList.separated(
                    itemCount: displayVenues.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppTheme.space4),
                    itemBuilder: (context, index) {
                      final venue = displayVenues[index];
                      return _VenueCard(venue: venue)
                          .animate(delay: (index * 50).ms)
                          .fadeIn(duration: 300.ms)
                          .slideY(begin: 0.05, end: 0);
                    },
                  ),
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: AppTheme.space24),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTab(
    String id,
    String label,
    int count,
    ColorScheme cs,
    TextTheme tt,
  ) {
    final isActive = _activeTab == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(40),
            boxShadow: isActive ? AppTheme.clayShadow : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  color: isActive
                      ? cs.onPrimary
                      : cs.onSurface.withValues(alpha: 0.20),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive
                      ? cs.onPrimary.withValues(alpha: 0.20)
                      : cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: isActive
                        ? cs.onPrimary
                        : cs.onSurface.withValues(alpha: 0.10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Venue card matching React admin venue list item —
/// image, name, location, category, operational badge, chevron.
class _VenueCard extends StatelessWidget {
  final dynamic venue;

  const _VenueCard({required this.venue});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final isActive = venue.status == VenueStatus.active;

    return PressableScale(
      onTap: () => context.pushNamed(
        AppRouteNames.adminVenueDetail,
        pathParameters: {AppRouteParams.id: venue.id},
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space5),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(48),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: AppTheme.clayShadow,
        ),
        child: Row(
          children: [
            // Venue image
            ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: SizedBox(
                width: 72,
                height: 72,
                child: DineInImage(
                  imageUrl: venue.imageUrl,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.space4),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          venue.name,
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isActive)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            LucideIcons.checkCircle2,
                            size: 16,
                            color: AppColors.secondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.mapPin,
                        size: 12,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.30),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        venue.address,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.30),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.20),
                          ),
                        ),
                      ),
                      Text(
                        venue.category,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.30),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.space3),

            // Status + chevron
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (isActive ? AppColors.secondary : cs.onSurfaceVariant)
                            .withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive ? 'OPERATIONAL' : 'SUSPENDED',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: isActive
                          ? AppColors.secondary
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    LucideIcons.chevronRight,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
