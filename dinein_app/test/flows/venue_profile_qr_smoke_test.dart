import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/features/venue/settings/venue_profile_screen.dart';
import 'package:dinein_app/features/venue/settings/venue_table_qr_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const venue = Venue(
    id: 'venue_1',
    name: 'Ocean Pearl',
    slug: 'ocean-pearl',
    category: 'Seafood',
    description: 'Seafront dining.',
    address: '45 Tower Rd, Sliema, Malta',
    phone: '+356 2123 4567',
    revolutUrl: 'https://revolut.me/oceanpearl',
  );

  Widget buildHarness(Widget child) {
    return ProviderScope(
      overrides: [currentVenueProvider.overrideWith((ref) async => venue)],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('venue profile screen renders screenshot-aligned controls', (
    tester,
  ) async {
    await tester.pumpWidget(buildHarness(const VenueProfileScreen()));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Venue Profile'), findsOneWidget);
    expect(find.text('UPLOAD COVER'), findsOneWidget);
    expect(find.text('SAVE CHANGES'), findsOneWidget);
    expect(find.text('VENUE NAME'), findsOneWidget);
    expect(find.text('Ocean Pearl'), findsAtLeast(1));
    await tester.scrollUntilVisible(
      find.text('REVOLUT LINK'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('REVOLUT LINK'), findsOneWidget);
  });

  testWidgets('venue table QR screen renders and updates table label', (
    tester,
  ) async {
    await tester.pumpWidget(buildHarness(const VenueTableQrScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Venue QR Codes'), findsOneWidget);
    expect(find.text('Guest Menu QR'), findsOneWidget);
    expect(find.text('Venue App QR'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('table-qr-number-field')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('SCAN TO ORDER TABLE 4'), findsOneWidget);
    expect(find.text('TABLE NUMBER'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('venue-table-qr-export-boundary')),
        matching: find.text('TABLE NUMBER'),
      ),
      findsNothing,
    );

    await tester.enterText(find.byKey(const Key('table-qr-number-field')), '7');
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('SCAN TO ORDER TABLE 7'), findsOneWidget);
  });
}
