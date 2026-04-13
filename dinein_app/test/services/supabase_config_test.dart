import 'package:dinein_app/core/services/supabase_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('validationErrorFor rejects empty credentials', () {
    expect(
      SupabaseConfig.validationErrorFor(url: '', anonKey: ''),
      contains('Supabase credentials missing'),
    );
  });

  test('validationErrorFor rejects placeholder and malformed values', () {
    expect(
      SupabaseConfig.validationErrorFor(
        url: 'https://your-project.supabase.co',
        anonKey: 'your-anon-key',
      ),
      isNotNull,
    );

    expect(
      SupabaseConfig.validationErrorFor(
        url: 'http://example.com',
        anonKey: 'eyJ.valid',
      ),
      contains('SUPABASE_URL is invalid'),
    );

    expect(
      SupabaseConfig.validationErrorFor(
        url: 'https://example.supabase.co',
        anonKey: 'plain-text-key',
      ),
      contains('SUPABASE_ANON_KEY is invalid'),
    );
  });

  test('validationErrorFor accepts release-like values', () {
    expect(
      SupabaseConfig.validationErrorFor(
        url: 'https://uskfnszcdqpcfrhjxitl.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.payload.signature',
      ),
      isNull,
    );
  });
}
