import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:db_pkg/models/models.dart';
import '../services/api_invoker.dart';
import '../infrastructure/app_notification_service.dart'
    if (dart.library.html) 'app_notification_service_web.dart';
import '../services/dinein_api_service.dart';
import '../services/supabase_config.dart';

/// Repository for authentication via Supabase Auth.
class AuthRepository {
  final ApiInvoker _invoke;

  AuthRepository._() : _invoke = DineinApiService.invoke;
  static final instance = AuthRepository._();

  /// Test-only constructor that accepts a mock invoker.
  AuthRepository.forTesting({required ApiInvoker invoker}) : _invoke = invoker;

  static const _venueSessionKey = 'dinein.venue_session';
  static const _adminSessionKey = 'dinein.admin_session';
  static const _secureStorageTimeout = Duration(seconds: 2);
  static const _secureStorage = FlutterSecureStorage();

  VenueAccessSession? _venueSession;
  AdminAccessSession? _adminSession;

  SupabaseClient? get _clientOrNull {
    try {
      return SupabaseConfig.client;
    } catch (_) {
      return null;
    }
  }

  /// Sign in with email and password (4-digit PIN).
  Future<AuthResponse> signIn(String email, String password) async {
    return await SupabaseConfig.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign up a new user.
  Future<AuthResponse> signUp(String email, String password) async {
    return await SupabaseConfig.client.auth.signUp(
      email: email,
      password: password,
    );
  }

  /// Sign out.
  Future<void> signOut() async {
    final client = _clientOrNull;
    if (client != null) {
      try {
        await client.auth.signOut();
      } catch (_) {
        // Custom OTP sessions do not depend on a Supabase auth session.
      }
    }
    await clearVenueSession();
    await clearAdminSession();
  }

  /// Get the current session.
  Session? get currentSession => _clientOrNull?.auth.currentSession;

  /// Get the current user.
  User? get currentUser => _clientOrNull?.auth.currentUser;

  /// Stream of auth state changes.
  Stream<AuthState> get onAuthStateChange =>
      _clientOrNull?.auth.onAuthStateChange ?? const Stream<AuthState>.empty();

  /// Check if user is signed in.
  bool get isAuthenticated => currentUser != null;

  /// Current persisted venue-owner session.
  VenueAccessSession? get currentVenueSession {
    final session = _venueSession;
    if (session == null || session.isExpired) {
      return null;
    }
    return session;
  }

  /// Whether a venue-owner session exists.
  bool get hasVenueSession => currentVenueSession != null;

  /// Whether venue routes may be accessed.
  bool get hasVenueAccess => hasVenueSession;

  /// Current persisted admin console session.
  AdminAccessSession? get currentAdminSession {
    final session = _adminSession;
    if (session == null || session.isExpired) {
      return null;
    }
    return session;
  }

  /// Whether a valid admin session exists.
  bool get hasAdminSession => currentAdminSession != null;

  /// Whether admin routes may be accessed.
  bool get hasAdminAccess => hasAdminSession;

  /// Restore persisted venue-owner session during app bootstrap.
  Future<void> restoreVenueSession() async {
    final raw = await _readSessionValue(_venueSessionKey);
    if (raw == null || raw.isEmpty) {
      _venueSession = null;
      return;
    }

    try {
      final session = VenueAccessSession.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (session.isExpired) {
        _venueSession = null;
        await _deleteSessionValue(_venueSessionKey);
        return;
      }
      _venueSession = session;
    } catch (_) {
      _venueSession = null;
      await _deleteSessionValue(_venueSessionKey);
    }
  }

  /// Restore persisted admin session during app bootstrap.
  Future<void> restoreAdminSession() async {
    final raw = await _readSessionValue(_adminSessionKey);
    if (raw == null || raw.isEmpty) {
      _adminSession = null;
      return;
    }

    try {
      final session = AdminAccessSession.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (session.isExpired) {
        _adminSession = null;
        await _deleteSessionValue(_adminSessionKey);
        return;
      }
      _adminSession = session;
    } catch (_) {
      _adminSession = null;
      await _deleteSessionValue(_adminSessionKey);
    }
  }

  /// Persist a venue-owner session after OTP verification.
  Future<void> saveVenueSession(VenueAccessSession session) async {
    _venueSession = session;
    await _writeSessionValue(_venueSessionKey, jsonEncode(session.toJson()));
    unawaited(AppNotificationService.handleVenueSessionUpdated(session));
  }

  /// Persist an admin console session after OTP verification.
  Future<void> saveAdminSession(AdminAccessSession session) async {
    _adminSession = session;
    await _writeSessionValue(_adminSessionKey, jsonEncode(session.toJson()));
  }

  /// Clear the venue-owner session only.
  Future<void> clearVenueSession() async {
    final session = _venueSession;
    _venueSession = null;
    await _deleteSessionValue(_venueSessionKey);
    if (session != null) {
      unawaited(AppNotificationService.handleVenueSessionCleared(session));
    }
  }

  /// Clear the admin console session only.
  Future<void> clearAdminSession() async {
    _adminSession = null;
    await _deleteSessionValue(_adminSessionKey);
  }

  Future<String?> _readSessionValue(String key) async {
    try {
      return await _secureStorage.read(key: key).timeout(_secureStorageTimeout);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeSessionValue(String key, String value) async {
    try {
      await _secureStorage
          .write(key: key, value: value)
          .timeout(_secureStorageTimeout);
    } catch (_) {
      // If secure storage fails, we do not fall back to plain preferences.
    }
  }

  Future<void> _deleteSessionValue(String key) async {
    try {
      await _secureStorage.delete(key: key).timeout(_secureStorageTimeout);
    } catch (_) {
      // Ignore secure storage cleanup failures.
    }
  }

  /// Create a profile for a newly signed-up user.
  Future<void> createProfile({
    required String userId,
    String? displayName,
    String? email,
    String role = 'customer',
  }) async {
    await _invoke(
      'create_profile',
      payload: {
        'userId': userId,
        'displayName': displayName,
        'email': email,
        'role': role,
      },
    );
  }

  /// Get the current user's profile role.
  Future<String?> getUserRole(String userId) async {
    final data = await _invoke(
      'get_user_role',
      payload: {'userId': userId},
    );
    return data as String?;
  }
}
