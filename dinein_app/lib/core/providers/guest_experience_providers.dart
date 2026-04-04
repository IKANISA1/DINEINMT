import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:db_pkg/models/guest_venue_feed.dart';
import 'package:db_pkg/models/models.dart';
import '../services/venue_repository.dart';
import 'menu_providers.dart';
import 'venue_providers.dart';

class GuestMenuRequest {
  final String? venueId;
  final String? venueSlug;

  const GuestMenuRequest({this.venueId, this.venueSlug})
    : assert(venueId != null || venueSlug != null);

  @override
  bool operator ==(Object other) {
    return other is GuestMenuRequest &&
        other.venueId == venueId &&
        other.venueSlug == venueSlug;
  }

  @override
  int get hashCode => Object.hash(venueId, venueSlug);
}

class GuestMenuBundle {
  final Venue? venue;
  final List<MenuItem> items;

  const GuestMenuBundle({required this.venue, required this.items});

  @override
  bool operator ==(Object other) {
    return other is GuestMenuBundle &&
        other.venue == venue &&
        _listsEqual(other.items, items);
  }

  @override
  int get hashCode => Object.hash(venue, Object.hashAll(items));
}

bool _listsEqual<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

final guestVenueFeedProvider =
    FutureProvider.family<GuestVenueFeed, GuestVenueQuery>((ref, query) async {
      return VenueRepository.instance.getVenueFeed(
        limit: query.limit,
        offset: query.offset,
        query: query.query,
        category: query.category,
        orderingOnly: query.orderingOnly,
        latitude: query.latitude,
        longitude: query.longitude,
      );
    });

final guestMenuBundleProvider =
    FutureProvider.family<GuestMenuBundle, GuestMenuRequest>((
      ref,
      request,
    ) async {
      if (request.venueId != null) {
        final venueId = request.venueId!;
        final items = await ref.watch(menuItemsProvider(venueId).future);
        Venue? venue;
        try {
          venue = await ref.watch(venueByIdProvider(venueId).future);
        } catch (_) {
          venue = null;
        }

        venue ??= Venue(
          id: venueId,
          name: 'Menu',
          slug: venueId,
          category: 'Restaurant',
          description: '',
          address: '',
        );
        return GuestMenuBundle(venue: venue, items: items);
      }

      final venue = await ref.watch(
        venueBySlugProvider(request.venueSlug!).future,
      );
      if (venue == null) {
        return const GuestMenuBundle(venue: null, items: <MenuItem>[]);
      }
      final items = await ref.watch(menuItemsProvider(venue.id).future);
      return GuestMenuBundle(venue: venue, items: items);
    });
