import 'package:dinein_app/core/config/country_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CountryConfig admin WhatsApp settings', () {
    test('Malta uses the current admin WhatsApp number and local length', () {
      expect(CountryConfig.mt.supportWhatsApp, '356771861993');
      expect(CountryConfig.mt.adminWhatsAppLocalDigits, 9);
    });

    test('Rwanda uses the current admin WhatsApp number and local length', () {
      expect(CountryConfig.rw.supportWhatsApp, '250788767816');
      expect(CountryConfig.rw.adminWhatsAppLocalDigits, 9);
    });
  });
}
