import 'package:core_pkg/constants/enums.dart';
import '../fixtures/mock_data.dart';
import 'package:dinein_app/core/providers/cart_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late CartNotifier notifier;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
    notifier = container.read(cartProvider.notifier);

    final venue = MockData.venues.first;
    notifier.setVenue(
      venueId: venue.id,
      venueSlug: venue.slug,
      venueName: venue.name,
      venueCountry: venue.country,
    );
  });

  tearDown(() => container.dispose());

  test('adding item multiple times increments quantity', () {
    final item = MockData.menuItems.first;
    notifier.addItem(item);
    notifier.addItem(item);
    notifier.addItem(item);

    final state = container.read(cartProvider);
    expect(state.itemCount, 3);
    expect(state.items, hasLength(1));
    expect(state.items.first.quantity, 3);
  });

  test('removeItem decrements quantity to zero removes entry', () {
    final item = MockData.menuItems.first;
    notifier.addItem(item);
    notifier.addItem(item);
    notifier.removeItem(item.id);

    final state = container.read(cartProvider);
    expect(state.itemCount, 1);

    notifier.removeItem(item.id);
    final afterRemoveAll = container.read(cartProvider);
    expect(afterRemoveAll.itemCount, 0);
    expect(afterRemoveAll.items, isEmpty);
  });

  test('clear empties all items and resets venue context', () {
    final item = MockData.menuItems.first;
    notifier.addItem(item);
    notifier.addItem(item);
    notifier.clear();

    final state = container.read(cartProvider);
    expect(state.items, isEmpty);
    expect(state.itemCount, 0);
    expect(state.subtotal, 0.0);
    expect(state.venueId, isNull);
  });

  test('empty cart has zero subtotal and service fee', () {
    final state = container.read(cartProvider);
    expect(state.subtotal, 0.0);
    expect(state.serviceFee, 0.0);
    expect(state.itemCount, 0);
    expect(state.isEmpty, isTrue);
  });

  test('buildOrder uses table number from venue context', () {
    final item = MockData.menuItems.first;

    notifier.setVenue(
      venueId: MockData.venues.first.id,
      venueSlug: MockData.venues.first.slug,
      venueName: MockData.venues.first.name,
      venueCountry: MockData.venues.first.country,
      tableNumber: '7',
    );

    // Re-add after venue reset
    notifier.addItem(item);

    final order = notifier.buildOrder(
      paymentMethod: PaymentMethod.cash,
    );

    expect(order.tableNumber, '7');
    expect(order.paymentMethod, PaymentMethod.cash);
  });

  test('setSpecialRequests is included in built order', () {
    final item = MockData.menuItems.first;
    notifier.addItem(item);
    notifier.setSpecialRequests('Peanut allergy');

    final order = notifier.buildOrder(
      paymentMethod: PaymentMethod.cash,
    );

    expect(order.specialRequests, 'Peanut allergy');
  });

  test('single item order has correct subtotal and service fee', () {
    final item = MockData.menuItems.first;
    notifier.addItem(item);

    final order = notifier.buildOrder(
      paymentMethod: PaymentMethod.cash,
    );

    expect(order.subtotal, item.price);
    expect(order.serviceFee, item.price * 0.05);
    expect(order.total, item.price + (item.price * 0.05));
  });

  test('adding items from multiple categories works correctly', () {
    final items = MockData.menuItems;
    for (final item in items) {
      notifier.addItem(item);
    }

    final state = container.read(cartProvider);
    expect(state.itemCount, items.length);
    expect(state.items, hasLength(items.length));
  });

  test('setQuantity directly sets item quantity', () {
    final item = MockData.menuItems.first;
    notifier.addItem(item);
    notifier.setQuantity(item.id, 5);

    final state = container.read(cartProvider);
    expect(state.items.first.quantity, 5);
    expect(state.itemCount, 5);
  });

  test('setQuantity to zero removes the item', () {
    final item = MockData.menuItems.first;
    notifier.addItem(item);
    notifier.setQuantity(item.id, 0);

    final state = container.read(cartProvider);
    expect(state.items, isEmpty);
  });

  test('quantityOf returns 0 for absent items', () {
    expect(notifier.quantityOf('nonexistent'), 0);
  });

  test('different notes create separate cart lines for the same menu item', () {
    final item = MockData.menuItems.first;
    notifier.addItem(item, note: 'No onions');
    notifier.addItem(item, note: 'Extra spicy');

    final state = container.read(cartProvider);

    expect(state.items, hasLength(2));
    expect(state.items.map((entry) => entry.note), containsAll([
      'No onions',
      'Extra spicy',
    ]));
  });

  test('quantityOf aggregates across note variants', () {
    final item = MockData.menuItems.first;
    notifier.addItem(item, note: 'No onions');
    notifier.addItem(item, note: 'Extra spicy');
    notifier.addItem(item);

    expect(notifier.quantityOf(item.id), 3);
  });

  test('setQuantity updates a specific note-aware cart line', () {
    final item = MockData.menuItems.first;
    notifier.addItem(item, note: 'No onions');
    notifier.addItem(item, note: 'Extra spicy');

    final state = container.read(cartProvider);
    final noOnionsLine = state.items.firstWhere(
      (entry) => entry.note == 'No onions',
    );

    notifier.setQuantity(noOnionsLine.lineId, 4, note: noOnionsLine.note);

    final updatedState = container.read(cartProvider);
    expect(
      updatedState.items.firstWhere((entry) => entry.note == 'No onions').quantity,
      4,
    );
    expect(
      updatedState.items.firstWhere((entry) => entry.note == 'Extra spicy').quantity,
      1,
    );
  });

  test('currency symbol defaults to EUR', () {
    final state = container.read(cartProvider);
    expect(state.currencySymbol, '€');
  });

  test('paymentMethods includes cash and revolut', () {
    final state = container.read(cartProvider);
    expect(state.paymentMethods, contains(PaymentMethod.cash));
    expect(state.paymentMethods, contains(PaymentMethod.revolutLink));
  });
}
