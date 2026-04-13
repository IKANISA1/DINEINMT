import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:db_pkg/models/models.dart';
import '../services/api_invoker.dart';
import '../infrastructure/app_notification_service.dart'
    if (dart.library.js_interop) 'app_notification_service_web.dart';
import '../infrastructure/app_telemetry_service.dart'
    if (dart.library.js_interop) 'app_telemetry_service_web.dart';
import '../services/dinein_api_service.dart';
import '../services/supabase_config.dart';

/// Repository for authentication via Supabase Auth.
class AuthRepository extends ChangeNotifier {
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
      } catch (error, stackTrace) {
        // Custom OTP sessions do not depend on a Supabase auth session.
        await AppTelemetryService.reportError(
          error,
          stackTrace,
          context: 'auth.sign_out',
        );
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

  /// Restore the persisted venue session when memory is cold (for example after a web refresh).
  Future<VenueAccessSession?> ensureVenueSession() async {
    final session = currentVenueSession;
    if (session != null) return session;
    await restoreVenueSession();
    return currentVenueSession;
  }

  /// Restore the persisted admin session when memory is cold (for example after a web refresh).
  Future<AdminAccessSession?> ensureAdminSession() async {
    final session = currentAdminSession;
    if (session != null) return session;
    await restoreAdminSession();
    return currentAdminSession;
  }

  /// Whether admin routes may be accessed.
  bool get hasAdminAccess => hasAdminSession;

  /// Restore persisted venue-owner session during app bootstrap.
  Future<void> restoreVenueSession() async {
    final raw = await _readSessionValue(_venueSessionKey);
    if (raw == null || raw.isEmpty) {
      _venueSession = null;
      notifyListeners();
      return;
    }

    try {
      final session = VenueAccessSession.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (session.isExpired) {
        _venueSession = null;
        await _deleteSessionValue(_venueSessionKey);
        notifyListeners();
        return;
      }
      _venueSession = session;
    } catch (error, stackTrace) {
      _venueSession = null;
      await _deleteSessionValue(_venueSessionKey);
      await AppTelemetryService.reportError(
        error,
        stackTrace,
        context: 'auth.restore_venue_session',
      );
    }
    notifyListeners();
  }

  /// Restore persisted admin session during app bootstrap.
  Future<void> restoreAdminSession() async {
    final raw = await _readSessionValue(_adminSessionKey);
    if (raw == null || raw.isEmpty) {
      _adminSession = null;
      notifyListeners();
      return;
    }

    try {
      final session = AdminAccessSession.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (session.isExpired) {
        _adminSession = null;
        await _deleteSessionValue(_adminSessionKey);
        notifyListeners();
        return;
      }
      _adminSession = session;
    } catch (error, stackTrace) {
      _adminSession = null;
      await _deleteSessionValue(_adminSessionKey);
      await AppTelemetryService.reportError(
        error,
        stackTrace,
        context: 'auth.restore_admin_session',
      );
    }
    notifyListeners();
  }

  /// Persist a venue-owner session after OTP verification.
  Future<void> saveVenueSession(VenueAccessSession session) async {
    _venueSession = session;
    await _writeSessionValue(_venueSessionKey, jsonEncode(session.toJson()));
    notifyListeners();
    unawaited(_syncVenueSessionNotifications(session));
  }

  /// Persist an admin console session after OTP verification.
  Future<void> saveAdminSession(AdminAccessSession session) async {
    _adminSession = session;
    await _writeSessionValue(_adminSessionKey, jsonEncode(session.toJson()));
    notifyListeners();
  }

  /// Clear the venue-owner session only.
  Future<void> clearVenueSession() async {
    final session = _venueSession;
    _venueSession = null;
    await _deleteSessionValue(_venueSessionKey);
    notifyListeners();
    if (session != null) {
      unawaited(_clearVenueSessionNotifications(session));
    }
  }

  Future<void> _syncVenueSessionNotifications(
    VenueAccessSession session,
  ) async {
    try {
      await AppNotificationService.handleVenueSessionUpdated(session);
    } catch (error, stackTrace) {
      // Notification setup is best-effort and must not break auth persistence.
      await AppTelemetryService.reportError(
        error,
        stackTrace,
        context: 'auth.sync_venue_notifications',
      );
    }
  }

  Future<void> _clearVenueSessionNotifications(
    VenueAccessSession session,
  ) async {
    try {
      await AppNotificationService.handleVenueSessionCleared(session);
    } catch (error, stackTrace) {
      // Notification teardown is best-effort and must not break auth cleanup.
      await AppTelemetryService.reportError(
        error,
        stackTrace,
        context: 'auth.clear_venue_notifications',
      );
    }
  }

  /// Clear the admin console session only.
  Future<void> clearAdminSession() async {
    _adminSession = null;
    await _deleteSessionValue(_adminSessionKey);
    notifyListeners();
  }

  Future<String?> _readSessionValue(String key) async {
    try {
      return await _secureStorage.read(key: key).timeout(_secureStorageTimeout);
    } catch (error, stackTrace) {
      unawaited(
        AppTelemetryService.reportError(
          error,
          stackTrace,
          context: 'auth.secure_storage.read',
          details: {'key': key},
        ),
      );
      return null;
    }
  }

  Future<void> _writeSessionValue(String key, String value) async {
    try {
      await _secureStorage
          .write(key: key, value: value)
          .timeout(_secureStorageTimeout);
    } catch (error, stackTrace) {
      // If secure storage fails, we do not fall back to plain preferences.
      await AppTelemetryService.reportError(
        error,
        stackTrace,
        context: 'auth.secure_storage.write',
        details: {'key': key},
      );
    }
  }

  Future<void> _deleteSessionValue(String key) async {
    try {
      await _secureStorage.delete(key: key).timeout(_secureStorageTimeout);
    } catch (error, stackTrace) {
      // Ignore secure storage cleanup failures.
      await AppTelemetryService.reportError(
        error,
        stackTrace,
        context: 'auth.secure_storage.delete',
        details: {'key': key},
      );
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
    final data = await _invoke('get_user_role', payload: {'userId': userId});
    return data as String?;
  }
}
