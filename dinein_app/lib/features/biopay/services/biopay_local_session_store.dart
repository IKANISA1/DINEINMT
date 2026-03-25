import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/biopay_models.dart';

typedef BiopaySecureRead = Future<String?> Function(String key);
typedef BiopaySecureWrite = Future<bool> Function(String key, String value);
typedef BiopaySecureDelete = Future<void> Function(String key);

/// Persists the local BioPay owner token securely on-device.
///
/// Secure storage is mandatory for BioPay session tokens.
class BiopayLocalSessionStore {
  BiopayLocalSessionStore({
    BiopaySecureRead? secureRead,
    BiopaySecureWrite? secureWrite,
    BiopaySecureDelete? secureDelete,
  }) : _secureRead = secureRead ?? _defaultSecureRead,
       _secureWrite = secureWrite ?? _defaultSecureWrite,
       _secureDelete = secureDelete ?? _defaultSecureDelete;

  static const storageKey = 'dinein.biopay.local_session';
  static const _secureStorageTimeout = Duration(seconds: 2);
  static const _secureStorage = FlutterSecureStorage();

  final BiopaySecureRead _secureRead;
  final BiopaySecureWrite _secureWrite;
  final BiopaySecureDelete _secureDelete;

  Future<BiopayLocalSession?> load() async {
    final secureRaw = await _secureRead(storageKey);
    if (secureRaw == null || secureRaw.isEmpty) {
      return null;
    }

    final parsed = _tryParse(secureRaw);
    if (parsed == null) {
      await clear();
      return null;
    }

    return parsed;
  }

  Future<void> save(BiopayLocalSession session) async {
    final raw = jsonEncode(session.toJson());
    await _secureWrite(storageKey, raw);
  }

  Future<void> clear() async {
    await _secureDelete(storageKey);
  }

  BiopayLocalSession? _tryParse(String raw) {
    try {
      return BiopayLocalSession.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _defaultSecureRead(String key) async {
    try {
      return await _secureStorage.read(key: key).timeout(_secureStorageTimeout);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _defaultSecureWrite(String key, String value) async {
    try {
      await _secureStorage
          .write(key: key, value: value)
          .timeout(_secureStorageTimeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _defaultSecureDelete(String key) async {
    try {
      await _secureStorage.delete(key: key).timeout(_secureStorageTimeout);
    } catch (_) {
      // Ignore secure storage cleanup failures in test environments.
    }
  }
}
