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

/// Menu items for a given venue in the admin console.
final adminMenuItemsProvider = FutureProvider.family<List<MenuItem>, String>((
  ref,
  venueId,
) async {
  try {
    return await MenuRepository.instance.getMenuItems(
      venueId,
      useAdminSession: true,
    );
  } catch (_) {
    final localItems = await MenuRepository.instance.getLocalMenuItems(venueId);
    if (localItems.isNotEmpty) return localItems;
    rethrow;
  }
});

/// Admin queue summarizing venues with menu items that need review.
final adminMenuQueueProvider = FutureProvider<List<AdminMenuQueueEntry>>((
  ref,
) async {
  return await MenuRepository.instance.getAdminMenuQueue();
});

/// Admin catalog of centrally managed menu items assigned across venues.
final adminMenuCatalogProvider = FutureProvider<List<AdminMenuCatalogEntry>>((
  ref,
) async {
  return await MenuRepository.instance.getAdminMenuCatalog();
});

/// Venue assignments for a centrally managed admin menu group.
final adminMenuGroupAssignmentsProvider =
    FutureProvider.family<List<AdminMenuGroupAssignment>, String>((
      ref,
      groupId,
    ) async {
      return await MenuRepository.instance.getAdminMenuGroupAssignments(
        groupId,
      );
    });
