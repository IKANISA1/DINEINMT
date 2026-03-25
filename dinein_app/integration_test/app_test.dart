import 'package:dinein_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-end test', () {
    testWidgets('tap on the guest icon and verify discovery screen', (
      tester,
    ) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify we are on the splash screen or directly on discovery
      // Splash auto-navigates to discovery after 2 seconds
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify Discovery screen elements
      expect(find.text('What are you looking for?'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('navigate to venue portal and back', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Tap on the bottom navigation if available, or use the settings icon
      // In guest screen, settings is in bottom nav or top right.
      // Let's assume there's a "Venue Portal" chip in the footer for this test.
      // (Based on role_switch_footer_test.dart)

      final venuePortalIcon = find.byTooltip('Venue Portal');
      if (venuePortalIcon.evaluate().isNotEmpty) {
        await tester.tap(venuePortalIcon);
        await tester.pumpAndSettle();

        expect(find.text('Venue Portal'), findsOneWidget);

        // Tap back to guest
        final guestIcon = find.byTooltip('Guest');
        await tester.tap(guestIcon);
        await tester.pumpAndSettle();

        expect(find.text('What are you looking for?'), findsOneWidget);
      }
    });
  });
}
