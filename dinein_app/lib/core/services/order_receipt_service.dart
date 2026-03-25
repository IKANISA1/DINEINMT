import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists guest order receipt tokens so unauthenticated order lookups can be
/// authorized without exposing raw order IDs as public access credentials.
class OrderReceiptService {
  OrderReceiptService._();

  static final instance = OrderReceiptService._();

  static const _receiptKeyPrefix = 'dinein.order_receipt.';
  static const _secureStorageTimeout = Duration(seconds: 2);
  static const _secureStorage = FlutterSecureStorage();

  String _keyForOrder(String orderId) => '$_receiptKeyPrefix$orderId';

  Future<void> saveReceiptToken(String orderId, String receiptToken) async {
    if (orderId.trim().isEmpty || receiptToken.trim().isEmpty) return;
    try {
      await _secureStorage
          .write(key: _keyForOrder(orderId), value: receiptToken.trim())
          .timeout(_secureStorageTimeout);
    } catch (_) {
      // If secure storage fails, we do not fall back to plain preferences.
    }
  }

  Future<String?> getReceiptToken(String orderId) async {
    if (orderId.trim().isEmpty) return null;
    try {
      final value = await _secureStorage
          .read(key: _keyForOrder(orderId))
          .timeout(_secureStorageTimeout);
      if (value == null || value.trim().isEmpty) return null;
      return value.trim();
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> getTrackedOrderIds() async {
    try {
      final all =
          await _secureStorage.readAll().timeout(_secureStorageTimeout);
      final orderIds =
          all.keys
              .where((key) => key.startsWith(_receiptKeyPrefix))
              .map((key) => key.substring(_receiptKeyPrefix.length).trim())
              .where((orderId) => orderId.isNotEmpty)
              .toList()
            ..sort();
      return orderIds;
    } catch (_) {
      return [];
    }
  }

  Future<void> clearReceiptToken(String orderId) async {
    if (orderId.trim().isEmpty) return;
    try {
      await _secureStorage
          .delete(key: _keyForOrder(orderId))
          .timeout(_secureStorageTimeout);
    } catch (_) {
      // Ignore secure storage cleanup failures.
    }
  }
}
