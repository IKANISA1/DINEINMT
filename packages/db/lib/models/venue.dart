part of 'models.dart';

/// A venue (restaurant, bar, café, etc.) available on DineIn.
class Venue extends Equatable {
  final String id;
  final String name;
  final String slug;
  final String category;
  final String description;
  final String address;
  final String? phone;
  final String? ownerWhatsAppNumber;

  final String? imageUrl;
  final String? revolutUrl;
  final String? momoCode;
  final VenueStatus status;
  final bool orderingEnabled;
  final double rating;
  final int ratingCount;
  final Country country;

  final String? ownerId;
  final List<Review>? reviews;
  final String? googleMapsUri;
  final Map<String, dynamic>? googleLocation;
  final String? googlePriceLevel;
  final String? googleReviewSummary;
  final String? googlePlaceSummary;
  final String? enrichmentStatus;
  final DateTime? lastEnrichedAt;
  final double? enrichmentConfidence;
  final List<PaymentMethod> supportedPaymentMethods;
  final String? wifiSsid;
  final String? wifiPassword;
  final String? wifiSecurity;
  final Map<String, String>? socialLinks;
  final String? promoMessage;
  final bool isPromoActive;

  const Venue({
    required this.id,
    required this.name,
    required this.slug,
    required this.category,
    required this.description,
    required this.address,
    this.phone,
    this.ownerWhatsAppNumber,

    this.imageUrl,
    this.revolutUrl,
    this.momoCode,
    this.status = VenueStatus.active,
    this.orderingEnabled = false,
    this.rating = 0.0,
    this.ratingCount = 0,
    this.country = Country.mt,

    this.ownerId,
    this.reviews,
    this.googleMapsUri,
    this.googleLocation,
    this.googlePriceLevel,
    this.googleReviewSummary,
    this.googlePlaceSummary,
    this.enrichmentStatus,
    this.lastEnrichedAt,
    this.enrichmentConfidence,
    this.supportedPaymentMethods = const [PaymentMethod.cash],
    this.wifiSsid,
    this.wifiPassword,
    this.wifiSecurity,
    this.socialLinks,
    this.promoMessage,
    this.isPromoActive = false,
  });

  /// Deserialize from Supabase JSON row.
  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      category: normalizeVenueCategoryLabel(json['category'] as String?),
      description: json['description'] as String? ?? '',
      address: json['address'] as String? ?? '',
      phone: json['phone'] as String?,
      ownerWhatsAppNumber: json['owner_whatsapp_number'] as String?,

      imageUrl: json['image_url'] as String?,
      revolutUrl: json['revolut_url'] as String?,
      momoCode: json['momo_code'] as String? ?? json['momoCode'] as String?,
      status: VenueStatus.fromString(json['status'] as String? ?? 'active'),
      orderingEnabled:
          json['ordering_enabled'] as bool? ??
          json['orderingEnabled'] as bool? ??
          false,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: json['rating_count'] as int? ?? 0,
      country: Country.fromCode(json['country'] as String? ?? 'MT'),

      ownerId: json['owner_id'] as String?,
      reviews: (json['reviews'] as List<dynamic>?)
          ?.map((r) => Review.fromJson(r as Map<String, dynamic>))
          .toList(),
      googleMapsUri:
          json['google_maps_uri'] as String? ??
          json['googleMapsUri'] as String?,
      googleLocation: _parseJsonMap(
        json['google_location'] ?? json['googleLocation'],
      ),
      googlePriceLevel:
          json['google_price_level'] as String? ??
          json['googlePriceLevel'] as String?,
      googleReviewSummary:
          json['google_review_summary'] as String? ??
          json['googleReviewSummary'] as String?,
      googlePlaceSummary:
          json['google_place_summary'] as String? ??
          json['googlePlaceSummary'] as String?,
      enrichmentStatus:
          json['enrichment_status'] as String? ??
          json['enrichmentStatus'] as String?,
      lastEnrichedAt: DateTime.tryParse(
        json['last_enriched_at'] as String? ??
            json['lastEnrichedAt'] as String? ??
            '',
      ),
      enrichmentConfidence:
          (json['enrichment_confidence'] as num?)?.toDouble() ??
          (json['enrichmentConfidence'] as num?)?.toDouble(),
      supportedPaymentMethods: _parseSupportedPaymentMethods(
        json['supported_payment_methods'] ?? json['supportedPaymentMethods'],
        revolutUrl:
            json['revolut_url'] as String? ?? json['revolutUrl'] as String?,
        momoCode:
            json['momo_code'] as String? ?? json['momoCode'] as String?,
      ),
      wifiSsid: json['wifi_ssid'] as String?,
      wifiPassword: json['wifi_password'] as String?,
      wifiSecurity: json['wifi_security'] as String?,
      socialLinks: _parseStringMap(json['social_links'] ?? json['socialLinks']),
      promoMessage: json['promo_message'] as String? ?? json['promoMessage'] as String?,
      isPromoActive: json['is_promo_active'] as bool? ?? json['isPromoActive'] as bool? ?? false,
    );
  }

  /// Serialize to JSON for Supabase insert/update.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'category': category,
    'description': description,
    'address': address,
    'phone': phone,
    'owner_whatsapp_number': ownerWhatsAppNumber,

    'image_url': imageUrl,
    'revolut_url': revolutUrl,
    'momo_code': momoCode,
    'status': status.dbValue,
    'ordering_enabled': orderingEnabled,
    'rating': rating,
    'rating_count': ratingCount,
    'country': country.code,

    'owner_id': ownerId,
    'google_maps_uri': googleMapsUri,
    'google_location': googleLocation,
    'google_price_level': googlePriceLevel,
    'google_review_summary': googleReviewSummary,
    'google_place_summary': googlePlaceSummary,
    'enrichment_status': enrichmentStatus,
    'last_enriched_at': lastEnrichedAt?.toIso8601String(),
    'enrichment_confidence': enrichmentConfidence,
    'supported_payment_methods': supportedPaymentMethods
        .map((method) => method.dbValue)
        .toList(growable: false),
    'wifi_ssid': wifiSsid,
    'wifi_password': wifiPassword,
    'wifi_security': wifiSecurity,
    'social_links': socialLinks,
    'promo_message': promoMessage,
    'is_promo_active': isPromoActive,
  };

  /// Whether this venue is currently accepting orders.
  bool get isOpen => status == VenueStatus.active;

  /// Legacy admin-form fallback after owner contact storage was merged away.
  String? get ownerContactPhone => phone;

  /// Backwards-compatible access-number lookup used by restored admin sheets.
  String? get effectiveAccessPhone {
    for (final candidate in [ownerWhatsAppNumber, phone, ownerContactPhone]) {
      final trimmed = candidate?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  bool get hasAssignedAccessPhone => effectiveAccessPhone != null;

  /// Whether guests can place orders with this venue right now.
  bool get canAcceptGuestOrders => isOpen && orderingEnabled;

  /// Whether guest-facing pricing should be hidden for this venue.
  bool get shouldHideGuestPricing => !canAcceptGuestOrders;

  /// Guest-facing availability label shown in venue detail surfaces.
  String get guestAvailabilityLabel => canAcceptGuestOrders
      ? 'Available'
      : switch (status) {
          VenueStatus.active => 'Browse Menu',
          VenueStatus.maintenance ||
          VenueStatus.inactive ||
          VenueStatus.suspended ||
          VenueStatus.deleted => 'Closed',
        };

  /// Short explanation for why the venue is browse-only.
  String get guestAvailabilityReason {
    if (canAcceptGuestOrders) return 'Now accepting guest orders.';
    return switch (status) {
      VenueStatus.maintenance => 'Temporarily unavailable for orders.',
      VenueStatus.inactive => 'Currently unavailable for ordering.',
      VenueStatus.suspended ||
      VenueStatus.deleted => 'Currently unavailable for ordering.',
      VenueStatus.active =>
        !orderingEnabled
            ? 'Ordering is disabled. Menu preview only.'
            : 'Currently unavailable for ordering.',
    };
  }

  /// Whether this venue has WiFi credentials configured for guests.
  bool get hasWifi => wifiSsid != null && wifiSsid!.trim().isNotEmpty;

  double? get latitude =>
      _doubleFromDynamic(googleLocation?['latitude'] ?? googleLocation?['lat']);

  double? get longitude => _doubleFromDynamic(
    googleLocation?['longitude'] ?? googleLocation?['lng'],
  );

  String? get priceLevelLabel {
    final level = googlePriceLevel?.trim();
    if (level == null || level.isEmpty) return null;
    return switch (level) {
      'FREE' => 'Free',
      'PRICE_LEVEL_INEXPENSIVE' => r'$',
      'PRICE_LEVEL_MODERATE' => r'$$',
      'PRICE_LEVEL_EXPENSIVE' => r'$$$',
      'PRICE_LEVEL_VERY_EXPENSIVE' => r'$$$$',
      _ => level.replaceAll('PRICE_LEVEL_', '').replaceAll('_', ' '),
    };
  }

  String? get primaryReviewSnippet {
    final reviewText = reviews
        ?.map((review) => review.text.trim())
        .where((text) => text.isNotEmpty)
        .firstOrNull;
    if (reviewText != null) return reviewText;
    final googleSummary = googleReviewSummary?.trim();
    if (googleSummary != null && googleSummary.isNotEmpty) {
      return googleSummary;
    }
    return null;
  }

  bool get hasDiscoveryMetadata =>
      latitude != null ||
      longitude != null ||
      priceLevelLabel != null ||
      primaryReviewSnippet != null;

  double? distanceInKmFrom(double latitude, double longitude) {
    final venueLatitude = this.latitude;
    final venueLongitude = this.longitude;
    if (venueLatitude == null || venueLongitude == null) return null;

    const earthRadiusKm = 6371.0;
    final dLat = (venueLatitude - latitude) * (pi / 180.0);
    final dLon = (venueLongitude - longitude) * (pi / 180.0);
    final lat1 = latitude * (pi / 180.0);
    final lat2 = venueLatitude * (pi / 180.0);

    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(lat1) * cos(lat2) * (sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  String? distanceLabelFrom(double latitude, double longitude) {
    final distance = distanceInKmFrom(latitude, longitude);
    if (distance == null) return null;
    if (distance < 1) {
      return '${(distance * 1000).round()} m away';
    }
    return '${distance.toStringAsFixed(distance < 10 ? 1 : 0)} km away';
  }

  /// Compact address for card display — first comma-segment, trimmed.
  String? get addressLocality {
    final raw = address.trim();
    if (raw.isEmpty) return null;
    final parts = raw.split(',');
    // Skip very short segments (e.g. street numbers) if a second part exists.
    final first = parts.first.trim();
    if (parts.length > 1 && first.length < 6) {
      return parts[1].trim();
    }
    return first;
  }

  bool supportsPaymentMethod(PaymentMethod method) =>
      supportedPaymentMethods.contains(method);

  @override
  List<Object?> get props => [
    id,
    slug,
    name,
    category,
    address,
    phone,
    ownerWhatsAppNumber,

    revolutUrl,
    momoCode,
    status,
    orderingEnabled,
    country,

    ownerId,
    reviews,
    googleMapsUri,
    googleLocation,
    googlePriceLevel,
    googleReviewSummary,
    googlePlaceSummary,
    enrichmentStatus,
    lastEnrichedAt,
    enrichmentConfidence,
    supportedPaymentMethods,
    wifiSsid,
    wifiPassword,
    wifiSecurity,
    socialLinks,
    promoMessage,
    isPromoActive,
  ];
}

class VenueNotificationSettings extends Equatable {
  final bool orderPushEnabled;
  final bool whatsAppUpdatesEnabled;

  const VenueNotificationSettings({
    this.orderPushEnabled = true,
    this.whatsAppUpdatesEnabled = true,
  });

  factory VenueNotificationSettings.fromJson(Map<String, dynamic> json) {
    return VenueNotificationSettings(
      orderPushEnabled:
          json['order_push_enabled'] as bool? ??
          json['orderPushEnabled'] as bool? ??
          true,
      whatsAppUpdatesEnabled:
          json['whatsapp_updates_enabled'] as bool? ??
          json['whatsAppUpdatesEnabled'] as bool? ??
          true,
    );
  }

  Map<String, dynamic> toJson() => {
    'order_push_enabled': orderPushEnabled,
    'whatsapp_updates_enabled': whatsAppUpdatesEnabled,
  };

  VenueNotificationSettings copyWith({
    bool? orderPushEnabled,
    bool? whatsAppUpdatesEnabled,
  }) {
    return VenueNotificationSettings(
      orderPushEnabled: orderPushEnabled ?? this.orderPushEnabled,
      whatsAppUpdatesEnabled:
          whatsAppUpdatesEnabled ?? this.whatsAppUpdatesEnabled,
    );
  }

  @override
  List<Object?> get props => [orderPushEnabled, whatsAppUpdatesEnabled];
}

/// A venue review.
class Review extends Equatable {
  final String author;
  final double rating;
  final String text;

  const Review({
    required this.author,
    required this.rating,
    required this.text,
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
    author: json['author'] as String? ?? 'Anonymous',
    rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
    text: json['text'] as String? ?? '',
  );

  @override
  List<Object?> get props => [author, rating, text];
}
