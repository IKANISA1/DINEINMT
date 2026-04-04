import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dinein_app/core/providers/cart_provider.dart';
import 'package:dinein_app/features/guest/cart/cart_screen.dart';

import 'package:db_pkg/models/models.dart';
import 'package:core_pkg/constants/enums.dart';

// A simple local override for the cart provider state
class MockCartNotifier extends Notifier<CartState> implements CartNotifier {
  final CartState initialState;

  MockCartNotifier(this.initialState);

  @override
  CartState build() => initialState;

  @override
  void setVenue({
    required String venueId,
    required String venueSlug,
    required String venueName,
    String? venueRevolutUrl,
    Country? venueCountry,
    String? tableNumber,
  }) {}
  @override
  void setTableNumber(String? tableNumber) {}
  @override
  void setSpecialRequests(String? specialRequests) {}
  @override
  void addItem(MenuItem item) {}
  @override
  void removeItem(String menuItemId) {}
  @override
  void setQuantity(
    String menuItemId,
    int quantity, {
    String? name,
    String? description,
    String? imageUrl,
    double? price,
  }) {}
  @override
  void clear() {}

  @override
  int quantityOf(String menuItemId) => 0;

  @override
  Order buildOrder({required PaymentMethod paymentMethod, String? userId}) {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('cart screen shows empty state when cart count is 0', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cartProvider.overrideWith(() => MockCartNotifier(const CartState())),
        ],
        child: const MaterialApp(home: Scaffold(body: CartScreen())),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(
      find.text("Looks like you haven't added\nanything to your order yet."),
      findsOneWidget,
    );
  });
}
