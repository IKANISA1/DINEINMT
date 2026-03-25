import 'package:dinein_app/shared/widgets/permission_access_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('location popup matches expected CTA copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PermissionAccessDialog(
            config: PermissionAccessDialogConfig.guestLocation(),
          ),
        ),
      ),
    );

    expect(find.text('LOCATION SHARING'), findsOneWidget);
    expect(
      find.textContaining('connect to a venue WiFi network'),
      findsOneWidget,
    );
    expect(find.text('GRANT ACCESS'), findsOneWidget);
    expect(find.text('MAYBE LATER'), findsOneWidget);
  });

  testWidgets('camera popup renders the venue access title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PermissionAccessDialog(
            config: PermissionAccessDialogConfig.venueCamera(),
          ),
        ),
      ),
    );

    expect(find.text('CAMERA ACCESS'), findsOneWidget);
    expect(find.textContaining('Capture your printed menu'), findsOneWidget);
  });

  testWidgets('BioPay camera popup renders enrollment copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PermissionAccessDialog(
            config: PermissionAccessDialogConfig.biopayCamera(),
          ),
        ),
      ),
    );

    expect(find.text('BIOPAY CAMERA ACCESS'), findsOneWidget);
    expect(
      find.textContaining('create your Rwanda payment profile'),
      findsOneWidget,
    );
  });
}
