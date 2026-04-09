import 'package:core_pkg/config/country_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CountryConfig admin WhatsApp settings', () {
    test('Malta uses the current admin WhatsApp number and local length', () {
      expect(CountryConfig.mt.adminAccessWhatsApp, '35699711145');
      expect(CountryConfig.mt.adminWhatsAppLocalDigits, 8);
    });

    test('Rwanda uses the current admin WhatsApp number and local length', () {
      expect(CountryConfig.rw.adminAccessWhatsApp, '25075588248');
      expect(CountryConfig.rw.adminWhatsAppLocalDigits, 8);
    });
  });

  group('CountryConfig venue WhatsApp settings', () {
    test('Malta venue access derives 8-digit local length', () {
      expect(CountryConfig.mt.venueAccessWhatsApp, '35699711145');
      expect(CountryConfig.mt.venueWhatsAppLocalDigits, 8);
    });

    test('Rwanda venue access derives 9-digit local length', () {
      expect(CountryConfig.rw.venueAccessWhatsApp, '250795588248');
      expect(CountryConfig.rw.venueWhatsAppLocalDigits, 9);
    });

    test(
      'venueWhatsAppLocalDigits matches adminWhatsAppLocalDigits for MT',
      () {
        expect(
          CountryConfig.mt.venueWhatsAppLocalDigits,
          CountryConfig.mt.adminWhatsAppLocalDigits,
        );
      },
    );

    test(
      'Rwanda venue and admin WhatsApp lengths are intentionally different',
      () {
        expect(
          CountryConfig.rw.venueWhatsAppLocalDigits,
          isNot(CountryConfig.rw.adminWhatsAppLocalDigits),
        );
      },
    );
  });
}
