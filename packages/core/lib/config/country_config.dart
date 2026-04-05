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
  final String supportEmail;
  final String venueAccessWhatsApp;
  final String venueAccessEmail;
  final String defaultCountryCode;
  final String countryDialCode;
  final String countryFlag;
  final String addressHint;
  final String welcomeMessage;
  final String privacyPolicyUrl;
  final String? revolutMerchant;
  final String? momoUssdCode;
  final bool biopayEnabled;

  const CountryConfig({
    required this.country,
    required this.appName,
    required this.appTitle,
    required this.siteHost,
    required this.playStoreId,
    required this.supportWhatsApp,
    required this.supportEmail,
    String? venueAccessWhatsApp,
    String? venueAccessEmail,
    required this.defaultCountryCode,
    required this.countryDialCode,
    required this.countryFlag,
    required this.addressHint,
    required this.welcomeMessage,
    required this.privacyPolicyUrl,
    this.revolutMerchant,
    this.momoUssdCode,
    this.biopayEnabled = false,
  }) : venueAccessWhatsApp = venueAccessWhatsApp ?? supportWhatsApp,
       venueAccessEmail = venueAccessEmail ?? supportEmail;

  /// Host prefix used for the role-specific app domains.
  ///
  /// Example: `dineinmt.ikanisa.com` -> `dineinmt`
  String get webHostPrefix => siteHost.split('.').first;

  /// Guest app hostname for this country.
  String get guestWebHost => '${webHostPrefix}g.ikanisa.com';

  /// Venue app hostname for this country.
  String get venueWebHost => '${webHostPrefix}v.ikanisa.com';

  /// Admin app hostname for this country.
  String get adminWebHost => '${webHostPrefix}a.ikanisa.com';

  /// Malta configuration.
  static const mt = CountryConfig(
    country: Country.mt,
    appName: 'Dinein MT',
    appTitle: 'DINEIN MALTA',
    siteHost: 'dineinmt.ikanisa.com',
    playStoreId: 'com.dineinmalta.app',
    supportWhatsApp: '35699711145',
    supportEmail: 'info@ikanisa.com',
    venueAccessWhatsApp: '35699711145',
    venueAccessEmail: 'info@ikanisa.com',
    defaultCountryCode: '356',
    countryDialCode: '+356',
    countryFlag: '🇲🇹',
    addressHint: '45 Tower Rd, Sliema, Malta',
    welcomeMessage: 'WELCOME TO DINEIN MALTA',
    privacyPolicyUrl: 'https://dineinmt.ikanisa.com/privacy',
    revolutMerchant: 'dineinmalta',
    biopayEnabled: false,
  );

  /// Rwanda configuration.
  static const rw = CountryConfig(
    country: Country.rw,
    appName: 'Dinein RW',
    appTitle: 'DINEIN RW',
    siteHost: 'dineinrw.ikanisa.com',
    playStoreId: 'com.dineinrw.app',
    supportWhatsApp: '250795588248',
    supportEmail: 'info@ikanisa.com',
    venueAccessWhatsApp: '250795588248',
    venueAccessEmail: 'info@ikanisa.com',
    defaultCountryCode: '250',
    countryDialCode: '+250',
    countryFlag: '🇷🇼',
    addressHint: 'KG 9 Ave, Kigali, Rwanda',
    welcomeMessage: 'WELCOME TO DINEIN RW',
    privacyPolicyUrl: 'https://dineinrw.ikanisa.com/privacy',
    momoUssdCode: '*182*8*1#', // MTN MoMo Rwanda
    biopayEnabled: true,
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

  /// Whether this country has BioPay face-payment enabled.
  bool get hasBioPay => biopayEnabled;

  /// Whether direct WhatsApp support is configured for this country.
  bool get hasWhatsAppSupport => supportWhatsApp.trim().isNotEmpty;

  /// Whether venue access WhatsApp support is configured for this country.
  bool get hasVenueAccessWhatsApp => venueAccessWhatsApp.trim().isNotEmpty;

  /// Local-digit length accepted for admin WhatsApp login in this country.
  int get adminWhatsAppLocalDigits {
    final digits = supportWhatsApp.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith(defaultCountryCode)) {
      final localDigits = digits.substring(defaultCountryCode.length);
      if (localDigits.length >= 8 && localDigits.length <= 10) {
        return localDigits.length;
      }
    }
    return country == Country.rw ? 10 : 8;
  }

  /// Share text for venue discovery.
  String shareText(String content) => '$content\nhttps://$siteHost';

  /// Terms of service URL.
  String get termsUrl => 'https://$siteHost/terms.html';

  /// Cookie policy URL (reuses privacy page).
  String get cookiePolicyUrl => privacyPolicyUrl;
}
