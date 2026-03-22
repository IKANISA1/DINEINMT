import '../models/models.dart';
import 'google_places_service.dart';

typedef DiscoverPlacesSearch =
    Future<List<GooglePlaceCandidate>> Function(String query);

enum DiscoverAssistantSource { dineIn, googleMaps }

class DiscoverAssistantMatch {
  final String id;
  final String title;
  final String subtitle;
  final String? address;
  final String? imageUrl;
  final double rating;
  final int ratingCount;
  final String? phoneNumber;
  final String? websiteUrl;
  final String? venueSlug;
  final DiscoverAssistantSource source;

  const DiscoverAssistantMatch({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.source,
    this.address,
    this.imageUrl,
    this.rating = 0,
    this.ratingCount = 0,
    this.phoneNumber,
    this.websiteUrl,
    this.venueSlug,
  });

  bool get isBookableOnDineIn => source == DiscoverAssistantSource.dineIn;

  Uri? get googleMapsUri {
    if (source != DiscoverAssistantSource.googleMaps) return null;

    final query = [title, address].whereType<String>().join(' ').trim();
    if (query.isEmpty) return null;

    final parameters = <String, String>{'api': '1', 'query': query};

    if (id.trim().isNotEmpty) {
      parameters['query_place_id'] = id.trim();
    }

    return Uri.https('www.google.com', '/maps/search/', parameters);
  }

  Uri? get websiteUri {
    final raw = websiteUrl?.trim();
    if (raw == null || raw.isEmpty) return null;

    final parsed = Uri.tryParse(raw);
    if (parsed == null) return null;
    if (parsed.hasScheme) return parsed;

    return Uri.tryParse('https://$raw');
  }

  Uri? get phoneUri {
    final raw = phoneNumber?.trim();
    if (raw == null || raw.isEmpty) return null;

    final normalized = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (normalized.isEmpty) return null;

    return Uri(scheme: 'tel', path: normalized);
  }
}

class DiscoverAssistantResult {
  final String query;
  final String summary;
  final String provenanceNote;
  final List<DiscoverAssistantMatch> dineInMatches;
  final List<DiscoverAssistantMatch> googleMapsMatches;
  final bool googleMapsEnabled;
  final String? googleMapsError;

  const DiscoverAssistantResult({
    required this.query,
    required this.summary,
    required this.provenanceNote,
    required this.dineInMatches,
    required this.googleMapsMatches,
    required this.googleMapsEnabled,
    this.googleMapsError,
  });

  bool get hasResults =>
      dineInMatches.isNotEmpty || googleMapsMatches.isNotEmpty;
}

class DiscoverAssistantService {
  DiscoverAssistantService({
    DiscoverPlacesSearch? placesSearch,
    bool? googleMapsEnabled,
  }) : _placesSearch = placesSearch ?? GooglePlacesService.instance.search,
       _googleMapsEnabled =
           googleMapsEnabled ?? GooglePlacesService.instance.isConfigured;

  static final instance = DiscoverAssistantService();

  final DiscoverPlacesSearch _placesSearch;
  final bool _googleMapsEnabled;

  Future<DiscoverAssistantResult> explore({
    required String query,
    required List<Venue> venues,
  }) async {
    final cleanedQuery = query.trim();
    if (cleanedQuery.isEmpty) {
      throw ArgumentError('Query must not be empty.');
    }

    final dineInMatches = _buildLocalMatches(cleanedQuery, venues);

    var googleMapsError = null as String?;
    var googleMapsMatches = <DiscoverAssistantMatch>[];

    if (_googleMapsEnabled) {
      try {
        final references = await _placesSearch(_scopeGoogleQuery(cleanedQuery));
        final localNames = dineInMatches
            .map((match) => _normalize(match.title))
            .toSet();
        googleMapsMatches = references
            .where((place) => !localNames.contains(_normalize(place.name)))
            .take(3)
            .map(_mapGooglePlace)
            .toList(growable: false);
      } catch (_) {
        googleMapsError = 'Google Maps data is temporarily unavailable.';
      }
    }

    return DiscoverAssistantResult(
      query: cleanedQuery,
      summary: _buildSummary(
        query: cleanedQuery,
        dineInMatches: dineInMatches,
        googleMapsMatches: googleMapsMatches,
        googleMapsEnabled: _googleMapsEnabled,
      ),
      provenanceNote: _buildProvenanceNote(
        googleMapsEnabled: _googleMapsEnabled,
        googleMapsMatches: googleMapsMatches,
        googleMapsError: googleMapsError,
      ),
      dineInMatches: dineInMatches,
      googleMapsMatches: googleMapsMatches,
      googleMapsEnabled: _googleMapsEnabled,
      googleMapsError: googleMapsError,
    );
  }

  List<DiscoverAssistantMatch> _buildLocalMatches(
    String query,
    List<Venue> venues,
  ) {
    final activeVenues = venues
        .where((venue) => venue.isOpen)
        .toList(growable: false);
    final scored = activeVenues
        .map((venue) => _ScoredVenue(venue, _scoreVenue(venue, query)))
        .where((entry) => entry.score > 0)
        .toList();

    if (scored.isEmpty) {
      final fallback = [...activeVenues]
        ..sort((left, right) {
          final rating = right.rating.compareTo(left.rating);
          if (rating != 0) return rating;
          return left.name.compareTo(right.name);
        });
      return fallback.take(3).map(_mapVenue).toList(growable: false);
    }

    scored.sort((left, right) {
      final scoreCompare = right.score.compareTo(left.score);
      if (scoreCompare != 0) return scoreCompare;
      final ratingCompare = right.venue.rating.compareTo(left.venue.rating);
      if (ratingCompare != 0) return ratingCompare;
      return left.venue.name.compareTo(right.venue.name);
    });

    return scored
        .take(3)
        .map((entry) => _mapVenue(entry.venue))
        .toList(growable: false);
  }

  double _scoreVenue(Venue venue, String query) {
    final normalizedQuery = _normalize(query);
    final haystack = _normalize(
      '${venue.name} ${venue.category} ${venue.description} ${venue.address}',
    );
    final tokens = normalizedQuery
        .split(' ')
        .where((token) => token.length > 2)
        .toList(growable: false);

    var score = 0.0;
    if (haystack.contains(normalizedQuery)) score += 8;
    if (_normalize(venue.name).contains(normalizedQuery)) score += 5;
    if (_normalize(venue.category).contains(normalizedQuery)) score += 4;
    if (_normalize(venue.description).contains(normalizedQuery)) score += 3;

    for (final token in tokens) {
      if (_normalize(venue.name).contains(token)) score += 2.5;
      if (_normalize(venue.category).contains(token)) score += 2;
      if (_normalize(venue.description).contains(token)) score += 1.5;
      if (_normalize(venue.address).contains(token)) score += 1;
    }

    if (_isOpenIntent(normalizedQuery) && venue.canAcceptGuestOrders) {
      score += 3;
    }

    if (_containsAny(normalizedQuery, const [
      'date',
      'romantic',
      'anniversary',
    ])) {
      score += _bonusForKeywords(venue, const [
        'fine',
        'cocktail',
        'wine',
        'lounge',
        'rooftop',
        'seafront',
      ]);
    }

    if (_containsAny(normalizedQuery, const [
      'coffee',
      'cafe',
      'brunch',
      'breakfast',
    ])) {
      score += _bonusForKeywords(venue, const [
        'cafe',
        'brunch',
        'breakfast',
        'bakery',
      ]);
    }

    if (_containsAny(normalizedQuery, const [
      'seafood',
      'fish',
      'waterfront',
      'view',
    ])) {
      score += _bonusForKeywords(venue, const [
        'seafood',
        'fish',
        'harbor',
        'waterfront',
        'seafront',
        'view',
      ]);
    }

    return score + (venue.rating > 0 ? venue.rating / 4 : 0);
  }

  double _bonusForKeywords(Venue venue, List<String> keywords) {
    final haystack = _normalize(
      '${venue.name} ${venue.category} ${venue.description} ${venue.address}',
    );
    return keywords.fold<double>(
      0,
      (total, keyword) => haystack.contains(keyword) ? total + 1.25 : total,
    );
  }

  bool _isOpenIntent(String normalizedQuery) {
    return _containsAny(normalizedQuery, const [
      'open now',
      'open',
      'tonight',
      'late',
      'right now',
    ]);
  }

  bool _containsAny(String haystack, List<String> needles) {
    return needles.any(haystack.contains);
  }

  DiscoverAssistantMatch _mapVenue(Venue venue) {
    final subtitle = venue.description.trim().isNotEmpty
        ? venue.description.trim()
        : '${venue.category} · ${venue.address}';
    return DiscoverAssistantMatch(
      id: venue.id,
      title: venue.name,
      subtitle: subtitle,
      address: venue.address,
      imageUrl: venue.imageUrl,
      rating: venue.rating,
      ratingCount: venue.ratingCount,
      phoneNumber: venue.phone,
      venueSlug: venue.slug,
      source: DiscoverAssistantSource.dineIn,
    );
  }

  DiscoverAssistantMatch _mapGooglePlace(GooglePlaceCandidate place) {
    return DiscoverAssistantMatch(
      id: place.placeId,
      title: place.name,
      subtitle: place.category,
      address: place.address,
      rating: place.rating,
      ratingCount: place.ratingCount,
      phoneNumber: place.phoneNumber,
      websiteUrl: place.websiteUrl,
      source: DiscoverAssistantSource.googleMaps,
    );
  }

  String _buildSummary({
    required String query,
    required List<DiscoverAssistantMatch> dineInMatches,
    required List<DiscoverAssistantMatch> googleMapsMatches,
    required bool googleMapsEnabled,
  }) {
    if (dineInMatches.isNotEmpty && googleMapsMatches.isNotEmpty) {
      return 'I found ${dineInMatches.length} bookable DINEIN matches and '
          '${googleMapsMatches.length} live Google Maps references for "$query" in Malta.';
    }

    if (dineInMatches.isNotEmpty) {
      if (googleMapsEnabled) {
        return 'I found ${dineInMatches.length} strong DINEIN matches for "$query".';
      }
      return 'I found ${dineInMatches.length} DINEIN matches for "$query".';
    }

    if (googleMapsMatches.isNotEmpty) {
      return 'I could not find a strong DINEIN match for "$query" yet, but '
          'Google Maps returned ${googleMapsMatches.length} live references in Malta.';
    }

    return 'I could not find a strong match for "$query" yet. Try a broader prompt like '
        '"open now", "quiet dinner", or "seafood by the water".';
  }

  String _buildProvenanceNote({
    required bool googleMapsEnabled,
    required List<DiscoverAssistantMatch> googleMapsMatches,
    required String? googleMapsError,
  }) {
    if (googleMapsError != null) return googleMapsError;
    if (!googleMapsEnabled) {
      return 'This build can answer from onboarded DINEIN venues only. Google Maps data is not configured.';
    }
    if (googleMapsMatches.isNotEmpty) {
      return 'Bookable venues come from DINEIN. External reference cards come from live Google Maps data.';
    }
    return 'No external Google Maps references were needed for this query.';
  }

  String _scopeGoogleQuery(String query) {
    final normalized = _normalize(query);
    if (normalized.contains('malta')) return query;
    return '$query in Malta';
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _ScoredVenue {
  final Venue venue;
  final double score;

  const _ScoredVenue(this.venue, this.score);
}
