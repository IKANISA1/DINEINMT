import 'package:dinein_app/features/biopay/models/biopay_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnrollmentResult', () {
    test('parses successful backend payload without explicit success flag', () {
      final result = EnrollmentResult.fromJson({
        'biopay_id': '123456',
        'owner_token': 'owner-token',
        'management_code': '654321',
        'management_code_hint': '21',
        'display_name': 'Jean Bosco',
        'ussd_string': '*182*1*1*0788123456#',
        'enrolled_at': '2026-03-22T10:30:00Z',
      });

      expect(result.success, isTrue);
      expect(result.biopayId, '123456');
      expect(result.ownerToken, 'owner-token');
      expect(result.managementCodeHint, '21');
      expect(result.displayName, 'Jean Bosco');
      expect(result.ussdString, '*182*1*1*0788123456#');
      expect(result.enrolledAt, DateTime.parse('2026-03-22T10:30:00Z'));
    });
  });

  group('BiopayLocalSession', () {
    test('toJson/fromJson round-trip preserves fields', () {
      final session = BiopayLocalSession(
        biopayId: '123456',
        ownerToken: 'owner-token',
        displayName: 'Jean Bosco',
        managementCodeHint: '21',
        savedAt: DateTime.parse('2026-03-22T11:00:00Z'),
      );

      final parsed = BiopayLocalSession.fromJson(session.toJson());
      expect(parsed.biopayId, '123456');
      expect(parsed.ownerToken, 'owner-token');
      expect(parsed.displayName, 'Jean Bosco');
      expect(parsed.managementCodeHint, '21');
      expect(parsed.savedAt, DateTime.parse('2026-03-22T11:00:00Z'));
    });
  });

  group('ManagedBiopayProfile', () {
    test('parses management profile payload', () {
      final profile = ManagedBiopayProfile.fromJson({
        'biopay_id': '123456',
        'display_name': 'Uwimana Marie',
        'ussd_string': '*182*1*1*0788123456#',
        'status': 'active',
        'management_code_hint': '56',
        'created_at': '2026-03-22T10:30:00Z',
      });

      expect(profile.biopayId, '123456');
      expect(profile.displayName, 'Uwimana Marie');
      expect(profile.ussdString, '*182*1*1*0788123456#');
      expect(profile.status, 'active');
      expect(profile.managementCodeHint, '56');
      expect(profile.createdAt, DateTime.parse('2026-03-22T10:30:00Z'));
    });
  });
}
