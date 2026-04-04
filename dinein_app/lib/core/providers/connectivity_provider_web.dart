import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Web implementation — reads `navigator.onLine` and listens for
/// the custom `dinein-pwa-connection-change` events dispatched by
/// the JS bridge in `index.html`.

@JS('window')
external JSObject get _window;

@JS('navigator')
external JSObject get _navigator;

bool isOnline() {
  try {
    final online = _navigator.getProperty('onLine'.toJS);
    if (online != null && online.isA<JSBoolean>()) {
      return (online as JSBoolean).toDart;
    }
    return true;
  } catch (_) {
    return true;
  }
}

Stream<bool> connectivityStream() {
  final controller = StreamController<bool>.broadcast();

  void handleOnline(JSAny? _) => controller.add(true);
  void handleOffline(JSAny? _) => controller.add(false);

  _window.callMethod(
    'addEventListener'.toJS,
    'online'.toJS,
    handleOnline.toJS,
  );
  _window.callMethod(
    'addEventListener'.toJS,
    'offline'.toJS,
    handleOffline.toJS,
  );

  return controller.stream;
}
