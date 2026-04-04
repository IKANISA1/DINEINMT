import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Web implementation — detects iOS Safari and standalone mode
/// using navigator.userAgent and window.matchMedia.

@JS('navigator')
external JSObject get _navigator;

@JS('window')
external JSObject get _window;

/// Detect if the browser is iOS Safari.
///
/// Checks for iPhone/iPad/iPod in user agent AND absence of Chrome/CriOS/FxiOS
/// (which would indicate a non-Safari browser on iOS).
bool isIosSafari() {
  try {
    final uaProperty = _navigator.getProperty('userAgent'.toJS);
    if (uaProperty == null) return false;
    final ua = (uaProperty as JSString).toDart;

    final isIos =
        ua.contains('iPhone') || ua.contains('iPad') || ua.contains('iPod');
    if (!isIos) return false;

    // Exclude Chrome, Firefox, and other browsers on iOS
    final isNotSafari =
        ua.contains('CriOS') || // Chrome on iOS
        ua.contains('FxiOS') || // Firefox on iOS
        ua.contains('OPiOS') || // Opera on iOS
        ua.contains('EdgiOS');  // Edge on iOS
    return !isNotSafari;
  } catch (_) {
    return false;
  }
}

/// Check if the app is running in standalone mode (already installed as PWA).
bool isStandalone() {
  try {
    // Check navigator.standalone (Safari-specific)
    final standalone = _navigator.getProperty('standalone'.toJS);
    if (standalone != null && standalone.isA<JSBoolean>()) {
      if ((standalone as JSBoolean).toDart) return true;
    }

    // Also check display-mode: standalone media query
    final matchMedia = _window.callMethod(
      'matchMedia'.toJS,
      '(display-mode: standalone)'.toJS,
    );
    if (matchMedia != null && matchMedia.isA<JSObject>()) {
      final matches = (matchMedia as JSObject).getProperty('matches'.toJS);
      if (matches != null && matches.isA<JSBoolean>()) {
        return (matches as JSBoolean).toDart;
      }
    }

    return false;
  } catch (_) {
    return false;
  }
}
