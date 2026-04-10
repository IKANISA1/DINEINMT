import 'package:dinein_app/core/services/app_bootstrap_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppStartupProfile', () {
    test('guest web keeps background boot minimal', () {
      const profile = AppStartupProfile.guestWeb();

      expect(profile.restoreVenueSession, isFalse);
      expect(profile.restoreAdminSession, isFalse);
      expect(profile.initializeTelemetry, isFalse);
      expect(profile.enableOfflineSyncListener, isFalse);
    });
  });
}
