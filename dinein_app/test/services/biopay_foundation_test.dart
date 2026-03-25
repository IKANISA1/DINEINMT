import 'package:dinein_app/features/biopay/models/biopay_models.dart';
import 'package:dinein_app/features/biopay/services/biopay_api_client.dart';
import 'package:dinein_app/features/biopay/services/biopay_local_session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BiopayApiClient.unwrapFunctionData', () {
    test('unwraps standard Supabase function payload', () {
      final payload = BiopayApiClient.unwrapFunctionData(
        action: 'enroll_face',
        statusCode: 201,
        rawData: {
          'data': {'biopay_id': '123456', 'owner_token': 'owner-token'},
        },
      );

      expect(payload['biopay_id'], '123456');
      expect(payload['owner_token'], 'owner-token');
    });

    test('throws on error payload', () {
      expect(
        () => BiopayApiClient.unwrapFunctionData(
          action: 'match_face',
          statusCode: 429,
          rawData: {'error': 'Too many requests'},
        ),
        throwsA(isA<BiopayApiException>()),
      );
    });
  });

  group('BiopayLocalSessionStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saves to secure storage when available and loads back', () async {
      final secure = <String, String>{};
      final store = BiopayLocalSessionStore(
        secureRead: (key) async => secure[key],
        secureWrite: (key, value) async {
          secure[key] = value;
          return true;
        },
        secureDelete: (key) async {
          secure.remove(key);
        },
      );

      final session = BiopayLocalSession(
        biopayId: '123456',
        ownerToken: 'owner-token',
        displayName: 'Jean Bosco',
        managementCodeHint: '21',
        savedAt: DateTime.parse('2026-03-22T11:00:00Z'),
      );

      await store.save(session);
      final loaded = await store.load();

      expect(loaded?.biopayId, '123456');
      expect(loaded?.ownerToken, 'owner-token');
      expect(secure.containsKey(BiopayLocalSessionStore.storageKey), isTrue);
    });

    test('load returns null when secure storage is empty', () async {
      final store = BiopayLocalSessionStore(
        secureRead: (key) async => null,
      );
      final loaded = await store.load();
      expect(loaded, isNull);
    });

    test('save persists to secure storage', () async {
      final secure = <String, String>{};
      final store = BiopayLocalSessionStore(
        secureWrite: (key, value) async {
          secure[key] = value;
          return true;
        },
      );

      final session = BiopayLocalSession(
        biopayId: 'BP123',
        ownerToken: 'tok123',
        displayName: 'Test User',
        savedAt: DateTime.now(),
      );

      await store.save(session);
      expect(secure.containsKey(BiopayLocalSessionStore.storageKey), isTrue);
      expect(secure[BiopayLocalSessionStore.storageKey], contains('BP123'));
    });
  });
}
