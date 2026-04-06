

import 'package:core_pkg/constants/enums.dart';
import 'package:dinein_app/core/providers/cart_provider.dart';
import 'package:dinein_app/core/services/cart_persistence_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CartPersistenceService', () {
    test('save and restore round-trips a cart state', () async {
      const cart = CartState(
        venueId: 'venue_1',
        venueSlug: 'ocean-pearl',
        venueName: 'Ocean Pearl',
        venueRevolutUrl: 'https://revolut.me/ocean',
        venueCountry: Country.mt,
        tableNumber: '4',
        specialRequests: 'No onions',
        serviceFeeRate: 0.05,
        items: [
          CartItem(
            menuItemId: 'item_1',
            name: 'Dry-Aged Ribeye',
            description: 'Charcoal grilled.',
            imageUrl: 'https://example.com/ribeye.jpg',
            price: 48.0,
            quantity: 2,
          ),
          CartItem(
            menuItemId: 'item_2',
            name: 'Aperol Spritz',
            price: 12.0,
            quantity: 1,
          ),
        ],
      );

      await CartPersistenceService.save(cart);
      final restored = await CartPersistenceService.restore();

      expect(restored, isNotNull);
      expect(restored!.venueId, 'venue_1');
      expect(restored.venueSlug, 'ocean-pearl');
      expect(restored.venueName, 'Ocean Pearl');
      expect(restored.venueRevolutUrl, 'https://revolut.me/ocean');
      expect(restored.venueCountry, Country.mt);
      expect(restored.tableNumber, '4');
      expect(restored.specialRequests, 'No onions');
      expect(restored.items.length, 2);
      expect(restored.items[0].menuItemId, 'item_1');
      expect(restored.items[0].name, 'Dry-Aged Ribeye');
      expect(restored.items[0].price, 48.0);
      expect(restored.items[0].quantity, 2);
      expect(restored.items[1].menuItemId, 'item_2');
      expect(restored.items[1].quantity, 1);
    });

    test('returns null when no cart is saved', () async {
      final restored = await CartPersistenceService.restore();
      expect(restored, isNull);
    });

    test('clears persisted cart', () async {
      const cart = CartState(
        venueId: 'venue_1',
        venueSlug: 'test',
        venueName: 'Test',
        items: [
          CartItem(menuItemId: 'i', name: 'x', price: 1.0),
        ],
      );

      await CartPersistenceService.save(cart);
      await CartPersistenceService.clear();
      final restored = await CartPersistenceService.restore();
      expect(restored, isNull);
    });

    test('saves nothing when cart is empty', () async {
      await CartPersistenceService.save(const CartState());
      final restored = await CartPersistenceService.restore();
      expect(restored, isNull);
    });

    test('returns null for corrupted data', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dinein_cart_state', '{invalid json}}}');

      final restored = await CartPersistenceService.restore();
      // Corrupted data should be wiped and return null
      expect(restored, isNull);
      // Verify it was cleaned up
      expect(prefs.getString('dinein_cart_state'), isNull);
    });

    test('returns null for stale cart (older than 12 hours)', () async {
      const cart = CartState(
        venueId: 'venue_1',
        venueSlug: 'test',
        venueName: 'Test',
        items: [
          CartItem(menuItemId: 'i', name: 'x', price: 1.0),
        ],
      );

      // Save with timestamp 13 hours ago
      final prefs = await SharedPreferences.getInstance();
      await CartPersistenceService.save(cart);
      final staleTimestamp = DateTime.now()
          .subtract(const Duration(hours: 13))
          .millisecondsSinceEpoch;
      await prefs.setInt('dinein_cart_timestamp', staleTimestamp);

      final restored = await CartPersistenceService.restore();
      expect(restored, isNull, reason: 'Cart older than 12h should be stale');
    });

    test('preserves Country.rw in round-trip', () async {
      const cart = CartState(
        venueId: 'v_rw',
        venueSlug: 'kigali-kitchen',
        venueName: 'Kigali Kitchen',
        venueCountry: Country.rw,
        items: [
          CartItem(menuItemId: 'rw_1', name: 'Brochettes', price: 3500.0),
        ],
      );

      await CartPersistenceService.save(cart);
      final restored = await CartPersistenceService.restore();
      expect(restored!.venueCountry, Country.rw);
    });
  });
}
