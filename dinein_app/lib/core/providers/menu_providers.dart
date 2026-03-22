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
