import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:dinein_app/core/services/app_telemetry.dart';

/// Web implementation using dart:js_interop + eval.
void setAppBadge(int count) {
  try {
    _eval('navigator.setAppBadge($count)');
  } catch (e) {
    debugPrint('[badge] setAppBadge not supported: $e');
    unawaited(
      AppTelemetryService.reportError(
        e,
        StackTrace.current,
        context: 'web_badge.set',
        details: {'count': count},
      ),
    );
  }
}

void clearAppBadge() {
  try {
    _eval('navigator.clearAppBadge()');
  } catch (e) {
    debugPrint('[badge] clearAppBadge not supported: $e');
    unawaited(
      AppTelemetryService.reportError(
        e,
        StackTrace.current,
        context: 'web_badge.clear',
      ),
    );
  }
}

@JS('eval')
external JSAny? _eval(String code);
