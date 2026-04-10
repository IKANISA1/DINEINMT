import 'package:db_pkg/models/bell_request.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/services/auth_repository.dart';
import 'package:dinein_app/core/services/bell_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/mock_api_invoker.dart';
import '../fixtures/mock_secure_storage.dart';

Map<String, dynamic> _bellRequestJson({
  String id = 'req1',
  String venueId = 'v1',
  String tableNumber = '12',
  String status = 'pending',
}) => {
  'id': id,
  'venue_id': venueId,
  'user_id': null,
  'table_number': tableNumber,
  'status': status,
  'created_at': DateTime.now().toIso8601String(),
};

VenueAccessSession _activeVenueSession({
  required String venueId,
  required String venueName,
  required String whatsAppNumber,
  required String accessToken,
}) {
  final now = DateTime.now().toUtc();
  return VenueAccessSession(
    venueId: venueId,
    venueName: venueName,
    whatsAppNumber: whatsAppNumber,
    accessToken: accessToken,
    issuedAt: now.subtract(const Duration(minutes: 5)),
    expiresAt: now.add(const Duration(days: 1)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockApiInvoker mock;
  late BellRepository repo;

  setUp(() {
    MockSecureStorage.setup();
    MockSecureStorage.clear();
    mock = MockApiInvoker();
    repo = BellRepository.forTesting(invoker: mock.invoke);
  });

  tearDown(() async {
    await AuthRepository.instance.clearVenueSession();
  });

  group('sendWave', () {
    test('passes venue and table number', () async {
      mock.registerResponse('send_wave', null);

      await repo.sendWave(venueId: 'v1', tableNumber: '42');

      final inv = mock.lastInvocation('send_wave')!;
      expect(inv.payload?['venueId'], 'v1');
      expect(inv.payload?['tableNumber'], '42');
      expect(inv.payload?.containsKey('userId'), isFalse);
    });

    test('includes userId if provided', () async {
      mock.registerResponse('send_wave', null);

      await repo.sendWave(venueId: 'v1', tableNumber: '1', userId: 'usr1');

      final inv = mock.lastInvocation('send_wave')!;
      expect(inv.payload?['userId'], 'usr1');
    });
  });

  group('resolveWave', () {
    test('passes requestId', () async {
      await AuthRepository.instance.saveVenueSession(
        _activeVenueSession(
          venueId: 'v1',
          venueName: 'Bell Venue',
          whatsAppNumber: '+35677186193',
          accessToken: 'bell-token',
        ),
      );
      mock.registerResponse('resolve_bell_request', null);

      await repo.resolveWave('req123');

      final inv = mock.lastInvocation('resolve_bell_request')!;
      expect(inv.payload?['requestId'], 'req123');
      expect(inv.payload?['venue_session'], {'access_token': 'bell-token'});
    });
  });

  group('getBellRequests', () {
    test('returns parsed requests', () async {
      mock.registerResponse('get_bell_requests', [
        _bellRequestJson(id: 'r1', status: 'pending'),
        _bellRequestJson(id: 'r2', status: 'resolved'),
      ]);

      final requests = await repo.getBellRequests('v1');

      expect(requests, hasLength(2));
      expect(requests[0].id, 'r1');
      expect(requests[0].status, WaveStatus.pending);
      expect(requests[1].id, 'r2');
      expect(requests[1].status, WaveStatus.resolved);
    });

    test('passes status filter if provided', () async {
      await AuthRepository.instance.saveVenueSession(
        _activeVenueSession(
          venueId: 'v1',
          venueName: 'Bell Venue',
          whatsAppNumber: '+35677186193',
          accessToken: 'bell-token',
        ),
      );
      mock.registerResponse('get_bell_requests', <dynamic>[]);

      await repo.getBellRequests('v1', status: WaveStatus.pending);

      final inv = mock.lastInvocation('get_bell_requests')!;
      expect(inv.payload?['venueId'], 'v1');
      expect(inv.payload?['status'], 'pending');
      expect(inv.payload?['venue_session'], {'access_token': 'bell-token'});
    });
  });
}
