import 'package:core_pkg/config/country_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CountryConfig admin WhatsApp settings', () {
    test('Malta uses the current admin WhatsApp number and local length', () {
      expect(CountryConfig.mt.supportWhatsApp, '35699711145');
      expect(CountryConfig.mt.adminWhatsAppLocalDigits, 8);
    });

    test('Rwanda uses the current admin WhatsApp number and local length', () {
      expect(CountryConfig.rw.supportWhatsApp, '250795588248');
      expect(CountryConfig.rw.adminWhatsAppLocalDigits, 9);
    });
  });
}
