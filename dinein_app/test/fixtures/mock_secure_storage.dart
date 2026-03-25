import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper to mock FlutterSecureStorage method channel.
class MockSecureStorage {
  static const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  static final Map<String, String> _storage = {};

  static void setup() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          switch (methodCall.method) {
            case 'read':
              return _storage[methodCall.arguments['key']];
            case 'write':
              _storage[methodCall.arguments['key']] = methodCall.arguments['value'];
              return null;
            case 'delete':
              _storage.remove(methodCall.arguments['key']);
              return null;
            case 'deleteAll':
              _storage.clear();
              return null;
            case 'readAll':
              return _storage;
            case 'containsKey':
              return _storage.containsKey(methodCall.arguments['key']);
            default:
              return null;
          }
        });
  }

  static void clear() {
    _storage.clear();
  }

  static void setMockValue(String key, String value) {
    _storage[key] = value;
  }
}
