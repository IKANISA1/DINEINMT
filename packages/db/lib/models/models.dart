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
    'vegetarian' || 'veg' => 'Vegetarian',
    'vegan' => 'Vegan',
    'halal' => 'Halal',
    'gluten free' || 'gluten-free' || 'gf' => 'Gluten-Free',
    _ => null,
  };
}

int? _minutesSinceMidnight(String raw) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw.trim());
  if (match == null) return null;
  final hours = int.tryParse(match.group(1) ?? '');
  final minutes = int.tryParse(match.group(2) ?? '');
  if (hours == null || minutes == null) return null;
  if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) return null;
  return hours * 60 + minutes;
}

double _degreesToRadians(double degrees) =>
    degrees * (3.1415926535897932 / 180);
