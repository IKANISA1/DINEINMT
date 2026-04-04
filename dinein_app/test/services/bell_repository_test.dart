import 'package:db_pkg/models/bell_request.dart';
import 'package:dinein_app/core/services/bell_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/mock_api_invoker.dart';

Map<String, dynamic> _bellRequestJson({
  String id = 'req1',
  String venueId = 'v1',
  String tableNumber = '12',
  String status = 'pending',
}) =>
    {
      'id': id,
      'venue_id': venueId,
      'user_id': null,
      'table_number': tableNumber,
      'status': status,
      'created_at': DateTime.now().toIso8601String(),
    };

void main() {
  late MockApiInvoker mock;
  late BellRepository repo;

  setUp(() {
    mock = MockApiInvoker();
    repo = BellRepository.forTesting(invoker: mock.invoke);
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
      mock.registerResponse('resolve_bell_request', null);

      await repo.resolveWave('req123');

      final inv = mock.lastInvocation('resolve_bell_request')!;
      expect(inv.payload?['requestId'], 'req123');
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
      mock.registerResponse('get_bell_requests', <dynamic>[]);

      await repo.getBellRequests('v1', status: WaveStatus.pending);

      final inv = mock.lastInvocation('get_bell_requests')!;
      expect(inv.payload?['venueId'], 'v1');
      expect(inv.payload?['status'], 'pending');
    });
  });
}
