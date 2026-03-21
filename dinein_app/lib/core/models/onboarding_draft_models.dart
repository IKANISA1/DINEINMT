import 'models.dart';

class ClaimedVenueDraft {
  final String? venueId;
  final String name;
  final String address;
  final String category;
  final String description;
  final String? imageUrl;
  final String? contactPhone;
  final String? contactEmail;
  final bool claimSubmitted;

  const ClaimedVenueDraft({
    this.venueId,
    required this.name,
    required this.address,
    required this.category,
    required this.description,
    this.imageUrl,
    this.contactPhone,
    this.contactEmail,
    this.claimSubmitted = false,
  });

  factory ClaimedVenueDraft.fromVenue(Venue venue) {
    return ClaimedVenueDraft(
      venueId: venue.id,
      name: venue.name,
      address: venue.address,
      category: normalizeVenueCategoryLabel(venue.category),
      description: venue.description,
      imageUrl: venue.imageUrl,
      contactPhone: venue.phone,
      contactEmail: venue.email,
    );
  }

  factory ClaimedVenueDraft.fromJson(Map<String, dynamic> json) {
    return ClaimedVenueDraft(
      venueId: json['venue_id'] as String?,
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      category: normalizeVenueCategoryLabel(json['category'] as String?),
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      contactPhone: json['contact_phone'] as String?,
      contactEmail: json['contact_email'] as String?,
      claimSubmitted: json['claim_submitted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'venue_id': venueId,
    'name': name,
    'address': address,
    'category': category,
    'description': description,
    'image_url': imageUrl,
    'contact_phone': contactPhone,
    'contact_email': contactEmail,
    'claim_submitted': claimSubmitted,
  };

  ClaimedVenueDraft copyWith({
    String? venueId,
    String? name,
    String? address,
    String? category,
    String? description,
    String? imageUrl,
    String? contactPhone,
    String? contactEmail,
    bool? claimSubmitted,
  }) {
    return ClaimedVenueDraft(
      venueId: venueId ?? this.venueId,
      name: name ?? this.name,
      address: address ?? this.address,
      category: category ?? this.category,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      claimSubmitted: claimSubmitted ?? this.claimSubmitted,
    );
  }
}

class OcrDraftMenuItem {
  final String name;
  final String description;
  final double price;
  final String category;
  final List<String> tags;
  final bool requiresReview;

  const OcrDraftMenuItem({
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    this.tags = const [],
    this.requiresReview = false,
  });

  factory OcrDraftMenuItem.fromJson(Map<String, dynamic> json) {
    return OcrDraftMenuItem(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String? ?? 'General',
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
      requiresReview: json['requires_review'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'price': price,
    'category': category,
    'tags': tags,
    'requires_review': requiresReview,
  };

  OcrDraftMenuItem copyWith({
    String? name,
    String? description,
    double? price,
    String? category,
    List<String>? tags,
    bool? requiresReview,
  }) {
    return OcrDraftMenuItem(
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      requiresReview: requiresReview ?? this.requiresReview,
    );
  }

  MenuItem toMenuItem(String venueId, {String? id}) {
    return MenuItem(
      id: id ?? '',
      venueId: venueId,
      name: name,
      description: description,
      price: price,
      category: category,
      tags: tags,
      isAvailable: true,
    );
  }
}
