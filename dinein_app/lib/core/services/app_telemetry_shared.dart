import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dinein_api_service.dart';

const _guestTelemetrySessionKey = 'dinein_guest_session_id_v1';

String? _guestTelemetrySessionId;
Future<void>? _guestTelemetryInitialization;

Future<void> initializeGuestTelemetrySession() async {
  if (_guestTelemetrySessionId != null) return;
  if (_guestTelemetryInitialization != null) {
    return _guestTelemetryInitialization!;
  }

  _guestTelemetryInitialization = _loadOrCreateGuestTelemetrySession();
  await _guestTelemetryInitialization!;
  _guestTelemetryInitialization = null;
}

String? currentGuestTelemetrySessionId() => _guestTelemetrySessionId;

Future<void> _loadOrCreateGuestTelemetrySession() async {
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(_guestTelemetrySessionKey)?.trim();
  if (existing != null && existing.isNotEmpty) {
    _guestTelemetrySessionId = existing;
    return;
  }

  final created = _generateGuestTelemetrySessionId();
  await prefs.setString(_guestTelemetrySessionKey, created);
  _guestTelemetrySessionId = created;
}

String _generateGuestTelemetrySessionId() {
  final random = Random();
  final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final entropy = List.generate(
    12,
    (_) => random.nextInt(36).toRadixString(36),
  ).join();
  return 'guest-$stamp-$entropy';
}

Future<void> recordGuestTelemetryEvent(
  String eventName, {
  String? route,
  String? venueId,
  String? menuItemId,
  String? orderId,
  Map<String, Object?> details = const {},
}) async {
  await initializeGuestTelemetrySession();

  final normalizedDetails = _sanitizeTelemetryMap(details);

  try {
    await DineinApiService.invoke(
      'track_guest_event',
      extraHeaders: const {'X-DineIn-Offline-Queue': 'telemetry'},
      payload: {
        'event_name': eventName,
        'session_id': _guestTelemetrySessionId,
        'route': route,
        'venue_id': venueId,
        'menu_item_id': menuItemId,
        'order_id': orderId,
        'details': normalizedDetails,
      },
    );
  } catch (error, stackTrace) {
    debugPrint('[telemetry] Failed to record event "$eventName": $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

Map<String, Object?> _sanitizeTelemetryMap(Map<String, Object?> values) {
  final normalized = <String, Object?>{};
  for (final entry in values.entries) {
    final key = entry.key.trim();
    if (key.isEmpty) continue;
    final value = _sanitizeTelemetryValue(entry.value);
    if (value == null) continue;
    normalized[key] = value;
  }
  return normalized;
}

Object? _sanitizeTelemetryValue(Object? value) {
  if (value == null) return null;
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is num || value is bool) return value;
  if (value is DateTime) return value.toIso8601String();
  if (value is Map<String, Object?>) return _sanitizeTelemetryMap(value);
  if (value is Iterable) {
    final items = value
        .map((item) => _sanitizeTelemetryValue(item))
        .whereType<Object>()
        .toList(growable: false);
    return items.isEmpty ? null : items;
  }
  return value.toString();
}
