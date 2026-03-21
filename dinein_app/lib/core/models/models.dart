import 'package:equatable/equatable.dart';
import '../constants/enums.dart';

String normalizeVenueCategoryLabel(
  String? value, {
  String fallback = 'Restaurants',
}) {
  final normalized = (value ?? '').trim().toLowerCase();
  if (normalized.isEmpty) return fallback;
  if (normalized.contains('hotel')) return 'Hotels';
  if (normalized.contains('bar') && normalized.contains('restaurant')) {
    return 'Bar & Restaurants';
  }
  if (normalized.contains('bar')) return 'Bar';
  if (normalized.contains('restaurant')) return 'Restaurants';
  return fallback;
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
  final String? email;
  final String? imageUrl;
  final String? revolutUrl;
  final VenueStatus status;
  final double rating;
  final int ratingCount;
  final Country country;
  final Map<String, OpeningHours>? openingHours;
  final String? ownerId;
  final List<Review>? reviews;
  final String? wifiSsid;
  final String? wifiPassword;
  final String? wifiSecurity;

  const Venue({
    required this.id,
    required this.name,
    required this.slug,
    required this.category,
    required this.description,
    required this.address,
    this.phone,
    this.email,
    this.imageUrl,
    this.revolutUrl,
    this.status = VenueStatus.active,
    this.rating = 0.0,
    this.ratingCount = 0,
    this.country = Country.mt,
    this.openingHours,
    this.ownerId,
    this.reviews,
    this.wifiSsid,
    this.wifiPassword,
    this.wifiSecurity,
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
      email: json['email'] as String?,
      imageUrl: json['image_url'] as String?,
      revolutUrl: json['revolut_url'] as String?,
      status: VenueStatus.fromString(json['status'] as String? ?? 'active'),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: json['rating_count'] as int? ?? 0,
      country: Country.fromCode(json['country'] as String? ?? 'MT'),
      ownerId: json['owner_id'] as String?,
      reviews: (json['reviews'] as List<dynamic>?)
          ?.map((r) => Review.fromJson(r as Map<String, dynamic>))
          .toList(),
      wifiSsid: json['wifi_ssid'] as String?,
      wifiPassword: json['wifi_password'] as String?,
      wifiSecurity: json['wifi_security'] as String?,
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
    'email': email,
    'image_url': imageUrl,
    'revolut_url': revolutUrl,
    'status': status.dbValue,
    'rating': rating,
    'rating_count': ratingCount,
    'country': country.code,
    'owner_id': ownerId,
    'wifi_ssid': wifiSsid,
    'wifi_password': wifiPassword,
    'wifi_security': wifiSecurity,
  };

  /// Whether this venue is currently accepting orders.
  bool get isOpen => status == VenueStatus.active;

  /// Whether this venue has WiFi credentials configured for guests.
  bool get hasWifi => wifiSsid != null && wifiSsid!.trim().isNotEmpty;

  @override
  List<Object?> get props => [
    id,
    slug,
    name,
    category,
    address,
    revolutUrl,
    status,
    country,
    ownerId,
    reviews,
    wifiSsid,
    wifiPassword,
    wifiSecurity,
  ];
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

  @override
  List<Object?> get props => [open, close, isOpen];
}

/// A menu item belonging to a venue.
class MenuItem extends Equatable {
  final String id;
  final String venueId;
  final String name;
  final String description;
  final double price;
  final String category;
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
    required this.name,
    required this.description,
    required this.price,
    required this.category,
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
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      price: (json['price'] as num).toDouble(),
      category: json['category'] as String? ?? 'Uncategorized',
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
    'venue_id': venueId,
    'name': name,
    'description': description,
    'price': price,
    'category': category,
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
    String? name,
    String? description,
    double? price,
    String? category,
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
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
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
    name,
    description,
    price,
    category,
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
  final String venueId;
  final String venueName;
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
    required this.venueId,
    required this.venueName,
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
      venueId: json['venue_id'] as String,
      venueName: json['venue_name'] as String,
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
    'venue_id': venueId,
    'venue_name': venueName,
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

  double get subtotal =>
      subtotalAmount ?? items.fold(0.0, (sum, item) => sum + item.subtotal);

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  double get serviceFee {
    if (serviceFeeAmount != null) return serviceFeeAmount!;
    final derived = total - subtotal;
    return derived > 0 ? derived : 0;
  }

  /// Currency symbol derived from venue country.
  /// Currently Malta-only; when multi-country is added,
  /// store country on the order and derive from that.
  String get currencySymbol => Country.mt.currencySymbol;

  @override
  List<Object?> get props => [
    id,
    venueId,
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

/// A venue ownership claim submitted by a prospective owner.
class VenueClaim extends Equatable {
  final String id;
  final String venueId;
  final String venueName;
  final String venueArea;
  final String contactPhone;
  final String? claimantName;
  final ClaimStatus status;
  final DateTime createdAt;

  const VenueClaim({
    required this.id,
    required this.venueId,
    required this.venueName,
    required this.venueArea,
    required this.contactPhone,
    this.claimantName,
    this.status = ClaimStatus.pending,
    required this.createdAt,
  });

  factory VenueClaim.fromJson(Map<String, dynamic> json) {
    return VenueClaim(
      id: json['id'] as String,
      venueId: json['venue_id'] as String,
      venueName: json['venue_name'] as String? ?? '',
      venueArea: json['venue_area'] as String? ?? '',
      contactPhone:
          json['whatsapp_number'] as String? ??
          json['contact_phone'] as String? ??
          json['email'] as String? ??
          '',
      claimantName: json['claimant_name'] as String?,
      status: ClaimStatus.fromString(json['status'] as String? ?? 'pending'),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'venue_id': venueId,
    'venue_name': venueName,
    'venue_area': venueArea,
    'whatsapp_number': contactPhone,
    'claimant_name': claimantName,
    'status': status.dbValue,
  };

  /// Backward-compatible alias used by older admin screens.
  String get email => contactPhone;

  String get displayName {
    final explicitName = claimantName?.trim();
    if (explicitName != null && explicitName.isNotEmpty) {
      return explicitName;
    }

    if (contactPhone.contains('@')) {
      return contactPhone.split('@').first;
    }

    final digits = contactPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 4) {
      return 'Owner ${digits.substring(digits.length - 4)}';
    }

    return contactPhone;
  }

  @override
  List<Object?> get props => [id, venueId, contactPhone, claimantName, status];
}
