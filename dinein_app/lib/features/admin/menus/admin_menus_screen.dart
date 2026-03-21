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
import '../../../core/models/models.dart';
import '../../../shared/widgets/shared_widgets.dart';

/// Admin Menus screen — list of venue menu submissions for review.
///
/// Matches React `admin/Menus.tsx`:
/// - Header: "Menus" + subtitle + filter button
/// - Search bar (clay-styled)
/// - Stats: Pending Review + Approved Today (2-column grid)
/// - Approval Queue: list of menu submission cards
class AdminMenusScreen extends ConsumerStatefulWidget {
  const AdminMenusScreen({super.key});

  @override
  ConsumerState<AdminMenusScreen> createState() => _AdminMenusScreenState();
}

class _AdminMenusScreenState extends ConsumerState<AdminMenusScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _statusFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final filters = ['all', 'active', 'inactive', 'pending'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filter Menus',
                  style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('By venue status',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: filters.map((f) {
                  final selected = _statusFilter == f;
                  return ChoiceChip(
                    label: Text(f[0].toUpperCase() + f.substring(1)),
                    selected: selected,
                    onSelected: (_) {
                      setSheetState(() {});
                      setState(() => _statusFilter = f);
                      Navigator.of(ctx).pop();
                    },
                    selectedColor: cs.primary,
                    labelStyle: TextStyle(
                      color: selected ? cs.onPrimary : cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final venuesAsync = ref.watch(allVenuesProvider);

    return venuesAsync.when(
      loading: () => const Center(
        child: SkeletonLoader(width: double.infinity, height: 200),
      ),
      error: (err, _) {
        final msg = err.toString().replaceFirst('Exception: ', '');
        return ErrorState(
          message: msg.isNotEmpty ? msg : 'Failed to load menus. Try again.',
          onRetry: () => ref.invalidate(allVenuesProvider),
        );
      },
      data: (venues) => _buildContent(context, cs, tt, venues),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
    List<Venue> venues,
  ) {
    // Filter venues by search query.
    final filtered = _query.isEmpty
        ? venues
        : venues
              .where((v) => v.name.toLowerCase().contains(_query.toLowerCase()))
              .toList();

    return CustomScrollView(
      slivers: [
        // ─── Header ───
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space8,
              AppTheme.space8,
              AppTheme.space8,
              0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Menus',
                      style: tt.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Review and approve AI-extracted menu data.',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.40),
                      ),
                    ),
                  ],
                ),
                // Filter button
                PressableScale(
                  onTap: () => _showFilterSheet(context),
                  child: Container(
                    width: 56,
                    height: 56,
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
                      size: 24,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.40),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ─── Search Bar ───
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space8,
              AppTheme.space10,
              AppTheme.space8,
              0,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                boxShadow: AppTheme.clayShadow,
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Icon(
                      LucideIcons.search,
                      size: 24,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.20),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v.trim()),
                      decoration: InputDecoration(
                        hintText: 'Search menu submissions...',
                        border: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        hintStyle: tt.titleLarge?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.10),
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ─── Stats Grid ───
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space8,
              AppTheme.space12,
              AppTheme.space8,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Pending Review',
                    value:
                        '${venues.where((v) => v.status != VenueStatus.active).length}',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppTheme.space6),
                Expanded(
                  child: _StatCard(
                    label: 'Approved Today',
                    value:
                        '${venues.where((v) => v.status == VenueStatus.active).length}',
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ─── Approval Queue Header ───
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space8 + 16,
              AppTheme.space12,
              AppTheme.space8,
              AppTheme.space4,
            ),
            child: Text(
              'Approval Queue',
              style: tt.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),

        // ─── Menu Cards ───
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: LucideIcons.fileText,
              title: 'No menu submissions',
              subtitle: _query.isNotEmpty
                  ? 'Try a different search term.'
                  : 'Menu submissions will appear here.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space8,
              0,
              AppTheme.space8,
              AppTheme.space24,
            ),
            sliver: SliverList.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppTheme.space4),
              itemBuilder: (context, index) {
                final venue = filtered[index];
                return _MenuQueueCard(venue: venue)
                    .animate(delay: (100 * index).ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.05, end: 0);
              },
            ),
          ),
      ],
    );
  }
}

/// Stat card matching React's 2-column stats grid.
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.space8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(48),
        border: Border.all(color: color.withValues(alpha: 0.10)),
        boxShadow: AppTheme.clayShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              color: color,
            ),
          ),
          const SizedBox(height: AppTheme.space4),
          Text(
            value,
            style: tt.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Menu queue card matching React's approval queue items.
class _MenuQueueCard extends StatelessWidget {
  final Venue venue;

  const _MenuQueueCard({required this.venue});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final isParsed = venue.status == VenueStatus.active;
    final statusLabel = isParsed ? 'Parsed' : 'Review Required';

    return PressableScale(
      onTap: () => context.pushNamed(
        AppRouteNames.adminMenuReview,
        pathParameters: {AppRouteParams.id: venue.id},
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(48),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: AppTheme.clayShadow,
        ),
        child: Row(
          children: [
            // Venue image / icon overlay
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.clayShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    if (venue.imageUrl != null)
                      Positioned.fill(
                        child: DineInImage(
                          imageUrl: venue.imageUrl,
                          fit: BoxFit.cover,
                          width: 80,
                          height: 80,
                        ),
                      ),
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.50),
                      ),
                    ),
                    Center(
                      child: Icon(
                        LucideIcons.fileText,
                        size: 32,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.40),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppTheme.space8),

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
                          style: tt.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusLabel.toUpperCase(),
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Meta info row
                  Row(
                    children: [
                      Icon(
                        LucideIcons.sparkles,
                        size: 14,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.20),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${venue.category} • Menu review',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.clock,
                        size: 14,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.20),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        venue.address.isNotEmpty ? venue.address : 'No address',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Chevron
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                LucideIcons.chevronRight,
                size: 28,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
