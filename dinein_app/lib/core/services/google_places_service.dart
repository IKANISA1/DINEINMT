import 'dart:convert';

import 'package:http/http.dart' as http;

class GooglePlaceCandidate {
  final String placeId;
  final String name;
  final String address;
  final String category;
  final double rating;
  final int ratingCount;
  final String? phoneNumber;
  final String? websiteUrl;
  final String? imageUrl;

  const GooglePlaceCandidate({
    required this.placeId,
    required this.name,
    required this.address,
    required this.category,
    this.rating = 0,
    this.ratingCount = 0,
    this.phoneNumber,
    this.websiteUrl,
    this.imageUrl,
  });
}

/// Simple Google Places Text Search wrapper for the claim fallback flow.
class GooglePlacesService {
  GooglePlacesService._();

  static final instance = GooglePlacesService._();

  static const _apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  bool get isConfigured => _apiKey.trim().isNotEmpty;

  Future<List<GooglePlaceCandidate>> search(String query) async {
    final trimmedQuery = query.trim();
    if (!isConfigured || trimmedQuery.length < 2) {
      return const [];
    }

    final response = await http.post(
      Uri.parse('https://places.googleapis.com/v1/places:searchText'),
      headers: {
        'content-type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask':
            'places.id,places.displayName,places.formattedAddress,places.primaryType,places.primaryTypeDisplayName,places.types,places.rating,places.userRatingCount,places.nationalPhoneNumber,places.websiteUri,places.photos.name',
      },
      body: jsonEncode({'textQuery': trimmedQuery, 'pageSize': 5}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Google Places lookup failed.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final places = json['places'] as List<dynamic>? ?? const [];

    return places.map((place) {
      final row = place as Map<String, dynamic>;
      final photos = row['photos'] as List<dynamic>? ?? const [];
      final firstPhoto = photos.isEmpty
          ? null
          : photos.first as Map<String, dynamic>;
      final photoName = firstPhoto?['name'] as String?;

      final imageUrl = photoName == null
          ? null
          : 'https://places.googleapis.com/v1/$photoName/media'
                '?maxWidthPx=1200&key=$_apiKey';

      return GooglePlaceCandidate(
        placeId: row['id'] as String? ?? '',
        name:
            (row['displayName'] as Map<String, dynamic>?)?['text'] as String? ??
            '',
        address: row['formattedAddress'] as String? ?? '',
        category: _normalizeVenueCategory(
          row['primaryType'] as String?,
          (row['types'] as List<dynamic>?)?.cast<String>() ?? const [],
          fallback:
              (row['primaryTypeDisplayName'] as Map<String, dynamic>?)?['text']
                  as String?,
        ),
        rating: (row['rating'] as num?)?.toDouble() ?? 0,
        ratingCount: row['userRatingCount'] as int? ?? 0,
        phoneNumber: row['nationalPhoneNumber'] as String?,
        websiteUrl: row['websiteUri'] as String?,
        imageUrl: imageUrl,
      );
    }).toList();
  }

  String _normalizeVenueCategory(
    String? primaryType,
    List<String> types, {
    String? fallback,
  }) {
    final normalizedTypes = <String>{
      if (primaryType != null && primaryType.trim().isNotEmpty)
        primaryType.trim().toLowerCase(),
      ...types.map((value) => value.trim().toLowerCase()),
    };

    const hotelTypes = {
      'hotel',
      'resort_hotel',
      'extended_stay_hotel',
      'inn',
      'hostel',
      'guest_house',
      'bed_and_breakfast',
      'lodging',
      'motel',
    };

    const barTypes = {
      'bar',
      'bar_and_grill',
      'cocktail_bar',
      'sports_bar',
      'wine_bar',
      'lounge_bar',
      'pub',
      'irish_pub',
      'gastropub',
      'brewpub',
      'beer_garden',
      'night_club',
      'hookah_bar',
    };

    final hasHotel = normalizedTypes.any(hotelTypes.contains);
    if (hasHotel) return 'Hotels';

    final hasBar = normalizedTypes.any(barTypes.contains);
    final hasRestaurant = normalizedTypes.any(
      (value) =>
          value == 'restaurant' ||
          value.endsWith('_restaurant') ||
          value == 'cafe' ||
          value == 'bistro' ||
          value == 'cafeteria' ||
          value == 'fine_dining_restaurant',
    );

    if (hasBar && hasRestaurant) return 'Bar & Restaurants';
    if (hasBar) return 'Bar';
    if (hasRestaurant) return 'Restaurants';

    final fallbackValue = (fallback ?? '').toLowerCase();
    if (fallbackValue.contains('hotel')) return 'Hotels';
    if (fallbackValue.contains('bar') && fallbackValue.contains('restaurant')) {
      return 'Bar & Restaurants';
    }
    if (fallbackValue.contains('bar')) return 'Bar';
    return 'Restaurants';
  }
}
