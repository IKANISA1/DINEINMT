import 'dart:convert';

import 'package:core_pkg/constants/enums.dart';
import 'package:dinein_app/core/providers/cart_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists cart state to SharedPreferences (backed by localStorage on web).
///
/// The cart is serialized as JSON and restored on app startup so that
/// users don't lose their cart on page refresh (critical for PWA UX).
class CartPersistenceService {
  static const _key = 'dinein_cart_state';

  /// Maximum age of a persisted cart before it's considered stale.
  /// Cart items for a venue shouldn't persist forever.
  static const _maxAge = Duration(hours: 12);

  static const _timestampKey = 'dinein_cart_timestamp';

  /// Save the current cart state.
  static Future<void> save(CartState cart) async {
    final prefs = await SharedPreferences.getInstance();
    if (cart.isEmpty) {
      await prefs.remove(_key);
      await prefs.remove(_timestampKey);
      return;
    }

    final json = _cartToJson(cart);
    await prefs.setString(_key, jsonEncode(json));
    await prefs.setInt(
      _timestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Restore the cart state from storage, or null if not available/stale.
  static Future<CartState?> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;

    // Check if the cart is stale
    final timestamp = prefs.getInt(_timestampKey);
    if (timestamp != null) {
      final savedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(savedAt) > _maxAge) {
        await prefs.remove(_key);
        await prefs.remove(_timestampKey);
        return null;
      }
    }

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return _cartFromJson(json);
    } catch (_) {
      // Corrupted data — wipe it
      await prefs.remove(_key);
      await prefs.remove(_timestampKey);
      return null;
    }
  }

  /// Clear persisted cart.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_timestampKey);
  }

  // ─── Serialization ───────────────────────────────────────────────────

  static Map<String, dynamic> _cartToJson(CartState cart) {
    return {
      'venueId': cart.venueId,
      'venueSlug': cart.venueSlug,
      'venueName': cart.venueName,
      'venueRevolutUrl': cart.venueRevolutUrl,
      'venueCountry': cart.venueCountry?.name,
      'tableNumber': cart.tableNumber,
      'specialRequests': cart.specialRequests,
      'serviceFeeRate': cart.serviceFeeRate,
      'items': cart.items.map(_itemToJson).toList(),
    };
  }

  static Map<String, dynamic> _itemToJson(CartItem item) {
    return {
      'menuItemId': item.menuItemId,
      'name': item.name,
      'description': item.description,
      'imageUrl': item.imageUrl,
      'price': item.price,
      'quantity': item.quantity,
    };
  }

  static CartState _cartFromJson(Map<String, dynamic> json) {
    final countryName = json['venueCountry'] as String?;
    final items = (json['items'] as List<dynamic>?)
            ?.map((e) => _itemFromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    return CartState(
      venueId: json['venueId'] as String?,
      venueSlug: json['venueSlug'] as String?,
      venueName: json['venueName'] as String?,
      venueRevolutUrl: json['venueRevolutUrl'] as String?,
      venueCountry: countryName != null
          ? Country.values.firstWhere(
              (c) => c.name == countryName,
              orElse: () => Country.mt,
            )
          : null,
      tableNumber: json['tableNumber'] as String?,
      specialRequests: json['specialRequests'] as String?,
      serviceFeeRate: (json['serviceFeeRate'] as num?)?.toDouble() ?? 0.05,
      items: items,
    );
  }

  static CartItem _itemFromJson(Map<String, dynamic> json) {
    return CartItem(
      menuItemId: json['menuItemId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    );
  }
}
