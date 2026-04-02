import '../models/models.dart';
import 'auth_repository.dart';
import 'dinein_api_service.dart';

/// Repository for venue data access via Supabase.
class VenueRepository {
  VenueRepository._();
  static final instance = VenueRepository._();

  Map<String, dynamic> _venueSessionPayload() {
    final session = AuthRepository.instance.currentVenueSession;
    if (session == null || session.accessToken.isEmpty) return const {};
    return {
      'venue_session': {'access_token': session.accessToken},
    };
  }

  /// Fetch all guest-visible venues for discovery.
  ///
  /// Use [limit] and [offset] for pagination. Omit both to fetch all.
  Future<List<Venue>> getVenues({int? limit, int? offset}) async {
    final payload = <String, dynamic>{'limit': ?limit, 'offset': ?offset};
    final data =
        await DineinApiService.invoke('get_venues', payload: payload)
            as List<dynamic>;
    return data.map((e) => Venue.fromJson(e)).toList();
  }

  /// Fetch all venues (admin view — includes inactive and pending).
  ///
  /// Use [limit] and [offset] for pagination. Omit both to fetch all.
  Future<List<Venue>> getAllVenues({int? limit, int? offset}) async {
    final payload = <String, dynamic>{'limit': ?limit, 'offset': ?offset};
    final data =
        await DineinApiService.invoke(
              'get_all_venues',
              useAdminSession: true,
              payload: payload,
            )
            as List<dynamic>;
    return data.map((e) => Venue.fromJson(e)).toList();
  }

  /// Fetch a single venue by slug (for deep link resolution).
  Future<Venue?> getVenueBySlug(String slug) async {
    final data = await DineinApiService.invoke(
      'get_venue_by_slug',
      payload: {'slug': slug, ..._venueSessionPayload()},
    );
    return data != null ? Venue.fromJson(data) : null;
  }

  /// Fetch a single venue by ID.
  Future<Venue?> getVenueById(String id) async {
    final data = await DineinApiService.invoke(
      'get_venue_by_id',
      payload: {'venueId': id, ..._venueSessionPayload()},
    );
    return data != null ? Venue.fromJson(data) : null;
  }

  /// Fetch the venue owned by a given user ID.
  Future<Venue?> getVenueForOwner(String ownerId) async {
    final data = await DineinApiService.invoke(
      'get_venue_for_owner',
      payload: {'ownerId': ownerId},
    );
    return data != null ? Venue.fromJson(data) : null;
  }

  /// Update venue info (for venue owner).
  Future<void> updateVenue(String id, Map<String, dynamic> updates) async {
    await DineinApiService.invoke(
      'update_venue',
      payload: {'venueId': id, 'updates': updates, ..._venueSessionPayload()},
    );
  }

  Future<void> updateVenueAsAdmin(
    String venueId,
    Map<String, dynamic> updates,
  ) async {
    await DineinApiService.invoke(
      'update_venue',
      useAdminSession: true,
      payload: {
        'venueId': venueId,
        'updates': updates,
        ..._venueSessionPayload(),
      },
    );
  }

  /// Update the operational status of a venue (admin action).
  Future<void> updateVenueStatus(String venueId, String status) async {
    await updateVenueAsAdmin(venueId, {'status': status});
  }

  /// Update whether the venue can accept guest orders.
  Future<void> updateVenueOrderingEnabled(
    String venueId,
    bool orderingEnabled,
  ) async {
    await updateVenueAsAdmin(venueId, {'ordering_enabled': orderingEnabled});
  }

  /// Soft-delete a venue by setting its status to 'deleted'.
  Future<void> deleteVenue(String venueId) async {
    await updateVenueStatus(venueId, 'deleted');
  }

  /// Search for venues on Google Maps through the backend-only grounded path.
  Future<List<Map<String, dynamic>>> searchGoogleMaps(String query) async {
    final data = await DineinApiService.invoke(
      'search_google_maps',
      payload: {'query': query},
    );
    return _normalizeGoogleResults(data);
  }

  /// Refresh Gemini Google Maps-grounded plus Gemini Search-grounded profile data.
  Future<Map<String, dynamic>> enrichVenueProfile(
    String venueId, {
    bool overwriteExisting = false,
    bool forcePlaceRefresh = false,
    bool skipSearchGrounding = false,
    bool useAdminSession = false,
  }) async {
    final data = await DineinApiService.invoke(
      'enrich_venue_profile',
      useAdminSession: useAdminSession,
      payload: {
        'venueId': venueId,
        'overwriteExisting': overwriteExisting,
        'forcePlaceRefresh': forcePlaceRefresh,
        'skipSearchGrounding': skipSearchGrounding,
        ..._venueSessionPayload(),
      },
    );
    return (data as Map<String, dynamic>?) ?? const {};
  }

  /// Batch-fill venue profile gaps from grounded Maps data and grounded web search.
  Future<Map<String, dynamic>> backfillVenueProfiles({
    String? venueId,
    int limit = 5,
    bool overwriteExisting = false,
    bool forcePlaceRefresh = false,
    bool skipSearchGrounding = false,
    bool useAdminSession = false,
  }) async {
    final data = await DineinApiService.invoke(
      'backfill_venue_profiles',
      useAdminSession: useAdminSession,
      payload: {
        ...(venueId == null ? const {} : {'venueId': venueId}),
        'limit': limit,
        'overwriteExisting': overwriteExisting,
        'forcePlaceRefresh': forcePlaceRefresh,
        'skipSearchGrounding': skipSearchGrounding,
        ..._venueSessionPayload(),
      },
    );
    return (data as Map<String, dynamic>?) ?? const {};
  }

  List<Map<String, dynamic>> _normalizeGoogleResults(dynamic data) {
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (data is Map && data.containsKey('results')) {
      final results = data['results'] as List<dynamic>? ?? [];
      return results.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }
}
