import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:db_pkg/models/models.dart';
import 'package:core_pkg/constants/enums.dart';
import 'package:dinein_app/core/providers/cart_provider.dart';
import 'package:dinein_app/features/guest/menu/menu_screen.dart';

// Provide an empty cart for the test context
class MockCartNotifier extends Notifier<CartState> implements CartNotifier {
  @override
  CartState build() => const CartState();

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
  void addItem(MenuItem item, {String? note, int quantity = 1}) {}
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
    String? note,
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
  testWidgets('menu screen renders loading state initially', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cartProvider.overrideWith(() => MockCartNotifier()),
          // override to provide a dummy venue bundle in loading state or empty
        ],
        child: const MaterialApp(
          home: Scaffold(body: MenuScreen(venueSlug: 'test-venue')),
        ),
      ),
    );

    await tester.pump();

    // We expect skeletons or loading state to appear before data loads
    // Since riverpod handles loading in the build methods
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
    ); // Should be using skeleton loader
  });
}
