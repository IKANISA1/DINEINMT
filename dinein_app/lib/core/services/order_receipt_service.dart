import 'package:shared_preferences/shared_preferences.dart';

/// Persists guest order receipt tokens so unauthenticated order lookups can be
/// authorized without exposing raw order IDs as public access credentials.
class OrderReceiptService {
  OrderReceiptService._();

  static final instance = OrderReceiptService._();

  static const _receiptKeyPrefix = 'dinein.order_receipt.';

  String _keyForOrder(String orderId) => '$_receiptKeyPrefix$orderId';

  Future<void> saveReceiptToken(String orderId, String receiptToken) async {
    if (orderId.trim().isEmpty || receiptToken.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyForOrder(orderId), receiptToken.trim());
  }

  Future<String?> getReceiptToken(String orderId) async {
    if (orderId.trim().isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyForOrder(orderId));
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  Future<List<String>> getTrackedOrderIds() async {
    final prefs = await SharedPreferences.getInstance();
    final orderIds =
        prefs
            .getKeys()
            .where((key) => key.startsWith(_receiptKeyPrefix))
            .map((key) => key.substring(_receiptKeyPrefix.length).trim())
            .where((orderId) => orderId.isNotEmpty)
            .toList()
          ..sort();
    return orderIds;
  }

  Future<void> clearReceiptToken(String orderId) async {
    if (orderId.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyForOrder(orderId));
  }
}
