import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';

import '../config/country_runtime.dart';
import '../models/models.dart';
import '../services/auth_repository.dart';
import '../services/discovery_location_service.dart';
import '../services/venue_repository.dart';
import 'auth_providers.dart';

const _venueBootstrapTimeout = Duration(seconds: 3);

String _fallbackVenueSlug(VenueAccessSession session) {
  final raw = (session.venueSlug ?? session.venueName).trim().toLowerCase();
  final normalized = raw
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (normalized.isNotEmpty) return normalized;
  return session.venueId;
}

class GuestVenueQuery extends Equatable {
  final int? limit;
  final int? offset;
  final String? query;
  final String? category;
  final bool orderingOnly;
  final double? latitude;
  final double? longitude;

  const GuestVenueQuery({
    this.limit,
    this.offset,
    this.query,
    this.category,
    this.orderingOnly = false,
    this.latitude,
    this.longitude,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  @override
  List<Object?> get props => [
    limit,
    offset,
    query,
    category,
    orderingOnly,
    latitude,
    longitude,
  ];
}

/// The venue owned by the currently authenticated user.
/// Used by VenueShell to display the venue name in the top bar.
final currentVenueProvider = FutureProvider<Venue?>((ref) async {
  await AuthRepository.instance.restoreVenueSession();
  final venueSession = AuthRepository.instance.currentVenueSession;
  if (venueSession != null) {
    try {
      final venue = await VenueRepository.instance
          .getVenueById(venueSession.venueId)
          .timeout(_venueBootstrapTimeout);
      if (venue != null) return venue;
    } catch (_) {
      // Fall back to the persisted venue session below.
    }

    return Venue(
      id: venueSession.venueId,
      name: venueSession.venueName,
      slug: _fallbackVenueSlug(venueSession),
      category: 'Restaurants',
      description: '',
      address: '',
      imageUrl: venueSession.venueImageUrl,
      country: CountryRuntime.config.country,
    );
  }

  final user = ref.watch(currentUserProvider);
  if (user != null) {
    try {
      final venue = await VenueRepository.instance
          .getVenueForOwner(user.id)
          .timeout(_venueBootstrapTimeout);
      if (venue != null) return venue;
    } catch (_) {
      // Fall through to draft fallback below.
    }
  }

  return null;
});

/// All active venues for the discover screen.
final venuesProvider = FutureProvider<List<Venue>>((ref) async {
  final discoveryLocation = ref.watch(discoveryLocationProvider).asData?.value;
  final query = GuestVenueQuery(
    latitude: discoveryLocation?.latitude,
    longitude: discoveryLocation?.longitude,
  );
  return await ref.watch(guestVenueQueryProvider(query).future);
});

/// Guest-visible venues queried through the backend discovery API.
final guestVenueQueryProvider =
    FutureProvider.family<List<Venue>, GuestVenueQuery>((ref, query) async {
      return await VenueRepository.instance.getVenues(
        limit: query.limit,
        offset: query.offset,
        query: query.query,
        category: query.category,
        orderingOnly: query.orderingOnly,
        latitude: query.latitude,
        longitude: query.longitude,
      );
    });

/// Single venue by slug (deep link resolution).
final venueBySlugProvider = FutureProvider.family<Venue?, String>((
  ref,
  slug,
) async {
  return await VenueRepository.instance.getVenueBySlug(slug);
});

/// Single venue by ID.
final venueByIdProvider = FutureProvider.family<Venue?, String>((
  ref,
  id,
) async {
  return await VenueRepository.instance.getVenueById(id);
});

/// All venues (admin view).
final allVenuesProvider = FutureProvider<List<Venue>>((ref) async {
  return await VenueRepository.instance.getAllVenues();
});
