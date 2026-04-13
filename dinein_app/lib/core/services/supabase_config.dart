import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase configuration for DineIn Malta.
///
/// Credentials MUST be injected via `--dart-define` at build time:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://your-project.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=your-anon-key
///
/// For local dev, create env/.env.local or pass via IDE run configuration.
/// The app will fail fast if either value is missing.
class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static String? get validationError =>
      validationErrorFor(url: url, anonKey: anonKey);
  static bool get isConfigured => validationError == null;
  static bool get isInitialized {
    try {
      return Supabase.instance.isInitialized;
    } catch (_) {
      return false;
    }
  }

  /// Initialize the Supabase client. Call once in main().
  /// Throws [StateError] if credentials are not provided via --dart-define.
  static Future<void> initialize() async {
    if (isInitialized) return;

    final error = validationError;
    if (error != null) {
      throw StateError(error);
    }
    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  /// Get the Supabase client instance.
  static SupabaseClient get client => Supabase.instance.client;

  static String? validationErrorFor({
    required String url,
    required String anonKey,
  }) {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) {
      return _missingCredentialMessage;
    }
    if (!normalizedUrl.startsWith('https://') ||
        !normalizedUrl.endsWith('.supabase.co')) {
      return 'SUPABASE_URL is invalid. '
          'Expected an https://*.supabase.co endpoint passed via '
          '--dart-define-from-file.';
    }
    if (_looksLikePlaceholder(normalizedUrl)) {
      return 'SUPABASE_URL contains a placeholder value. '
          'Update the release env file with the live Supabase project URL.';
    }

    final normalizedAnonKey = anonKey.trim();
    if (normalizedAnonKey.isEmpty) {
      return _missingCredentialMessage;
    }
    if (!normalizedAnonKey.startsWith('eyJ')) {
      return 'SUPABASE_ANON_KEY is invalid. '
          'Expected a non-empty JWT passed via --dart-define-from-file.';
    }
    if (_looksLikePlaceholder(normalizedAnonKey)) {
      return 'SUPABASE_ANON_KEY contains a placeholder value. '
          'Update the release env file with the live anon key.';
    }

    return null;
  }

  static bool _looksLikePlaceholder(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('your-project') ||
        normalized.contains('your-anon-key') ||
        normalized.contains('placeholder') ||
        normalized.contains('mock') ||
        normalized.endsWith('anon-key');
  }

  static const String _missingCredentialMessage =
      'Supabase credentials missing. '
      'Pass --dart-define=SUPABASE_URL=... and '
      '--dart-define=SUPABASE_ANON_KEY=... at build time.';
}
