import 'url_strategy_stub.dart'
    if (dart.library.js_interop) 'url_strategy_web.dart'
    as impl;

void configureWebUrlStrategy() {
  impl.configureWebUrlStrategy();
}
