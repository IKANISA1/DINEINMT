import '../models/models.dart';
import '../models/onboarding_draft_models.dart';
import 'auth_repository.dart';
import 'dinein_api_service.dart';

class OnboardingVenueSearchBlock {
  final String name;
  final String reason;

  const OnboardingVenueSearchBlock({required this.name, required this.reason});
}

class OnboardingVenueSearchResult {
  final List<Venue> venues;
  final OnboardingVenueSearchBlock? blockedMatch;

  const OnboardingVenueSearchResult({required this.venues, this.blockedMatch});
}

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

  /// Fetch active venues that are not yet claimed by an owner.
  ///
  /// Used by venue onboarding so search and featured results only surface
  /// claimable venues from Supabase.
  Future<List<Venue>> getClaimableVenues({
    int? limit,
    int? offset,
    String? query,
  }) async {
    final normalizedQuery = query?.trim();
    final payload = <String, dynamic>{
      'limit': ?limit,
      'offset': ?offset,
      'query': ?(normalizedQuery != null && normalizedQuery.isNotEmpty
          ? normalizedQuery
          : null),
    };
    final data =
        await DineinApiService.invoke('get_claimable_venues', payload: payload)
            as List<dynamic>;
    return data.map((e) => Venue.fromJson(e)).toList();
  }

  Future<OnboardingVenueSearchResult> searchOnboardingVenues(
    String query, {
    int limit = 10,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const OnboardingVenueSearchResult(venues: []);
    }

    final data =
        await DineinApiService.invoke(
              'search_onboarding_venues',
              payload: {'query': normalizedQuery, 'limit': limit},
            )
            as Map<String, dynamic>;

    final venues = ((data['results'] as List?) ?? const [])
        .map((e) => Venue.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final blockedRaw = data['blockedMatch'];
    final blockedMatch = blockedRaw is Map
        ? OnboardingVenueSearchBlock(
            name: blockedRaw['name'] as String? ?? '',
            reason: blockedRaw['reason'] as String? ?? '',
          )
        : null;

    return OnboardingVenueSearchResult(
      venues: venues,
      blockedMatch: blockedMatch,
    );
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

  /// Create a pending venue record for claim onboarding flows.
  Future<Venue> createPendingClaimVenue(ClaimedVenueDraft draft) async {
    final data = await DineinApiService.invoke(
      'create_pending_claim_venue',
      payload: {
        'draft': {
          'name': draft.name,
          'slug': _slugify(draft.name),
          'category': draft.category,
          'description': draft.description,
          'address': draft.address,
          'image_url': draft.imageUrl,
          'contact_phone': draft.contactPhone,
          'website_url': draft.websiteUrl,
        },
        if (draft.contactPhone != null) 'contactPhone': draft.contactPhone,
        if (draft.contactEmail != null) 'email': draft.contactEmail,
      },
    );
    return Venue.fromJson(data as Map<String, dynamic>);
  }

  /// Update the operational status of a venue (admin action).
  Future<void> updateVenueStatus(String venueId, String status) async {
    await DineinApiService.invoke(
      'update_venue',
      useAdminSession: true,
      payload: {
        'venueId': venueId,
        'updates': {'status': status},
        ..._venueSessionPayload(),
      },
    );
  }

  /// Update whether the venue can accept guest orders.
  Future<void> updateVenueOrderingEnabled(
    String venueId,
    bool orderingEnabled,
  ) async {
    await DineinApiService.invoke(
      'update_venue',
      useAdminSession: true,
      payload: {
        'venueId': venueId,
        'updates': {'ordering_enabled': orderingEnabled},
        ..._venueSessionPayload(),
      },
    );
  }

  /// Soft-delete a venue by setting its status to 'deleted'.
  Future<void> deleteVenue(String venueId) async {
    await updateVenueStatus(venueId, 'deleted');
  }

  /// Search for venues on Google Maps through the backend-only grounded path.
  Future<List<Map<String, dynamic>>> searchGoogleMaps(String query) async {
    final data = await DineinApiService.invoke(
      'search_google_maps',
      payload: {'query': query, 'country': 'Malta'},
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

  String _slugify(String value) {
    final base = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (base.isNotEmpty) return base;
    return 'venue-${DateTime.now().millisecondsSinceEpoch}';
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
