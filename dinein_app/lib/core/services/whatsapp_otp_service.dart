import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:db_pkg/models/models.dart';
import 'supabase_config.dart';

class WhatsAppOtpChallenge {
  final String verificationId;
  final DateTime expiresAt;
  final String? debugCode;
  final bool usesMock;

  const WhatsAppOtpChallenge({
    required this.verificationId,
    required this.expiresAt,
    this.debugCode,
    required this.usesMock,
  });
}

class WhatsAppOtpVerificationResult {
  final bool verified;
  final String? reason;
  final int? remainingAttempts;
  final DateTime? verifiedAt;
  final AdminAccessSession? adminSession;
  final VenueAccessSession? venueSession;

  const WhatsAppOtpVerificationResult({
    required this.verified,
    this.reason,
    this.remainingAttempts,
    this.verifiedAt,
    this.adminSession,
    this.venueSession,
  });
}

@immutable
class WhatsAppOtpException implements Exception {
  final String message;
  final String? reason;
  final int? statusCode;

  const WhatsAppOtpException({
    required this.message,
    this.reason,
    this.statusCode,
  });

  @override
  String toString() => message;
}

/// WhatsApp OTP transport backed by the Supabase Edge Function `whatsapp-otp`.
///
/// Local app-side mocking is disabled by default so backend misconfiguration
/// does not silently bypass venue verification. If needed for isolated UI work:
/// `--dart-define=WHATSAPP_OTP_ALLOW_LOCAL_MOCK=true`
class WhatsAppOtpService {
  WhatsAppOtpService._();

  static final instance = WhatsAppOtpService._();

  static const _functionName = String.fromEnvironment(
    'WHATSAPP_OTP_FUNCTION_NAME',
    defaultValue: 'whatsapp-otp',
  );
  static const _allowLocalMockFlag = String.fromEnvironment(
    'WHATSAPP_OTP_ALLOW_LOCAL_MOCK',
    defaultValue: 'false',
  );
  static const _defaultCountryCode = String.fromEnvironment(
    'DEFAULT_WHATSAPP_COUNTRY_CODE',
    defaultValue: '356',
  );
  static const _mockKeyPrefix = 'dinein.whatsapp_otp.';

  bool get _allowLocalMock =>
      _allowLocalMockFlag.toLowerCase() == 'true' || _allowLocalMockFlag == '1';

  Future<WhatsAppOtpChallenge> sendOtp(
    String phone, {
    String appScope = 'venue',
  }) async {
    final normalizedPhone = _normalizePhone(phone);
    if (normalizedPhone.isEmpty) {
      throw const WhatsAppOtpException(
        message: 'A valid WhatsApp number is required.',
        reason: 'invalid_phone',
      );
    }

    try {
      return await _sendRemote(normalizedPhone, appScope: appScope);
    } catch (error) {
      if (!_allowLocalMock || _shouldRethrowSendError(error)) rethrow;
    }

    return _sendMock(normalizedPhone);
  }

  Future<bool> verifyOtp({
    required String phone,
    required String verificationId,
    required String code,
    String appScope = 'venue',
  }) async {
    final result = await verifyOtpDetailed(
      phone: phone,
      verificationId: verificationId,
      code: code,
      appScope: appScope,
    );
    return result.verified;
  }

  Future<WhatsAppOtpVerificationResult> verifyOtpDetailed({
    required String phone,
    required String verificationId,
    required String code,
    String appScope = 'venue',
  }) async {
    final normalizedPhone = _normalizePhone(phone);
    final normalizedCode = code.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalizedPhone.isEmpty || normalizedCode.length != 6) {
      return const WhatsAppOtpVerificationResult(verified: false);
    }

    try {
      return await _verifyRemote(
        phone: normalizedPhone,
        verificationId: verificationId,
        code: normalizedCode,
        appScope: appScope,
      );
    } catch (_) {
      if (!_allowLocalMock) rethrow;
    }

    return _verifyMock(
      phone: normalizedPhone,
      verificationId: verificationId,
      code: normalizedCode,
    );
  }

  Future<WhatsAppOtpChallenge> _sendRemote(
    String phone, {
    required String appScope,
  }) async {
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        _functionName,
        body: {'action': 'send', 'phone': phone, 'appScope': appScope},
      );

      final json = _asJson(response.data);
      if (json['success'] != true) {
        throw WhatsAppOtpException(
          message:
              (json['message'] as String?) ?? 'Supabase OTP request failed.',
          reason: json['reason'] as String? ?? json['code'] as String?,
          statusCode: response.status,
        );
      }

      return WhatsAppOtpChallenge(
        verificationId:
            json['verificationId'] as String? ??
            json['verification_id'] as String? ??
            '',
        expiresAt:
            DateTime.tryParse(
              json['expiresAt'] as String? ??
                  json['expires_at'] as String? ??
                  '',
            ) ??
            DateTime.now().add(const Duration(minutes: 10)),
        debugCode:
            json['debugCode'] as String? ?? json['debug_code'] as String?,
        usesMock: false,
      );
    } catch (error) {
      if (error is WhatsAppOtpException) rethrow;
      throw const WhatsAppOtpException(
        message: 'Could not send WhatsApp code right now.',
        reason: 'network_error',
      );
    }
  }

  bool _shouldRethrowSendError(Object error) {
    if (error is WhatsAppOtpException) {
      return switch (error.reason) {
        'admin_not_found' || 'venue_not_found' => true,
        _ =>
          error.message.toLowerCase().contains('not registered for admin') ||
              error.message.toLowerCase().contains(
                'not linked to a registered venue',
              ),
      };
    }
    final raw = error.toString().toLowerCase();
    return raw.contains('not registered for admin') ||
        raw.contains('not linked to a registered venue');
  }

  Future<WhatsAppOtpVerificationResult> _verifyRemote({
    required String phone,
    required String verificationId,
    required String code,
    required String appScope,
  }) async {
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        _functionName,
        body: {
          'action': 'verify',
          'phone': phone,
          'appScope': appScope,
          'verificationId': verificationId,
          'verification_id': verificationId,
          'code': code,
        },
      );

      final json = _asJson(response.data);
      if (json['success'] != true) {
        throw WhatsAppOtpException(
          message:
              (json['message'] as String?) ??
              'Supabase OTP verification failed.',
          reason: json['reason'] as String? ?? json['code'] as String?,
          statusCode: response.status,
        );
      }

      final adminSessionValue = json['adminSession'] ?? json['admin_session'];
      final adminSessionRaw = adminSessionValue is Map
          ? adminSessionValue.map(
              (key, value) => MapEntry(key.toString(), value),
            )
          : null;
      final venueSessionValue = json['venueSession'] ?? json['venue_session'];
      final venueSessionRaw = venueSessionValue is Map
          ? venueSessionValue.map(
              (key, value) => MapEntry(key.toString(), value),
            )
          : null;

      return WhatsAppOtpVerificationResult(
        verified: json['verified'] == true,
        reason: json['reason'] as String?,
        remainingAttempts: (json['remainingAttempts'] as num?)?.toInt(),
        verifiedAt: DateTime.tryParse(
          json['verifiedAt'] as String? ?? json['verified_at'] as String? ?? '',
        ),
        adminSession: adminSessionRaw == null
            ? null
            : AdminAccessSession.fromJson(adminSessionRaw),
        venueSession: venueSessionRaw == null
            ? null
            : VenueAccessSession.fromJson(venueSessionRaw),
      );
    } catch (error) {
      if (error is WhatsAppOtpException) rethrow;
      throw const WhatsAppOtpException(
        message: 'Could not verify the WhatsApp code right now.',
        reason: 'network_error',
      );
    }
  }

  Future<WhatsAppOtpChallenge> _sendMock(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final random = Random.secure();
    final code = (100000 + random.nextInt(900000)).toString();
    final verificationId =
        'mock-${DateTime.now().microsecondsSinceEpoch}-${random.nextInt(9999)}';
    final expiresAt = DateTime.now().add(const Duration(minutes: 10));

    await prefs.setString(
      '$_mockKeyPrefix$verificationId',
      jsonEncode({
        'phone': phone,
        'code': code,
        'expires_at': expiresAt.toIso8601String(),
      }),
    );

    return WhatsAppOtpChallenge(
      verificationId: verificationId,
      expiresAt: expiresAt,
      debugCode: code,
      usesMock: true,
    );
  }

  Future<WhatsAppOtpVerificationResult> _verifyMock({
    required String phone,
    required String verificationId,
    required String code,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_mockKeyPrefix$verificationId');
    if (raw == null || raw.isEmpty) {
      return const WhatsAppOtpVerificationResult(
        verified: false,
        reason: 'not_found',
      );
    }

    final payload = jsonDecode(raw) as Map<String, dynamic>;
    final storedPhone = payload['phone'] as String? ?? '';
    final storedCode = payload['code'] as String? ?? '';
    final expiresAt = DateTime.tryParse(payload['expires_at'] as String? ?? '');

    final isValid =
        storedPhone == phone &&
        storedCode == code &&
        expiresAt != null &&
        DateTime.now().isBefore(expiresAt);

    if (isValid) {
      await prefs.remove('$_mockKeyPrefix$verificationId');
    }

    return WhatsAppOtpVerificationResult(
      verified: isValid,
      reason: isValid ? null : 'invalid_code',
      verifiedAt: isValid ? DateTime.now() : null,
    );
  }

  String _normalizePhone(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    final defaultCountryDigits = _defaultCountryCode.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    if (digits.isEmpty) return '';

    if (trimmed.startsWith('+')) {
      return digits.length >= 8 && digits.length <= 15 ? '+$digits' : '';
    }

    if (trimmed.startsWith('00')) {
      final normalized = digits.length > 2 ? digits.substring(2) : '';
      return normalized.length >= 8 && normalized.length <= 15
          ? '+$normalized'
          : '';
    }

    if (digits.length == 8 && defaultCountryDigits.isNotEmpty) {
      return '+$defaultCountryDigits$digits';
    }

    if (digits.length >= 10 && digits.length <= 15) {
      return '+$digits';
    }

    return '';
  }

  Map<String, dynamic> _asJson(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    if (raw is String && raw.trim().isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    }
    throw FunctionException(
      status: 500,
      details: 'Unexpected Supabase function response.',
    );
  }
}
