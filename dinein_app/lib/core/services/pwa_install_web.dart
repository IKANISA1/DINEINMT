import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Web implementation — accesses `window.__dineinDeferredInstallPrompt`.

@JS('window')
external JSObject get _window;

bool hasDeferredPrompt() {
  try {
    final prompt = _window.getProperty('__dineinDeferredInstallPrompt'.toJS);
    return prompt != null && prompt.isA<JSObject>();
  } catch (_) {
    return false;
  }
}

void triggerInstallPrompt() {
  try {
    final prompt = _window.getProperty('__dineinDeferredInstallPrompt'.toJS);
    if (prompt != null && prompt.isA<JSObject>()) {
      (prompt as JSObject).callMethod('prompt'.toJS);
    }
  } catch (_) {
    // Silently fail — prompt may have been spent or dismissed
  }
}
