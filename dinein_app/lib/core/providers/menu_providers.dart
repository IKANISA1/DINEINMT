import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/menu_repository.dart';

/// Menu items for a given venue.
final menuItemsProvider = FutureProvider.family<List<MenuItem>, String>((
  ref,
  venueId,
) async {
  final localItems = await MenuRepository.instance.getLocalMenuItems(venueId);

  try {
    final remoteItems = await MenuRepository.instance.getMenuItems(venueId);
    return _mergeMenuItems(remoteItems, localItems);
  } catch (_) {
    if (localItems.isNotEmpty) {
      return localItems;
    }
    rethrow;
  }
});

List<MenuItem> _mergeMenuItems(
  List<MenuItem> primary,
  List<MenuItem> secondary,
) {
  final merged = <String, MenuItem>{};
  for (final item in [...primary, ...secondary]) {
    merged[item.id] = item;
  }

  return merged.values.toList()
    ..sort((left, right) => left.category.compareTo(right.category));
}
