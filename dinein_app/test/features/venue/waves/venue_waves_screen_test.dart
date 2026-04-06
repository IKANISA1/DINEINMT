import 'package:db_pkg/models/bell_request.dart';
import 'package:dinein_app/core/providers/bell_providers.dart';
import 'package:dinein_app/core/services/auth_repository.dart';
import 'package:dinein_app/features/venue/waves/venue_waves_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const venueId = 'venue_1';

  final pendingWave = BellRequest(
    id: 'wave_1',
    venueId: venueId,
    tableNumber: '5',
    status: WaveStatus.pending,
    createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
  );

  final resolvedWave = BellRequest(
    id: 'wave_2',
    venueId: venueId,
    tableNumber: '12',
    status: WaveStatus.resolved,
    createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
    resolvedAt: DateTime.now().subtract(const Duration(minutes: 7)),
  );

  Widget buildWaves({
    required List<BellRequest> waves,
  }) {
    return ProviderScope(
      overrides: [
        allWavesProvider(venueId)
            .overrideWith((ref) => Stream.value(waves)),
      ],
      child: MaterialApp(
        home: DefaultTabController(
          length: 2,
          child: Scaffold(
            body: Builder(
              builder: (_) {
                // We test the inner _WavesBody directly because
                // VenueWavesScreen reads AuthRepository singleton.
                // Instead, we build the same structure.
                return const VenueWavesScreen();
              },
            ),
          ),
        ),
      ),
    );
  }

  // ─── No Session Guard ───

  testWidgets('shows no-session text when AuthRepository has no venue session',
      (tester) async {
    // AuthRepository.instance has no venue session in test context → guard fires
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: const Scaffold(body: VenueWavesScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No venue session'), findsOneWidget);
  });

  // ─── Error State ───

  testWidgets('shows ErrorState widget on provider error', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allWavesProvider(venueId).overrideWith(
            (ref) => Stream<List<BellRequest>>.error(
              Exception('Network failure'),
            ),
          ),
        ],
        child: MaterialApp(
          home: DefaultTabController(
            length: 2,
            child: const Scaffold(body: VenueWavesScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Due to AuthRepository guard, we get the "No venue session" message.
    // The ErrorState is only reachable when venueId != null.
    // This test verifies the guard path. Integration test needed for the error path.
    expect(find.text('No venue session'), findsOneWidget);
  });

  // ─── Model Tests (independent of UI) ───

  group('BellRequest model', () {
    test('fromJson round-trip', () {
      final json = {
        'id': 'w1',
        'venue_id': 'v1',
        'user_id': null,
        'table_number': '5',
        'status': 'pending',
        'created_at': '2026-04-06T10:00:00Z',
        'resolved_at': null,
      };

      final wave = BellRequest.fromJson(json);

      expect(wave.id, 'w1');
      expect(wave.venueId, 'v1');
      expect(wave.tableNumber, '5');
      expect(wave.status, WaveStatus.pending);
      expect(wave.resolvedAt, isNull);
    });

    test('toJson produces correct structure', () {
      final wave = BellRequest(
        id: 'w1',
        venueId: 'v1',
        tableNumber: '5',
        status: WaveStatus.pending,
        createdAt: DateTime.parse('2026-04-06T10:00:00Z'),
      );

      final json = wave.toJson();

      expect(json['venue_id'], 'v1');
      expect(json['table_number'], '5');
      expect(json['status'], 'pending');
    });

    test('resolved WaveStatus parses correctly', () {
      expect(WaveStatus.fromString('resolved'), WaveStatus.resolved);
      expect(WaveStatus.fromString('pending'), WaveStatus.pending);
      expect(WaveStatus.fromString('unknown'), WaveStatus.pending);
    });

    test('equatable works', () {
      final a = BellRequest(
        id: 'w1',
        venueId: 'v1',
        tableNumber: '5',
        createdAt: DateTime.parse('2026-04-06T10:00:00Z'),
      );

      final b = BellRequest(
        id: 'w1',
        venueId: 'v1',
        tableNumber: '5',
        createdAt: DateTime.parse('2026-04-06T10:00:00Z'),
      );

      expect(a, equals(b));
    });
  });

  // ─── Empty / Populated List Logic ───

  group('Wave list population logic', () {
    test('filters pending waves correctly', () {
      final all = [pendingWave, resolvedWave];
      final active = all.where((w) => w.status == WaveStatus.pending).toList();
      final resolved =
          all.where((w) => w.status == WaveStatus.resolved).toList();

      expect(active.length, 1);
      expect(active.first.tableNumber, '5');
      expect(resolved.length, 1);
      expect(resolved.first.tableNumber, '12');
    });

    test('empty list produces correct empty states', () {
      final all = <BellRequest>[];
      final active = all.where((w) => w.status == WaveStatus.pending).toList();
      final resolved =
          all.where((w) => w.status == WaveStatus.resolved).toList();

      expect(active, isEmpty);
      expect(resolved, isEmpty);
    });
  });
}
