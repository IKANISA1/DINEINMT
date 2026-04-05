import 'dart:js_interop';
import 'package:flutter/foundation.dart';

/// Web implementation using dart:js_interop + eval.
void setAppBadge(int count) {
  try {
    _eval('navigator.setAppBadge($count)');
  } catch (e) {
    debugPrint('[badge] setAppBadge not supported: $e');
  }
}

void clearAppBadge() {
  try {
    _eval('navigator.clearAppBadge()');
  } catch (e) {
    debugPrint('[badge] clearAppBadge not supported: $e');
  }
}

@JS('eval')
external JSAny? _eval(String code);
