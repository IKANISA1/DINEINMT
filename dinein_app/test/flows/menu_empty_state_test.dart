import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/features/guest/menu/menu_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('guest menu empty state avoids coming soon language', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          menuItemsProvider(
            'venue_1',
          ).overrideWith((ref) async => const <MenuItem>[]),
        ],
        child: const MaterialApp(home: MenuScreen(venueId: 'venue_1')),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Menu not published yet'), findsOneWidget);
    expect(
      find.text(
        'This venue has not added menu items yet. Check back later or ask the team in person.',
      ),
      findsOneWidget,
    );
    expect(find.text('Menu coming soon'), findsNothing);
  });

  testWidgets('guest menu category tabs jump to later sections lazily', (
    tester,
  ) async {
    const venue = Venue(
      id: 'venue_1',
      name: 'Harbor Table',
      slug: 'harbor-table',
      category: 'Seafood',
      description: 'Seafront seafood dining with sunset views.',
      address: 'Valletta Waterfront',
    );

    final firstCategoryItems = List.generate(
      8,
      (index) => MenuItem(
        id: 'coffee_$index',
        venueId: venue.id,
        name: 'Coffee $index',
        description: 'House coffee number $index.',
        price: (2 + index).toDouble(),
        category: 'Coffees',
      ),
    );

    final items = [
      ...firstCategoryItems,
      MenuItem(
        id: 'dessert_1',
        venueId: venue.id,
        name: 'Tiramisu',
        description: 'Classic tiramisu.',
        price: 7,
        category: 'Desserts',
      ),
    ];

    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          venueByIdProvider(venue.id).overrideWith((ref) async => venue),
          menuItemsProvider(venue.id).overrideWith((ref) async => items),
        ],
        child: const MaterialApp(home: MenuScreen(venueId: 'venue_1')),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Tiramisu'), findsNothing);

    await tester.tap(find.text('DESSERTS'));
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Tiramisu'), findsOneWidget);
  });

  testWidgets('guest menu search filters items in place', (tester) async {
    const venue = Venue(
      id: 'venue_search',
      name: 'Harbor Table',
      slug: 'harbor-table',
      category: 'Seafood',
      description: 'Seafront seafood dining with sunset views.',
      address: 'Valletta Waterfront',
    );

    final items = [
      MenuItem(
        id: 'coffee_1',
        venueId: venue.id,
        name: 'Espresso',
        description: 'Strong and short coffee.',
        price: 2.5,
        category: 'Coffees',
      ),
      MenuItem(
        id: 'dessert_1',
        venueId: venue.id,
        name: 'Tiramisu',
        description: 'Classic tiramisu dessert.',
        price: 7,
        category: 'Desserts',
      ),
    ];

    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          venueByIdProvider(venue.id).overrideWith((ref) async => venue),
          menuItemsProvider(venue.id).overrideWith((ref) async => items),
        ],
        child: const MaterialApp(home: MenuScreen(venueId: 'venue_search')),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Espresso'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'tiramisu');
    await tester.pump();

    expect(find.text('Espresso'), findsNothing);
    expect(find.text('Tiramisu'), findsOneWidget);
    expect(find.text('DESSERTS'), findsWidgets);
  });
}
