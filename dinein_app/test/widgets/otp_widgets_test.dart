import 'package:ui/widgets/otp_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeMaltesePhoneLocalInput', () {
    test('keeps local 8-digit numbers unchanged', () {
      expect(normalizeMaltesePhoneLocalInput('77186193'), '77186193');
    });

    test('strips +356 and 00356 prefixes from pasted Maltese numbers', () {
      expect(normalizeMaltesePhoneLocalInput('+35677186193'), '77186193');
      expect(normalizeMaltesePhoneLocalInput('0035677186193'), '77186193');
    });

    test(
      'does not treat an 8-digit value starting with 356 as a valid local number',
      () {
        expect(isValidMaltesePhoneLocalInput('35677186'), isFalse);
      },
    );
  });

  testWidgets(
    'MaltaPhoneInput normalizes a pasted full number and enables OTP action',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _PhoneEntryHarness()));

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      await tester.enterText(textField, '+35677186193');
      await tester.pump();

      final field = tester.widget<TextField>(textField);
      expect(field.controller?.text, '77186193');

      final button = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('otp-button')),
      );
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets('OtpPillFields supports keyboard backspace navigation', (
    tester,
  ) async {
    final controllers = List.generate(6, (_) => TextEditingController());
    final focusNodes = List.generate(6, (_) => FocusNode());

    addTearDown(() {
      for (final controller in controllers) {
        controller.dispose();
      }
      for (final node in focusNodes) {
        node.dispose();
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OtpPillFields(controllers: controllers, focusNodes: focusNodes),
        ),
      ),
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '1');
    await tester.pump();

    expect(focusNodes[1].hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    expect(controllers[0].text, isEmpty);
    expect(focusNodes[0].hasFocus, isTrue);
  });
}

class _PhoneEntryHarness extends StatefulWidget {
  const _PhoneEntryHarness();

  @override
  State<_PhoneEntryHarness> createState() => _PhoneEntryHarnessState();
}

class _PhoneEntryHarnessState extends State<_PhoneEntryHarness> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            MaltaPhoneInput(
              controller: _controller,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              key: const ValueKey('otp-button'),
              onPressed: isValidMaltesePhoneLocalInput(_controller.text)
                  ? () {}
                  : null,
              child: const Text('Get OTP'),
            ),
          ],
        ),
      ),
    );
  }
}
