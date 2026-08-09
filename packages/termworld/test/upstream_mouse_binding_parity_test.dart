import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/termworld.dart';

void main() {
  testWidgets('xterm MouseService 10', (tester) async {
    final terminal = await _pumpMouseTerminal(tester);
    expect(_cursor(tester), SystemMouseCursors.basic);

    terminal.options.mouseEventsRequireAlt = true;
    await tester.pump();
    expect(_cursor(tester), SystemMouseCursors.text);

    terminal.options.mouseEventsRequireAlt = false;
    await tester.pump();
    expect(_cursor(tester), SystemMouseCursors.basic);
  });

  testWidgets('xterm MouseService 11', (tester) async {
    await _pumpMouseTerminal(tester, mouseEventsRequireAlt: true);
    expect(_cursor(tester), SystemMouseCursors.text);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
    expect(_cursor(tester), SystemMouseCursors.basic);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
    expect(_cursor(tester), SystemMouseCursors.text);
  });

  testWidgets('xterm MouseService 12', (tester) async {
    final terminal = Terminal();
    addTearDown(terminal.dispose);
    final reports = <String>[];
    terminal.onBinary.listen(reports.add);
    await _writeAndPump(tester, terminal, '\u001b[?1003h');
    final key = GlobalKey();
    await _pumpView(tester, terminal, key, left: false);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(key)),
    );
    await tester.pump();
    await _pumpView(tester, terminal, key, left: true);
    await gesture.up();
    await tester.pump();

    expect(reports.length, 2);
    expect(reports.first.codeUnitAt(3), 0x20);
    expect(reports.last.codeUnitAt(3), 0x23);
  });
}

Future<Terminal> _pumpMouseTerminal(
  WidgetTester tester, {
  bool mouseEventsRequireAlt = false,
}) async {
  final terminal = Terminal(
    options: TerminalOptions(mouseEventsRequireAlt: mouseEventsRequireAlt),
  );
  addTearDown(terminal.dispose);
  await _writeAndPump(tester, terminal, '\u001b[?1003h');
  await _pumpView(
    tester,
    terminal,
    const ValueKey<String>('mouse-terminal-view'),
    left: false,
  );
  return terminal;
}

Future<void> _pumpView(
  WidgetTester tester,
  Terminal terminal,
  Key key, {
  required bool left,
}) => tester.pumpWidget(
  MaterialApp(
    home: Align(
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      child: SizedBox(
        width: 400,
        height: 240,
        child: TerminalView(key: key, terminal: terminal, autofocus: true),
      ),
    ),
  ),
);

Future<void> _writeAndPump(
  WidgetTester tester,
  Terminal terminal,
  String data,
) async {
  await tester.runAsync(() => terminal.writeAndWait(data));
  await tester.pump();
}

MouseCursor _cursor(WidgetTester tester) =>
    tester.widget<MouseRegion>(find.byType(MouseRegion).last).cursor;
