import 'package:dinein_app/features/admin/settings/admin_settings_screen.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSettingsScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const AdminSettingsScreen(),
      ),
    );

    // Let flutter_animate animations complete
    await tester.pumpAndSettle();
  }

  testWidgets('admin settings renders header and admin account info', (
    tester,
  ) async {
    await pumpSettingsScreen(tester);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Console profile and account controls.'), findsOneWidget);

    expect(find.text('Administrator Account'), findsOneWidget);
    expect(find.text('Full system access granted.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('admin settings renders sign out button', (tester) async {
    await pumpSettingsScreen(tester);

    final signOutFinder = find.text('Sign out');
    expect(signOutFinder, findsOneWidget);

    expect(
      find.ancestor(
        of: signOutFinder,
        matching: find.byType(PressableScale),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('admin settings renders version footer', (tester) async {
    await pumpSettingsScreen(tester);

    expect(find.text('DineIn PWA v1.0.0'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
