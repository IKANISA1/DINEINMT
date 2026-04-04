import 'package:dinein_app/shared/widgets/shell_scroll_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'shell chrome host hides the top bar on downward scroll and restores it on upward scroll',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _ShellChromeHarness()));

      expect(find.text('visible'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -320));
      await tester.pumpAndSettle();
      expect(find.text('hidden'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, 220));
      await tester.pumpAndSettle();
      expect(find.text('visible'), findsOneWidget);
    },
  );
}

class _ShellChromeHarness extends StatefulWidget {
  const _ShellChromeHarness();

  @override
  State<_ShellChromeHarness> createState() => _ShellChromeHarnessState();
}

class _ShellChromeHarnessState extends State<_ShellChromeHarness> {
  bool _visible = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text(_visible ? 'visible' : 'hidden'),
          CollapsibleShellBar(
            visible: _visible,
            child: Container(
              height: 56,
              width: double.infinity,
              color: Colors.blue,
            ),
          ),
          Expanded(
            child: ShellScrollNotificationHost(
              onTopBarVisibilityChanged: (visible) {
                if (_visible == visible) return;
                setState(() => _visible = visible);
              },
              child: ListView.builder(
                itemCount: 40,
                itemBuilder: (context, index) => SizedBox(
                  height: 72,
                  child: Center(child: Text('row $index')),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
