import '../constants/enums.dart';

/// Build-time country configuration.
///
/// Each flavor provides a concrete instance via its entry point
/// (`main_mt.dart` or `main_rw.dart`). All country-specific values
/// flow from here — no hardcoded Malta/Rwanda elsewhere.
class CountryConfig {
  final Country country;
  final String appName;
  final String appTitle;
  final String siteHost;
  final String playStoreId;
  final String supportWhatsApp;
  final String defaultCountryCode;
  final String countryDialCode;
  final String countryFlag;
  final String addressHint;
  final String welcomeMessage;
  final String privacyPolicyUrl;
  final String? revolutMerchant;
  final String? momoUssdCode;

  const CountryConfig({
    required this.country,
    required this.appName,
    required this.appTitle,
    required this.siteHost,
    required this.playStoreId,
    required this.supportWhatsApp,
    required this.defaultCountryCode,
    required this.countryDialCode,
    required this.countryFlag,
    required this.addressHint,
    required this.welcomeMessage,
    required this.privacyPolicyUrl,
    this.revolutMerchant,
    this.momoUssdCode,
  });

  /// Malta configuration.
  static const mt = CountryConfig(
    country: Country.mt,
    appName: 'Dinein MT',
    appTitle: 'DINEIN MALTA',
    siteHost: 'dineinmalta.com',
    playStoreId: 'com.dineinmalta.app',
    supportWhatsApp: '35699711145',
    defaultCountryCode: '356',
    countryDialCode: '+356',
    countryFlag: '🇲🇹',
    addressHint: '45 Tower Rd, Sliema, Malta',
    welcomeMessage: 'WELCOME TO DINEIN MALTA',
    privacyPolicyUrl: 'https://dineinmalta.com/privacy.html',
    revolutMerchant: 'dineinmalta',
  );

  /// Rwanda configuration.
  static const rw = CountryConfig(
    country: Country.rw,
    appName: 'Dinein RW',
    appTitle: 'DINEIN RW',
    siteHost: 'dineinrw.ikanisa.com',
    playStoreId: 'com.dineinrw.app',
    supportWhatsApp: '250788000000', // TODO: replace with actual RW support number
    defaultCountryCode: '250',
    countryDialCode: '+250',
    countryFlag: '🇷🇼',
    addressHint: 'KG 9 Ave, Kigali, Rwanda',
    welcomeMessage: 'WELCOME TO DINEIN RW',
    privacyPolicyUrl: 'https://dineinrw.ikanisa.com/privacy.html',
    momoUssdCode: '*182*8*1#', // MTN MoMo Rwanda
  );

  /// Play Store URL.
  String get playStoreUrl =>
      'https://play.google.com/store/apps/details?id=$playStoreId';

  /// Revolut payment link (Malta only).
  String? get revolutPayUrl =>
      revolutMerchant != null ? 'https://revolut.me/$revolutMerchant' : null;

  /// Whether this country uses Revolut.
  bool get hasRevolut => revolutMerchant != null;

  /// Whether this country uses MoMo USSD.
  bool get hasMomo => momoUssdCode != null;

  /// Share text for venue discovery.
  String shareText(String content) => '$content\nhttps://$siteHost';

  /// Terms of service URL.
  String get termsUrl => 'https://$siteHost/terms.html';

  /// Cookie policy URL (reuses privacy page).
  String get cookiePolicyUrl => privacyPolicyUrl;
}
