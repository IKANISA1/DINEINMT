import 'package:core_pkg/config/country_config.dart';
import 'package:dinein_app/firebase_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Malta Firebase options resolve to the Malta app ids', () {
    final android = DefaultFirebaseOptions.androidForCountry(CountryConfig.mt.country);
    final ios = DefaultFirebaseOptions.iosForCountry(CountryConfig.mt.country);

    expect(android.appId, '1:1074154147498:android:1dd401b016b8c501dc4ad3');
    expect(ios.appId, '1:1074154147498:ios:f9338408dab88c45dc4ad3');
    expect(ios.iosBundleId, 'com.dineinmalta.app');
  });

  test('Rwanda Firebase options resolve to the Rwanda app ids', () {
    final android = DefaultFirebaseOptions.androidForCountry(CountryConfig.rw.country);
    final ios = DefaultFirebaseOptions.iosForCountry(CountryConfig.rw.country);

    expect(android.appId, '1:1074154147498:android:cbd8a51892a2ee93dc4ad3');
    expect(ios.appId, '1:1074154147498:ios:a44ce46db3c51bfcdc4ad3');
    expect(ios.iosBundleId, 'com.dineinrw.app');
  });

  test('Web Firebase options are configured for the live project', () {
    final web = DefaultFirebaseOptions.web;

    expect(web.appId, '1:1074154147498:web:40ff2d11ccfa7d2cdc4ad3');
    expect(web.projectId, 'gen-lang-client-0172279957');
    expect(web.messagingSenderId, '1074154147498');
  });
}
