import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';

void main() {
  group('shared widgets', () {
    testWidgets('PremiumButton shows a loader and disables taps while loading', (
      tester,
    ) async {
      var taps = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: PremiumButton(
              label: 'Submit',
              isLoading: true,
              onPressed: () => taps++,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Submit'), findsNothing);

      await tester.tap(find.byType(PremiumButton));
      await tester.pump();

      expect(taps, 0);
    });

    testWidgets('StatusBadge renders its uppercase label', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: StatusBadge(label: 'Ready'),
          ),
        ),
      );

      expect(find.text('READY'), findsOneWidget);
    });
  });
}
