part of 'models.dart';

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

  bool get isPopular =>
      isGuestHighlight || tags.any((tag) => _isPopularMenuTag(tag));

  bool get isSignature => tags.any((tag) => _isSignatureMenuTag(tag));

  String? get guestHighlightLabel {
    if (isPopular) return 'Popular';
    if (isSignature) return 'Signature';
    return null;
  }

  List<String> get dietaryBadges {
    final badges = <String>[];
    for (final tag in tags) {
      final normalized = _normalizeDietaryMenuTag(tag);
      if (normalized == null || badges.contains(normalized)) continue;
      badges.add(normalized);
    }
    return badges;
  }

  List<String> get guestDisplayTags {
    final badges = <String>[];
    final highlight = guestHighlightLabel;
    if (highlight != null) badges.add(highlight);
    badges.addAll(dietaryBadges);

    for (final tag in tags) {
      final trimmed = tag.trim();
      if (trimmed.isEmpty) continue;
      if (_isPopularMenuTag(trimmed) ||
          _isSignatureMenuTag(trimmed) ||
          _normalizeDietaryMenuTag(trimmed) != null) {
        continue;
      }
      if (badges.any(
        (existing) => existing.toLowerCase() == trimmed.toLowerCase(),
      )) {
        continue;
      }
      badges.add(trimmed);
    }

    return badges;
  }

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
