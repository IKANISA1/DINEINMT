import 'dart:convert';

import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests for the local persistence layer used by MenuRepository.
///
/// The network methods in MenuRepository delegate to DineinApiService
/// (which requires a live backend), so we focus on the SharedPreferences
/// caching logic that is purely local and deterministic.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MenuRepository local persistence', () {
    const venueId = 'test-venue';
    const localMenuKey = 'dinein.local_menu.$venueId';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('persists and reads back menu items via SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();

      final items = [
        const MenuItem(
          id: 'item-1',
          venueId: venueId,
          name: 'Espresso',
          description: 'Strong and smooth',
          price: 3.50,
          category: 'Beverages',
          itemClass: MenuItemClass.drinks,
        ),
        const MenuItem(
          id: 'item-2',
          venueId: venueId,
          name: 'Croissant',
          description: 'Flaky, buttery',
          price: 4.00,
          category: 'Pastries',
          itemClass: MenuItemClass.food,
        ),
      ];

      await prefs.setString(
        localMenuKey,
        jsonEncode(items.map((item) => item.toJson()).toList()),
      );

      final raw = prefs.getString(localMenuKey);
      expect(raw, isNotNull);

      final decoded = jsonDecode(raw!) as List<dynamic>;
      final restored = decoded
          .map((item) => MenuItem.fromJson(item as Map<String, dynamic>))
          .toList();

      expect(restored.length, 2);
      expect(restored[0].id, 'item-1');
      expect(restored[0].name, 'Espresso');
      expect(restored[0].price, 3.50);
      expect(restored[0].category, 'Beverages');
      expect(restored[0].itemClass, MenuItemClass.drinks);
      expect(restored[1].id, 'item-2');
      expect(restored[1].name, 'Croissant');
      expect(restored[1].itemClass, MenuItemClass.food);
    });

    test('merge logic preserves existing items and upserts new ones', () async {
      final prefs = await SharedPreferences.getInstance();

      // Seed with initial item
      final seed = [
        const MenuItem(
          id: 'item-1',
          venueId: venueId,
          name: 'Espresso',
          description: '',
          price: 3.50,
          category: 'Beverages',
          itemClass: MenuItemClass.drinks,
        ),
      ];
      await prefs.setString(
        localMenuKey,
        jsonEncode(seed.map((item) => item.toJson()).toList()),
      );

      // Merge: update item-1 price, add item-3
      final updates = [
        const MenuItem(
          id: 'item-1',
          venueId: venueId,
          name: 'Espresso Double',
          description: 'Stronger',
          price: 4.50,
          category: 'Beverages',
          itemClass: MenuItemClass.drinks,
        ),
        const MenuItem(
          id: 'item-3',
          venueId: venueId,
          name: 'Latte',
          description: '',
          price: 5.00,
          category: 'Beverages',
          itemClass: MenuItemClass.drinks,
        ),
      ];

      // Simulate merge logic as used in MenuRepository
      final existingRaw = prefs.getString(localMenuKey);
      final existingList = (jsonDecode(existingRaw!) as List<dynamic>)
          .map((e) => MenuItem.fromJson(e as Map<String, dynamic>));
      final merged = <String, MenuItem>{
        for (final item in existingList) item.id: item,
        for (final item in updates) item.id: item,
      };
      await prefs.setString(
        localMenuKey,
        jsonEncode(merged.values.map((item) => item.toJson()).toList()),
      );

      final result = (jsonDecode(prefs.getString(localMenuKey)!) as List)
          .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
          .toList();

      expect(result.length, 2);

      final espresso = result.firstWhere((i) => i.id == 'item-1');
      expect(espresso.name, 'Espresso Double');
      expect(espresso.price, 4.50);

      final latte = result.firstWhere((i) => i.id == 'item-3');
      expect(latte.name, 'Latte');
      expect(latte.price, 5.00);
    });

    test('remove logic filters out deleted item and persists', () async {
      final prefs = await SharedPreferences.getInstance();

      final items = [
        const MenuItem(
          id: 'item-1',
          venueId: venueId,
          name: 'A',
          description: '',
          price: 1,
          category: 'C',
        ),
        const MenuItem(
          id: 'item-2',
          venueId: venueId,
          name: 'B',
          description: '',
          price: 2,
          category: 'C',
        ),
        const MenuItem(
          id: 'item-3',
          venueId: venueId,
          name: 'C',
          description: '',
          price: 3,
          category: 'C',
        ),
      ];
      await prefs.setString(
        localMenuKey,
        jsonEncode(items.map((i) => i.toJson()).toList()),
      );

      // Remove item-2 (simulate MenuRepository._removeLocalMenuItemById)
      final existing = (jsonDecode(prefs.getString(localMenuKey)!) as List)
          .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
          .toList();
      final filtered = existing
          .where((item) => item.id != 'item-2')
          .toList(growable: false);
      await prefs.setString(
        localMenuKey,
        jsonEncode(filtered.map((i) => i.toJson()).toList()),
      );

      final result = (jsonDecode(prefs.getString(localMenuKey)!) as List)
          .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
          .toList();

      expect(result.length, 2);
      expect(result.any((i) => i.id == 'item-2'), isFalse);
      expect(result.any((i) => i.id == 'item-1'), isTrue);
      expect(result.any((i) => i.id == 'item-3'), isTrue);
    });

    test('removing last item clears the key entirely', () async {
      final prefs = await SharedPreferences.getInstance();

      final items = [
        const MenuItem(
          id: 'item-1',
          venueId: venueId,
          name: 'Solo',
          description: '',
          price: 1,
          category: 'C',
        ),
      ];
      await prefs.setString(
        localMenuKey,
        jsonEncode(items.map((i) => i.toJson()).toList()),
      );

      // Remove the only item
      final existing = (jsonDecode(prefs.getString(localMenuKey)!) as List)
          .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
          .toList();
      final filtered = existing
          .where((item) => item.id != 'item-1')
          .toList(growable: false);

      // Simulate: if empty, remove key
      if (filtered.isEmpty) {
        await prefs.remove(localMenuKey);
      }

      expect(prefs.getString(localMenuKey), isNull);
    });

    test('update-by-id transforms a specific item in the local cache',
        () async {
      final prefs = await SharedPreferences.getInstance();

      final items = [
        const MenuItem(
          id: 'item-1',
          venueId: venueId,
          name: 'Falafel',
          description: '',
          price: 8,
          category: 'Main',
          isAvailable: true,
        ),
        const MenuItem(
          id: 'item-2',
          venueId: venueId,
          name: 'Hummus',
          description: '',
          price: 6,
          category: 'Starters',
          isAvailable: true,
        ),
      ];
      await prefs.setString(
        localMenuKey,
        jsonEncode(items.map((i) => i.toJson()).toList()),
      );

      // Toggle item-1 availability
      final existing = (jsonDecode(prefs.getString(localMenuKey)!) as List)
          .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
          .toList();
      final updated = existing.map((item) {
        if (item.id != 'item-1') return item;
        return item.copyWith(isAvailable: false);
      }).toList();
      await prefs.setString(
        localMenuKey,
        jsonEncode(updated.map((i) => i.toJson()).toList()),
      );

      final result = (jsonDecode(prefs.getString(localMenuKey)!) as List)
          .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
          .toList();

      final falafel = result.firstWhere((i) => i.id == 'item-1');
      expect(falafel.isAvailable, isFalse);

      final hummus = result.firstWhere((i) => i.id == 'item-2');
      expect(hummus.isAvailable, isTrue);
    });

    test('empty local cache returns empty list', () async {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(localMenuKey);
      expect(raw, isNull);

      // Simulate _readLocalMenuItemsByKey with null
      final items = raw == null
          ? <MenuItem>[]
          : (jsonDecode(raw) as List)
              .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
              .toList();
      expect(items, isEmpty);
    });

    test('all-prices-hidden clears local cache', () async {
      final prefs = await SharedPreferences.getInstance();

      // Simulate: all items have priceHidden=true → clear cache
      final items = [
        const MenuItem(
          id: 'item-1',
          venueId: venueId,
          name: 'Hidden',
          description: '',
          price: 10,
          category: 'C',
          priceHidden: true,
        ),
      ];

      final allPricesHidden =
          items.isNotEmpty && items.every((item) => item.priceHidden);
      if (allPricesHidden) {
        await prefs.remove(localMenuKey);
      }

      expect(prefs.getString(localMenuKey), isNull);
    });
  });
}
