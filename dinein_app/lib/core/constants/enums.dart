/// DineIn order status values.
/// Per STARTER RULES: Placed → Received → Served, or Cancelled.
/// NO delivery statuses. NO "preparing".
enum OrderStatus {
  placed,
  received,
  served,
  cancelled;

  String get label {
    return switch (this) {
      OrderStatus.placed => 'Placed',
      OrderStatus.received => 'Received',
      OrderStatus.served => 'Served',
      OrderStatus.cancelled => 'Cancelled',
    };
  }

  /// Database string value.
  String get dbValue => name;

  /// Parse from database string.
  static OrderStatus fromString(String value) {
    return OrderStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => OrderStatus.placed,
    );
  }

  bool get isActive => this == placed || this == received;
  bool get isTerminal => this == served || this == cancelled;

  /// Order of progression for tracking UI.
  int get stepIndex {
    return switch (this) {
      OrderStatus.placed => 0,
      OrderStatus.received => 1,
      OrderStatus.served => 2,
      OrderStatus.cancelled => -1,
    };
  }
}

/// Payment methods (Malta market).
/// - Revolut link opens outside app (no API)
/// - Cash always available.
enum PaymentMethod {
  cash,
  revolutLink;

  String get label {
    return switch (this) {
      PaymentMethod.cash => 'Cash',
      PaymentMethod.revolutLink => 'Revolut',
    };
  }

  String get description {
    return switch (this) {
      PaymentMethod.cash => 'Pay at the venue',
      PaymentMethod.revolutLink => 'Pay via Revolut link',
    };
  }

  /// Database string value.
  String get dbValue {
    return switch (this) {
      PaymentMethod.cash => 'cash',
      PaymentMethod.revolutLink => 'revolut_link',
    };
  }

  /// Parse from database string.
  static PaymentMethod fromString(String value) {
    return switch (value) {
      'revolut_link' => PaymentMethod.revolutLink,
      _ => PaymentMethod.cash,
    };
  }
}

/// Supported country — Malta only.
/// Country is auto-derived from venue context, never manually picked.
enum Country {
  mt;

  String get label => 'Malta';

  String get code => 'MT';

  String get currency => 'EUR';

  String get currencySymbol => '€';

  /// Available payment methods.
  List<PaymentMethod> get paymentMethods {
    return [PaymentMethod.cash, PaymentMethod.revolutLink];
  }

  /// Parse from database country code.
  static Country fromCode(String code) => Country.mt;
}

/// Venue status.
enum VenueStatus {
  active,
  inactive,
  maintenance,
  suspended,
  deleted,
  pendingClaim,
  pendingActivation;

  String get label {
    return switch (this) {
      VenueStatus.active => 'Active',
      VenueStatus.inactive => 'Inactive',
      VenueStatus.maintenance => 'Maintenance',
      VenueStatus.suspended => 'Suspended',
      VenueStatus.deleted => 'Deleted',
      VenueStatus.pendingClaim => 'Pending Claim',
      VenueStatus.pendingActivation => 'Pending Activation',
    };
  }

  /// Database string value.
  String get dbValue {
    return switch (this) {
      VenueStatus.active => 'active',
      VenueStatus.inactive => 'inactive',
      VenueStatus.maintenance => 'maintenance',
      VenueStatus.suspended => 'suspended',
      VenueStatus.deleted => 'deleted',
      VenueStatus.pendingClaim => 'pending_claim',
      VenueStatus.pendingActivation => 'pending_activation',
    };
  }

  /// Parse from database string.
  static VenueStatus fromString(String value) {
    return switch (value) {
      'active' => VenueStatus.active,
      'inactive' => VenueStatus.inactive,
      'maintenance' => VenueStatus.maintenance,
      'suspended' => VenueStatus.suspended,
      'deleted' => VenueStatus.deleted,
      'pending_claim' => VenueStatus.pendingClaim,
      'pending_activation' => VenueStatus.pendingActivation,
      _ => VenueStatus.active,
    };
  }
}

/// Venue claim status.
enum ClaimStatus {
  pending,
  approved,
  rejected;

  String get label {
    return switch (this) {
      ClaimStatus.pending => 'Pending',
      ClaimStatus.approved => 'Approved',
      ClaimStatus.rejected => 'Rejected',
    };
  }

  String get dbValue => name;

  static ClaimStatus fromString(String value) {
    return ClaimStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ClaimStatus.pending,
    );
  }
}

/// AI image generation lifecycle for menu items.
enum MenuItemImageStatus {
  pending,
  generating,
  ready,
  failed;

  String get dbValue => name;

  String get label {
    return switch (this) {
      MenuItemImageStatus.pending => 'Pending',
      MenuItemImageStatus.generating => 'Generating',
      MenuItemImageStatus.ready => 'Ready',
      MenuItemImageStatus.failed => 'Failed',
    };
  }

  static MenuItemImageStatus fromString(String value) {
    return MenuItemImageStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => MenuItemImageStatus.pending,
    );
  }
}

/// Origin of the current menu image.
enum MenuItemImageSource {
  unknown,
  manual,
  aiGemini;

  String? get dbValue {
    return switch (this) {
      MenuItemImageSource.unknown => null,
      MenuItemImageSource.manual => 'manual',
      MenuItemImageSource.aiGemini => 'ai_gemini',
    };
  }

  String get label {
    return switch (this) {
      MenuItemImageSource.unknown => 'Unknown',
      MenuItemImageSource.manual => 'Manual',
      MenuItemImageSource.aiGemini => 'Gemini AI',
    };
  }

  static MenuItemImageSource fromString(String? value) {
    return switch (value) {
      'manual' => MenuItemImageSource.manual,
      'ai_gemini' => MenuItemImageSource.aiGemini,
      _ => MenuItemImageSource.unknown,
    };
  }
}
