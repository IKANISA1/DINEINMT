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

/// Payment methods per market.
/// - Revolut link opens outside app (Malta, no API)
/// - MoMo USSD launches outside app (Rwanda, no API)
/// - Cash always available.
enum PaymentMethod {
  cash,
  revolutLink,
  momoUssd;

  String get label {
    return switch (this) {
      PaymentMethod.cash => 'Cash',
      PaymentMethod.revolutLink => 'Revolut',
      PaymentMethod.momoUssd => 'MoMo',
    };
  }

  String get description {
    return switch (this) {
      PaymentMethod.cash => 'Pay at the venue',
      PaymentMethod.revolutLink => 'Pay via Revolut link',
      PaymentMethod.momoUssd => 'Pay via MoMo mobile money',
    };
  }

  /// Database string value.
  String get dbValue {
    return switch (this) {
      PaymentMethod.cash => 'cash',
      PaymentMethod.revolutLink => 'revolut_link',
      PaymentMethod.momoUssd => 'momo_ussd',
    };
  }

  /// Parse from database string.
  static PaymentMethod fromString(String value) {
    return switch (value) {
      'revolut_link' => PaymentMethod.revolutLink,
      'momo_ussd' => PaymentMethod.momoUssd,
      _ => PaymentMethod.cash,
    };
  }
}

/// Supported countries.
/// Country is auto-derived from venue context, never manually picked.
enum Country {
  mt,
  rw;

  String get label {
    return switch (this) {
      Country.mt => 'Malta',
      Country.rw => 'Rwanda',
    };
  }

  String get code {
    return switch (this) {
      Country.mt => 'MT',
      Country.rw => 'RW',
    };
  }

  String get currency {
    return switch (this) {
      Country.mt => 'EUR',
      Country.rw => 'RWF',
    };
  }

  String get currencySymbol {
    return switch (this) {
      Country.mt => '€',
      Country.rw => 'RWF',
    };
  }

  /// Format an amount with the correct currency symbol and locale rules.
  ///
  /// - **Malta (MT)**: `€12.34` — 2 decimal places, comma thousands for ≥1000.
  /// - **Rwanda (RW)**: `RWF 12,345` — 0 decimal places, comma thousands.
  String formatPrice(double amount) {
    switch (this) {
      case Country.rw:
        final rounded = amount.round();
        // Insert comma thousands separators.
        final digits = rounded.abs().toString();
        final buffer = StringBuffer();
        for (var i = 0; i < digits.length; i++) {
          if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
          buffer.write(digits[i]);
        }
        final formatted = rounded < 0 ? '-${buffer.toString()}' : buffer.toString();
        return 'RWF $formatted';

      case Country.mt:
        final fixed = amount.toStringAsFixed(2);
        // Split into integer and decimal parts.
        final parts = fixed.split('.');
        final intPart = parts[0];
        final decPart = parts.length > 1 ? parts[1] : '00';
        // Insert comma thousands separators for the integer part.
        final absInt = intPart.startsWith('-') ? intPart.substring(1) : intPart;
        final buffer = StringBuffer();
        for (var i = 0; i < absInt.length; i++) {
          if (i > 0 && (absInt.length - i) % 3 == 0) buffer.write(',');
          buffer.write(absInt[i]);
        }
        final formattedInt = intPart.startsWith('-') ? '-${buffer.toString()}' : buffer.toString();
        return '€$formattedInt.$decPart';
    }
  }
  /// Format an amount with 2 decimal places for tabular/report alignment.
  ///
  /// Unlike [formatPrice], this always uses 2 decimal places regardless of
  /// currency, ensuring flush column alignment in data-dense screens.
  ///
  /// - **Malta (MT)**: `€12,345.00` (same as formatPrice)
  /// - **Rwanda (RW)**: `RWF 12,345.00` (adds `.00` for alignment)
  String formatPriceTabular(double amount) {
    final fixed = amount.toStringAsFixed(2);
    final parts = fixed.split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? parts[1] : '00';
    final absInt = intPart.startsWith('-') ? intPart.substring(1) : intPart;
    final buffer = StringBuffer();
    for (var i = 0; i < absInt.length; i++) {
      if (i > 0 && (absInt.length - i) % 3 == 0) buffer.write(',');
      buffer.write(absInt[i]);
    }
    final formattedInt =
        intPart.startsWith('-') ? '-${buffer.toString()}' : buffer.toString();
    return '${currencySymbol == '€' ? '€' : '$currencySymbol '}$formattedInt.$decPart';
  }

  /// Available payment methods per country.
  List<PaymentMethod> get paymentMethods {
    return switch (this) {
      Country.mt => [PaymentMethod.cash, PaymentMethod.revolutLink],
      Country.rw => [PaymentMethod.cash, PaymentMethod.momoUssd],
    };
  }

  /// Parse from database country code.
  static Country fromCode(String code) {
    return switch (code.toUpperCase()) {
      'RW' => Country.rw,
      _ => Country.mt,
    };
  }
}

/// Venue status.
enum VenueStatus {
  active,
  inactive,
  maintenance,
  suspended,
  deleted;

  String get label {
    return switch (this) {
      VenueStatus.active => 'Active',
      VenueStatus.inactive => 'Inactive',
      VenueStatus.maintenance => 'Maintenance',
      VenueStatus.suspended => 'Suspended',
      VenueStatus.deleted => 'Deleted',
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
      _ => VenueStatus.inactive,
    };
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

/// Menu item classification used to separate food from drinks.
enum MenuItemClass {
  food,
  drinks;

  String get dbValue => name;

  String get label {
    return switch (this) {
      MenuItemClass.food => 'Food',
      MenuItemClass.drinks => 'Drinks',
    };
  }

  static MenuItemClass? fromString(String? value) {
    return switch (value) {
      'food' => MenuItemClass.food,
      'drinks' => MenuItemClass.drinks,
      _ => null,
    };
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
