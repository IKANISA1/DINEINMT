part of 'models.dart';

/// Persisted venue-owner access session for WhatsApp-based portal login.
class VenueAccessSession extends Equatable {
  final String accessToken;
  final String venueId;
  final String venueName;
  final String? venueSlug;
  final String whatsAppNumber;
  final String? venueImageUrl;
  final DateTime issuedAt;
  final DateTime expiresAt;

  const VenueAccessSession({
    required this.accessToken,
    required this.venueId,
    required this.venueName,
    this.venueSlug,
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
      venueSlug: json['venue_slug'] as String? ?? json['venueSlug'] as String?,
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
    'venue_slug': venueSlug,
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
    venueSlug,
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
