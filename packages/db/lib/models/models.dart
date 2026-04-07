import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:core_pkg/constants/enums.dart';

// Domain part files — each contains one logical group of model classes.
// All classes remain in the same library scope, so private helpers below are 
// accessible from every part file and all existing imports continue to work.
part 'venue.dart';
part 'menu_item.dart';
part 'order.dart';
part 'auth_session.dart';

// ---------------------------------------------------------------------------
// Shared private helpers used by model factories across part files.
// ---------------------------------------------------------------------------

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

/// All venues are treated as restaurants — category differentiation removed.
String normalizeVenueCategoryLabel(
  String? value, {
  String fallback = 'Restaurant',
}) {
  return fallback;
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

Map<String, dynamic>? _parseJsonMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((key, value) => MapEntry('$key', value));
  }
  return null;
}

double? _doubleFromDynamic(Object? raw) {
  return switch (raw) {
    num value => value.toDouble(),
    String value => double.tryParse(value),
    _ => null,
  };
}

List<PaymentMethod> _parseSupportedPaymentMethods(
  Object? raw, {
  String? revolutUrl,
  String? momoCode,
}) {
  final parsed = <PaymentMethod>[];
  if (raw is List) {
    for (final value in raw) {
      final method = switch (value) {
        'cash' => PaymentMethod.cash,
        'revolut_link' => PaymentMethod.revolutLink,
        'momo_ussd' => PaymentMethod.momoUssd,
        _ => null,
      };
      if (method != null && !parsed.contains(method)) {
        parsed.add(method);
      }
    }
  }

  if (parsed.isNotEmpty) return parsed;

  // Fallback: infer payment methods from configured payment links/codes.
  if ((revolutUrl ?? '').trim().isNotEmpty) {
    return const [PaymentMethod.cash, PaymentMethod.revolutLink];
  }

  if ((momoCode ?? '').trim().isNotEmpty) {
    return const [PaymentMethod.cash, PaymentMethod.momoUssd];
  }

  return const [PaymentMethod.cash];
}

const Object _menuItemNoChange = Object();

bool _isPopularMenuTag(String raw) {
  final normalized = raw.trim().toLowerCase();
  return normalized == 'popular' ||
      normalized == 'bestseller' ||
      normalized == 'best seller' ||
      normalized == 'house favorite' ||
      normalized == 'house favourite';
}

bool _isSignatureMenuTag(String raw) {
  final normalized = raw.trim().toLowerCase();
  return normalized == 'signature' || normalized == 'chef special';
}

String? _normalizeDietaryMenuTag(String raw) {
  final normalized = raw.trim().toLowerCase();
  return switch (normalized) {
    // Dietary labels
    'vegetarian' || 'veg' => 'Vegetarian',
    'vegan' => 'Vegan',
    'halal' => 'Halal',
    'kosher' => 'Kosher',
    // EU 14 mandatory allergens
    'gluten free' || 'gluten-free' || 'gf' => 'Gluten-Free',
    'dairy free' || 'dairy-free' || 'lactose free' || 'lactose-free' =>
      'Dairy-Free',
    'nut free' || 'nut-free' || 'tree nut free' => 'Nut-Free',
    'peanut free' || 'peanut-free' => 'Peanut-Free',
    'egg free' || 'egg-free' => 'Egg-Free',
    'soy free' || 'soy-free' || 'soya free' => 'Soy-Free',
    'fish free' || 'fish-free' => 'Fish-Free',
    'shellfish free' || 'shellfish-free' || 'crustacean free' =>
      'Shellfish-Free',
    'sesame free' || 'sesame-free' => 'Sesame-Free',
    'celery free' || 'celery-free' => 'Celery-Free',
    'mustard free' || 'mustard-free' => 'Mustard-Free',
    'sulphite free' || 'sulphite-free' || 'sulfite free' || 'sulfite-free' =>
      'Sulphite-Free',
    'lupin free' || 'lupin-free' => 'Lupin-Free',
    'mollusc free' || 'mollusc-free' || 'mollusk free' => 'Mollusc-Free',
    // Contains-style tags (also useful for EU disclosure)
    'contains nuts' || 'contains tree nuts' => 'Contains Nuts',
    'contains gluten' || 'contains wheat' => 'Contains Gluten',
    'contains dairy' || 'contains milk' || 'contains lactose' =>
      'Contains Dairy',
    'contains eggs' || 'contains egg' => 'Contains Eggs',
    'contains soy' || 'contains soya' => 'Contains Soy',
    'contains fish' => 'Contains Fish',
    'contains shellfish' || 'contains crustaceans' => 'Contains Shellfish',
    'contains sesame' => 'Contains Sesame',
    'contains peanuts' || 'contains peanut' => 'Contains Peanuts',
    'spicy' || 'hot' => 'Spicy',
    _ => null,
  };
}



double _degreesToRadians(double degrees) =>
    degrees * (3.1415926535897932 / 180);
