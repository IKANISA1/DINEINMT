import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/services/venue_repository.dart';
import '../../../shared/widgets/shared_widgets.dart';

/// Admin venue detail screen with activation/deactivation controls.
/// Matches React admin/VenueDetail.tsx.
class AdminVenueDetailScreen extends ConsumerWidget {
  final String venueId;

  const AdminVenueDetailScreen({super.key, required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final venueAsync = ref.watch(venueByIdProvider(venueId));

    return Scaffold(
      body: venueAsync.when(
        loading: () => const Center(
          child: SkeletonLoader(width: double.infinity, height: 200),
        ),
        error: (err, _) => ErrorState(
          message: 'Could not load venue.',
          onRetry: () => ref.invalidate(venueByIdProvider(venueId)),
        ),
        data: (venue) {
          if (venue == null) {
            return Center(child: Text('Venue not found', style: tt.bodyLarge));
          }
          return _buildContent(context, ref, cs, tt, venue);
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ColorScheme cs,
    TextTheme tt,
    Venue venue,
  ) {
    return CustomScrollView(
      slivers: [
        // ─── Header ───
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.space8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(color: AppColors.white5),
                      ),
                      child: const Icon(LucideIcons.chevronLeft, size: 28),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ADMIN · VENUE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            color: cs.primary,
                          ),
                        ),
                        Text(
                          venue.name,
                          style: tt.headlineMedium?.copyWith(height: 1),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ─── Info Card ───
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space8),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.space10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppTheme.radius3xl),
                border: Border.all(color: AppColors.white5),
                boxShadow: AppTheme.clayShadow,
              ),
              child: Column(
                children: [
                  _infoRow(tt, cs, 'Category', venue.category),
                  const SizedBox(height: AppTheme.space4),
                  Container(height: 1, color: AppColors.white5),
                  const SizedBox(height: AppTheme.space4),
                  _infoRow(tt, cs, 'Address', venue.address),
                  const SizedBox(height: AppTheme.space4),
                  Container(height: 1, color: AppColors.white5),
                  const SizedBox(height: AppTheme.space4),
                  _infoRow(
                    tt,
                    cs,
                    'Rating',
                    '${venue.rating} (${venue.ratingCount} reviews)',
                  ),
                  const SizedBox(height: AppTheme.space4),
                  Container(height: 1, color: AppColors.white5),
                  const SizedBox(height: AppTheme.space4),
                  _infoRow(tt, cs, 'Status', venue.status.label),
                  const SizedBox(height: AppTheme.space4),
                  Container(height: 1, color: AppColors.white5),
                  const SizedBox(height: AppTheme.space4),
                  _infoRow(tt, cs, 'Country', venue.country.label),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
          ),
        ),

        // ─── Admin Actions ───
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ADMIN ACTIONS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.60),
                  ),
                ),
                const SizedBox(height: AppTheme.space4),

                // Toggle activation
                Container(
                  padding: const EdgeInsets.all(AppTheme.space6),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                    border: Border.all(color: AppColors.white5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Venue Activation',
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            venue.isOpen
                                ? 'Venue is live and active'
                                : 'Venue is deactivated',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: venue.isOpen ? cs.secondary : cs.error,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: venue.isOpen,
                        onChanged: (_) async {
                          final newStatus = venue.isOpen
                              ? 'inactive'
                              : 'active';
                          try {
                            await VenueRepository.instance.updateVenueStatus(
                              venue.id,
                              newStatus,
                            );
                            ref.invalidate(allVenuesProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Venue ${venue.isOpen ? 'deactivated' : 'activated'}',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Update failed: $e')),
                              );
                            }
                          }
                        },
                        activeThumbColor: cs.secondary,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.space4),

                Container(
                  padding: const EdgeInsets.all(AppTheme.space6),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                    border: Border.all(color: AppColors.white5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Guest Ordering Validation',
                              style: tt.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              venue.orderingEnabled
                                  ? 'Guests can place orders for this venue'
                                  : 'Guests can browse only until validation is complete',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                color: venue.orderingEnabled
                                    ? cs.secondary
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: venue.orderingEnabled,
                        onChanged: (_) async {
                          try {
                            await VenueRepository.instance
                                .updateVenueOrderingEnabled(
                                  venue.id,
                                  !venue.orderingEnabled,
                                );
                            ref.invalidate(allVenuesProvider);
                            ref.invalidate(venueByIdProvider(venue.id));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    venue.orderingEnabled
                                        ? 'Guest ordering disabled'
                                        : 'Guest ordering enabled',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Update failed: $e')),
                              );
                            }
                          }
                        },
                        activeThumbColor: cs.secondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.space12)),
      ],
    );
  }

  Widget _infoRow(TextTheme tt, ColorScheme cs, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: cs.onSurfaceVariant.withValues(alpha: 0.60),
          ),
        ),
        Text(
          value,
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
