import 'package:dinein_app/core/models/models.dart';
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
}
