import 'package:dinein_app/core/config/country_config.dart';
import 'package:dinein_app/core/config/country_runtime.dart';
import 'package:dinein_app/features/admin/auth/admin_login_screen.dart';
import 'package:dinein_app/shared/widgets/pressable_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpAdminLogin(WidgetTester tester, CountryConfig config) async {
    CountryRuntime.configure(config);
    await tester.pumpWidget(const MaterialApp(home: AdminLoginScreen()));
    await tester.pump();
  }

  PressableScale otpButton(WidgetTester tester) {
    return tester.widget<PressableScale>(
      find
          .ancestor(
            of: find.text('Get OTP'),
            matching: find.byType(PressableScale),
          )
          .last,
    );
  }

  testWidgets('Malta admin login accepts the current 9-digit admin number', (
    tester,
  ) async {
    await pumpAdminLogin(tester, CountryConfig.mt);

    await tester.enterText(find.byType(TextField).first, '771861993');
    await tester.pump();

    expect(otpButton(tester).onTap, isNotNull);
  });

  testWidgets(
    'Rwanda admin login accepts the current admin number with a leading zero',
    (tester) async {
      await pumpAdminLogin(tester, CountryConfig.rw);

      await tester.enterText(find.byType(TextField).first, '0788767816');
      await tester.pump();

      expect(otpButton(tester).onTap, isNotNull);
    },
  );
}
