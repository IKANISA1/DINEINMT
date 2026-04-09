import 'dart:convert';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/services/auth_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/mock_api_invoker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockApiInvoker mock;
  late AuthRepository repo;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    mock = MockApiInvoker();
    repo = AuthRepository.forTesting(invoker: mock.invoke);
  });

  group('createProfile', () {
    test('sends profile data via invoke', () async {
      mock.registerResponse('create_profile', null);

      await repo.createProfile(
        userId: 'u1',
        displayName: 'John',
        email: 'j@test.com',
        role: 'admin',
      );

      final inv = mock.lastInvocation('create_profile')!;
      expect(inv.payload?['userId'], 'u1');
      expect(inv.payload?['displayName'], 'John');
      expect(inv.payload?['email'], 'j@test.com');
      expect(inv.payload?['role'], 'admin');
    });
  });

  group('getUserRole', () {
    test('returns role string', () async {
      mock.registerResponse('get_user_role', 'owner');

      final role = await repo.getUserRole('u2');

      expect(role, 'owner');
      final inv = mock.lastInvocation('get_user_role')!;
      expect(inv.payload?['userId'], 'u2');
    });
  });

  group('Venue Session Management', () {
    final fakeSession = VenueAccessSession(
      venueId: 'v1',
      venueName: 'Test Venue',
      whatsAppNumber: '1234567890',
      accessToken: 'token-123',
      issuedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 1)),
    );

    test('saveVenueSession persists to storage and updates memory', () async {
      await repo.saveVenueSession(fakeSession);

      expect(repo.currentVenueSession, isNotNull);
      expect(repo.currentVenueSession!.venueId, 'v1');
    });

    test('restoreVenueSession loads from storage', () async {
      FlutterSecureStorage.setMockInitialValues({
        'dinein.venue_session': jsonEncode(fakeSession.toJson()),
      });

      await repo.restoreVenueSession();

      expect(repo.currentVenueSession, isNotNull);
      expect(repo.currentVenueSession!.venueId, 'v1');
      expect(repo.hasVenueAccess, isTrue);
    });

    test(
      'ensureVenueSession restores from storage when memory is cold',
      () async {
        FlutterSecureStorage.setMockInitialValues({
          'dinein.venue_session': jsonEncode(fakeSession.toJson()),
        });

        final session = await repo.ensureVenueSession();

        expect(session, isNotNull);
        expect(session!.venueId, 'v1');
        expect(repo.hasVenueAccess, isTrue);
      },
    );

    test('clearVenueSession removes from storage and memory', () async {
      await repo.saveVenueSession(fakeSession);
      await repo.clearVenueSession();

      expect(repo.currentVenueSession, isNull);
      expect(repo.hasVenueSession, isFalse);
    });
  });

  group('Admin Session Management', () {
    final fakeAdminSession = AdminAccessSession(
      adminUserId: 'a1',
      displayName: 'Test Admin',
      whatsAppNumber: '0987654321',
      accessToken: 'admin-token',
      issuedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 1)),
    );

    test('saveAdminSession persists to storage and updates memory', () async {
      await repo.saveAdminSession(fakeAdminSession);

      expect(repo.currentAdminSession, isNotNull);
      expect(repo.currentAdminSession!.adminUserId, 'a1');
    });

    test('restoreAdminSession loads from storage', () async {
      FlutterSecureStorage.setMockInitialValues({
        'dinein.admin_session': jsonEncode(fakeAdminSession.toJson()),
      });

      await repo.restoreAdminSession();

      expect(repo.currentAdminSession, isNotNull);
      expect(repo.currentAdminSession!.adminUserId, 'a1');
      expect(repo.hasAdminAccess, isTrue);
    });

    test(
      'ensureAdminSession restores from storage when memory is cold',
      () async {
        FlutterSecureStorage.setMockInitialValues({
          'dinein.admin_session': jsonEncode(fakeAdminSession.toJson()),
        });

        final session = await repo.ensureAdminSession();

        expect(session, isNotNull);
        expect(session!.adminUserId, 'a1');
        expect(repo.hasAdminAccess, isTrue);
      },
    );

    test('clearAdminSession removes from storage and memory', () async {
      await repo.saveAdminSession(fakeAdminSession);
      await repo.clearAdminSession();

      expect(repo.currentAdminSession, isNull);
      expect(repo.hasAdminSession, isFalse);
    });
  });
}
