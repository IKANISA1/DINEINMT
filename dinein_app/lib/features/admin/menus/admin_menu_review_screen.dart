import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';

/// Admin menu review — review menus submitted by venues.
/// Accepts a [venueId] and displays real menu items from Supabase.
class AdminMenuReviewScreen extends ConsumerWidget {
  final String venueId;

  const AdminMenuReviewScreen({super.key, required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final venueAsync = ref.watch(venueByIdProvider(venueId));
    final menuAsync = ref.watch(menuItemsProvider(venueId));

    final venueName = venueAsync.whenOrNull(data: (v) => v?.name) ?? 'Venue';

    return Scaffold(
      appBar: AppBar(
        title: Text('Menu Review — $venueName', style: tt.headlineMedium),
      ),
      body: menuAsync.when(
        loading: () => const Center(
          child: SkeletonLoader(width: double.infinity, height: 300),
        ),
        error: (_, _) => ErrorState(
          message: 'Could not load menu items.',
          onRetry: () => ref.invalidate(menuItemsProvider(venueId)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: LucideIcons.fileText,
              title: 'No menu items to review',
              subtitle: 'This venue has no menu items yet.',
            );
          }

          // Group by category
          final categories = <String, List<MenuItem>>{};
          for (final item in items) {
            categories.putIfAbsent(item.category, () => []).add(item);
          }

          return ListView(
            padding: const EdgeInsets.all(AppTheme.space6),
            children: categories.entries.expand((entry) {
              final category = entry.key;
              final categoryItems = entry.value;

              return [
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppTheme.space4,
                    bottom: AppTheme.space2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        category.toUpperCase(),
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          letterSpacing: 3,
                        ),
                      ),
                      Text(
                        '${categoryItems.length} items',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                ...categoryItems.asMap().entries.map((itemEntry) {
                  final item = itemEntry.value;
                  final idx = itemEntry.key;

                  return ClayCard(
                    padding: const EdgeInsets.all(AppTheme.space5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMd,
                              ),
                              child: DineInImage(
                                imageUrl: item.imageUrl,
                                width: 48,
                                height: 48,
                                fallbackIcon: LucideIcons.chefHat,
                              ),
                            ),
                            const SizedBox(width: AppTheme.space3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, style: tt.titleSmall),
                                  Text(
                                    '${item.price.toStringAsFixed(2)} • ${item.isAvailable ? "Available" : "Unavailable"}',
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(
                              label: item.isAvailable ? 'Active' : 'Hidden',
                              color: (item.isAvailable
                                      ? cs.secondary
                                      : cs.error)
                                  .withValues(alpha: 0.12),
                              textColor:
                                  item.isAvailable ? cs.secondary : cs.error,
                            ),
                          ],
                        ),
                        if (item.description.isNotEmpty) ...[
                          const SizedBox(height: AppTheme.space2),
                          Text(
                            item.description,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  )
                      .animate(delay: (80 * idx).ms)
                      .fadeIn(duration: 300.ms);
                }),
              ];
            }).toList(),
          );
        },
      ),
    );
  }
}
