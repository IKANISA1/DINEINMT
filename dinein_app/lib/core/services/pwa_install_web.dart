import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:dinein_app/core/services/app_telemetry.dart';

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
  } catch (error, stackTrace) {
    unawaited(
      AppTelemetryService.reportError(
        error,
        stackTrace,
        context: 'pwa_install_web.has_deferred_prompt',
      ),
    );
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
  } catch (error, stackTrace) {
    unawaited(
      AppTelemetryService.reportError(
        error,
        stackTrace,
        context: 'pwa_install_web.trigger_install_prompt',
      ),
    );
  }
}

void setAppBadge(int count) {
  try {
    final nav = _window.getProperty('navigator'.toJS);
    if (nav != null && nav.isA<JSObject>()) {
      final navObj = nav as JSObject;
      if (navObj.hasProperty('setAppBadge'.toJS).toDart) {
        navObj.callMethod('setAppBadge'.toJS, count.toJS);
      }
    }
  } catch (error, stackTrace) {
    unawaited(
      AppTelemetryService.reportError(
        error,
        stackTrace,
        context: 'pwa_install_web.set_app_badge',
        details: {'count': count},
      ),
    );
  }
}

void clearAppBadge() {
  try {
    final nav = _window.getProperty('navigator'.toJS);
    if (nav != null && nav.isA<JSObject>()) {
      final navObj = nav as JSObject;
      if (navObj.hasProperty('clearAppBadge'.toJS).toDart) {
        navObj.callMethod('clearAppBadge'.toJS);
      }
    }
  } catch (error, stackTrace) {
    unawaited(
      AppTelemetryService.reportError(
        error,
        stackTrace,
        context: 'pwa_install_web.clear_app_badge',
      ),
    );
  }
}
