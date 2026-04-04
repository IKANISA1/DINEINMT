import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Web implementation — accesses `window.__dineinDeferredInstallPrompt`.

@JS('window')
external JSObject get _window;

bool hasDeferredPrompt() {
  try {
    final canTrigger = _window.getProperty(
      '__dineinCanTriggerInstallPrompt'.toJS,
    );
    if (canTrigger != null && canTrigger.isA<JSBoolean>()) {
      return (canTrigger as JSBoolean).toDart;
    }
    final prompt = _window.getProperty('__dineinDeferredInstallPrompt'.toJS);
    return prompt != null && prompt.isA<JSObject>();
  } catch (_) {
    return false;
  }
}

void triggerInstallPrompt() {
  try {
    final handler = _window.getProperty('__dineinTriggerInstallPrompt'.toJS);
    if (handler != null && handler.isA<JSObject>()) {
      _window.callMethod('__dineinTriggerInstallPrompt'.toJS);
      return;
    }
    final prompt = _window.getProperty('__dineinDeferredInstallPrompt'.toJS);
    if (prompt != null && prompt.isA<JSObject>()) {
      (prompt as JSObject).callMethod('prompt'.toJS);
    }
  } catch (_) {
    // Silently fail — prompt may have been spent or dismissed
  }
}
