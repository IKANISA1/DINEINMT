import 'package:dinein_app/shared/widgets/pressable_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pressable scale can enforce a minimum touch target', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PressableScale(
              onTap: () {},
              minTouchTargetSize: const Size(44, 44),
              child: const Icon(Icons.close, size: 18),
            ),
          ),
        ),
      ),
    );

    final constrainedTarget = find.descendant(
      of: find.byType(PressableScale),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedBox &&
            widget.constraints.minWidth == 44 &&
            widget.constraints.minHeight == 44,
      ),
    );

    expect(constrainedTarget, findsOneWidget);
    expect(tester.getSize(constrainedTarget), const Size(44, 44));
  });
}
