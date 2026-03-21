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

  /// Initialize the Supabase client. Call once in main().
  /// Throws [StateError] if credentials are not provided via --dart-define.
  static Future<void> initialize() async {
    if (url.isEmpty || anonKey.isEmpty) {
      throw StateError(
        'Supabase credentials missing. '
        'Pass --dart-define=SUPABASE_URL=... and '
        '--dart-define=SUPABASE_ANON_KEY=... at build time.',
      );
    }
    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  /// Get the Supabase client instance.
  static SupabaseClient get client => Supabase.instance.client;
}
