import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';

class VenueMenuHighlights extends ConsumerWidget {
  final Venue venue;
  final VoidCallback onOpenMenu;

  const VenueMenuHighlights({
    super.key,
    required this.venue,
    required this.onOpenMenu,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final menuAsync = ref.watch(enrichedMenuItemsProvider(venue.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GuestSectionHeader(
          title: 'Menu highlights',
          subtitle: 'A few strong picks',
          actionLabel: 'Full menu',
          onAction: onOpenMenu,
        ),
        const SizedBox(height: AppTheme.space4),
        menuAsync.when(
          loading: () => Column(
            children: List.generate(
              3,
              (_) => const Padding(
                padding: EdgeInsets.only(bottom: AppTheme.space4),
                child: SkeletonLoader(width: double.infinity, height: 148),
              ),
            ),
          ),
          error: (error, stackTrace) => const SizedBox.shrink(),
          data: (items) {
            final highlights = resolveVenueHighlights(items);
            if (highlights.isEmpty) return const SizedBox.shrink();

            return Column(
              children: highlights.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.space4),
                  child: GuestSurfaceCard(
                    onTap: () => context.pushNamed(
                      AppRouteNames.itemDetail,
                      pathParameters: {AppRouteParams.id: item.id},
                      extra: item,
                    ),
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
                            height: 164,
                            width: double.infinity,
                            child: DineInImage(
                              imageUrl: item.imageUrl,
                              fit: BoxFit.cover,
                              fallbackIcon: LucideIcons.chefHat,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(AppTheme.space4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: tt.titleLarge,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (item.description.trim().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        item.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: tt.bodySmall?.copyWith(
                                          color: cs.onSurfaceVariant.withValues(
                                            alpha: 0.8,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppTheme.space4),
                              GuestMetaPill(
                                label: venue.country.formatPrice(item.price),
                                emphasized: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

List<MenuItem> resolveVenueHighlights(List<MenuItem> items) {
  final availableItems = items.where((item) => item.isAvailable).toList();
  if (availableItems.isEmpty) return const [];

  final selectedItems =
      availableItems.where((item) => item.highlightRank != null).toList()
        ..sort((a, b) {
          final aRank = a.highlightRank ?? 99;
          final bRank = b.highlightRank ?? 99;
          return aRank.compareTo(bRank);
        });

  final highlights = <MenuItem>[];
  final seenIds = <String>{};

  for (final item in selectedItems) {
    if (seenIds.add(item.id)) {
      highlights.add(item);
    }
    if (highlights.length == 3) return highlights;
  }

  for (final item in availableItems) {
    if (seenIds.add(item.id)) {
      highlights.add(item);
    }
    if (highlights.length == 3) break;
  }

  return highlights;
}
