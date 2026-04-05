import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';

class VenueMenuHighlights extends ConsumerWidget {
  final Venue venue;
  final VoidCallback onOpenMenu;

  const VenueMenuHighlights({super.key, required this.venue, required this.onOpenMenu});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final menuAsync = ref.watch(enrichedMenuItemsProvider(venue.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(child: Text('Highlights', style: tt.headlineLarge)),
              PressableScale(
                onTap: onOpenMenu,
                semanticLabel: 'See all menu items',
                child: ConstrainedBox(
                  key: const ValueKey('venue-detail-see-all-action'),
                  constraints: const BoxConstraints(
                    minWidth: 96,
                    minHeight: 48,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'SEE ALL',
                          style: TextStyle(
                            color: cs.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          LucideIcons.arrowRight,
                          size: 16,
                          color: cs.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.space6),
        menuAsync.when(
          loading: () => Column(
            children: List.generate(
              3,
              (_) => const Padding(
                padding: EdgeInsets.only(bottom: AppTheme.space6),
                child: SkeletonLoader(width: double.infinity, height: 180),
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
                  padding: const EdgeInsets.only(bottom: AppTheme.space6),
                  child: PressableScale(
                    onTap: () => context.pushNamed(
                      AppRouteNames.itemDetail,
                      pathParameters: {AppRouteParams.id: item.id},
                      extra: item,
                    ),
                    semanticLabel: 'View ${item.name}',
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: AppColors.white10),
                          boxShadow: AppTheme.ambientShadow,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            DineInImage(
                              imageUrl: item.imageUrl,
                              fit: BoxFit.cover,
                              fallbackIcon: LucideIcons.chefHat,
                            ),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.18),
                                      Colors.black.withValues(alpha: 0.92),
                                    ],
                                    stops: const [0.0, 0.45, 1.0],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 24,
                              right: 24,
                              bottom: 24,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: tt.headlineSmall?.copyWith(
                                      color: Colors.white,
                                      letterSpacing: -0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${venue.country.currencySymbol}${item.price.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: cs.primary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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
    if (highlights.length == 3) {
      return highlights;
    }
  }

  for (final item in availableItems) {
    if (seenIds.add(item.id)) {
      highlights.add(item);
    }
    if (highlights.length == 3) {
      break;
    }
  }

  return highlights;
}

