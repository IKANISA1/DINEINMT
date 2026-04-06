import 'package:core_pkg/constants/enums.dart';
import '../fixtures/mock_data.dart';
import 'package:dinein_app/core/providers/cart_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  test('cart builds an order using the active venue context', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final venue = MockData.venues.first;
    final item = MockData.menuItems.firstWhere(
      (entry) => entry.venueId == venue.id,
    );
    final notifier = container.read(cartProvider.notifier);

    notifier.setVenue(
      venueId: venue.id,
      venueSlug: venue.slug,
      venueName: venue.name,
      venueCountry: venue.country,
      tableNumber: '12',
    );
    notifier.addItem(item);
    notifier.addItem(item);

    final state = container.read(cartProvider);
    final order = notifier.buildOrder(
      paymentMethod: PaymentMethod.revolutLink,
      userId: 'guest-1',
    );
    final expectedSubtotal = item.price * 2;
    final expectedServiceFee = expectedSubtotal * 0.05;

    expect(state.itemCount, 2);
    expect(state.subtotal, expectedSubtotal);
    expect(order.venueId, venue.id);
    expect(order.venueName, venue.name);
    expect(order.userId, 'guest-1');
    expect(order.tableNumber, '12');
    expect(order.paymentMethod, PaymentMethod.revolutLink);
    expect(order.subtotal, expectedSubtotal);
    expect(order.serviceFee, expectedServiceFee);
    expect(order.total, expectedSubtotal + expectedServiceFee);
    expect(order.items, hasLength(1));
    expect(order.items.single.quantity, 2);
    expect(order.items.single.description, item.description);
    expect(order.items.single.imageUrl, item.imageUrl);
  });

  test(
    'switching venues resets cart items and keeps the new venue context',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final firstVenue = MockData.venues.first;
      final secondVenue = MockData.venues[1];
      final firstItem = MockData.menuItems.firstWhere(
        (entry) => entry.venueId == firstVenue.id,
      );
      final notifier = container.read(cartProvider.notifier);

      notifier.setVenue(
        venueId: firstVenue.id,
        venueSlug: firstVenue.slug,
        venueName: firstVenue.name,
        venueCountry: firstVenue.country,
      );
      notifier.addItem(firstItem);

      notifier.setVenue(
        venueId: secondVenue.id,
        venueSlug: secondVenue.slug,
        venueName: secondVenue.name,
        venueCountry: secondVenue.country,
      );

      final state = container.read(cartProvider);
      expect(state.venueId, secondVenue.id);
      expect(state.venueSlug, secondVenue.slug);
      expect(state.items, isEmpty);
      expect(state.itemCount, 0);
    },
  );
}
