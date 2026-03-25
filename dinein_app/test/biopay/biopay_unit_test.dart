import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dinein_app/features/biopay/models/biopay_models.dart';
import 'package:dinein_app/features/biopay/services/match_cache.dart';
import 'package:dinein_app/features/biopay/services/stable_frame_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Provide empty initial values for SharedPreferences in tests
    SharedPreferences.setMockInitialValues({});
  });
  group('BiopayModels', () {
    test('BiopayProfile.fromJson parses correctly', () {
      final json = {
        'id': 'abc123',
        'biopay_id': 'BP-001',
        'display_name': 'Jean',
        'ussd_string': '*182*8*1*500#',
        'status': 'active',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      };

      final profile = BiopayProfile.fromJson(json);

      expect(profile.id, 'abc123');
      expect(profile.biopayId, 'BP-001');
      expect(profile.displayName, 'Jean');
      expect(profile.ussdString, '*182*8*1*500#');
      expect(profile.isActive, true);
    });

    test('MatchResult.fromJson handles match', () {
      final json = {
        'match': true,
        'display_name': 'Alice',
        'ussd_string': '*182*8*1*200#',
        'biopay_id': 'BP-002',
        'score': 0.92,
      };

      final result = MatchResult.fromJson(json);

      expect(result.isMatch, true);
      expect(result.displayName, 'Alice');
      expect(result.score, 0.92);
    });

    test('MatchResult.noMatch returns false', () {
      final result = MatchResult.noMatch();
      expect(result.isMatch, false);
      expect(result.displayName, null);
    });

    test('EnrollmentResult.fromJson parses success', () {
      final json = {
        'success': true,
        'biopay_id': 'BP-003',
        'owner_token': 'tok123',
        'management_code': '7842',
        'display_name': 'Bob',
      };

      final result = EnrollmentResult.fromJson(json);

      expect(result.success, true);
      expect(result.biopayId, 'BP-003');
      expect(result.managementCode, '7842');
    });

    test('EnrollmentResult.failure creates error result', () {
      final result = EnrollmentResult.failure('Network error');
      expect(result.success, false);
      expect(result.error, 'Network error');
    });
  });

  group('StableFrameGate', () {
    test('scan gate requires 3 stable frames', () {
      final gate = StableFrameGate.scan();

      expect(gate.onFrame(isQualityAcceptable: true, trackingId: 1), false);
      expect(gate.onFrame(isQualityAcceptable: true, trackingId: 1), false);
      expect(gate.onFrame(isQualityAcceptable: true, trackingId: 1), true);
    });

    test('enrollment gate requires 5 stable frames', () {
      final gate = StableFrameGate.enrollment();

      for (int i = 0; i < 4; i++) {
        expect(gate.onFrame(isQualityAcceptable: true, trackingId: 1), false);
      }
      expect(gate.onFrame(isQualityAcceptable: true, trackingId: 1), true);
    });

    test('resets on quality failure', () {
      final gate = StableFrameGate.scan();

      gate.onFrame(isQualityAcceptable: true, trackingId: 1);
      gate.onFrame(isQualityAcceptable: true, trackingId: 1);
      gate.onFrame(isQualityAcceptable: false, trackingId: 1); // Reset

      expect(gate.stableCount, 0);
      expect(gate.onFrame(isQualityAcceptable: true, trackingId: 1), false);
    });

    test('resets on face change', () {
      final gate = StableFrameGate.scan();

      gate.onFrame(isQualityAcceptable: true, trackingId: 1);
      gate.onFrame(isQualityAcceptable: true, trackingId: 1);
      gate.onFrame(isQualityAcceptable: true, trackingId: 2); // Different face

      expect(gate.stableCount, 0);
    });

    test('progress reports ratio', () {
      final gate = StableFrameGate.scan();
      expect(gate.progress, 0.0);

      gate.onFrame(isQualityAcceptable: true, trackingId: 1);
      expect(gate.progress, closeTo(0.33, 0.01));

      gate.onFrame(isQualityAcceptable: true, trackingId: 1);
      expect(gate.progress, closeTo(0.67, 0.01));
    });
  });

  group('MatchCache', () {
    test('findMatch returns null for empty cache', () {
      final cache = MatchCache();
      final embedding = List<double>.generate(192, (i) => i * 0.01);

      expect(cache.findMatch(embedding), null);
    });

    test('addMatch and findMatch round trip', () async {
      final cache = MatchCache();
      final embedding = List<double>.generate(192, (i) => i * 0.01);

      await cache.addMatch(
        embedding: embedding,
        biopayId: 'BP-001',
        displayName: 'Alice',
        ussdString: '*182*8*1*500#',
      );

      final match = cache.findMatch(embedding);
      expect(match, isNotNull);
      expect(match!.biopayId, 'BP-001');
      expect(match.displayName, 'Alice');
    });

    test('dissimilar embeddings do not match', () async {
      final cache = MatchCache();

      final embedding1 = List<double>.generate(192, (i) => i * 0.01);
      await cache.addMatch(
        embedding: embedding1,
        biopayId: 'BP-001',
        displayName: 'Alice',
        ussdString: '*182*8*1*500#',
      );

      // Very different embedding
      final embedding2 = List<double>.generate(192, (i) => -i * 0.01);
      expect(cache.findMatch(embedding2), null);
    });

    test('clear removes all entries', () async {
      final cache = MatchCache();
      final embedding = List<double>.generate(192, (i) => i * 0.01);

      await cache.addMatch(
        embedding: embedding,
        biopayId: 'BP-001',
        displayName: 'Test',
        ussdString: '*123#',
      );

      expect(cache.size, 1);
      await cache.clear();
      expect(cache.size, 0);
    });

    test('respects maxEntries', () async {
      final cache = MatchCache(maxEntries: 3);

      for (int i = 0; i < 5; i++) {
        await cache.addMatch(
          embedding: List<double>.generate(192, (j) => (i * 192 + j) * 0.001),
          biopayId: 'BP-$i',
          displayName: 'User $i',
          ussdString: '*123#',
        );
      }

      expect(cache.size, 3);
    });

    test('updates existing biopayId instead of duplicating', () async {
      final cache = MatchCache();
      final embedding = List<double>.generate(192, (i) => i * 0.01);

      await cache.addMatch(
        embedding: embedding,
        biopayId: 'BP-001',
        displayName: 'Alice',
        ussdString: '*123#',
      );

      await cache.addMatch(
        embedding: embedding,
        biopayId: 'BP-001',
        displayName: 'Alice Updated',
        ussdString: '*456#',
      );

      expect(cache.size, 1);
      final match = cache.findMatch(embedding);
      expect(match!.displayName, 'Alice Updated');
    });

    test('removeBiopayId invalidates stale cached profile data', () async {
      final cache = MatchCache();
      final embedding = List<double>.generate(192, (i) => i * 0.01);

      await cache.addMatch(
        embedding: embedding,
        biopayId: 'BP-001',
        displayName: 'Alice',
        ussdString: '*123#',
      );

      await cache.removeBiopayId('BP-001');

      expect(cache.size, 0);
      expect(cache.findMatch(embedding), isNull);
    });
  });
}
