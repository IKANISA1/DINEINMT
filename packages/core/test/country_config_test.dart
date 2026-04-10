import 'package:core_pkg/config/country_config.dart';
import 'package:core_pkg/constants/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CountryConfig', () {
    test('Malta flavor exposes the expected release metadata', () {
      expect(CountryConfig.mt.country, Country.mt);
      expect(CountryConfig.mt.playStoreId, 'com.dineinmalta.app');
      expect(CountryConfig.mt.privacyPolicyUrl, 'https://dineinmt.ikanisa.com/privacy');
      expect(CountryConfig.mt.hasBioPay, isFalse);
      expect(CountryConfig.mt.hasRevolut, isTrue);
      expect(CountryConfig.mt.hasMomo, isFalse);
      expect(CountryConfig.mt.playStoreUrl, contains(CountryConfig.mt.playStoreId));
      expect(CountryConfig.mt.guestWebHost, 'dineinmtg.ikanisa.com');
      expect(CountryConfig.mt.venueWebHost, 'dineinmtv.ikanisa.com');
      expect(CountryConfig.mt.adminWebHost, 'dineinmta.ikanisa.com');
    });

    test('Rwanda flavor exposes the expected release metadata', () {
      expect(CountryConfig.rw.country, Country.rw);
      expect(CountryConfig.rw.playStoreId, 'com.dineinrw.app');
      expect(CountryConfig.rw.privacyPolicyUrl, 'https://dineinrw.ikanisa.com/privacy');
      expect(CountryConfig.rw.hasBioPay, isTrue);
      expect(CountryConfig.rw.hasRevolut, isFalse);
      expect(CountryConfig.rw.hasMomo, isTrue);
      expect(CountryConfig.rw.momoUssdCode, '*182*8*1#');
      expect(CountryConfig.rw.playStoreUrl, contains(CountryConfig.rw.playStoreId));
      expect(CountryConfig.rw.guestWebHost, 'dineinrwg.ikanisa.com');
      expect(CountryConfig.rw.venueWebHost, 'dineinrwv.ikanisa.com');
      expect(CountryConfig.rw.adminWebHost, 'dineinrwa.ikanisa.com');
    });
  });
}
