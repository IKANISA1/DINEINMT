import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:db_pkg/models/models.dart';
import '../services/menu_repository.dart';

/// Menu items for a given venue.
final menuItemsProvider = FutureProvider.family<List<MenuItem>, String>((
  ref,
  venueId,
) async {
  try {
    return await MenuRepository.instance.getMenuItems(venueId);
  } catch (_) {
    final localItems = await MenuRepository.instance.getLocalMenuItems(venueId);
    if (localItems.isNotEmpty) return localItems;
    rethrow;
  }
});

/// Per-item order popularity for a venue (served orders, last 7 days).
/// Returns {menuItemId: totalQuantityOrdered}.
final menuItemPopularityProvider =
    FutureProvider.family<Map<String, int>, String>((ref, venueId) async {
      return await MenuRepository.instance.getVenueItemPopularity(venueId);
    });

/// Menu items enriched with real order-based popularity data.
/// Each item's `totalOrdered` is set from the popularity map.
final enrichedMenuItemsProvider =
    FutureProvider.family<List<MenuItem>, String>((ref, venueId) async {
      final items = await ref.watch(menuItemsProvider(venueId).future);
      final popularity = await ref.watch(
        menuItemPopularityProvider(venueId).future,
      );

      if (popularity.isEmpty) return items;

      return items
          .map(
            (item) => item.copyWith(
              totalOrdered: popularity[item.id] ?? 0,
            ),
          )
          .toList();
    });

final menuItemByIdProvider = FutureProvider.family<MenuItem?, String>((
  ref,
  itemId,
) async {
  return await MenuRepository.instance.getMenuItemById(itemId);
});

