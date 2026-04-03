import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
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
