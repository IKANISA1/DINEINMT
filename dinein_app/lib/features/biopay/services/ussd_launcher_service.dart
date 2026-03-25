import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service for launching Rwanda MoMo USSD dial strings.
///
/// Opens the phone dialer with the USSD code pre-filled.
/// The app does NOT handle payment verification — the handoff
/// happens entirely outside the app via the native dialer.
class UssdLauncherService {
  /// Launch a USSD string via the native phone dialer.
  ///
  /// [ussdString] should be a valid Rwanda USSD pattern like `*182*8*1*500#`.
  /// Returns `true` if the dialer was launched, `false` otherwise.
  static Future<bool> launch(String ussdString) async {
    // Encode the USSD for tel: URI (# → %23)
    final encoded = ussdString.replaceAll('#', '%23');
    final uri = Uri.parse('tel:$encoded');

    try {
      final canDo = await canLaunchUrl(uri);
      if (!canDo) return false;

      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on PlatformException {
      return false;
    }
  }

  /// Check if the device can launch USSD codes.
  static Future<bool> isAvailable() async {
    try {
      return await canLaunchUrl(Uri.parse('tel:*123%23'));
    } catch (_) {
      return false;
    }
  }
}
