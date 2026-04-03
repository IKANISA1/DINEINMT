import 'package:dinein_app/core/models/models.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/core/services/auth_repository.dart';
import 'package:dinein_app/core/config/country_config.dart';
import 'package:dinein_app/core/config/country_runtime.dart';
import 'package:dinein_app/core/constants/enums.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../fixtures/mock_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/firebase_core');

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          if (methodCall.method == 'Firebase#initializeApp') {
            return {
              'name': methodCall.arguments['appName'],
              'options': methodCall.arguments['options'],
              'pluginConstants': {},
            };
          }
          return null;
        });

    MockSecureStorage.setup();
    MockSecureStorage.clear();
    await AuthRepository.instance.clearVenueSession();
    CountryRuntime.configure(CountryConfig.rw);
  });

  test(
    'currentVenueProvider falls back to the persisted venue session when backend access is unavailable',
    () async {
      final now = DateTime.now();
      await AuthRepository.instance.saveVenueSession(
        VenueAccessSession(
          accessToken: 'test-venue-token',
          venueId: 'venue-123',
          venueName: 'Session Venue',
          venueSlug: 'session-venue-real-slug',
          whatsAppNumber: '+35612345678',
          venueImageUrl: 'https://example.com/venue.png',
          issuedAt: now.subtract(const Duration(minutes: 5)),
          expiresAt: now.add(const Duration(days: 1)),
        ),
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final venue = await container.read(currentVenueProvider.future);

      expect(venue, isNotNull);
      expect(venue?.id, 'venue-123');
      expect(venue?.name, 'Session Venue');
      expect(venue?.slug, 'session-venue-real-slug');
      expect(venue?.imageUrl, 'https://example.com/venue.png');
      expect(venue?.country, Country.rw);
    },
  );
}
