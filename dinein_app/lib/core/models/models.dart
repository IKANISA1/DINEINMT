import 'package:equatable/equatable.dart';
import '../constants/enums.dart';

String _toTitleCaseLabel(String value) {
  return value
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) {
        if (part.length == 1) return part.toUpperCase();
        return '${part[0].toUpperCase()}${part.substring(1)}';
      })
      .join(' ');
}

String normalizeVenueCategoryLabel(
  String? value, {
  String fallback = 'Restaurants',
}) {
  final raw = (value ?? '').trim();
  final normalized = raw.toLowerCase();
  if (normalized.isEmpty) return fallback;
  if (normalized.contains('hotel')) return 'Hotels';
  if (normalized.contains('bar') && normalized.contains('restaurant')) {
    return 'Bar & Restaurants';
  }
  if (normalized.contains('bar')) return 'Bar';
  if (normalized.contains('restaurant')) return 'Restaurants';
  return _toTitleCaseLabel(raw);
}

Map<String, OpeningHours>? _parseOpeningHours(Object? raw) {
  if (raw is! Map) return null;

  final parsed = <String, OpeningHours>{};
  for (final entry in raw.entries) {
    final key = entry.key;
    final value = entry.value;
    if (key is! String || value is! Map) continue;
    parsed[key] = OpeningHours.fromJson(Map<String, dynamic>.from(value));
  }

  return parsed.isEmpty ? null : parsed;
}

Map<String, String>? _parseStringMap(Object? raw) {
  if (raw is! Map) return null;

  final parsed = <String, String>{};
  for (final entry in raw.entries) {
    final key = entry.key;
    if (key is! String) continue;
    final value = entry.value?.toString().trim();
    if (value == null || value.isEmpty) continue;
    parsed[key] = value;
  }

  return parsed.isEmpty ? null : parsed;
}

List<PaymentMethod> _parseSupportedPaymentMethods(
  Object? raw, {
  String? revolutUrl,
}) {
  final parsed = <PaymentMethod>[];
  if (raw is List) {
    for (final value in raw) {
      final method = switch (value) {
        'cash' => PaymentMethod.cash,
        'revolut_link' => PaymentMethod.revolutLink,
        _ => null,
      };
      if (method != null && !parsed.contains(method)) {
        parsed.add(method);
      }
    }
  }

  if (parsed.isNotEmpty) return parsed;

  if ((revolutUrl ?? '').trim().isNotEmpty) {
    return const [PaymentMethod.cash, PaymentMethod.revolutLink];
  }

  return const [PaymentMethod.cash];
}

/// A venue (restaurant, bar, café, etc.) available on DineIn.
class Venue extends Equatable {
  final String id;
  final String name;
  final String slug;
  final String category;
  final String description;
  final String address;
  final String? phone;
  final String? ownerContactPhone;
  final String? ownerWhatsAppNumber;
  final String? email;
  final String? imageUrl;
  final String? revolutUrl;
  final VenueStatus status;
  final bool orderingEnabled;
  final DateTime? approvedAt;
  final DateTime? accessVerifiedAt;
  final DateTime? lastAccessTokenIssuedAt;
  final DateTime? accessNumberUpdatedAt;
  final String? accessVerificationMethod;
  final String? accessVerifiedBy;
  final String? accessVerificationNote;
  final String? accessNumberUpdatedBy;
  final String? normalizedAccessPhone;
  final double rating;
  final int ratingCount;
  final Country country;
  final Map<String, OpeningHours>? openingHours;
  final String? websiteUrl;
  final String? reservationUrl;
  final String? ownerId;
  final List<Review>? reviews;
  final List<PaymentMethod> supportedPaymentMethods;
  final String? wifiSsid;
  final String? wifiPassword;
  final String? wifiSecurity;
  final Map<String, String>? socialLinks;

  const Venue({
    required this.id,
    required this.name,
    required this.slug,
    required this.category,
    required this.description,
    required this.address,
    this.phone,
    this.ownerContactPhone,
    this.ownerWhatsAppNumber,
    this.email,
    this.imageUrl,
    this.revolutUrl,
    this.status = VenueStatus.active,
    this.orderingEnabled = false,
    this.approvedAt,
    this.accessVerifiedAt,
    this.lastAccessTokenIssuedAt,
    this.accessNumberUpdatedAt,
    this.accessVerificationMethod,
    this.accessVerifiedBy,
    this.accessVerificationNote,
    this.accessNumberUpdatedBy,
    this.normalizedAccessPhone,
    this.rating = 0.0,
    this.ratingCount = 0,
    this.country = Country.mt,
    this.openingHours,
    this.websiteUrl,
    this.reservationUrl,
    this.ownerId,
    this.reviews,
    this.supportedPaymentMethods = const [PaymentMethod.cash],
    this.wifiSsid,
    this.wifiPassword,
    this.wifiSecurity,
    this.socialLinks,
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
      ownerContactPhone: json['owner_contact_phone'] as String?,
      ownerWhatsAppNumber: json['owner_whatsapp_number'] as String?,
      email: json['email'] as String?,
      imageUrl: json['image_url'] as String?,
      revolutUrl: json['revolut_url'] as String?,
      status: VenueStatus.fromString(json['status'] as String? ?? 'active'),
      orderingEnabled:
          json['ordering_enabled'] as bool? ??
          json['orderingEnabled'] as bool? ??
          false,
      approvedAt: DateTime.tryParse(json['approved_at'] as String? ?? ''),
      accessVerifiedAt: DateTime.tryParse(
        json['access_verified_at'] as String? ?? '',
      ),
      lastAccessTokenIssuedAt: DateTime.tryParse(
        json['last_access_token_issued_at'] as String? ?? '',
      ),
      accessNumberUpdatedAt: DateTime.tryParse(
        json['access_number_updated_at'] as String? ?? '',
      ),
      accessVerificationMethod:
          json['access_verification_method'] as String? ??
          json['accessVerificationMethod'] as String?,
      accessVerifiedBy:
          json['access_verified_by'] as String? ??
          json['accessVerifiedBy'] as String?,
      accessVerificationNote:
          json['access_verification_note'] as String? ??
          json['accessVerificationNote'] as String?,
      accessNumberUpdatedBy:
          json['access_number_updated_by'] as String? ??
          json['accessNumberUpdatedBy'] as String?,
      normalizedAccessPhone:
          json['normalized_access_phone'] as String? ??
          json['normalizedAccessPhone'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: json['rating_count'] as int? ?? 0,
      country: Country.fromCode(json['country'] as String? ?? 'MT'),
      openingHours: _parseOpeningHours(
        json['opening_hours'] ?? json['openingHours'],
      ),
      websiteUrl:
          json['website_url'] as String? ?? json['websiteUrl'] as String?,
      reservationUrl:
          json['reservation_url'] as String? ??
          json['reservationUrl'] as String?,
      ownerId: json['owner_id'] as String?,
      reviews: (json['reviews'] as List<dynamic>?)
          ?.map((r) => Review.fromJson(r as Map<String, dynamic>))
          .toList(),
      supportedPaymentMethods: _parseSupportedPaymentMethods(
        json['supported_payment_methods'] ?? json['supportedPaymentMethods'],
        revolutUrl:
            json['revolut_url'] as String? ?? json['revolutUrl'] as String?,
      ),
      wifiSsid: json['wifi_ssid'] as String?,
      wifiPassword: json['wifi_password'] as String?,
      wifiSecurity: json['wifi_security'] as String?,
      socialLinks: _parseStringMap(json['social_links'] ?? json['socialLinks']),
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
    'owner_contact_phone': ownerContactPhone,
    'owner_whatsapp_number': ownerWhatsAppNumber,
    'email': email,
    'image_url': imageUrl,
    'revolut_url': revolutUrl,
    'status': status.dbValue,
    'ordering_enabled': orderingEnabled,
    'approved_at': approvedAt?.toIso8601String(),
    'access_verified_at': accessVerifiedAt?.toIso8601String(),
    'last_access_token_issued_at': lastAccessTokenIssuedAt?.toIso8601String(),
    'access_number_updated_at': accessNumberUpdatedAt?.toIso8601String(),
    'access_verification_method': accessVerificationMethod,
    'access_verified_by': accessVerifiedBy,
    'access_verification_note': accessVerificationNote,
    'access_number_updated_by': accessNumberUpdatedBy,
    'normalized_access_phone': normalizedAccessPhone,
    'rating': rating,
    'rating_count': ratingCount,
    'country': country.code,
    'opening_hours': openingHours?.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
    'website_url': websiteUrl,
    'reservation_url': reservationUrl,
    'owner_id': ownerId,
    'supported_payment_methods': supportedPaymentMethods
        .map((method) => method.dbValue)
        .toList(growable: false),
    'wifi_ssid': wifiSsid,
    'wifi_password': wifiPassword,
    'wifi_security': wifiSecurity,
    'social_links': socialLinks,
  };

  /// Whether this venue is currently accepting orders.
  bool get isOpen => status == VenueStatus.active;

  String? get effectiveAccessPhone {
    for (final candidate in [phone, ownerWhatsAppNumber, ownerContactPhone]) {
      final trimmed = candidate?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  bool get hasAssignedAccessPhone => effectiveAccessPhone != null;

  bool get isAccessVerified => accessVerifiedAt != null;

  bool get isAccessReady =>
      isOpen && hasAssignedAccessPhone && isAccessVerified;

  /// Whether guests can place orders with this venue right now.
  bool get canAcceptGuestOrders => isOpen && orderingEnabled;

  /// Whether guest-facing pricing should be hidden for this venue.
  bool get shouldHideGuestPricing => !canAcceptGuestOrders;

  /// Guest-facing browse label shown in discovery and venue detail surfaces.
  String get guestAvailabilityLabel => canAcceptGuestOrders
      ? 'Available'
      : switch (status) {
          VenueStatus.active || VenueStatus.pendingActivation => 'Browse Menu',
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
      VenueStatus.pendingActivation => 'Activation pending. Menu preview only.',
      VenueStatus.suspended ||
      VenueStatus.deleted => 'Currently unavailable for ordering.',
      VenueStatus.active =>
        !orderingEnabled
            ? 'Validation pending. Menu preview only.'
            : 'Currently unavailable for ordering.',
    };
  }

  /// Whether this venue has WiFi credentials configured for guests.
  bool get hasWifi => wifiSsid != null && wifiSsid!.trim().isNotEmpty;

  bool supportsPaymentMethod(PaymentMethod method) =>
      supportedPaymentMethods.contains(method);

  Uri? get websiteUri {
    final raw = websiteUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    final resolved = raw.startsWith('http://') || raw.startsWith('https://')
        ? raw
        : 'https://$raw';
    return Uri.tryParse(resolved);
  }

  @override
  List<Object?> get props => [
    id,
    slug,
    name,
    category,
    address,
    phone,
    ownerContactPhone,
    ownerWhatsAppNumber,
    websiteUrl,
    reservationUrl,
    revolutUrl,
    status,
    orderingEnabled,
    approvedAt,
    accessVerifiedAt,
    lastAccessTokenIssuedAt,
    accessNumberUpdatedAt,
    accessVerificationMethod,
    accessVerifiedBy,
    accessVerificationNote,
    accessNumberUpdatedBy,
    normalizedAccessPhone,
    country,
    openingHours,
    ownerId,
    reviews,
    supportedPaymentMethods,
    wifiSsid,
    wifiPassword,
    wifiSecurity,
    socialLinks,
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

/// Opening hours for a single day.
class OpeningHours extends Equatable {
  final String open;
  final String close;
  final bool isOpen;

  const OpeningHours({
    required this.open,
    required this.close,
    this.isOpen = true,
  });

  factory OpeningHours.fromJson(Map<String, dynamic> json) => OpeningHours(
    open: json['open'] as String? ?? '',
    close: json['close'] as String? ?? '',
    isOpen: json['is_open'] as bool? ?? json['isOpen'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'open': open,
    'close': close,
    'is_open': isOpen,
  };

  @override
  List<Object?> get props => [open, close, isOpen];
}

/// Admin queue summary for a venue's menu review state.
class AdminMenuQueueEntry extends Equatable {
  final String venueId;
  final String venueName;
  final String? venueImageUrl;
  final String venueCategory;
  final String venueAddress;
  final VenueStatus venueStatus;
  final int totalItems;
  final int availableItems;
  final int pendingReviewCount;
  final int failedReviewCount;
  final int readyCount;
  final int categoryCount;
  final DateTime? lastUpdatedAt;

  const AdminMenuQueueEntry({
    required this.venueId,
    required this.venueName,
    this.venueImageUrl,
    required this.venueCategory,
    required this.venueAddress,
    this.venueStatus = VenueStatus.active,
    required this.totalItems,
    required this.availableItems,
    required this.pendingReviewCount,
    required this.failedReviewCount,
    required this.readyCount,
    required this.categoryCount,
    this.lastUpdatedAt,
  });

  factory AdminMenuQueueEntry.fromJson(Map<String, dynamic> json) {
    return AdminMenuQueueEntry(
      venueId: json['venue_id'] as String? ?? json['venueId'] as String? ?? '',
      venueName:
          json['venue_name'] as String? ??
          json['venueName'] as String? ??
          'Venue',
      venueImageUrl:
          json['venue_image_url'] as String? ??
          json['venueImageUrl'] as String?,
      venueCategory: normalizeVenueCategoryLabel(
        json['venue_category'] as String? ?? json['venueCategory'] as String?,
      ),
      venueAddress:
          json['venue_address'] as String? ??
          json['venueAddress'] as String? ??
          '',
      venueStatus: VenueStatus.fromString(
        json['venue_status'] as String? ??
            json['venueStatus'] as String? ??
            'active',
      ),
      totalItems:
          (json['total_items'] as num?)?.toInt() ??
          (json['totalItems'] as num?)?.toInt() ??
          0,
      availableItems:
          (json['available_items'] as num?)?.toInt() ??
          (json['availableItems'] as num?)?.toInt() ??
          0,
      pendingReviewCount:
          (json['pending_review_count'] as num?)?.toInt() ??
          (json['pendingReviewCount'] as num?)?.toInt() ??
          0,
      failedReviewCount:
          (json['failed_review_count'] as num?)?.toInt() ??
          (json['failedReviewCount'] as num?)?.toInt() ??
          0,
      readyCount:
          (json['ready_count'] as num?)?.toInt() ??
          (json['readyCount'] as num?)?.toInt() ??
          0,
      categoryCount:
          (json['category_count'] as num?)?.toInt() ??
          (json['categoryCount'] as num?)?.toInt() ??
          0,
      lastUpdatedAt: DateTime.tryParse(
        json['last_updated_at'] as String? ??
            json['lastUpdatedAt'] as String? ??
            '',
      ),
    );
  }

  bool get requiresReview => pendingReviewCount > 0 || failedReviewCount > 0;

  @override
  List<Object?> get props => [
    venueId,
    venueName,
    venueImageUrl,
    venueCategory,
    venueAddress,
    venueStatus,
    totalItems,
    availableItems,
    pendingReviewCount,
    failedReviewCount,
    readyCount,
    categoryCount,
    lastUpdatedAt,
  ];
}

/// Admin catalog summary for centrally managed menu items.
class AdminMenuCatalogEntry extends Equatable {
  final String groupId;
  final String representativeItemId;
  final String representativeVenueId;
  final String name;
  final String description;
  final String category;
  final MenuItemClass? itemClass;
  final String? imageUrl;
  final MenuItemImageSource imageSource;
  final MenuItemImageStatus imageStatus;
  final bool imageLocked;
  final List<String> tags;
  final int assignedVenueCount;
  final int assignedActiveVenueCount;
  final DateTime? lastUpdatedAt;

  const AdminMenuCatalogEntry({
    required this.groupId,
    required this.representativeItemId,
    required this.representativeVenueId,
    required this.name,
    required this.description,
    required this.category,
    this.itemClass,
    this.imageUrl,
    this.imageSource = MenuItemImageSource.unknown,
    this.imageStatus = MenuItemImageStatus.pending,
    this.imageLocked = false,
    this.tags = const [],
    required this.assignedVenueCount,
    required this.assignedActiveVenueCount,
    this.lastUpdatedAt,
  });

  factory AdminMenuCatalogEntry.fromJson(Map<String, dynamic> json) {
    return AdminMenuCatalogEntry(
      groupId: json['group_id'] as String? ?? json['groupId'] as String? ?? '',
      representativeItemId:
          json['representative_item_id'] as String? ??
          json['representativeItemId'] as String? ??
          '',
      representativeVenueId:
          json['representative_venue_id'] as String? ??
          json['representativeVenueId'] as String? ??
          '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'Uncategorized',
      itemClass: MenuItemClass.fromString(
        json['class'] as String? ?? json['itemClass'] as String?,
      ),
      imageUrl: json['image_url'] as String? ?? json['imageUrl'] as String?,
      imageSource: MenuItemImageSource.fromString(
        json['image_source'] as String? ?? json['imageSource'] as String?,
      ),
      imageStatus: MenuItemImageStatus.fromString(
        json['image_status'] as String? ??
            json['imageStatus'] as String? ??
            'pending',
      ),
      imageLocked:
          json['image_locked'] as bool? ??
          json['imageLocked'] as bool? ??
          false,
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      assignedVenueCount:
          (json['assigned_venue_count'] as num?)?.toInt() ??
          (json['assignedVenueCount'] as num?)?.toInt() ??
          0,
      assignedActiveVenueCount:
          (json['assigned_active_venue_count'] as num?)?.toInt() ??
          (json['assignedActiveVenueCount'] as num?)?.toInt() ??
          0,
      lastUpdatedAt: DateTime.tryParse(
        json['last_updated_at'] as String? ??
            json['lastUpdatedAt'] as String? ??
            '',
      ),
    );
  }

  @override
  List<Object?> get props => [
    groupId,
    representativeItemId,
    representativeVenueId,
    name,
    description,
    category,
    itemClass,
    imageUrl,
    imageSource,
    imageStatus,
    imageLocked,
    tags,
    assignedVenueCount,
    assignedActiveVenueCount,
    lastUpdatedAt,
  ];
}

/// Venue assignment state for a centrally managed menu item.
class AdminMenuGroupAssignment extends Equatable {
  final String itemId;
  final String groupId;
  final String venueId;
  final String venueName;
  final String venueSlug;
  final VenueStatus venueStatus;
  final bool orderingEnabled;
  final double price;
  final bool isAvailable;
  final DateTime? updatedAt;

  const AdminMenuGroupAssignment({
    required this.itemId,
    required this.groupId,
    required this.venueId,
    required this.venueName,
    required this.venueSlug,
    this.venueStatus = VenueStatus.active,
    this.orderingEnabled = false,
    this.price = 0,
    this.isAvailable = false,
    this.updatedAt,
  });

  factory AdminMenuGroupAssignment.fromJson(Map<String, dynamic> json) {
    return AdminMenuGroupAssignment(
      itemId: json['item_id'] as String? ?? json['itemId'] as String? ?? '',
      groupId: json['group_id'] as String? ?? json['groupId'] as String? ?? '',
      venueId: json['venue_id'] as String? ?? json['venueId'] as String? ?? '',
      venueName:
          json['venue_name'] as String? ??
          json['venueName'] as String? ??
          'Venue',
      venueSlug:
          json['venue_slug'] as String? ?? json['venueSlug'] as String? ?? '',
      venueStatus: VenueStatus.fromString(
        json['venue_status'] as String? ??
            json['venueStatus'] as String? ??
            'active',
      ),
      orderingEnabled:
          json['ordering_enabled'] as bool? ??
          json['orderingEnabled'] as bool? ??
          false,
      price:
          (json['price'] as num?)?.toDouble() ??
          (json['menu_price'] as num?)?.toDouble() ??
          0,
      isAvailable:
          json['is_available'] as bool? ??
          json['isAvailable'] as bool? ??
          false,
      updatedAt: DateTime.tryParse(
        json['updated_at'] as String? ?? json['updatedAt'] as String? ?? '',
      ),
    );
  }

  @override
  List<Object?> get props => [
    itemId,
    groupId,
    venueId,
    venueName,
    venueSlug,
    venueStatus,
    orderingEnabled,
    price,
    isAvailable,
    updatedAt,
  ];
}

/// A menu item belonging to a venue.
class MenuItem extends Equatable {
  final String id;
  final String venueId;
  final String? adminGroupId;
  final bool adminManaged;
  final String name;
  final String description;
  final double price;
  final bool priceHidden;
  final int? highlightRank;
  final String category;
  final MenuItemClass? itemClass;
  final String? imageUrl;
  final MenuItemImageSource imageSource;
  final MenuItemImageStatus imageStatus;
  final String? imageModel;
  final String? imageError;
  final DateTime? imageGeneratedAt;
  final bool imageLocked;
  final String? imageStoragePath;
  final int imageAttempts;
  final bool isAvailable;
  final List<String> tags;

  const MenuItem({
    required this.id,
    required this.venueId,
    this.adminGroupId,
    this.adminManaged = false,
    required this.name,
    required this.description,
    required this.price,
    this.priceHidden = false,
    this.highlightRank,
    required this.category,
    this.itemClass,
    this.imageUrl,
    this.imageSource = MenuItemImageSource.unknown,
    this.imageStatus = MenuItemImageStatus.pending,
    this.imageModel,
    this.imageError,
    this.imageGeneratedAt,
    this.imageLocked = false,
    this.imageStoragePath,
    this.imageAttempts = 0,
    this.isAvailable = true,
    this.tags = const [],
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] as String,
      venueId: json['venue_id'] as String,
      adminGroupId:
          json['admin_group_id'] as String? ?? json['adminGroupId'] as String?,
      adminManaged:
          json['admin_managed'] as bool? ??
          json['adminManaged'] as bool? ??
          false,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      priceHidden: json['price_hidden'] as bool? ?? false,
      highlightRank:
          (json['highlight_rank'] as num?)?.toInt() ??
          (json['highlightRank'] as num?)?.toInt(),
      category: json['category'] as String? ?? 'Uncategorized',
      itemClass: MenuItemClass.fromString(json['class'] as String?),
      imageUrl: json['image_url'] as String?,
      imageSource: MenuItemImageSource.fromString(
        json['image_source'] as String?,
      ),
      imageStatus: MenuItemImageStatus.fromString(
        json['image_status'] as String? ?? 'pending',
      ),
      imageModel: json['image_model'] as String?,
      imageError: json['image_error'] as String?,
      imageGeneratedAt: DateTime.tryParse(
        json['image_generated_at'] as String? ?? '',
      ),
      imageLocked: json['image_locked'] as bool? ?? false,
      imageStoragePath: json['image_storage_path'] as String?,
      imageAttempts: (json['image_attempts'] as num?)?.toInt() ?? 0,
      isAvailable: json['is_available'] as bool? ?? true,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'venue_id': venueId,
    'admin_group_id': adminGroupId,
    'admin_managed': adminManaged,
    'name': name,
    'description': description,
    'price': price,
    'price_hidden': priceHidden,
    'highlight_rank': highlightRank,
    'category': category,
    'class': itemClass?.dbValue,
    'image_url': imageUrl,
    'image_source': effectiveImageSource?.dbValue,
    'image_status': effectiveImageStatus.dbValue,
    'image_model': imageModel,
    'image_error': imageError,
    'image_generated_at': imageGeneratedAt?.toIso8601String(),
    'image_locked': imageLocked,
    'image_storage_path': imageStoragePath,
    'image_attempts': imageAttempts,
    'is_available': isAvailable,
    'tags': tags,
  };

  MenuItem copyWith({
    String? id,
    String? venueId,
    String? adminGroupId,
    bool? adminManaged,
    String? name,
    String? description,
    double? price,
    bool? priceHidden,
    Object? highlightRank = _menuItemNoChange,
    String? category,
    MenuItemClass? itemClass,
    String? imageUrl,
    MenuItemImageSource? imageSource,
    MenuItemImageStatus? imageStatus,
    String? imageModel,
    String? imageError,
    DateTime? imageGeneratedAt,
    bool? imageLocked,
    String? imageStoragePath,
    int? imageAttempts,
    bool? isAvailable,
    List<String>? tags,
  }) {
    return MenuItem(
      id: id ?? this.id,
      venueId: venueId ?? this.venueId,
      adminGroupId: adminGroupId ?? this.adminGroupId,
      adminManaged: adminManaged ?? this.adminManaged,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      priceHidden: priceHidden ?? this.priceHidden,
      highlightRank: identical(highlightRank, _menuItemNoChange)
          ? this.highlightRank
          : highlightRank as int?,
      category: category ?? this.category,
      itemClass: itemClass ?? this.itemClass,
      imageUrl: imageUrl ?? this.imageUrl,
      imageSource: imageSource ?? this.imageSource,
      imageStatus: imageStatus ?? this.imageStatus,
      imageModel: imageModel ?? this.imageModel,
      imageError: imageError ?? this.imageError,
      imageGeneratedAt: imageGeneratedAt ?? this.imageGeneratedAt,
      imageLocked: imageLocked ?? this.imageLocked,
      imageStoragePath: imageStoragePath ?? this.imageStoragePath,
      imageAttempts: imageAttempts ?? this.imageAttempts,
      isAvailable: isAvailable ?? this.isAvailable,
      tags: tags ?? this.tags,
    );
  }

  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  bool get isGeneratingImage => imageStatus == MenuItemImageStatus.generating;

  bool get needsGeneratedImage => !hasImage && !imageLocked;

  bool get isGuestHighlight => highlightRank != null;

  MenuItemImageSource? get effectiveImageSource {
    if (imageSource != MenuItemImageSource.unknown) return imageSource;
    if (hasImage) return MenuItemImageSource.manual;
    return null;
  }

  MenuItemImageStatus get effectiveImageStatus {
    if (hasImage && imageStatus == MenuItemImageStatus.pending) {
      return MenuItemImageStatus.ready;
    }
    return imageStatus;
  }

  @override
  List<Object?> get props => [
    id,
    venueId,
    adminGroupId,
    adminManaged,
    name,
    description,
    price,
    priceHidden,
    highlightRank,
    category,
    itemClass,
    imageUrl,
    imageSource,
    imageStatus,
    imageLocked,
    imageStoragePath,
    imageAttempts,
    isAvailable,
    tags,
  ];
}

const Object _menuItemNoChange = Object();

/// A single item in a cart or order.
class OrderItem extends Equatable {
  final String menuItemId;
  final String name;
  final double price;
  final int quantity;
  final String? note;

  const OrderItem({
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.quantity,
    this.note,
  });

  double get subtotal => price * quantity;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      menuItemId: json['menu_item_id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      quantity: json['quantity'] as int,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'menu_item_id': menuItemId,
    'name': name,
    'price': price,
    'quantity': quantity,
    'note': note,
  };

  OrderItem copyWith({int? quantity, String? note}) {
    return OrderItem(
      menuItemId: menuItemId,
      name: name,
      price: price,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
    );
  }

  @override
  List<Object?> get props => [menuItemId, name, price, quantity, note];
}

/// A placed order.
class Order extends Equatable {
  final String id;
  final String? orderNumber;
  final Country country;
  final String venueId;
  final String venueName;
  final String? venueImageUrl;
  final String? userId;
  final String? userName;
  final List<OrderItem> items;
  final double? subtotalAmount;
  final double? serviceFeeAmount;
  final double total;
  final OrderStatus status;
  final DateTime createdAt;
  final PaymentMethod paymentMethod;
  final String? tableNumber;
  final String? specialRequests;
  final String? guestReceiptToken;

  const Order({
    required this.id,
    this.orderNumber,
    this.country = Country.mt,
    required this.venueId,
    required this.venueName,
    this.venueImageUrl,
    this.userId,
    this.userName,
    required this.items,
    this.subtotalAmount,
    this.serviceFeeAmount,
    required this.total,
    this.status = OrderStatus.placed,
    required this.createdAt,
    required this.paymentMethod,
    this.tableNumber,
    this.specialRequests,
    this.guestReceiptToken,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      orderNumber:
          json['order_number'] as String? ?? json['orderNumber'] as String?,
      country: Country.fromCode(
        json['country'] as String? ?? json['venue_country'] as String? ?? 'MT',
      ),
      venueId: json['venue_id'] as String,
      venueName: json['venue_name'] as String,
      venueImageUrl: json['venue_image_url'] as String?,
      userId: json['user_id'] as String?,
      userName: json['user_name'] as String?,
      items: (json['items'] as List<dynamic>)
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtotalAmount: (json['subtotal'] as num?)?.toDouble(),
      serviceFeeAmount: (json['service_fee'] as num?)?.toDouble(),
      total: (json['total'] as num).toDouble(),
      status: OrderStatus.fromString(json['status'] as String? ?? 'placed'),
      createdAt: DateTime.parse(json['created_at'] as String),
      paymentMethod: PaymentMethod.fromString(
        json['payment_method'] as String? ?? 'cash',
      ),
      tableNumber: json['table_number'] as String?,
      specialRequests: json['special_requests'] as String?,
      guestReceiptToken:
          json['receipt_token'] as String? ??
          json['guest_receipt_token'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'country': country.code,
    'venue_id': venueId,
    'venue_name': venueName,
    'venue_image_url': venueImageUrl,
    'user_id': userId,
    'user_name': userName,
    'items': items.map((e) => e.toJson()).toList(),
    'subtotal': subtotal,
    'service_fee': serviceFee,
    'total': total,
    'status': status.dbValue,
    'payment_method': paymentMethod.dbValue,
    'table_number': tableNumber,
    'special_requests': specialRequests,
  };

  String get displayNumber {
    final explicit = orderNumber?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) return '';
    if (normalizedId.length <= 8) return normalizedId.toUpperCase();
    return normalizedId.substring(0, 8).toUpperCase();
  }

  double get subtotal =>
      subtotalAmount ?? items.fold(0.0, (sum, item) => sum + item.subtotal);

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  double get serviceFee {
    if (serviceFeeAmount != null) return serviceFeeAmount!;
    final derived = total - subtotal;
    return derived > 0 ? derived : 0;
  }

  /// Currency symbol derived from the order venue country.
  String get currencySymbol => country.currencySymbol;

  @override
  List<Object?> get props => [
    id,
    orderNumber,
    country,
    venueId,
    venueImageUrl,
    total,
    status,
    createdAt,
    specialRequests,
  ];
}

/// Persisted venue-owner access session for WhatsApp-based portal login.
class VenueAccessSession extends Equatable {
  final String accessToken;
  final String venueId;
  final String venueName;
  final String whatsAppNumber;
  final String? venueImageUrl;
  final DateTime issuedAt;
  final DateTime expiresAt;

  const VenueAccessSession({
    required this.accessToken,
    required this.venueId,
    required this.venueName,
    required this.whatsAppNumber,
    this.venueImageUrl,
    required this.issuedAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory VenueAccessSession.fromJson(Map<String, dynamic> json) {
    return VenueAccessSession(
      accessToken:
          json['access_token'] as String? ??
          json['accessToken'] as String? ??
          '',
      venueId: json['venue_id'] as String,
      venueName: json['venue_name'] as String? ?? '',
      whatsAppNumber: json['whatsapp_number'] as String? ?? '',
      venueImageUrl: json['venue_image_url'] as String?,
      issuedAt: DateTime.parse(
        json['issued_at'] as String? ?? json['issuedAt'] as String? ?? '',
      ),
      expiresAt: DateTime.parse(
        json['expires_at'] as String? ?? json['expiresAt'] as String? ?? '',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'venue_id': venueId,
    'venue_name': venueName,
    'whatsapp_number': whatsAppNumber,
    'venue_image_url': venueImageUrl,
    'issued_at': issuedAt.toIso8601String(),
    'expires_at': expiresAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [
    accessToken,
    venueId,
    venueName,
    whatsAppNumber,
    venueImageUrl,
    issuedAt,
    expiresAt,
  ];
}

/// Persisted admin console access session for WhatsApp OTP login.
class AdminAccessSession extends Equatable {
  final String adminUserId;
  final String accessToken;
  final String displayName;
  final String whatsAppNumber;
  final String? email;
  final DateTime expiresAt;
  final DateTime issuedAt;

  const AdminAccessSession({
    required this.adminUserId,
    required this.accessToken,
    required this.displayName,
    required this.whatsAppNumber,
    this.email,
    required this.expiresAt,
    required this.issuedAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'A';
    final first = parts.first.substring(0, 1).toUpperCase();
    if (parts.length == 1) return first;
    return '$first${parts.last.substring(0, 1).toUpperCase()}';
  }

  factory AdminAccessSession.fromJson(Map<String, dynamic> json) {
    return AdminAccessSession(
      adminUserId:
          json['admin_user_id'] as String? ??
          json['user_id'] as String? ??
          json['id'] as String? ??
          '',
      accessToken:
          json['access_token'] as String? ??
          json['accessToken'] as String? ??
          '',
      displayName:
          json['display_name'] as String? ??
          json['displayName'] as String? ??
          'Admin',
      whatsAppNumber:
          json['whatsapp_number'] as String? ??
          json['whatsAppNumber'] as String? ??
          '',
      email: json['email'] as String?,
      expiresAt: DateTime.parse(
        json['expires_at'] as String? ?? json['expiresAt'] as String? ?? '',
      ),
      issuedAt: DateTime.parse(
        json['issued_at'] as String? ?? json['issuedAt'] as String? ?? '',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'admin_user_id': adminUserId,
    'access_token': accessToken,
    'display_name': displayName,
    'whatsapp_number': whatsAppNumber,
    'email': email,
    'expires_at': expiresAt.toIso8601String(),
    'issued_at': issuedAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [
    adminUserId,
    accessToken,
    displayName,
    whatsAppNumber,
    email,
    expiresAt,
    issuedAt,
  ];
}
