import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/services/auth_repository.dart';
import 'package:dinein_app/core/services/menu_repository.dart';
import 'package:dinein_app/core/services/venue_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/mock_api_invoker.dart';
import '../fixtures/mock_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockApiInvoker mock;
  late VenueRepository venueRepository;
  late MenuRepository menuRepository;

  setUp(() async {
    MockSecureStorage.setup();
    MockSecureStorage.clear();
    mock = MockApiInvoker();
    venueRepository = VenueRepository.forTesting(invoker: mock.invoke);
    menuRepository = MenuRepository.forTesting(invoker: mock.invoke);

    final now = DateTime.now();
    await AuthRepository.instance.saveVenueSession(
      VenueAccessSession(
        accessToken: 'venue-token',
        venueId: 'venue-123',
        venueName: 'Venue Name',
        venueSlug: 'venue-name',
        whatsAppNumber: '+35612345678',
        issuedAt: now.subtract(const Duration(minutes: 5)),
        expiresAt: now.add(const Duration(hours: 4)),
      ),
    );
  });

  tearDown(() async {
    await AuthRepository.instance.clearVenueSession();
    await AuthRepository.instance.clearAdminSession();
  });

  test('venue admin mutations do not send venue_session payloads', () async {
    mock.registerResponse('update_venue', null);
    mock.registerResponse('enrich_venue_profile', <String, dynamic>{});

    await venueRepository.updateVenueAsAdmin('venue-123', {'name': 'Updated'});
    await venueRepository.enrichVenueProfile(
      'venue-123',
      useAdminSession: true,
    );

    expect(
      mock.lastInvocation('update_venue')?.payload?.containsKey('venue_session'),
      isFalse,
    );
    expect(
      mock.lastInvocation('enrich_venue_profile')
          ?.payload
          ?.containsKey('venue_session'),
      isFalse,
    );
  });

  test('menu admin mutations do not send venue_session payloads', () async {
    mock.registerResponse('update_menu_item', <String, dynamic>{});

    await menuRepository.updateMenuItem(
      'item-123',
      {'name': 'Updated'},
      useAdminSession: true,
    );
    await menuRepository.setMenuItemImageLock(
      'item-123',
      true,
      useAdminSession: true,
    );

    final invocations = mock.invocations
        .where((invocation) => invocation.action == 'update_menu_item')
        .toList(growable: false);

    expect(invocations, hasLength(2));
    expect(invocations.every((inv) => inv.useAdminSession), isTrue);
    expect(
      invocations.every(
        (invocation) =>
            !(invocation.payload?.containsKey('venue_session') ?? false),
      ),
      isTrue,
    );
  });
}
